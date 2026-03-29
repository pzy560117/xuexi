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

PHASE_NAMES=(
  "prompt-parser" "spec-gateway" "writing-plans-p2r" "consistency-gate"
  "executing-plans-p2r" "domain-checklist" "self-review" "test-gate"
  "runtime-smoke" "stability-loop" "coverage-gate" "policy-gate"
  "delivery-packager" "delivery-checker"
)
PHASE_PROMISES=(
  "PROMPT_PARSING_COMPLETE" "SPEC_COMPLETE" "PLANNING_COMPLETE" "ANALYSIS_COMPLETE"
  "EXECUTION_COMPLETE" "CHECKLIST_COMPLETE" "SELF_REVIEW_COMPLETE" "TEST_GATE_COMPLETE"
  "RUNTIME_SMOKE_COMPLETE" "STABILITY_COMPLETE" "COVERAGE_COMPLETE" "POLICY_COMPLETE"
  "PACKAGE_COMPLETE" "DELIVERY_COMPLETE"
)
PHASE_SKIPPABLE=(
  "no" "yes" "no" "yes"
  "no" "yes" "yes" "yes"
  "yes" "yes" "yes" "yes"
  "yes" "yes"
)

phase_index_from_name() {
  local raw_name="$1"
  local normalized
  normalized=$(printf '%s' "$raw_name" | tr '[:upper:]' '[:lower:]')
  normalized=$(printf '%s' "$normalized" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  normalized=$(printf '%s' "$normalized" | sed 's/[[:space:]]\+/ /g')

  case "$normalized" in
    "prompt-parser"|"prompt parser") echo 0 ;;
    "spec-gateway"|"spec gateway") echo 1 ;;
    "writing-plans-p2r"|"writing-plans"|"writing plans p2r"|"writing plans") echo 2 ;;
    "consistency-gate"|"consistency gate") echo 3 ;;
    "executing-plans-p2r"|"executing-plans"|"executing plans p2r"|"executing plans"|"implementation") echo 4 ;;
    "domain-checklist"|"domain checklist") echo 5 ;;
    "self-review"|"self review") echo 6 ;;
    "test-gate"|"test gate") echo 7 ;;
    "runtime-smoke"|"runtime smoke") echo 8 ;;
    "stability-loop"|"stability loop") echo 9 ;;
    "coverage-gate"|"coverage gate") echo 10 ;;
    "policy-gate"|"policy gate") echo 11 ;;
    "delivery-packager"|"delivery packager") echo 12 ;;
    "delivery-checker"|"delivery checker") echo 13 ;;
    *)
      return 1
      ;;
  esac
}

