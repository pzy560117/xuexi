#!/usr/bin/env bash

# Coverage gate verifier
# Runs project tests in verify mode and enforces minimum line/branch coverage.

set -euo pipefail

# Parse CLI arguments and define defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/coverage-gate-report.md"
  STRICT_MODE="true"
  MIN_LINE_COVERAGE=70
  MIN_BRANCH_COVERAGE=50

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
      --min-line-coverage)
        MIN_LINE_COVERAGE="$2"
        shift 2
        ;;
      --min-branch-coverage)
        MIN_BRANCH_COVERAGE="$2"
        shift 2
        ;;
      -h|--help)
        cat <<'HELP'
Usage: verify-coverage-gate.sh [options]

Options:
  --repo-dir <path>             Project root (default: current directory)
  --report-file <path>          Report path (default: .tmp/coverage-gate-report.md)
  --strict <true|false>         Fail on capability gaps (default: true)
  --min-line-coverage <n>       Minimum line coverage percentage (default: 70)
  --min-branch-coverage <n>     Minimum branch coverage percentage (default: 50)
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
  [[ "$MIN_LINE_COVERAGE" =~ ^[0-9]+$ ]] || { echo "--min-line-coverage must be number" >&2; return 1; }
  [[ "$MIN_BRANCH_COVERAGE" =~ ^[0-9]+$ ]] || { echo "--min-branch-coverage must be number" >&2; return 1; }
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

# Parse JaCoCo XML counters and compute integer percentages.
parse_jacoco_counters() {
  local jacoco_xml="$1"
  local line_counter
  local branch_counter

  line_counter="$(grep -o '<counter type="LINE" missed="[0-9]*" covered="[0-9]*"/>' "$jacoco_xml" | tail -n 1 || true)"
  branch_counter="$(grep -o '<counter type="BRANCH" missed="[0-9]*" covered="[0-9]*"/>' "$jacoco_xml" | tail -n 1 || true)"

  if [[ -z "$line_counter" ]]; then
    strict_or_warn "JaCoCo XML missing LINE counter"
    return
  fi

  LINE_MISSED="$(echo "$line_counter" | sed -E 's/.*missed="([0-9]+)".*/\1/')"
  LINE_COVERED="$(echo "$line_counter" | sed -E 's/.*covered="([0-9]+)".*/\1/')"
  LINE_TOTAL=$((LINE_MISSED + LINE_COVERED))
  if [[ "$LINE_TOTAL" -gt 0 ]]; then
    LINE_COVERAGE="$(awk -v c="$LINE_COVERED" -v t="$LINE_TOTAL" 'BEGIN { printf("%d", (c/t)*100) }')"
  else
    LINE_COVERAGE=0
  fi

  if [[ -n "$branch_counter" ]]; then
    BRANCH_MISSED="$(echo "$branch_counter" | sed -E 's/.*missed="([0-9]+)".*/\1/')"
    BRANCH_COVERED="$(echo "$branch_counter" | sed -E 's/.*covered="([0-9]+)".*/\1/')"
    BRANCH_TOTAL=$((BRANCH_MISSED + BRANCH_COVERED))
    if [[ "$BRANCH_TOTAL" -gt 0 ]]; then
      BRANCH_COVERAGE="$(awk -v c="$BRANCH_COVERED" -v t="$BRANCH_TOTAL" 'BEGIN { printf("%d", (c/t)*100) }')"
    else
      BRANCH_COVERAGE=0
    fi
  else
    BRANCH_COVERAGE=-1
  fi
}

# Execute Maven verify path with JaCoCo and coverage thresholds.
run_maven_coverage_gate() {
  if ! command -v mvn >/dev/null 2>&1; then
    strict_or_warn "mvn is unavailable; cannot run Maven coverage gate"
    return
  fi

  if grep -qi '<failIfNoTests>true</failIfNoTests>' "$REPO_DIR/pom.xml"; then
    pass_check "pom.xml enforces failIfNoTests=true"
  else
    strict_or_warn "pom.xml does not enforce failIfNoTests=true"
  fi

  if grep -qi 'jacoco-maven-plugin' "$REPO_DIR/pom.xml"; then
    pass_check "pom.xml includes jacoco-maven-plugin"
  else
    strict_or_warn "pom.xml missing jacoco-maven-plugin; cannot enforce coverage metrics"
  fi

  local maven_log
  maven_log="$(mktemp)"
  set +e
  (cd "$REPO_DIR" && mvn -q verify) >"$maven_log" 2>&1
  local maven_exit=$?
  set -e
  MAVEN_LOG_SNIPPET="$(tail -n 120 "$maven_log")"
  rm -f "$maven_log"

  if [[ "$maven_exit" -ne 0 ]]; then
    fail_check "mvn verify failed"
    return
  fi
  pass_check "mvn verify passed"

  local jacoco_xml="$REPO_DIR/target/site/jacoco/jacoco.xml"
  if [[ ! -f "$jacoco_xml" ]]; then
    strict_or_warn "JaCoCo report missing at target/site/jacoco/jacoco.xml"
    return
  fi

  parse_jacoco_counters "$jacoco_xml"

  if [[ "${LINE_COVERAGE:-0}" -ge "$MIN_LINE_COVERAGE" ]]; then
    pass_check "Line coverage ${LINE_COVERAGE}% >= ${MIN_LINE_COVERAGE}%"
  else
    fail_check "Line coverage ${LINE_COVERAGE}% < ${MIN_LINE_COVERAGE}%"
  fi

  if [[ "${BRANCH_COVERAGE:--1}" -lt 0 ]]; then
    strict_or_warn "Branch coverage counter unavailable in JaCoCo report"
  elif [[ "$BRANCH_COVERAGE" -ge "$MIN_BRANCH_COVERAGE" ]]; then
    pass_check "Branch coverage ${BRANCH_COVERAGE}% >= ${MIN_BRANCH_COVERAGE}%"
  else
    fail_check "Branch coverage ${BRANCH_COVERAGE}% < ${MIN_BRANCH_COVERAGE}%"
  fi
}

# Persist markdown report to disk.
write_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Coverage Gate Report"
    echo
    echo "- Repo: \`$REPO_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Strict Mode: \`$STRICT_MODE\`"
    echo "- Min Line Coverage: \`${MIN_LINE_COVERAGE}%\`"
    echo "- Min Branch Coverage: \`${MIN_BRANCH_COVERAGE}%\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"

    if [[ -n "${MAVEN_LOG_SNIPPET:-}" ]]; then
      echo
      echo "## Maven Verify Snippet"
      echo
      echo '```text'
      echo "$MAVEN_LOG_SNIPPET"
      echo '```'
    fi
  } >"$REPORT_FILE"
}

# Main entrypoint.
main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""
  LINE_COVERAGE=0
  BRANCH_COVERAGE=-1
  MAVEN_LOG_SNIPPET=""

  parse_args "$@" || exit 2

  if [[ -f "$REPO_DIR/pom.xml" ]]; then
    run_maven_coverage_gate
  else
    strict_or_warn "Unsupported coverage gate stack: pom.xml not found"
  fi

  write_report

  echo "Coverage gate finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
