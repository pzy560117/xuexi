#!/usr/bin/env bash

# Stability loop verifier
# Repeats runtime smoke checks multiple times to detect flaky startup/tests.

set -euo pipefail

# Parse CLI arguments and set defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/stability-loop-report.md"
  ITERATIONS=3
  STRICT_MODE="true"
  API_WAIT_SECONDS=180
  HEALTHCHECK_URL=""
  STOP_ON_FIRST_FAIL="true"
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  RUNTIME_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$script_dir}/scripts/verify-runtime-smoke.sh"
  if [[ ! -f "$RUNTIME_SCRIPT" ]]; then
    RUNTIME_SCRIPT="$script_dir/verify-runtime-smoke.sh"
  fi

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
      --iterations)
        ITERATIONS="$2"
        shift 2
        ;;
      --strict)
        STRICT_MODE="$2"
        shift 2
        ;;
      --api-wait-seconds)
        API_WAIT_SECONDS="$2"
        shift 2
        ;;
      --healthcheck-url)
        HEALTHCHECK_URL="$2"
        shift 2
        ;;
      --stop-on-first-fail)
        STOP_ON_FIRST_FAIL="$2"
        shift 2
        ;;
      --runtime-script)
        RUNTIME_SCRIPT="$2"
        shift 2
        ;;
      -h|--help)
        cat <<'HELP'
Usage: verify-stability-loop.sh [options]

Options:
  --repo-dir <path>            Project root (default: current directory)
  --report-file <path>         Report path (default: .tmp/stability-loop-report.md)
  --iterations <n>             Number of runtime cycles (default: 3)
  --strict <true|false>        Strict mode for runtime checks (default: true)
  --api-wait-seconds <n>       Runtime health wait timeout (default: 180)
  --healthcheck-url <url>      Preferred runtime health endpoint (optional)
  --stop-on-first-fail <bool>  Stop loop immediately on first fail (default: true)
  --runtime-script <path>      Path to verify-runtime-smoke.sh
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
  [[ -f "$RUNTIME_SCRIPT" ]] || { echo "Runtime script not found: $RUNTIME_SCRIPT" >&2; return 1; }
  [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || { echo "--iterations must be number" >&2; return 1; }
  [[ "$ITERATIONS" -gt 0 ]] || { echo "--iterations must be > 0" >&2; return 1; }
  [[ "$STRICT_MODE" =~ ^(true|false)$ ]] || { echo "--strict must be true|false" >&2; return 1; }
  [[ "$STOP_ON_FIRST_FAIL" =~ ^(true|false)$ ]] || { echo "--stop-on-first-fail must be true|false" >&2; return 1; }
  [[ "$API_WAIT_SECONDS" =~ ^[0-9]+$ ]] || { echo "--api-wait-seconds must be number" >&2; return 1; }
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

# Execute one runtime-smoke iteration and record result.
run_iteration() {
  local iter="$1"
  local iter_report
  iter_report="$(mktemp)"
  local iter_log
  iter_log="$(mktemp)"

  local cmd=("$RUNTIME_SCRIPT" "--repo-dir" "$REPO_DIR" "--report-file" "$iter_report" "--strict" "$STRICT_MODE" "--api-wait-seconds" "$API_WAIT_SECONDS")
  if [[ -n "$HEALTHCHECK_URL" ]]; then
    cmd+=("--healthcheck-url" "$HEALTHCHECK_URL")
  fi

  set +e
  "${cmd[@]}" >"$iter_log" 2>&1
  local iter_exit=$?
  set -e

  ITERATION_RESULTS+="Iteration ${iter}: exit=${iter_exit}"$'\n'

  if [[ "$iter_exit" -eq 0 ]]; then
    pass_check "Iteration ${iter} runtime smoke passed"
  else
    fail_check "Iteration ${iter} runtime smoke failed"
    local iter_log_tail
    iter_log_tail="$(tail -n 80 "$iter_log")"
    FAILED_ITERATION_SNIPPETS="${FAILED_ITERATION_SNIPPETS}
### Iteration ${iter}
```text
${iter_log_tail}
```"
  fi

  rm -f "$iter_log" "$iter_report"
  return "$iter_exit"
}

# Persist markdown report.
write_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Stability Loop Report"
    echo
    echo "- Repo: \`$REPO_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Iterations: \`$ITERATIONS\`"
    echo "- Strict Mode: \`$STRICT_MODE\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"
    echo
    echo "## Iteration Summary"
    echo
    echo '```text'
    printf "%s" "$ITERATION_RESULTS"
    echo '```'
    if [[ -n "${FAILED_ITERATION_SNIPPETS:-}" ]]; then
      echo
      echo "## Failed Iteration Snippets"
      echo
      printf "%s\n" "$FAILED_ITERATION_SNIPPETS"
    fi
  } >"$REPORT_FILE"
}

# Main entrypoint.
main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""
  ITERATION_RESULTS=""
  FAILED_ITERATION_SNIPPETS=""

  parse_args "$@" || exit 2

  local i=1
  while [[ "$i" -le "$ITERATIONS" ]]; do
    if run_iteration "$i"; then
      :
    else
      if [[ "$STOP_ON_FIRST_FAIL" == "true" ]]; then
        warn_check "Stopped early after iteration ${i} failure"
        break
      fi
    fi
    i=$((i + 1))
  done

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    pass_check "All stability iterations passed (${ITERATIONS}/${ITERATIONS})"
  fi

  write_report

  echo "Stability loop finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