write_canonical_state() {
  local state_path="$1"
  local phase_idx="$2"
  local iteration_value="${3:-1}"
  local max_iterations_value="${4:-100}"
  local completion_promise_value="${5:-DELIVERY_COMPLETE}"
  local started_at_value="${6:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  local session_value="${7:-$HOOK_SESSION}"

  if [[ ! "$phase_idx" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  local last_idx
  last_idx=$((${#PHASE_NAMES[@]} - 1))
  if [[ "$phase_idx" -lt 0 ]] || [[ "$phase_idx" -gt "$last_idx" ]]; then
    return 1
  fi

  local state_dir
  state_dir="$(dirname "$state_path")"
  mkdir -p "$state_dir"

  {
    echo "---"
    echo "active: true"
    echo "iteration: ${iteration_value}"
    echo "session_id: \"${session_value}\""
    echo "max_iterations: ${max_iterations_value}"
    echo "completion_promise: \"${completion_promise_value}\""
    echo "started_at: \"${started_at_value}\""
    echo "current_phase: ${phase_idx}"
    echo "phases:"
    local i
    local status
    local skippable
    for i in "${!PHASE_NAMES[@]}"; do
      status="pending"
      if [[ "$i" -lt "$phase_idx" ]]; then
        status="done"
      elif [[ "$i" -eq "$phase_idx" ]]; then
        status="in_progress"
      fi
      skippable="false"
      if [[ "${PHASE_SKIPPABLE[$i]}" == "yes" ]]; then
        skippable="true"
      fi
      echo "  - name: \"${PHASE_NAMES[$i]}\""
      echo "    status: \"${status}\""
      echo "    completion_promise: \"${PHASE_PROMISES[$i]}\""
      echo "    skippable: ${skippable}"
    done
    echo "---"
    echo
    echo "# Superpower Loop State"
    echo
    echo "## Phases"
  } > "$state_path"

  return 0
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
  write_canonical_state "$recovered_state" 1 1 100 "DELIVERY_COMPLETE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_SESSION"

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
  local state_path="$SUPERPOWER_STATE_FILE"
  local state_dir
  state_dir="$(dirname "$state_path")"
  mkdir -p "$state_dir"

  write_canonical_state "$state_path" "$phase_idx" 1 100 "DELIVERY_COMPLETE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_SESSION"

  local recovered_abs
  recovered_abs="$(cd "$state_dir" && pwd)/$(basename "$state_path")"
  register_registry_path "$recovered_abs"
  return 0
}

# Recovery path:
# Some runs rewrite state into runtime report markdown format, for example:
# - **current_phase_index**: 1
# - **next_phase**: writing-plans-p2r (Phase 2)
# Convert this format back into canonical YAML phase state.
recover_state_from_runtime_status_markdown() {
  local content="$1"

  if ! printf '%s\n' "$content" | grep -Eq '^#[[:space:]]+Superpower Loop Runtime State'; then
    return 1
  fi

  local current_phase_index
  local current_phase_name
  local next_phase_name
  local target_idx=""

  current_phase_index=$(printf '%s\n' "$content" | sed -n 's/.*\*\*current_phase_index\*\*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -n 1)
  current_phase_name=$(printf '%s\n' "$content" | sed -n 's/.*\*\*current_phase\*\*:[[:space:]]*\([^()]*\).*/\1/p' | head -n 1 | sed 's/^[[:space:]-]*//; s/[[:space:]]*$//')
  next_phase_name=$(printf '%s\n' "$content" | sed -n 's/.*\*\*next_phase\*\*:[[:space:]]*\([^()]*\).*/\1/p' | head -n 1 | sed 's/^[[:space:]-]*//; s/[[:space:]]*$//')

  if [[ "$current_phase_index" =~ ^[0-9]+$ ]]; then
    target_idx="$current_phase_index"
  fi

  if [[ -z "$target_idx" ]] && [[ -n "$current_phase_name" ]]; then
    target_idx=$(phase_index_from_name "$current_phase_name" || true)
  fi

  if [[ -z "$target_idx" ]] && [[ -n "$next_phase_name" ]]; then
    target_idx=$(phase_index_from_name "$next_phase_name" || true)
  fi

  if [[ ! "$target_idx" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  local state_path="$SUPERPOWER_STATE_FILE"
  local state_dir
  state_dir="$(dirname "$state_path")"
  mkdir -p "$state_dir"

  write_canonical_state "$state_path" "$target_idx" 1 100 "DELIVERY_COMPLETE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_SESSION"

  local recovered_abs
  recovered_abs="$(cd "$state_dir" && pwd)/$(basename "$state_path")"
  register_registry_path "$recovered_abs"
  return 0
}

# Parse YAML phase blocks from frontmatter and expose current/next phase metadata.
# Globals produced:
#   CURRENT_PHASE_INDEX, CURRENT_PHASE_NAME, CURRENT_PHASE_PROMISE,
#   NEXT_PENDING_PHASE_INDEX, LAST_PHASE_INDEX
parse_phase_metadata_from_frontmatter() {
  local frontmatter="$1"
  CURRENT_PHASE_INDEX=-1
  CURRENT_PHASE_NAME=""
  CURRENT_PHASE_PROMISE=""
  NEXT_PENDING_PHASE_INDEX=-1
  LAST_PHASE_INDEX=-1
  IN_PROGRESS_COUNT=0

  local rows=()
  local row
  while IFS= read -r row; do
    rows+=("$row")
  done < <(printf '%s\n' "$frontmatter" | awk '
    BEGIN { idx=-1; name=""; status=""; promise="" }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      if (idx >= 0) {
        print idx "\t" name "\t" status "\t" promise
      }
      idx++
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      name=line
      status=""
      promise=""
      next
    }
    idx >= 0 && /^[[:space:]]*status:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*status:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      status=line
      next
    }
    idx >= 0 && /^[[:space:]]*completion_promise:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*completion_promise:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      promise=line
      next
    }
    END {
      if (idx >= 0) {
        print idx "\t" name "\t" status "\t" promise
      }
    }
  ')

  if [[ ${#rows[@]} -eq 0 ]]; then
    return 1
  fi

  local current_found=0
  local i
  local name
  local status
  local promise
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r i name status promise <<< "$row"
    LAST_PHASE_INDEX="$i"
    if [[ "$status" == "in_progress" ]]; then
      IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    fi
    if [[ "$status" == "in_progress" ]] && [[ "$CURRENT_PHASE_INDEX" -lt 0 ]]; then
      CURRENT_PHASE_INDEX="$i"
      CURRENT_PHASE_NAME="$name"
      CURRENT_PHASE_PROMISE="$promise"
      current_found=1
      continue
    fi
    if [[ "$current_found" -eq 1 ]] && [[ "$NEXT_PENDING_PHASE_INDEX" -lt 0 ]] && [[ "$status" == "pending" ]]; then
      NEXT_PENDING_PHASE_INDEX="$i"
    fi
  done

  return 0
}

# Fallback parser for markdown phase table format.
parse_phase_metadata_from_markdown_table() {
  local content="$1"
  CURRENT_PHASE_INDEX=-1
  CURRENT_PHASE_NAME=""
  CURRENT_PHASE_PROMISE=""
  NEXT_PENDING_PHASE_INDEX=-1
  LAST_PHASE_INDEX=-1
  IN_PROGRESS_COUNT=0

  local rows=()
  local row
  while IFS= read -r row; do
    rows+=("$row")
  done < <(printf '%s\n' "$content" | awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      idx=$2; name=$3; status=$4; promise=$5
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", idx)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", promise)
      print idx "\t" name "\t" status "\t" promise
    }
  ')

  if [[ ${#rows[@]} -eq 0 ]]; then
    return 1
  fi

  local current_found=0
  local i
  local name
  local status
  local promise
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r i name status promise <<< "$row"
    LAST_PHASE_INDEX="$i"
    if [[ "$status" == "in_progress" ]]; then
      IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    fi
    if [[ "$status" == "in_progress" ]] && [[ "$CURRENT_PHASE_INDEX" -lt 0 ]]; then
      CURRENT_PHASE_INDEX="$i"
      CURRENT_PHASE_NAME="$name"
      CURRENT_PHASE_PROMISE="$promise"
      current_found=1
      continue
    fi
    if [[ "$current_found" -eq 1 ]] && [[ "$NEXT_PENDING_PHASE_INDEX" -lt 0 ]] && [[ "$status" == "pending" ]]; then
      NEXT_PENDING_PHASE_INDEX="$i"
    fi
  done

  return 0
}

# Persist phase advancement directly in state file.
advance_phase_in_state_file() {
  local state_file="$1"
  local current_idx="$2"
  local next_idx="$3"
  local tmp_file="${state_file}.phase.$$"

  awk -v ci="$current_idx" -v ni="$next_idx" '
    BEGIN { in_frontmatter=0; phase=-1 }
    NR==1 { sub(/^\xef\xbb\xbf/, "") }
    $0 == "---" {
      if (in_frontmatter == 0) { in_frontmatter=1; print; next }
      if (in_frontmatter == 1) { in_frontmatter=2; print; next }
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      phase++
      print
      next
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*status:[[:space:]]*/ {
      if (phase == ci) {
        sub(/status:.*/, "status: \"done\"")
      } else if (phase == ni) {
        sub(/status:.*/, "status: \"in_progress\"")
      }
      print
      next
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*current_phase:[[:space:]]*/ {
      if (ni >= 0) {
        sub(/current_phase:.*/, "current_phase: " ni)
      } else {
        sub(/current_phase:.*/, "current_phase: " ci)
      }
      print
      next
    }
    { print }
  ' "$state_file" > "$tmp_file"

  mv "$tmp_file" "$state_file"
}

# Ensure only one phase stays in_progress. Extra in_progress phases are
# normalized to pending to avoid ambiguous auto-advance behavior.
normalize_multiple_in_progress_in_state() {
  local state_file="$1"
  local keep_idx="$2"
  local tmp_file="${state_file}.normalize.$$"

  awk -v ki="$keep_idx" '
    BEGIN { in_frontmatter=0; phase=-1 }
    NR==1 { sub(/^\xef\xbb\xbf/, "") }
    $0 == "---" {
      if (in_frontmatter == 0) { in_frontmatter=1; print; next }
      if (in_frontmatter == 1) { in_frontmatter=2; print; next }
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      phase++
      print
      next
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*status:[[:space:]]*/ {
      if (phase != ki && $0 ~ /in_progress/) {
        sub(/status:.*/, "status: \"pending\"")
      }
      print
      next
    }
    { print }
  ' "$state_file" > "$tmp_file"

  mv "$tmp_file" "$state_file"
}

# Keep current_phase aligned with the detected in_progress phase index.
sync_current_phase_index_in_state() {
  local state_file="$1"
  local idx="$2"
  local tmp_file="${state_file}.sync.$$"

  sed "s/^current_phase: .*/current_phase: ${idx}/" "$state_file" > "$tmp_file"
  mv "$tmp_file" "$state_file"
}

# Promote first pending phase to in_progress when state file has no active phase.
promote_first_pending_to_in_progress() {
  local state_file="$1"
  local pending_idx
  pending_idx=$(awk '
    BEGIN { in_frontmatter=0; phase=-1 }
    NR==1 { sub(/^\xef\xbb\xbf/, "") }
    $0 == "---" {
      if (in_frontmatter == 0) { in_frontmatter=1; next }
      if (in_frontmatter == 1) { in_frontmatter=2; next }
    }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { phase++; next }
    in_frontmatter == 1 && $0 ~ /^[[:space:]]*status:[[:space:]]*/ {
      if ($0 ~ /pending/) { print phase; exit }
    }
  ' "$state_file")

  if [[ -n "$pending_idx" ]] && [[ "$pending_idx" =~ ^[0-9]+$ ]]; then
    local tmp_file="${state_file}.promote.$$"
    awk -v pi="$pending_idx" '
      BEGIN { in_frontmatter=0; phase=-1 }
      NR==1 { sub(/^\xef\xbb\xbf/, "") }
      $0 == "---" {
        if (in_frontmatter == 0) { in_frontmatter=1; print; next }
        if (in_frontmatter == 1) { in_frontmatter=2; print; next }
      }
      in_frontmatter == 1 && $0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
        phase++
        print
        next
      }
      in_frontmatter == 1 && $0 ~ /^[[:space:]]*status:[[:space:]]*/ {
        if (phase == pi) {
          sub(/status:.*/, "status: \"in_progress\"")
        }
        print
        next
      }
      in_frontmatter == 1 && $0 ~ /^[[:space:]]*current_phase:[[:space:]]*/ {
        sub(/current_phase:.*/, "current_phase: " pi)
        print
        next
      }
      { print }
    ' "$state_file" > "$tmp_file"
    mv "$tmp_file" "$state_file"
    return 0
  fi
  return 1
}

phase_label_from_index() {
  local idx="$1"
  case "$idx" in
    0) echo "Phase 0" ;;
    1) echo "Phase 0.5" ;;
    2) echo "Phase 1" ;;
    3) echo "Phase 1.5" ;;
    4) echo "Phase 2" ;;
    5) echo "Phase 2.5" ;;
    6) echo "Phase 3" ;;
    7) echo "Phase 3.5" ;;
    8) echo "Phase 3.6" ;;
    9) echo "Phase 3.7" ;;
    10) echo "Phase 3.8" ;;
    11) echo "Phase 3.9" ;;
    12) echo "Phase 4" ;;
    13) echo "Phase 4.5" ;;
    *) echo "" ;;
  esac
}

