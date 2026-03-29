#!/usr/bin/env bash

# Test Gate verifier
# Enforces stricter testing requirements before packaging/delivery.

set -euo pipefail

# Parse CLI arguments and provide strict defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/test-gate-report.md"
  MIN_UNIT_TEST_FILES=5
  MIN_API_TEST_FILES=5
  MIN_UNIT_TEST_CASES=20
  MIN_API_TEST_CASES=10
  MIN_UNIT_COVERAGE=80
  RUN_API_TESTS="always" # auto | always | never
  UNIT_REPEAT=3
  API_REPEAT=2
  FAIL_ON_WARN="true"
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
      --min-unit-test-cases)
        MIN_UNIT_TEST_CASES="$2"
        shift 2
        ;;
      --min-api-test-cases)
        MIN_API_TEST_CASES="$2"
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
      --unit-repeat)
        UNIT_REPEAT="$2"
        shift 2
        ;;
      --api-repeat)
        API_REPEAT="$2"
        shift 2
        ;;
      --fail-on-warn)
        FAIL_ON_WARN="$2"
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
  --min-unit-test-files <n>      Minimum unit test file count (default: 5)
  --min-api-test-files <n>       Minimum API test file count (default: 5)
  --min-unit-test-cases <n>      Minimum unit test cases per run (default: 20)
  --min-api-test-cases <n>       Minimum API test cases per run (default: 10)
  --min-unit-coverage <n>        Minimum unit coverage percent (default: 80)
  --run-api-tests <mode>         auto|always|never (default: always)
  --unit-repeat <n>              Unit test repeat count for flaky detection (default: 3)
  --api-repeat <n>               API test repeat count for flaky detection (default: 2)
  --fail-on-warn <true|false>    Treat WARN as gate failure (default: true)
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
  [[ "$FAIL_ON_WARN" =~ ^(true|false)$ ]] || { echo "--fail-on-warn must be true|false" >&2; return 1; }
  [[ "$MIN_UNIT_TEST_FILES" =~ ^[0-9]+$ ]] || { echo "--min-unit-test-files must be number" >&2; return 1; }
  [[ "$MIN_API_TEST_FILES" =~ ^[0-9]+$ ]] || { echo "--min-api-test-files must be number" >&2; return 1; }
  [[ "$MIN_UNIT_TEST_CASES" =~ ^[0-9]+$ ]] || { echo "--min-unit-test-cases must be number" >&2; return 1; }
  [[ "$MIN_API_TEST_CASES" =~ ^[0-9]+$ ]] || { echo "--min-api-test-cases must be number" >&2; return 1; }
  [[ "$MIN_UNIT_COVERAGE" =~ ^[0-9]+$ ]] || { echo "--min-unit-coverage must be number" >&2; return 1; }
  [[ "$UNIT_REPEAT" =~ ^[0-9]+$ ]] || { echo "--unit-repeat must be number" >&2; return 1; }
  [[ "$API_REPEAT" =~ ^[0-9]+$ ]] || { echo "--api-repeat must be number" >&2; return 1; }
  [[ "$UNIT_REPEAT" -gt 0 ]] || { echo "--unit-repeat must be > 0" >&2; return 1; }
  [[ "$API_REPEAT" -gt 0 ]] || { echo "--api-repeat must be > 0" >&2; return 1; }
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

# Extract pytest passed test-case count from output.
extract_pytest_passed_count() {
  local output="$1"
  local count
  count="$(printf '%s\n' "$output" | perl -ne 'if (/([0-9]+)\s+passed\b/) { $v=$1 } END { print $v if defined $v }' 2>/dev/null || true)"
  echo "$count"
}

# Sum surefire XML tests="N" counters for Maven/JUnit runs.
sum_surefire_test_count() {
  local report_dir="$1"
  if [[ ! -d "$report_dir" ]]; then
    echo ""
    return
  fi
  local sum
  sum="$(grep -Rho 'tests="[0-9]\+"' "$report_dir" 2>/dev/null | sed -E 's/tests="([0-9]+)"/\1/' | awk '{s+=$1} END {if (NR>0) print s}' || true)"
  echo "$sum"
}

