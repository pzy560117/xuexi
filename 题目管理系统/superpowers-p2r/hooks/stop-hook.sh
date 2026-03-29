#!/bin/bash

# Superpower Loop Stop Hook
# Prevents session exit when a superpower-loop is active
# Feeds Claude's output back as input to continue the loop

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')

# Resolve a stable user home path across Windows PowerShell + Git Bash.
resolve_user_home() {
  local raw_home="${HOME:-}"
  if [[ -n "${USERPROFILE:-}" ]]; then
    raw_home="${USERPROFILE}"
  fi
  if command -v cygpath >/dev/null 2>&1; then
    case "$raw_home" in
      [A-Za-z]:\\*)
        raw_home="$(cygpath "$raw_home")"
        ;;
    esac
  fi
  echo "$raw_home"
}

# Find the state file owned by this session.
# Supports multiple concurrent loops (e.g. parallel tasks in executing-plans)
# and scans both the new default path and legacy .claude path.
SUPERPOWER_STATE_FILE=""
ALL_CANDIDATES=()
USER_HOME_RESOLVED="$(resolve_user_home)"
REGISTRY_FILE="${USER_HOME_RESOLVED}/.claude/superpower-loop-registry.txt"

# Remove stale registry entries (best effort, never block hook flow).
prune_registry_path() {
  local target="$1"
  [[ -n "$target" ]] || return 0
  [[ -f "$REGISTRY_FILE" ]] || return 0
  local tmp="${REGISTRY_FILE}.tmp.$$"
  grep -F -x -v "$target" "$REGISTRY_FILE" > "$tmp" || true
  mv "$tmp" "$REGISTRY_FILE"
}

# Scope registry fallback candidates to current workspace, preventing
# cross-project hijacking when multiple loop states exist globally.
workspace_match_candidate() {
  local candidate="$1"
  [[ -n "$candidate" ]] || return 1
  local candidate_abs="$candidate"
  if command -v cygpath >/dev/null 2>&1; then
    case "$candidate_abs" in
      [A-Za-z]:\\*)
        candidate_abs="$(cygpath "$candidate_abs")"
        ;;
    esac
  fi
  [[ -f "$candidate_abs" ]] || return 1
  candidate_abs="$(cd "$(dirname "$candidate_abs")" && pwd)/$(basename "$candidate_abs")"

  local project_root="$candidate_abs"
  case "$candidate_abs" in
    */docs/runtime/superpower-loop*.local.md)
      project_root="${candidate_abs%/docs/runtime/superpower-loop*.local.md}"
      ;;
    *)
      project_root="$(cd "$(dirname "$candidate_abs")" && pwd)"
      ;;
  esac

  local cwd_abs
  cwd_abs="$(pwd -P)"
  if [[ "$cwd_abs" == "$project_root"* ]] || [[ "$project_root" == "$cwd_abs"* ]]; then
    return 0
  fi
  return 1
}

# Register absolute state path into registry (idempotent).
register_registry_path() {
  local target="$1"
  [[ -n "$target" ]] || return 0
  local registry_dir
  registry_dir="$(dirname "$REGISTRY_FILE")"
  mkdir -p "$registry_dir"
  touch "$REGISTRY_FILE"
  local tmp="${REGISTRY_FILE}.tmp.$$"
  grep -F -x -v "$target" "$REGISTRY_FILE" > "$tmp" || true
  echo "$target" >> "$tmp"
  mv "$tmp" "$REGISTRY_FILE"
}