latest_task_dir() {
  ls -1dt TASK-* 2>/dev/null | head -n 1
}

phase_artifacts_ok() {
  local phase="$1"
  local missing=()
  local f

  case "$phase" in
    "prompt-parser")
      for f in "docs/designs/_meta.md" "docs/designs/requirement-analysis.md" "metadata.draft.json" "questions.md"; do
        [[ -f "$f" ]] || missing+=("$f")
      done
      ;;
    "spec-gateway")
      for f in "docs/specs/spec.md" "docs/specs/checklists/requirements.md"; do
        [[ -f "$f" ]] || missing+=("$f")
      done
      ;;
    "writing-plans-p2r")
      for f in "docs/designs/bdd-specs.md" "docs/designs/architecture.md" "docs/designs/best-practices.md" "docs/plans/_index.md"; do
        [[ -f "$f" ]] || missing+=("$f")
      done
      compgen -G "docs/plans/task-*.md" > /dev/null || missing+=("docs/plans/task-*.md")
      ;;
    "consistency-gate")
      [[ -f "docs/specs/analysis-report.md" ]] || missing+=("docs/specs/analysis-report.md")
      ;;
    "executing-plans-p2r")
      [[ -f "docs/plans/_index.md" ]] || missing+=("docs/plans/_index.md")
      if [[ -f "docs/plans/_index.md" ]] && grep -Eq '\|\s*pending\s*\|' "docs/plans/_index.md"; then
        missing+=("docs/plans/_index.md(no pending)")
      fi
      ;;
    "domain-checklist")
      for f in "docs/specs/checklists/security.md" "docs/specs/checklists/code_quality.md" "docs/specs/checklists/api.md" "docs/specs/checklists/opensource.md" "docs/specs/checklists/execution-report.md"; do
        [[ -f "$f" ]] || missing+=("$f")
      done
      ;;
    "self-review")
      [[ -f ".tmp/self-review-report.md" ]] || missing+=(".tmp/self-review-report.md")
      ;;
    "test-gate")
      [[ -f ".tmp/test-gate-report.md" ]] || missing+=(".tmp/test-gate-report.md")
      ;;
    "runtime-smoke")
      [[ -f ".tmp/runtime-smoke-report.md" ]] || missing+=(".tmp/runtime-smoke-report.md")
      ;;
    "stability-loop")
      [[ -f ".tmp/stability-loop-report.md" ]] || missing+=(".tmp/stability-loop-report.md")
      ;;
    "coverage-gate")
      [[ -f ".tmp/coverage-gate-report.md" ]] || missing+=(".tmp/coverage-gate-report.md")
      ;;
    "policy-gate")
      [[ -f ".tmp/policy-gate-report.md" ]] || missing+=(".tmp/policy-gate-report.md")
      ;;
    "delivery-packager")
      local d
      d="$(latest_task_dir)"
      [[ -n "$d" ]] || missing+=("TASK-*")
      [[ -n "$d" && -d "$d/repo" ]] || missing+=("TASK-*/repo")
      [[ -n "$d" && -f "$d/metadata.json" ]] || missing+=("TASK-*/metadata.json")
      ;;
    "delivery-checker")
      local d2
      d2="$(latest_task_dir)"
      [[ -n "$d2" ]] || missing+=("TASK-*")
      [[ -n "$d2" && -f "$d2/delivery-check-report.md" ]] || missing+=("TASK-*/delivery-check-report.md")
      ;;
    *)
      ;;
  esac

  if [[ ${#missing[@]} -gt 0 ]]; then
    PHASE_ARTIFACTS_MISSING="$(printf '%s, ' "${missing[@]}")"
    PHASE_ARTIFACTS_MISSING="${PHASE_ARTIFACTS_MISSING%, }"
    return 1
  fi
  PHASE_ARTIFACTS_MISSING=""
  return 0
}

output_has_explicit_promise_signal() {
  local token="$1"
  [[ -n "$token" ]] || return 1

  if [[ "$LAST_NON_EMPTY_LINE" =~ ^\<promise\>[[:space:]]*${token}[[:space:]]*\<\/promise\>$ ]]; then
    return 0
  fi
  if [[ "$LAST_NON_EMPTY_LINE" == "$token" ]]; then
    return 0
  fi

  if [[ "$LAST_OUTPUT" =~ \<promise\>[[:space:]]*${token}[[:space:]]*\<\/promise\> ]]; then
    return 0
  fi
  if [[ "$LAST_OUTPUT" =~ (^|[[:space:][:punct:]])${token}([[:space:][:punct:]]|$) ]]; then
    return 0
  fi
  if [[ "$LAST_OUTPUT" == *"\"promise\""* ]] && [[ "$LAST_OUTPUT" == *"\"${token}\""* ]]; then
    return 0
  fi
  return 1
}

output_contains_completion_word() {
  local lower_text
  lower_text=$(printf '%s' "$LAST_OUTPUT" | tr '[:upper:]' '[:lower:]')
  if [[ "$lower_text" == *"complete"* ]] || [[ "$lower_text" == *"completed"* ]] || [[ "$lower_text" == *"done"* ]] || [[ "$lower_text" == *"finish"* ]] || [[ "$lower_text" == *"finished"* ]] || [[ "$lower_text" == *"pass"* ]]; then
    return 0
  fi
  if [[ "$LAST_OUTPUT" == *"通过"* ]] || [[ "$LAST_OUTPUT" == *"完成"* ]] || [[ "$LAST_OUTPUT" == *"已完成"* ]]; then
    return 0
  fi
  return 1
}

output_has_phase_completion_hint() {
  local phase_label="$1"
  local phase_name="$2"
  local token="$3"

  local lower
  lower=$(printf '%s' "$LAST_OUTPUT" | tr '[:upper:]' '[:lower:]')
  local token_words
  token_words=$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]' | tr '_' ' ')

  if [[ "$lower" == *"$token_words"* ]]; then
    return 0
  fi

  local phase_label_lower
  phase_label_lower=$(printf '%s' "$phase_label" | tr '[:upper:]' '[:lower:]')
  if [[ -n "$phase_label_lower" ]] && [[ "$lower" == *"$phase_label_lower"* ]] && output_contains_completion_word; then
    return 0
  fi

  local phase_name_lower
  phase_name_lower=$(printf '%s' "$phase_name" | tr '[:upper:]' '[:lower:]')
  if [[ -n "$phase_name_lower" ]] && [[ "$lower" == *"$phase_name_lower"* ]] && output_contains_completion_word; then
    return 0
  fi

  return 1
}

output_has_global_completion_hint() {
  local lower
  lower=$(printf '%s' "$LAST_OUTPUT" | tr '[:upper:]' '[:lower:]')
  if [[ "$lower" == *"all phases completed"* ]] || [[ "$lower" == *"pipeline has completed"* ]] || [[ "$lower" == *"pipeline completed"* ]] || [[ "$lower" == *"delivery complete"* ]] || [[ "$LAST_OUTPUT" == *"DELIVERY_COMPLETE"* ]] || [[ "$LAST_OUTPUT" == *"全部阶段完成"* ]] || [[ "$LAST_OUTPUT" == *"流水线完成"* ]] || [[ "$LAST_OUTPUT" == *"交付完成"* ]]; then
    return 0
  fi
  return 1
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
STATE_SESSION_ID=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' | sed 's/^"\(.*\)"$/\1/' || true)
STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || true)

# If state file was overwritten into markdown report format, try recovery once.
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  if recover_state_from_legacy_status_markdown "$STATE_CONTENT" || recover_state_from_runtime_status_markdown "$STATE_CONTENT"; then
    STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
    FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
    ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || true)
    MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || true)
    COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || true)
    STATE_SESSION_ID=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' | sed 's/^"\(.*\)"$/\1/' || true)
    STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || true)
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

