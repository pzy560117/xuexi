#!/bin/bash

# Superpower Loop Stop Hook
# Prevents session exit when a superpower-loop is active
# Feeds Claude's output back as input to continue the loop

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')

# Find the state file owned by this session.
# Supports multiple concurrent loops (e.g. parallel tasks in executing-plans)
# and scans both the new default path and legacy .claude path.
SUPERPOWER_STATE_FILE=""
ALL_CANDIDATES=()
REGISTRY_FILE="${HOME}/.claude/superpower-loop-registry.txt"

# Remove stale registry entries (best effort, never block hook flow).
prune_registry_path() {
  local target="$1"
  [[ -n "$target" ]] || return 0
  [[ -f "$REGISTRY_FILE" ]] || return 0
  local tmp="${REGISTRY_FILE}.tmp.$$"
  grep -F -x -v "$target" "$REGISTRY_FILE" > "$tmp" || true
  mv "$tmp" "$REGISTRY_FILE"
}

# Parse a candidate state file and match session ownership.
inspect_candidate() {
  local candidate="$1"
  [[ -f "$candidate" ]] || return 1
  ALL_CANDIDATES+=("$candidate")
  # Normalize UTF-8 BOM on first line before parsing frontmatter.
  local candidate_content
  candidate_content=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$candidate")
  local candidate_frontmatter
  candidate_frontmatter=$(printf '%s\n' "$candidate_content" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
  local candidate_session
  candidate_session=$(echo "$candidate_frontmatter" | grep '^session_id:' | sed 's/session_id: *//' || true)
  # Match explicit session_id, or fall through for legacy files without one.
  if [[ -z "$candidate_session" ]] || [[ "$candidate_session" == "$HOOK_SESSION" ]]; then
    SUPERPOWER_STATE_FILE="$candidate"
    return 0
  fi
  return 1
}

STATE_GLOBS=(
  "docs/runtime/superpower-loop*.local.md"
  ".claude/superpower-loop*.local.md"
)

for pattern in "${STATE_GLOBS[@]}"; do
  for candidate in $pattern; do
    if inspect_candidate "$candidate"; then
      break 2
    fi
  done
done

if [[ -z "$SUPERPOWER_STATE_FILE" ]] && [[ -f "$REGISTRY_FILE" ]]; then
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if [[ ! -f "$candidate" ]]; then
      prune_registry_path "$candidate"
      continue
    fi
    if inspect_candidate "$candidate"; then
      break
    fi
  done < "$REGISTRY_FILE"
fi

if [[ -z "$SUPERPOWER_STATE_FILE" ]]; then
  # Compatibility fallback:
  # In some environments, setup writes a non-UUID session id while hook payload
  # provides UUID session id. If there is exactly one active loop file, use it.
  if [[ ${#ALL_CANDIDATES[@]} -eq 1 ]]; then
    SUPERPOWER_STATE_FILE="${ALL_CANDIDATES[0]}"
  else
    # No active loop for this session - allow exit
    exit 0
  fi
fi

# Parse markdown frontmatter (YAML between ---) and extract values
STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: Superpower loop: State file corrupted" >&2
  echo "   File: $SUPERPOWER_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Superpower loop is stopping. Run /superpower-loop again to start fresh." >&2
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Superpower loop: State file corrupted" >&2
  echo "   File: $SUPERPOWER_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Superpower loop is stopping. Run /superpower-loop again to start fresh." >&2
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Superpower loop: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$SUPERPOWER_STATE_FILE"
  prune_registry_path "$SUPERPOWER_STATE_FILE"
  exit 0
fi

# Prefer hook-native last_assistant_message (newer Claude Code field).
# Fallback to transcript parsing for older versions.
LAST_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')

if [[ -z "$LAST_OUTPUT" ]]; then
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')

  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Read last assistant message from transcript (JSONL format - one JSON per line)
    LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100 || true)

    if [[ -n "$LAST_LINES" ]]; then
      # Parse recent lines and pull out the final text block.
      set +e
      PARSED_LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
        map(.message.content[]? | select(.type == "text") | .text) | last // ""
      ' 2>&1)
      JQ_EXIT=$?
      set -e

      if [[ $JQ_EXIT -eq 0 ]]; then
        LAST_OUTPUT="$PARSED_LAST_OUTPUT"
      fi
    fi
  fi
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  # -0777 slurps entire input, s flag makes . match newlines
  # .*? is non-greedy (takes FIRST tag), whitespace normalized
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  LAST_NON_EMPTY_LINE=$(printf '%s\n' "$LAST_OUTPUT" | awk 'NF{line=$0} END{print line}')
  LAST_NON_EMPTY_LINE=$(echo "$LAST_NON_EMPTY_LINE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # Use = for literal string comparison (not pattern matching)
  # == in [[ ]] does glob pattern matching which breaks with *, ?, [ characters
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Superpower loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    rm -f "$SUPERPOWER_STATE_FILE"
    prune_registry_path "$SUPERPOWER_STATE_FILE"
    exit 0
  fi

  # Backward compatibility:
  # Some model turns may output bare completion text without <promise> tags.
  # Accept only when the LAST non-empty line is an exact literal match.
  if [[ -z "$PROMISE_TEXT" ]] && [[ "$LAST_NON_EMPTY_LINE" = "$COMPLETION_PROMISE" ]]; then
    echo "Superpower loop: Detected legacy completion line '$COMPLETION_PROMISE' (without <promise> tag)"
    rm -f "$SUPERPOWER_STATE_FILE"
    prune_registry_path "$SUPERPOWER_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
# Skip first --- line, skip until second --- line, then print everything after
# Use i>=2 instead of i==2 to handle --- in prompt content
PROMPT_TEXT=$(printf '%s\n' "$STATE_CONTENT" | awk '/^---$/{i++; next} i>=2')

SKILL_RESOLUTION_ERROR=0
if echo "$LAST_OUTPUT" | grep -Eqi "Unknown skill:|not available as a standalone skill|Agent type .* not found"; then
  SKILL_RESOLUTION_ERROR=1
fi

if [[ -z "$PROMPT_TEXT" ]]; then
  # Fallback for phase-style state files that contain only frontmatter.
  # Derive the in-progress phase and synthesize a continuation prompt.
  CURRENT_PHASE_NAME=$(echo "$FRONTMATTER" | awk '
    /- name:/ { name=$3; gsub(/"/, "", name); next }
    /status:[[:space:]]*"in_progress"/ { print name; exit }
  ')
  CURRENT_PHASE_PROMISE=$(echo "$FRONTMATTER" | awk '
    /- name:/ { name=$3; gsub(/"/, "", name); next }
    /status:[[:space:]]*"in_progress"/ { in_progress=1; next }
    in_progress && /completion_promise:/ {
      sub(/.*completion_promise:[[:space:]]*/, "", $0);
      gsub(/"/, "", $0);
      print $0;
      exit
    }
  ')

  if [[ -n "$CURRENT_PHASE_NAME" ]]; then
    PHASE_SKILL="superpowers:${CURRENT_PHASE_NAME}"
    FALLBACK_SKILL_ROOT="${CLAUDE_PLUGIN_ROOT:-superpowers-p2r}"
    FALLBACK_SKILL_PATH="${FALLBACK_SKILL_ROOT}/skills/${CURRENT_PHASE_NAME}/SKILL.md"
    PROMPT_TEXT="Continue the active pipeline phase: ${CURRENT_PHASE_NAME}.
STRICT PROCESS:
1) Use the exact phase skill first: ${PHASE_SKILL}
2) If the skill tool cannot resolve it in this environment, immediately fallback to reading:
   ${FALLBACK_SKILL_PATH}
   and execute that skill workflow directly from file instructions.
3) Execute ONLY this phase, do not jump to next phase.
4) Before phase completion signal, update ${SUPERPOWER_STATE_FILE} safely (current phase done, next phase in_progress, current_phase index).
When this phase is genuinely complete, output the exact final line:"
    if [[ -n "$CURRENT_PHASE_PROMISE" ]]; then
      PROMPT_TEXT="${PROMPT_TEXT}
<promise>${CURRENT_PHASE_PROMISE}</promise>"
    else
      PROMPT_TEXT="${PROMPT_TEXT}
<promise>${COMPLETION_PROMISE}</promise>"
    fi
  else
    PROMPT_TEXT="Continue the active superpower loop task from ${SUPERPOWER_STATE_FILE}."
  fi
fi

if [[ "$SKILL_RESOLUTION_ERROR" -eq 1 ]]; then
  PROMPT_TEXT="${PROMPT_TEXT}

SKILL RESOLUTION RECOVERY:
- You previously hit a skill/agent resolution error.
- Do not stop. Use the fallback path-based skill execution:
  1) Read the local SKILL.md for the current phase.
  2) Follow it strictly.
  3) Continue pipeline progression without asking user to restart."
fi

# Update iteration in frontmatter (portable across macOS and Linux)
# Create temp file, then atomically replace
TEMP_FILE="${SUPERPOWER_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$SUPERPOWER_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$SUPERPOWER_STATE_FILE"

# Build system message with iteration count and completion promise info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="Superpower loop iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when statement is TRUE - do not lie to exit!)"
else
  SYSTEM_MSG="Superpower loop iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
fi

# Append completion instruction to the re-injected prompt so Claude always
# has a positive directive — not just the negative "do not lie" constraint in
# the system message. This is critical: by the time later iterations run,
# the original skill context (SKILL.md) has been compressed out of the
# conversation window. Without this, Claude sees only a bare task prompt and
# never knows it must emit the promise tag when done.
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  INJECTED_PROMPT="${PROMPT_TEXT}

---
LOOP COMPLETION REQUIRED: When the above task is genuinely complete, output the following tag as the very last line of your response — nothing after it:
<promise>${COMPLETION_PROMISE}</promise>"
else
  INJECTED_PROMPT="$PROMPT_TEXT"
fi

# Block Stop via exit code 2 and feed prompt back through stderr.
# This path is the most stable across Claude Code versions for Stop hooks.
echo "$INJECTED_PROMPT" >&2
exit 2