# Recovery path:
# If Phase 0 has completed but loop state is missing (bootstrap not persisted),
# reconstruct a canonical prompt2repo loop state so stop-hook can continue Phase 0.5.
recover_state_from_phase0_completion() {
  local last_output="$1"
  local marker
  marker="$(printf '%s\n' "$last_output" | awk 'NF{line=$0} END{print line}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ "$marker" != "PROMPT_PARSING_COMPLETE" ]] && [[ "$marker" != "<promise>PROMPT_PARSING_COMPLETE</promise>" ]]; then
    return 1
  fi

  # Guard: recover only when phase-0 artifacts exist in current project.
  if [[ ! -f "docs/designs/requirement-analysis.md" ]]; then
    return 1
  fi

  local recovered_state="docs/runtime/superpower-loop.local.md"
  local recovered_dir
  recovered_dir="$(dirname "$recovered_state")"
  mkdir -p "$recovered_dir"

  cat > "$recovered_state" <<EOF
---
active: true
iteration: 1
session_id: "${HOOK_SESSION}"
max_iterations: 100
completion_promise: "DELIVERY_COMPLETE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
current_phase: 1
---

# Superpower Loop State

## Phases

| # | Name | Status | Completion Promise | Skippable |
|---|------|--------|-------------------|-----------|
| 0 | prompt-parser | done | PROMPT_PARSING_COMPLETE | no |
| 1 | spec-gateway | in_progress | SPEC_COMPLETE | yes |
| 2 | writing-plans-p2r | pending | PLANNING_COMPLETE | no |
| 3 | consistency-gate | pending | ANALYSIS_COMPLETE | yes |
| 4 | executing-plans-p2r | pending | EXECUTION_COMPLETE | no |
| 5 | domain-checklist | pending | CHECKLIST_COMPLETE | yes |
| 6 | self-review | pending | SELF_REVIEW_COMPLETE | yes |
| 7 | test-gate | pending | TEST_GATE_COMPLETE | yes |
| 8 | runtime-smoke | pending | RUNTIME_SMOKE_COMPLETE | yes |
| 9 | stability-loop | pending | STABILITY_COMPLETE | yes |
| 10 | coverage-gate | pending | COVERAGE_COMPLETE | yes |
| 11 | policy-gate | pending | POLICY_COMPLETE | yes |
| 12 | delivery-packager | pending | PACKAGE_COMPLETE | yes |
| 13 | delivery-checker | pending | DELIVERY_COMPLETE | yes |
EOF

  local bootstrap_file="${recovered_dir}/superpower-loop.bootstrap.md"
  cat > "$bootstrap_file" <<EOF
# Superpower Loop Bootstrap Confirmation (Auto-Recovered)

- recovered_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- working_directory: $(pwd)
- state_file: ${recovered_state}
- source: stop-hook.sh
- reason: missing loop state after Phase 0 completion marker
EOF

  local recovered_abs
  recovered_abs="$(cd "$recovered_dir" && pwd)/$(basename "$recovered_state")"
  register_registry_path "$recovered_abs"
  SUPERPOWER_STATE_FILE="$recovered_state"
  return 0
}