# Derive current/next phase metadata early (YAML first, markdown fallback).
if ! parse_phase_metadata_from_frontmatter "$FRONTMATTER"; then
  parse_phase_metadata_from_markdown_table "$STATE_CONTENT" || true
fi

# Self-heal: convert non-YAML phase states (table/report style) into canonical YAML.
if [[ "${CURRENT_PHASE_INDEX:--1}" =~ ^[0-9]+$ ]] && ! printf '%s\n' "$FRONTMATTER" | grep -Eq '^[[:space:]]*-[[:space:]]*name:[[:space:]]*'; then
  if [[ -z "$STATE_SESSION_ID" ]] || [[ "$STATE_SESSION_ID" == "null" ]]; then
    STATE_SESSION_ID="$HOOK_SESSION"
  fi
  if [[ -z "$STARTED_AT" ]] || [[ "$STARTED_AT" == "null" ]]; then
    STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
  if [[ -z "$COMPLETION_PROMISE" ]] || [[ "$COMPLETION_PROMISE" == "null" ]]; then
    COMPLETION_PROMISE="DELIVERY_COMPLETE"
  fi

  write_canonical_state "$SUPERPOWER_STATE_FILE" "$CURRENT_PHASE_INDEX" "$ITERATION" "$MAX_ITERATIONS" "$COMPLETION_PROMISE" "$STARTED_AT" "$STATE_SESSION_ID"
  STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
  FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
  parse_phase_metadata_from_frontmatter "$FRONTMATTER" || parse_phase_metadata_from_markdown_table "$STATE_CONTENT" || true
