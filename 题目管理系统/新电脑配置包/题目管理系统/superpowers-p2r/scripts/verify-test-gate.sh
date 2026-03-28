#!/usr/bin/env bash

# Test Gate verifier
# Enforces stricter testing requirements before packaging/delivery.

set -euo pipefail

# Parse CLI arguments and provide strict defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/test-gate-report.md"
  MIN_UNIT_TEST_FILES=3
  MIN_API_TEST_FILES=3
  MIN_UNIT_COVERAGE=70
  RUN_API_TESTS="auto" # auto | always | never
  STRICT_MODE="true"
  API_WAIT_SECONDS=120
  HEALTHCHECK_URL="http://localhost:8000/health"

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
      --min-unit-test-files)
        MIN_UNIT_TEST_FILES="$2"
        shift 2
        ;;
      --min-api-test-files)
        MIN_API_TEST_FILES="$2"
        shift 2
        ;;
      --min-unit-coverage)
        MIN_UNIT_COVERAGE="$2"
        shift 2
        ;;
      --run-api-tests)
        RUN_API_TESTS="$2"
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
      -h|--help)
        cat <<'HELP'
Usage: verify-test-gate.sh [options]

Options:
  --repo-dir <path>              Project root (default: current directory)
  --report-file <path>           Report path (default: .tmp/test-gate-report.md)
  --min-unit-test-files <n>      Minimum unit test file count (default: 3)
  --min-api-test-files <n>       Minimum API test file count (default: 3)
  --min-unit-coverage <n>        Minimum unit coverage percent (default: 70)
  --run-api-tests <mode>         auto|always|never (default: auto)
  --strict <true|false>          Fail if env cannot execute tests (default: true)
  --api-wait-seconds <n>         API readiness timeout seconds (default: 120)
  --healthcheck-url <url>        API health endpoint (default: http://localhost:8000/health)
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
  [[ "$RUN_API_TESTS" =~ ^(auto|always|never)$ ]] || { echo "--run-api-tests must be auto|always|never" >&2; return 1; }
  [[ "$STRICT_MODE" =~ ^(true|false)$ ]] || { echo "--strict must be true|false" >&2; return 1; }
  [[ "$MIN_UNIT_TEST_FILES" =~ ^[0-9]+$ ]] || { echo "--min-unit-test-files must be number" >&2; return 1; }
  [[ "$MIN_API_TEST_FILES" =~ ^[0-9]+$ ]] || { echo "--min-api-test-files must be number" >&2; return 1; }
  [[ "$MIN_UNIT_COVERAGE" =~ ^[0-9]+$ ]] || { echo "--min-unit-coverage must be number" >&2; return 1; }
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

# Apply strict-mode behavior for environment capability failures.
strict_or_warn() {
  local msg="$1"
  if [[ "$STRICT_MODE" == "true" ]]; then
    fail_check "$msg"
  else
    warn_check "$msg"
  fi
}

# Count test files for unit/API scopes.
count_test_files() {
  UNIT_TEST_FILE_COUNT=$(find "$REPO_DIR/unit_tests" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')
  API_TEST_FILE_COUNT=$(find "$REPO_DIR/API_tests" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$UNIT_TEST_FILE_COUNT" -ge "$MIN_UNIT_TEST_FILES" ]]; then
    pass_check "Unit test file count ${UNIT_TEST_FILE_COUNT} >= ${MIN_UNIT_TEST_FILES}"
  else
    fail_check "Unit test file count ${UNIT_TEST_FILE_COUNT} < ${MIN_UNIT_TEST_FILES}"
  fi

  if [[ "$API_TEST_FILE_COUNT" -ge "$MIN_API_TEST_FILES" ]]; then
    pass_check "API test file count ${API_TEST_FILE_COUNT} >= ${MIN_API_TEST_FILES}"
  else
    fail_check "API test file count ${API_TEST_FILE_COUNT} < ${MIN_API_TEST_FILES}"
  fi
}

# Ensure test scripts are fail-fast and do not swallow failures.
check_test_script_hardening() {
  local sh_file="$REPO_DIR/run_tests.sh"
  local bat_file="$REPO_DIR/run_tests.bat"

  [[ -f "$sh_file" ]] && pass_check "run_tests.sh exists" || fail_check "run_tests.sh missing"
  [[ -f "$bat_file" ]] && pass_check "run_tests.bat exists" || fail_check "run_tests.bat missing"

  if [[ -f "$sh_file" ]]; then
    if grep -Eq '\|\|\s*echo|may have failed - this is expected' "$sh_file"; then
      fail_check "run_tests.sh contains failure-swallow pattern (|| echo / expected-failure text)"
    else
      pass_check "run_tests.sh is fail-fast"
    fi
  fi

  if [[ -f "$bat_file" ]]; then
    if grep -Ei '\|\|\s*echo|may have failed - this is expected' "$bat_file" >/dev/null 2>&1; then
      fail_check "run_tests.bat contains failure-swallow pattern (|| echo / expected-failure text)"
    else
      pass_check "run_tests.bat is fail-fast"
    fi
  fi
}

# Execute unit tests with coverage threshold.
run_unit_tests_with_coverage() {
  if [[ ! -d "$REPO_DIR/unit_tests" ]]; then
    fail_check "unit_tests directory missing"
    return
  fi

  if ! command -v python >/dev/null 2>&1; then
    strict_or_warn "python is unavailable; cannot run unit tests"
    return
  fi

  if ! python -m pytest --help >/dev/null 2>&1; then
    strict_or_warn "pytest is unavailable; cannot run unit tests"
    return
  fi

  if ! python -m pytest --help 2>/dev/null | grep -q -- '--cov'; then
    strict_or_warn "pytest-cov is unavailable; cannot enforce coverage threshold"
    return
  fi

  UNIT_TEST_LOG=$(mktemp)
  set +e
  PYTHONPATH="$REPO_DIR/backend${PYTHONPATH:+:$PYTHONPATH}" \
    python -m pytest "$REPO_DIR/unit_tests" \
      -q \
      --maxfail=1 \
      --disable-warnings \
      --cov="$REPO_DIR/backend/app" \
      --cov-report=term >"$UNIT_TEST_LOG" 2>&1
  UNIT_TEST_EXIT=$?
  set -e

  UNIT_TEST_OUTPUT="$(cat "$UNIT_TEST_LOG")"
  rm -f "$UNIT_TEST_LOG"

  if [[ "$UNIT_TEST_EXIT" -ne 0 ]]; then
    fail_check "Unit tests failed"
    UNIT_LOG_SNIPPET="$(echo "$UNIT_TEST_OUTPUT" | tail -n 80)"
    return
  fi

  pass_check "Unit tests passed"

  UNIT_COVERAGE="$(echo "$UNIT_TEST_OUTPUT" | awk '
    /TOTAL/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /%$/) {
          gsub("%", "", $i);
          cov = $i;
        }
      }
    }
    END { if (cov != "") print cov; }
  ')"

  if [[ -z "${UNIT_COVERAGE:-}" ]]; then
    strict_or_warn "Unable to parse unit test coverage percentage"
    return
  fi

  if [[ "$UNIT_COVERAGE" -ge "$MIN_UNIT_COVERAGE" ]]; then
    pass_check "Unit coverage ${UNIT_COVERAGE}% >= ${MIN_UNIT_COVERAGE}%"
  else
    fail_check "Unit coverage ${UNIT_COVERAGE}% < ${MIN_UNIT_COVERAGE}%"
  fi
}