# Recovery path:
# Some model turns may overwrite docs/runtime/superpower-loop.local.md with
# human-readable markdown status (no YAML frontmatter). Rebuild canonical state.
recover_state_from_legacy_status_markdown() {
  local content="$1"
  local legacy_phase
  legacy_phase=$(printf '%s\n' "$content" | awk -F'|' '
    /^\|/ {
      col1=$2; col2=$3;
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", col1);
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", col2);
      if (col1 ~ /^Phase / && toupper(col2)=="IN_PROGRESS") { print col1; exit }
    }
  ')
  [[ -n "$legacy_phase" ]] || return 1

  local phase_idx
  case "$legacy_phase" in
    "Phase 0 (prompt-parser)") phase_idx=0 ;;
    "Phase 0.5 (spec-gateway)") phase_idx=1 ;;
    "Phase 1 (writing-plans-p2r)") phase_idx=2 ;;
    "Phase 1.5 (consistency-gate)") phase_idx=3 ;;
    "Phase 2 (Implementation)"|"Phase 2 (executing-plans-p2r)") phase_idx=4 ;;
    "Phase 2.5 (domain-checklist)") phase_idx=5 ;;
    "Phase 3 (self-review)") phase_idx=6 ;;
    "Phase 3.5 (test-gate)") phase_idx=7 ;;
    "Phase 3.6 (runtime-smoke)") phase_idx=8 ;;
    "Phase 3.7 (stability-loop)") phase_idx=9 ;;
    "Phase 3.8 (coverage-gate)") phase_idx=10 ;;
    "Phase 3.9 (policy-gate)") phase_idx=11 ;;
    "Phase 4 (delivery-packager)") phase_idx=12 ;;
    "Phase 4.5 (delivery-checker)") phase_idx=13 ;;
    *) return 1 ;;
  esac

  local phase_names=(
    "prompt-parser" "spec-gateway" "writing-plans-p2r" "consistency-gate"
    "executing-plans-p2r" "domain-checklist" "self-review" "test-gate"
    "runtime-smoke" "stability-loop" "coverage-gate" "policy-gate"
    "delivery-packager" "delivery-checker"
  )
  local phase_promises=(
    "PROMPT_PARSING_COMPLETE" "SPEC_COMPLETE" "PLANNING_COMPLETE" "ANALYSIS_COMPLETE"
    "EXECUTION_COMPLETE" "CHECKLIST_COMPLETE" "SELF_REVIEW_COMPLETE" "TEST_GATE_COMPLETE"
    "RUNTIME_SMOKE_COMPLETE" "STABILITY_COMPLETE" "COVERAGE_COMPLETE" "POLICY_COMPLETE"
    "PACKAGE_COMPLETE" "DELIVERY_COMPLETE"
  )
  local phase_skippable=(
    "no" "yes" "no" "yes"
    "no" "yes" "yes" "yes"
    "yes" "yes" "yes" "yes"
    "yes" "yes"
  )

  local state_path="$SUPERPOWER_STATE_FILE"
  local state_dir
  state_dir="$(dirname "$state_path")"
  mkdir -p "$state_dir"

  {
    echo "---"
    echo "active: true"
    echo "iteration: 1"
    echo "session_id: \"${HOOK_SESSION}\""
    echo "max_iterations: 100"
    echo "completion_promise: \"DELIVERY_COMPLETE\""
    echo "started_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    echo "current_phase: ${phase_idx}"
    echo "---"
    echo
    echo "# Superpower Loop State"
    echo
    echo "## Phases"
    echo
    echo "| # | Name | Status | Completion Promise | Skippable |"
    echo "|---|------|--------|-------------------|-----------|"
    local i
    for i in "${!phase_names[@]}"; do
      local status="pending"
      if [[ "$i" -lt "$phase_idx" ]]; then
        status="done"
      elif [[ "$i" -eq "$phase_idx" ]]; then
        status="in_progress"
      fi
      echo "| ${i} | ${phase_names[$i]} | ${status} | ${phase_promises[$i]} | ${phase_skippable[$i]} |"
    done
  } > "$state_path"

  local recovered_abs
  recovered_abs="$(cd "$state_dir" && pwd)/$(basename "$state_path")"
  register_registry_path "$recovered_abs"
  return 0
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
  # Normalize YAML scalar forms: trim whitespace/newline and unwrap quotes.
  # This fixes values like session_id: "" being treated as non-empty literal.
  candidate_session=$(printf '%s' "$candidate_session" | perl -pe 's/\r$//; s/^\s+|\s+$//g; s/^"(.*)"$/$1/; s/^\x27(.*)\x27$/$1/;')
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
    candidate="${candidate%$'\r'}"
    [[ -n "$candidate" ]] || continue
    if [[ ! -f "$candidate" ]]; then
      prune_registry_path "$candidate"
      continue
    fi
    if ! workspace_match_candidate "$candidate"; then
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
    LAST_OUTPUT_HINT=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')
    if ! recover_state_from_phase0_completion "$LAST_OUTPUT_HINT"; then
      # No active loop for this session - allow exit
      exit 0
    fi
  fi
fi

# Parse markdown frontmatter (YAML between ---) and extract values
STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || true)
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || true)
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || true)

# If state file was overwritten into markdown report format, try recovery once.
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  if recover_state_from_legacy_status_markdown "$STATE_CONTENT"; then
    STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
    FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
    ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || true)
    MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || true)
    COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || true)
  fi
fi

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
  # Extract text from first <promise>...</promise> tag only.
  # Keep empty when tags are absent so legacy bare-line fallback can trigger.
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -ne '
    if (/<promise>(.*?)<\/promise>/s) {
      $v = $1;
      $v =~ s/^\s+|\s+$//g;
      $v =~ s/\s+/ /g;
      print $v;
    }
  ' 2>/dev/null || true)
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

# Derive in-progress phase from YAML frontmatter first.
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

# Fallback: derive in-progress phase from markdown phase table.
if [[ -z "$CURRENT_PHASE_NAME" ]]; then
  CURRENT_PHASE_NAME=$(printf '%s\n' "$STATE_CONTENT" | awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      name=$3; status=$4;
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name);
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status);
      if (status=="in_progress") { print name; exit }
    }
  ')
  CURRENT_PHASE_PROMISE=$(printf '%s\n' "$STATE_CONTENT" | awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      status=$4; promise=$5;
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status);
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", promise);
      if (status=="in_progress") { print promise; exit }
    }
  ')
fi

# Synthesize continuation prompt for loop-state files (YAML-only or markdown table).
SHOULD_SYNTHESIZE=0
if [[ -z "$PROMPT_TEXT" ]]; then
  SHOULD_SYNTHESIZE=1
elif printf '%s\n' "$STATE_CONTENT" | grep -q '^## Phases'; then
  SHOULD_SYNTHESIZE=1
fi

if [[ "$SHOULD_SYNTHESIZE" -eq 1 ]]; then
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