fi

# Self-heal: ensure only one in_progress exists.
if [[ "${IN_PROGRESS_COUNT:-0}" -gt 1 ]] && [[ "${CURRENT_PHASE_INDEX:--1}" =~ ^[0-9]+$ ]]; then
  echo "Warning: Detected multiple in_progress phases; normalizing to phase index ${CURRENT_PHASE_INDEX}." >&2
  normalize_multiple_in_progress_in_state "$SUPERPOWER_STATE_FILE" "$CURRENT_PHASE_INDEX"
  STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
  FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
  parse_phase_metadata_from_frontmatter "$FRONTMATTER" || parse_phase_metadata_from_markdown_table "$STATE_CONTENT" || true
fi

# Self-heal: if no active phase exists but pending phases remain, auto-promote first pending.
if [[ "${CURRENT_PHASE_INDEX:--1}" -lt 0 ]]; then
  if promote_first_pending_to_in_progress "$SUPERPOWER_STATE_FILE"; then
    echo "Warning: No in_progress phase found; auto-promoted first pending phase." >&2
    STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
    FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
    parse_phase_metadata_from_frontmatter "$FRONTMATTER" || parse_phase_metadata_from_markdown_table "$STATE_CONTENT" || true
  fi
fi

# Keep declared current_phase and detected in_progress phase aligned.
DECLARED_CURRENT_PHASE=$(echo "$FRONTMATTER" | grep '^current_phase:' | sed 's/current_phase: *//' || true)
if [[ "$DECLARED_CURRENT_PHASE" =~ ^[0-9]+$ ]] && [[ "${CURRENT_PHASE_INDEX:- -1}" =~ ^[0-9]+$ ]] && [[ "$DECLARED_CURRENT_PHASE" -ne "$CURRENT_PHASE_INDEX" ]]; then
  echo "Warning: current_phase index mismatch (declared=${DECLARED_CURRENT_PHASE}, detected=${CURRENT_PHASE_INDEX}); syncing." >&2
  sync_current_phase_index_in_state "$SUPERPOWER_STATE_FILE" "$CURRENT_PHASE_INDEX"
  STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
  FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
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