# Ensure test suite covers multiple quality dimensions (auth/permission/validation/etc).
check_test_dimension_coverage() {
  local unit_root="$REPO_DIR/unit_tests"
  local api_root="$REPO_DIR/API_tests"
  local scan_roots=()
  [[ -d "$unit_root" ]] && scan_roots+=("$unit_root")
  [[ -d "$api_root" ]] && scan_roots+=("$api_root")

  if [[ "${#scan_roots[@]}" -eq 0 ]]; then
    fail_check "Cannot check test dimensions: unit_tests/API_tests directories are missing"
    return
  fi

  check_dimension() {
    local label="$1"
    local pattern="$2"
    if grep -R -E -i -n -- "$pattern" "${scan_roots[@]}" >/dev/null 2>&1; then
      pass_check "Test dimension covered: ${label}"
    else
      fail_check "Test dimension missing: ${label}"
    fi
  }

  check_dimension "auth" 'auth|login|token|jwt'
  check_dimension "permission" 'permission|rbac|role|forbidden|unauthorized|403|401'
  check_dimension "validation" 'invalid|required|missing|bad[_ -]?request|422|400|schema'
  check_dimension "workflow" 'workflow|state|transition|approve|reject|cancel'
  check_dimension "error-path" 'exception|error|fail|timeout|retry'
  check_dimension "boundary" 'limit|max|min|boundary|edge|overflow|underflow'
}

