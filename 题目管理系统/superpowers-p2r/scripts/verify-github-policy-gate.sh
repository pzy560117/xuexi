#!/usr/bin/env bash

# GitHub policy gate verifier
# Validates local CI policy files and optionally checks GitHub branch protection.

set -euo pipefail

# Parse CLI arguments and defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/policy-gate-report.md"
  STRICT_MODE="false"
  REQUIRED_CHECKS="test-gate,runtime-smoke,stability-loop,coverage-gate,delivery-check"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-dir)
        REPO_DIR="$2"
        shift 2
        ;;
      --report-file)
        REPORT_FILE="$2"
        shift 2
        ;;
      --strict)
        STRICT_MODE="$2"
        shift 2
        ;;
      --required-checks)
        REQUIRED_CHECKS="$2"
        shift 2
        ;;
      -h|--help)
        cat <<'HELP'
Usage: verify-github-policy-gate.sh [options]

Options:
  --repo-dir <path>           Project root (default: current directory)
  --report-file <path>        Report path (default: .tmp/policy-gate-report.md)
  --strict <true|false>       Fail when remote policy cannot be verified (default: false)
  --required-checks <csv>     Required check names (default: test-gate,runtime-smoke,stability-loop,coverage-gate,delivery-check)
HELP
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        return 1
        ;;
    esac
  done

  [[ -d "$REPO_DIR" ]] || { echo "Repo directory not found: $REPO_DIR" >&2; return 1; }
  [[ "$STRICT_MODE" =~ ^(true|false)$ ]] || { echo "--strict must be true|false" >&2; return 1; }
}

# Append markdown line into report buffer.
add_report_line() {
  REPORT_LINES="${REPORT_LINES}$1"$'\n'
}

# Mark a passed check.
pass_check() {
  PASS_COUNT=$((PASS_COUNT + 1))
  add_report_line "- [PASS] $1"
}

# Mark a warning check.
warn_check() {
  WARN_COUNT=$((WARN_COUNT + 1))
  add_report_line "- [WARN] $1"
}

# Mark a failed check.
fail_check() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  add_report_line "- [FAIL] $1"
}

# Apply strict-mode behavior for capability gaps.
strict_or_warn() {
  local msg="$1"
  if [[ "$STRICT_MODE" == "true" ]]; then
    fail_check "$msg"
  else
    warn_check "$msg"
  fi
}

# Validate local workflow policy files and required checks references.
check_local_workflow_policy() {
  local workflows_dir="$REPO_DIR/.github/workflows"
  if [[ ! -d "$workflows_dir" ]]; then
    strict_or_warn ".github/workflows is missing"
    return
  fi

  local workflow_count
  workflow_count=$(find "$workflows_dir" -type f \( -name '*.yml' -o -name '*.yaml' \) | wc -l | tr -d ' ')
  if [[ "$workflow_count" -eq 0 ]]; then
    strict_or_warn "No workflow YAML files found under .github/workflows"
    return
  fi
  pass_check "Workflow files found: ${workflow_count}"

  if rg -n --no-heading 'concurrency:' "$workflows_dir" >/dev/null 2>&1; then
    pass_check "Workflow concurrency policy is configured"
  else
    strict_or_warn "Workflow concurrency policy missing (concurrency:)"
  fi

  if rg -n --no-heading 'cancel-in-progress:' "$workflows_dir" >/dev/null 2>&1; then
    pass_check "Workflow cancel-in-progress is configured"
  else
    strict_or_warn "cancel-in-progress not configured in workflows"
  fi

  IFS=',' read -r -a checks <<< "$REQUIRED_CHECKS"
  local check=""
  for check in "${checks[@]}"; do
    local trimmed
    trimmed="$(echo "$check" | xargs)"
    if [[ -z "$trimmed" ]]; then
      continue
    fi
    if rg -n --no-heading "$trimmed" "$workflows_dir" >/dev/null 2>&1; then
      pass_check "Required check referenced in workflow: ${trimmed}"
    else
      strict_or_warn "Required check not referenced in workflows: ${trimmed}"
    fi
  done
}

# Extract GitHub owner/repo slug from origin remote URL.
resolve_repo_slug() {
  local remote_url="$1"
  local slug=""
  if [[ "$remote_url" =~ github\.com[:/](.+)/(.+)\.git$ ]]; then
    slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  elif [[ "$remote_url" =~ github\.com[:/](.+)/(.+)$ ]]; then
    slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  echo "$slug"
}

# Validate GitHub branch protection required checks when gh CLI is available.
check_remote_branch_protection() {
  if ! command -v git >/dev/null 2>&1; then
    strict_or_warn "git unavailable; cannot verify GitHub branch protection"
    return
  fi
  if ! command -v gh >/dev/null 2>&1; then
    strict_or_warn "gh unavailable; cannot verify GitHub branch protection"
    return
  fi
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    strict_or_warn "No .git directory; skipped remote branch protection checks"
    return
  fi

  local origin_url
  origin_url="$(cd "$REPO_DIR" && git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin_url" ]]; then
    strict_or_warn "Origin remote missing; skipped remote branch protection checks"
    return
  fi

  local slug
  slug="$(resolve_repo_slug "$origin_url")"
  if [[ -z "$slug" ]]; then
    strict_or_warn "Origin is not a GitHub repo; skipped remote branch protection checks"
    return
  fi
  pass_check "GitHub remote detected: ${slug}"

  local default_branch
  default_branch="$(cd "$REPO_DIR" && gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || true)"
  if [[ -z "$default_branch" ]]; then
    strict_or_warn "Unable to resolve default branch via gh"
    return
  fi

  local protection_json
  protection_json="$(cd "$REPO_DIR" && gh api "repos/${slug}/branches/${default_branch}/protection" 2>/dev/null || true)"
  if [[ -z "$protection_json" ]]; then
    strict_or_warn "Failed to query branch protection for ${default_branch}"
    return
  fi
  pass_check "Branch protection API query succeeded"

  if echo "$protection_json" | jq -e '.required_status_checks.strict == true' >/dev/null 2>&1; then
    pass_check "Branch protection strict mode enabled"
  else
    strict_or_warn "Branch protection strict mode not enabled"
  fi

  IFS=',' read -r -a checks <<< "$REQUIRED_CHECKS"
  local check=""
  for check in "${checks[@]}"; do
    local trimmed
    trimmed="$(echo "$check" | xargs)"
    if [[ -z "$trimmed" ]]; then
      continue
    fi
    if echo "$protection_json" | jq -e --arg c "$trimmed" '.required_status_checks.contexts[]? | select(. == $c)' >/dev/null 2>&1; then
      pass_check "Required status check enforced in branch protection: ${trimmed}"
    else
      strict_or_warn "Required status check missing in branch protection: ${trimmed}"
    fi
  done
}

# Persist markdown report to disk.
write_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# GitHub Policy Gate Report"
    echo
    echo "- Repo: \`$REPO_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Strict Mode: \`$STRICT_MODE\`"
    echo "- Required Checks: \`$REQUIRED_CHECKS\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"
  } >"$REPORT_FILE"
}

# Main entrypoint.
main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""

  parse_args "$@" || exit 2
  check_local_workflow_policy
  check_remote_branch_protection
  write_report

  echo "Policy gate finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