# Extract text from first <promise>...</promise> tag only.
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

PHASE_COMPLETION_SIGNAL=0
PHASE_SIGNAL_REASON=""
PHASE_VALIDATION_NOTE=""

CURRENT_PHASE_LABEL="$(phase_label_from_index "${CURRENT_PHASE_INDEX:--1}")"

if [[ -n "$CURRENT_PHASE_PROMISE" ]]; then
  if output_has_explicit_promise_signal "$CURRENT_PHASE_PROMISE"; then
    if phase_artifacts_ok "$CURRENT_PHASE_NAME"; then
      PHASE_COMPLETION_SIGNAL=1
      PHASE_SIGNAL_REASON="explicit-promise"
    else
      PHASE_VALIDATION_NOTE="Detected explicit signal for ${CURRENT_PHASE_NAME} but required artifacts are missing: ${PHASE_ARTIFACTS_MISSING}"
      echo "Warning: ${PHASE_VALIDATION_NOTE}" >&2
    fi
  elif output_has_phase_completion_hint "$CURRENT_PHASE_LABEL" "$CURRENT_PHASE_NAME" "$CURRENT_PHASE_PROMISE"; then
    if phase_artifacts_ok "$CURRENT_PHASE_NAME"; then
      PHASE_COMPLETION_SIGNAL=1
      PHASE_SIGNAL_REASON="heuristic-phase-complete"
    else
      PHASE_VALIDATION_NOTE="Detected heuristic completion hint for ${CURRENT_PHASE_NAME}, but artifacts are incomplete: ${PHASE_ARTIFACTS_MISSING}"
      echo "Warning: ${PHASE_VALIDATION_NOTE}" >&2
    fi
  fi