# Wait for API health endpoint during integration checks.
wait_for_api_health() {
  local elapsed=0
  while [[ "$elapsed" -lt "$API_WAIT_SECONDS" ]]; do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS "$HEALTHCHECK_URL" >/dev/null 2>&1; then
        return 0
      fi
    else
      if python - <<PY >/dev/null 2>&1
import sys, urllib.request
try:
    urllib.request.urlopen("${HEALTHCHECK_URL}", timeout=3)
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
      then
        return 0
      fi
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Run API integration tests with docker-compose based environment.
run_api_tests() {
  if [[ "$RUN_API_TESTS" == "never" ]]; then
    warn_check "API tests skipped by configuration (--run-api-tests=never)"
    return
  fi

  if [[ ! -d "$REPO_DIR/API_tests" ]]; then
    fail_check "API_tests directory missing"
    return
  fi

  if [[ "$RUN_API_TESTS" == "auto" ]] && [[ "$API_TEST_FILE_COUNT" -eq 0 ]]; then
    warn_check "No API test files found; skip API execution in auto mode"
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    strict_or_warn "docker is unavailable; cannot run API integration tests"
    return
  fi

  if [[ ! -f "$REPO_DIR/docker-compose.yml" ]]; then
    strict_or_warn "docker-compose.yml missing; cannot run API integration tests"
    return
  fi

  if ! command -v python >/dev/null 2>&1; then
    strict_or_warn "python is unavailable; cannot run API integration tests"
    return
  fi

  if ! python -m pytest --help >/dev/null 2>&1; then
    strict_or_warn "pytest is unavailable; cannot run API integration tests"
    return
  fi

  API_TEST_LOG=$(mktemp)
  local compose_log=""

  set +e
  compose_log="$(cd "$REPO_DIR" && docker compose up -d --build 2>&1)"
  COMPOSE_UP_EXIT=$?
  set -e
  COMPOSE_LOG="$compose_log"

  if [[ "$COMPOSE_UP_EXIT" -ne 0 ]]; then
    fail_check "docker compose up -d --build failed during API test setup"
    API_LOG_SNIPPET="$(echo "$compose_log" | tail -n 80)"
    return
  fi

  if wait_for_api_health; then
    pass_check "API healthcheck passed within ${API_WAIT_SECONDS}s"
  else
    fail_check "API healthcheck timeout (${API_WAIT_SECONDS}s)"
    (cd "$REPO_DIR" && docker compose down >/dev/null 2>&1) || true
    return
  fi

  set +e
  python -m pytest "$REPO_DIR/API_tests" -q --maxfail=1 --disable-warnings >"$API_TEST_LOG" 2>&1
  API_TEST_EXIT=$?
  set -e

  API_TEST_OUTPUT="$(cat "$API_TEST_LOG")"
  rm -f "$API_TEST_LOG"

  (cd "$REPO_DIR" && docker compose down >/dev/null 2>&1) || true

  if [[ "$API_TEST_EXIT" -ne 0 ]]; then
    fail_check "API integration tests failed"
    API_LOG_SNIPPET="$(echo "$API_TEST_OUTPUT" | tail -n 80)"
    return
  fi

  pass_check "API integration tests passed"
}

# Persist markdown report to disk.
write_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Test Gate Report"
    echo
    echo "- Repo: \`$REPO_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Strict Mode: \`$STRICT_MODE\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"

    if [[ -n "${UNIT_LOG_SNIPPET:-}" ]]; then
      echo
      echo "## Unit Test Failure Snippet"
      echo
      echo '```text'
      echo "$UNIT_LOG_SNIPPET"
      echo '```'
    fi

    if [[ -n "${API_LOG_SNIPPET:-}" ]]; then
      echo
      echo "## API Test Failure Snippet"
      echo
      echo '```text'
      echo "$API_LOG_SNIPPET"
      echo '```'
    fi

    if [[ -n "${COMPOSE_LOG:-}" ]]; then
      echo
      echo "## Docker Compose Log"
      echo
      echo '```text'
      echo "$COMPOSE_LOG"
      echo '```'
    fi
  } >"$REPORT_FILE"
}

main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""
  UNIT_LOG_SNIPPET=""
  API_LOG_SNIPPET=""
  COMPOSE_LOG=""

  parse_args "$@" || exit 2

  check_test_script_hardening
  count_test_files
  run_unit_tests_with_coverage
  run_api_tests
  write_report

  echo "Test gate finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