# Count test files for unit/API scopes.
count_test_files() {
  UNIT_TEST_FILE_COUNT=$(find "$REPO_DIR/unit_tests" "$REPO_DIR/tests" "$REPO_DIR/src/test/java" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' -o -name '*Test.java' -o -name '*Tests.java' \) 2>/dev/null | wc -l | tr -d ' ')
  API_TEST_FILE_COUNT=$(find "$REPO_DIR/API_tests" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' -o -name '*Test.java' -o -name '*Tests.java' \) 2>/dev/null | wc -l | tr -d ' ')

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

# Parse JaCoCo XML and return LINE coverage percentage (integer).
parse_jacoco_line_coverage() {
  local jacoco_xml="$1"
  local line_counter
  line_counter="$(grep -o '<counter type="LINE" missed="[0-9]*" covered="[0-9]*"/>' "$jacoco_xml" | tail -n 1 || true)"
  if [[ -z "$line_counter" ]]; then
    echo ""
    return
  fi
  local missed covered total percent
  missed="$(echo "$line_counter" | sed -E 's/.*missed="([0-9]+)".*/\1/')"
  covered="$(echo "$line_counter" | sed -E 's/.*covered="([0-9]+)".*/\1/')"
  total=$((missed + covered))
  if [[ "$total" -le 0 ]]; then
    echo "0"
    return
  fi
  percent="$(awk -v c="$covered" -v t="$total" 'BEGIN { printf("%d", (c/t)*100) }')"
  echo "$percent"
}

# Run Maven unit tests and enforce coverage threshold when JaCoCo report exists.
run_maven_unit_tests_with_coverage() {
  if ! command -v mvn >/dev/null 2>&1; then
    strict_or_warn "mvn is unavailable; cannot run Maven unit tests"
    return
  fi

  local pom_dir="$REPO_DIR"
  if [[ -f "$REPO_DIR/unit_tests/pom.xml" ]]; then
    pom_dir="$REPO_DIR/unit_tests"
  fi

  local min_coverage_seen=999
  local min_cases_seen=999999
  local run_index=1
  while [[ "$run_index" -le "$UNIT_REPEAT" ]]; do
    UNIT_TEST_LOG=$(mktemp)
    set +e
    (cd "$pom_dir" && mvn -q test) >"$UNIT_TEST_LOG" 2>&1
    UNIT_TEST_EXIT=$?
    set -e

    UNIT_TEST_OUTPUT="$(cat "$UNIT_TEST_LOG")"
    rm -f "$UNIT_TEST_LOG"

    if [[ "$UNIT_TEST_EXIT" -ne 0 ]]; then
      fail_check "Maven unit tests failed on run ${run_index}/${UNIT_REPEAT}"
      UNIT_LOG_SNIPPET="$(echo "$UNIT_TEST_OUTPUT" | tail -n 80)"
      return
    fi

    local surefire_dir="$pom_dir/target/surefire-reports"
    local case_count
    case_count="$(sum_surefire_test_count "$surefire_dir")"
    if [[ -z "$case_count" ]]; then
      strict_or_warn "Unable to parse Maven unit test case count on run ${run_index}/${UNIT_REPEAT}"
    elif [[ "$case_count" -lt "$MIN_UNIT_TEST_CASES" ]]; then
      fail_check "Maven unit test case count ${case_count} < ${MIN_UNIT_TEST_CASES} on run ${run_index}/${UNIT_REPEAT}"
    else
      pass_check "Maven unit test case count ${case_count} >= ${MIN_UNIT_TEST_CASES} on run ${run_index}/${UNIT_REPEAT}"
    fi

    if [[ -n "$case_count" ]] && [[ "$case_count" -lt "$min_cases_seen" ]]; then
      min_cases_seen="$case_count"
    fi

    local jacoco_xml=""
    if [[ -f "$pom_dir/target/site/jacoco/jacoco.xml" ]]; then
      jacoco_xml="$pom_dir/target/site/jacoco/jacoco.xml"
    elif [[ -f "$REPO_DIR/target/site/jacoco/jacoco.xml" ]]; then
      jacoco_xml="$REPO_DIR/target/site/jacoco/jacoco.xml"
    fi

    if [[ -z "$jacoco_xml" ]]; then
      strict_or_warn "JaCoCo coverage report missing; cannot enforce unit coverage threshold on run ${run_index}/${UNIT_REPEAT}"
      return
    fi

    UNIT_COVERAGE="$(parse_jacoco_line_coverage "$jacoco_xml")"
    if [[ -z "$UNIT_COVERAGE" ]]; then
      strict_or_warn "Unable to parse JaCoCo LINE coverage percentage on run ${run_index}/${UNIT_REPEAT}"
      return
    fi

    if [[ "$UNIT_COVERAGE" -ge "$MIN_UNIT_COVERAGE" ]]; then
      pass_check "Unit coverage ${UNIT_COVERAGE}% >= ${MIN_UNIT_COVERAGE}% on run ${run_index}/${UNIT_REPEAT}"
    else
      fail_check "Unit coverage ${UNIT_COVERAGE}% < ${MIN_UNIT_COVERAGE}% on run ${run_index}/${UNIT_REPEAT}"
    fi

    if [[ "$UNIT_COVERAGE" -lt "$min_coverage_seen" ]]; then
      min_coverage_seen="$UNIT_COVERAGE"
    fi
    run_index=$((run_index + 1))
  done

  pass_check "Maven unit tests are stable across ${UNIT_REPEAT} runs (min cases=${min_cases_seen}, min coverage=${min_coverage_seen}%)"
}

# Execute unit tests with coverage threshold.
run_unit_tests_with_coverage() {
  if [[ -f "$REPO_DIR/pom.xml" ]] || [[ -f "$REPO_DIR/unit_tests/pom.xml" ]]; then
    run_maven_unit_tests_with_coverage
    return
  fi

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

  local run_index=1
  local min_coverage_seen=999
  local min_cases_seen=999999
  while [[ "$run_index" -le "$UNIT_REPEAT" ]]; do
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
      fail_check "Unit tests failed on run ${run_index}/${UNIT_REPEAT}"
      UNIT_LOG_SNIPPET="$(echo "$UNIT_TEST_OUTPUT" | tail -n 80)"
      return
    fi

    local unit_cases
    unit_cases="$(extract_pytest_passed_count "$UNIT_TEST_OUTPUT")"
    if [[ -z "$unit_cases" ]]; then
      strict_or_warn "Unable to parse unit test case count on run ${run_index}/${UNIT_REPEAT}"
    elif [[ "$unit_cases" -lt "$MIN_UNIT_TEST_CASES" ]]; then
      fail_check "Unit test case count ${unit_cases} < ${MIN_UNIT_TEST_CASES} on run ${run_index}/${UNIT_REPEAT}"
    else
      pass_check "Unit test case count ${unit_cases} >= ${MIN_UNIT_TEST_CASES} on run ${run_index}/${UNIT_REPEAT}"
    fi

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
      strict_or_warn "Unable to parse unit test coverage percentage on run ${run_index}/${UNIT_REPEAT}"
      return
    fi

    if [[ "$UNIT_COVERAGE" -ge "$MIN_UNIT_COVERAGE" ]]; then
      pass_check "Unit coverage ${UNIT_COVERAGE}% >= ${MIN_UNIT_COVERAGE}% on run ${run_index}/${UNIT_REPEAT}"
    else
      fail_check "Unit coverage ${UNIT_COVERAGE}% < ${MIN_UNIT_COVERAGE}% on run ${run_index}/${UNIT_REPEAT}"
    fi

    if [[ -n "$unit_cases" ]] && [[ "$unit_cases" -lt "$min_cases_seen" ]]; then
      min_cases_seen="$unit_cases"
    fi
    if [[ "$UNIT_COVERAGE" -lt "$min_coverage_seen" ]]; then
      min_coverage_seen="$UNIT_COVERAGE"
    fi
    run_index=$((run_index + 1))
  done

  pass_check "Unit tests are stable across ${UNIT_REPEAT} runs (min cases=${min_cases_seen}, min coverage=${min_coverage_seen}%)"
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
    fail_check "API tests skipped by configuration (--run-api-tests=never) under strict gate"
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

  local api_runner=""
  local run_index=1
  local min_api_cases_seen=999999
  while [[ "$run_index" -le "$API_REPEAT" ]]; do
    if [[ -f "$REPO_DIR/run_api_tests.sh" ]]; then
      set +e
      (cd "$REPO_DIR" && bash ./run_api_tests.sh) >"$API_TEST_LOG" 2>&1
      API_TEST_EXIT=$?
      set -e
      api_runner="run_api_tests.sh"
    elif [[ -f "$REPO_DIR/run_api_tests.bat" ]] && command -v cmd.exe >/dev/null 2>&1; then
      local win_repo
      win_repo="$(cd "$REPO_DIR" && pwd -W 2>/dev/null || echo "$REPO_DIR")"
      set +e
      cmd.exe /c "cd /d \"${win_repo}\" && run_api_tests.bat" >"$API_TEST_LOG" 2>&1
      API_TEST_EXIT=$?
      set -e
      api_runner="run_api_tests.bat"
    elif [[ -f "$REPO_DIR/API_tests/pom.xml" ]] && command -v mvn >/dev/null 2>&1; then
      set +e
      (cd "$REPO_DIR/API_tests" && mvn -q -DfailIfNoTests=true test) >"$API_TEST_LOG" 2>&1
      API_TEST_EXIT=$?
      set -e
      api_runner="maven-api-tests"
    else
      set +e
      python -m pytest "$REPO_DIR/API_tests" -q --maxfail=1 --disable-warnings >"$API_TEST_LOG" 2>&1
      API_TEST_EXIT=$?
      set -e
      api_runner="pytest-api-tests"
    fi

    API_TEST_OUTPUT="$(cat "$API_TEST_LOG")"

    if [[ "$API_TEST_EXIT" -ne 0 ]]; then
      rm -f "$API_TEST_LOG"
      (cd "$REPO_DIR" && docker compose down >/dev/null 2>&1) || true
      fail_check "API integration tests failed via ${api_runner} on run ${run_index}/${API_REPEAT}"
      API_LOG_SNIPPET="$(echo "$API_TEST_OUTPUT" | tail -n 80)"
      return
    fi

    local api_cases=""
    if [[ "$api_runner" == "pytest-api-tests" ]]; then
      api_cases="$(extract_pytest_passed_count "$API_TEST_OUTPUT")"
    elif [[ "$api_runner" == "maven-api-tests" ]]; then
      api_cases="$(sum_surefire_test_count "$REPO_DIR/API_tests/target/surefire-reports")"
    else
      api_cases="$(extract_pytest_passed_count "$API_TEST_OUTPUT")"
    fi

    if [[ -z "$api_cases" ]]; then
      strict_or_warn "Unable to parse API test case count via ${api_runner} on run ${run_index}/${API_REPEAT}"
    elif [[ "$api_cases" -lt "$MIN_API_TEST_CASES" ]]; then
      fail_check "API test case count ${api_cases} < ${MIN_API_TEST_CASES} on run ${run_index}/${API_REPEAT}"
    else
      pass_check "API test case count ${api_cases} >= ${MIN_API_TEST_CASES} on run ${run_index}/${API_REPEAT}"
    fi

    if [[ -n "$api_cases" ]] && [[ "$api_cases" -lt "$min_api_cases_seen" ]]; then
      min_api_cases_seen="$api_cases"
    fi
    pass_check "API integration tests passed via ${api_runner} on run ${run_index}/${API_REPEAT}"
    run_index=$((run_index + 1))
  done

  rm -f "$API_TEST_LOG"
  (cd "$REPO_DIR" && docker compose down >/dev/null 2>&1) || true
  pass_check "API integration tests are stable across ${API_REPEAT} runs (min cases=${min_api_cases_seen})"
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
    echo "- Fail On Warn: \`$FAIL_ON_WARN\`"
    echo "- Unit Repeat: \`$UNIT_REPEAT\`"
    echo "- API Repeat: \`$API_REPEAT\`"
    echo "- Unit Thresholds: files>=${MIN_UNIT_TEST_FILES}, cases>=${MIN_UNIT_TEST_CASES}, coverage>=${MIN_UNIT_COVERAGE}%"
    echo "- API Thresholds: files>=${MIN_API_TEST_FILES}, cases>=${MIN_API_TEST_CASES}"
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
  check_test_dimension_coverage
  run_unit_tests_with_coverage
  run_api_tests
  write_report

  echo "Test gate finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  if [[ "$FAIL_ON_WARN" == "true" ]] && [[ "$WARN_COUNT" -gt 0 ]]; then
    echo "Test gate failed because WARN exists and --fail-on-warn=true" >&2
    exit 1
  fi
  exit 0
}

main "$@"