fi

# Phase-level completion should advance the loop state even when model forgot
# to manually edit docs/runtime/superpower-loop.local.md.
if [[ "$PHASE_COMPLETION_SIGNAL" -eq 1 ]]; then
  if [[ "$NEXT_PENDING_PHASE_INDEX" -ge 0 ]]; then
    echo "Superpower loop: Phase '${CURRENT_PHASE_NAME}' completed (${PHASE_SIGNAL_REASON}), auto-advancing to phase index ${NEXT_PENDING_PHASE_INDEX}."
    advance_phase_in_state_file "$SUPERPOWER_STATE_FILE" "$CURRENT_PHASE_INDEX" "$NEXT_PENDING_PHASE_INDEX"
    STATE_CONTENT=$(awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {print}' "$SUPERPOWER_STATE_FILE")
    FRONTMATTER=$(printf '%s\n' "$STATE_CONTENT" | sed -n '/^---$/,/^---$/{ /^---$/d; p; }')
    parse_phase_metadata_from_frontmatter "$FRONTMATTER" || parse_phase_metadata_from_markdown_table "$STATE_CONTENT" || true
  else
    echo "Superpower loop: Final phase '${CURRENT_PHASE_NAME}' completed (${PHASE_SIGNAL_REASON})."
    rm -f "$SUPERPOWER_STATE_FILE"
    prune_registry_path "$SUPERPOWER_STATE_FILE"
    exit 0
  fi
fi

GLOBAL_COMPLETION_SIGNAL=0
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  if output_has_explicit_promise_signal "$COMPLETION_PROMISE"; then
    GLOBAL_COMPLETION_SIGNAL=1
  elif output_has_global_completion_hint; then
    # Heuristic global completion requires delivery-check artifacts in final stage.
    if phase_artifacts_ok "delivery-checker"; then
      GLOBAL_COMPLETION_SIGNAL=1
    fi
  fi
fi

# Global completion promise can terminate only when loop is truly at final phase
# (or non-phase legacy mode). This prevents accidental early DELIVERY_COMPLETE.
if [[ "$GLOBAL_COMPLETION_SIGNAL" -eq 1 ]]; then
  if [[ -z "$CURRENT_PHASE_PROMISE" ]] || [[ "$CURRENT_PHASE_PROMISE" = "$COMPLETION_PROMISE" ]] || [[ "$NEXT_PENDING_PHASE_INDEX" -lt 0 ]]; then
    echo "Superpower loop: Detected global completion '$COMPLETION_PROMISE'."
    rm -f "$SUPERPOWER_STATE_FILE"
    prune_registry_path "$SUPERPOWER_STATE_FILE"
    exit 0
  else
    echo "Warning: Ignoring early global completion '$COMPLETION_PROMISE' while current phase is '${CURRENT_PHASE_NAME}'." >&2
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

# Synthesize continuation prompt for loop-state files (YAML-only or markdown table).
SHOULD_SYNTHESIZE=0
if [[ -z "$PROMPT_TEXT" ]]; then
  SHOULD_SYNTHESIZE=1
elif printf '%s\n' "$STATE_CONTENT" | grep -q '^## Phases'; then
  SHOULD_SYNTHESIZE=1
elif printf '%s\n' "$FRONTMATTER" | grep -Eq '^[[:space:]]*phases:[[:space:]]*$'; then
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

if [[ -n "${PHASE_VALIDATION_NOTE:-}" ]]; then
  PROMPT_TEXT="${PROMPT_TEXT}

PHASE COMPLETION BLOCKED:
- ${PHASE_VALIDATION_NOTE}
- Please finish missing artifacts first, then output the phase completion promise again."
fi

# Update iteration in frontmatter (portable across macOS and Linux)
# Create temp file, then atomically replace
TEMP_FILE="${SUPERPOWER_STATE_FILE}.tmp.$$"
awk -v ni="$NEXT_ITERATION" '
  NR==1 { sub(/^\xef\xbb\xbf/, "") }
  /^iteration:[[:space:]]*/ {
    sub(/^iteration:.*/, "iteration: " ni)
  }
  { print }
' "$SUPERPOWER_STATE_FILE" > "$TEMP_FILE"
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
