#!/usr/bin/env bash

# Runtime smoke gate verifier
# Boots the service stack, waits for health readiness, runs API tests, and
# guarantees compose cleanup before exit.

set -euo pipefail

# Parse CLI arguments and initialize defaults.
parse_args() {
  REPO_DIR="$PWD"
  REPORT_FILE=".tmp/runtime-smoke-report.md"
  STRICT_MODE="true"
  FAIL_ON_WARN="true"
  API_WAIT_SECONDS=180
  HEALTHCHECK_URL=""
  SKIP_BUILD="false"
  API_REPEAT=2
  SMOKE_PATHS="/health,/api/v1/system/health"

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
      --fail-on-warn)
        FAIL_ON_WARN="$2"
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
      --skip-build)
        SKIP_BUILD="$2"
        shift 2
        ;;
      --api-repeat)
        API_REPEAT="$2"
        shift 2
        ;;
      --smoke-paths)
        SMOKE_PATHS="$2"
        shift 2
        ;;
      -h|--help)
        cat <<'HELP'
Usage: verify-runtime-smoke.sh [options]

Options:
  --repo-dir <path>          Project root (default: current directory)
  --report-file <path>       Report path (default: .tmp/runtime-smoke-report.md)
  --strict <true|false>      Fail on environment capability gaps (default: true)
  --fail-on-warn <true|false> Treat WARN as gate failure (default: true)
  --api-wait-seconds <n>     Max wait seconds for health endpoint (default: 180)
  --healthcheck-url <url>    Preferred health endpoint (optional)
  --skip-build <true|false>  Use 'docker compose up -d' without build (default: false)
  --api-repeat <n>           Repeat API smoke runner for flaky detection (default: 2)
  --smoke-paths <csv>        Extra HTTP smoke paths (default: /health,/api/v1/system/health)
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
  [[ "$FAIL_ON_WARN" =~ ^(true|false)$ ]] || { echo "--fail-on-warn must be true|false" >&2; return 1; }
  [[ "$SKIP_BUILD" =~ ^(true|false)$ ]] || { echo "--skip-build must be true|false" >&2; return 1; }
  [[ "$API_WAIT_SECONDS" =~ ^[0-9]+$ ]] || { echo "--api-wait-seconds must be number" >&2; return 1; }
  [[ "$API_REPEAT" =~ ^[0-9]+$ ]] || { echo "--api-repeat must be number" >&2; return 1; }
  [[ "$API_REPEAT" -gt 0 ]] || { echo "--api-repeat must be > 0" >&2; return 1; }
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

# Apply strict-mode behavior to capability gaps.
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

# Probe a URL using available client tools.
probe_url() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "$url" >/dev/null 2>&1
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O /dev/null "$url" >/dev/null 2>&1
    return $?
  fi
  if command -v python >/dev/null 2>&1; then
    python - <<PY >/dev/null 2>&1
import sys, urllib.request
try:
    urllib.request.urlopen("${url}", timeout=5)
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
    return $?
  fi
  return 2
}

# Build candidate health endpoints based on common backend conventions.
build_health_candidates() {
  HEALTH_CANDIDATES=()
  if [[ -n "$HEALTHCHECK_URL" ]]; then
    HEALTH_CANDIDATES+=("$HEALTHCHECK_URL")
  fi
  HEALTH_CANDIDATES+=(
    "http://localhost:8080/actuator/health"
    "http://localhost:8000/health"
    "http://localhost:8000/actuator/health"
  )
}

# Wait until any candidate health endpoint returns success.
wait_for_api_health() {
  local elapsed=0
  while [[ "$elapsed" -lt "$API_WAIT_SECONDS" ]]; do
    local url=""
    for url in "${HEALTH_CANDIDATES[@]}"; do
      if command -v curl >/dev/null 2>&1; then
        if curl -fsS "$url" >/dev/null 2>&1; then
          USED_HEALTH_URL="$url"
          return 0
        fi
      elif command -v wget >/dev/null 2>&1; then
        if wget -q -O /dev/null "$url" >/dev/null 2>&1; then
          USED_HEALTH_URL="$url"
          return 0
        fi
      elif command -v python >/dev/null 2>&1; then
        if python - <<PY >/dev/null 2>&1
import sys, urllib.request
try:
    urllib.request.urlopen("${url}", timeout=3)
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
        then
          USED_HEALTH_URL="$url"
          return 0
        fi
      fi
    done
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Run API tests by preferring project-provided runners, then known stack fallbacks.
run_api_tests() {
  local api_log
  api_log="$(mktemp)"
  local run_index=1
  local min_cases_seen=999999
  while [[ "$run_index" -le "$API_REPEAT" ]]; do
    local test_exit=1

    if [[ -f "$REPO_DIR/run_api_tests.sh" ]]; then
      set +e
      (cd "$REPO_DIR" && bash ./run_api_tests.sh) >"$api_log" 2>&1
      test_exit=$?
      set -e
      API_RUNNER="run_api_tests.sh"
    elif [[ -f "$REPO_DIR/run_api_tests.bat" ]] && command -v cmd.exe >/dev/null 2>&1; then
      local win_repo
      win_repo="$(cd "$REPO_DIR" && pwd -W 2>/dev/null || echo "$REPO_DIR")"
      set +e
      cmd.exe /c "cd /d \"${win_repo}\" && run_api_tests.bat" >"$api_log" 2>&1
      test_exit=$?
      set -e
      API_RUNNER="run_api_tests.bat"
    elif [[ -f "$REPO_DIR/API_tests/pom.xml" ]] && command -v mvn >/dev/null 2>&1; then
      set +e
      (cd "$REPO_DIR/API_tests" && mvn -q -DfailIfNoTests=true test) >"$api_log" 2>&1
      test_exit=$?
      set -e
      API_RUNNER="maven-api-tests"
    elif [[ -d "$REPO_DIR/API_tests" ]] && command -v python >/dev/null 2>&1 && python -m pytest --help >/dev/null 2>&1; then
      set +e
      python -m pytest "$REPO_DIR/API_tests" -q --maxfail=1 --disable-warnings >"$api_log" 2>&1
      test_exit=$?
      set -e
      API_RUNNER="pytest-api-tests"
    else
      rm -f "$api_log"
      strict_or_warn "No executable API test runner found (run_api_tests.sh/.bat, API_tests/pom.xml, or pytest API_tests)"
      return
    fi

    API_TEST_OUTPUT="$(cat "$api_log")"

    if [[ "$test_exit" -ne 0 ]]; then
      rm -f "$api_log"
      fail_check "API smoke tests failed via ${API_RUNNER} on run ${run_index}/${API_REPEAT}"
      API_LOG_SNIPPET="$(echo "$API_TEST_OUTPUT" | tail -n 120)"
      return
    fi

    local case_count
    case_count="$(extract_pytest_passed_count "$API_TEST_OUTPUT")"
    if [[ -n "$case_count" ]] && [[ "$case_count" -lt "$min_cases_seen" ]]; then
      min_cases_seen="$case_count"
    fi

    pass_check "API smoke tests passed via ${API_RUNNER} on run ${run_index}/${API_REPEAT}"
    run_index=$((run_index + 1))
  done
  rm -f "$api_log"

  if [[ "$min_cases_seen" -lt 999999 ]]; then
    pass_check "API smoke tests are stable across ${API_REPEAT} runs (min passed=${min_cases_seen})"
  else
    warn_check "API smoke case count could not be parsed; stability assessed by runner exit codes only"
  fi
}

# Probe additional smoke endpoints after primary healthcheck is up.
run_additional_endpoint_checks() {
  if [[ -z "${USED_HEALTH_URL:-}" ]]; then
    strict_or_warn "Cannot run extra endpoint checks: health URL unresolved"
    return
  fi

  local base_url
  base_url="$(printf '%s\n' "$USED_HEALTH_URL" | sed -E 's#(https?://[^/]+).*#\1#')"
  if [[ -z "$base_url" ]]; then
    strict_or_warn "Cannot derive base URL from health endpoint: ${USED_HEALTH_URL}"
    return
  fi

  IFS=',' read -r -a smoke_paths <<< "$SMOKE_PATHS"
  local path=""
  for path in "${smoke_paths[@]}"; do
    path="$(printf '%s' "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$path" ]] || continue
    if [[ "$path" != /* ]]; then
      path="/$path"
    fi
    local url="${base_url}${path}"
    if probe_url "$url"; then
      pass_check "Smoke endpoint check passed: ${url}"
    else
      fail_check "Smoke endpoint check failed: ${url}"
    fi
  done
}

# Persist markdown report to disk.
write_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Runtime Smoke Report"
    echo
    echo "- Repo: \`$REPO_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Strict Mode: \`$STRICT_MODE\`"
    echo "- Fail On Warn: \`$FAIL_ON_WARN\`"
    echo "- API Repeat: \`$API_REPEAT\`"
    echo "- Extra Smoke Paths: \`$SMOKE_PATHS\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"

    if [[ -n "${COMPOSE_UP_LOG:-}" ]]; then
      echo
      echo "## Compose Up Log"
      echo
      echo '```text'
      echo "$COMPOSE_UP_LOG"
      echo '```'
    fi

    if [[ -n "${COMPOSE_DOWN_LOG:-}" ]]; then
      echo
      echo "## Compose Down Log"
      echo
      echo '```text'
      echo "$COMPOSE_DOWN_LOG"
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

    if [[ -n "${COMPOSE_APP_LOG:-}" ]]; then
      echo
      echo "## Compose Logs (Tail)"
      echo
      echo '```text'
      echo "$COMPOSE_APP_LOG"
      echo '```'
    fi
  } >"$REPORT_FILE"
}

# Run the end-to-end runtime smoke sequence with guaranteed compose teardown.
run_runtime_smoke() {
  if ! command -v docker >/dev/null 2>&1; then
    strict_or_warn "docker is unavailable; cannot run runtime smoke"
    return
  fi

  if [[ ! -f "$REPO_DIR/docker-compose.yml" ]]; then
    strict_or_warn "docker-compose.yml is missing; cannot run runtime smoke"
    return
  fi

  local up_exit=0
  if [[ "$SKIP_BUILD" == "true" ]]; then
    set +e
    COMPOSE_UP_LOG="$(cd "$REPO_DIR" && docker compose up -d 2>&1)"
    up_exit=$?
    set -e
  else
    set +e
    COMPOSE_UP_LOG="$(cd "$REPO_DIR" && docker compose up -d --build 2>&1)"
    up_exit=$?
    set -e
  fi

  if [[ "$up_exit" -ne 0 ]]; then
    fail_check "docker compose up failed"
    API_LOG_SNIPPET="$(echo "$COMPOSE_UP_LOG" | tail -n 120)"
    return
  fi
  pass_check "docker compose up succeeded"

  if wait_for_api_health; then
    pass_check "Healthcheck passed at ${USED_HEALTH_URL}"
  else
    fail_check "Healthcheck timeout (${API_WAIT_SECONDS}s)"
    set +e
    COMPOSE_APP_LOG="$(cd "$REPO_DIR" && docker compose logs --tail=120 2>&1)"
    set -e
  fi

  # Detect unhealthy/exited services before running deeper checks.
  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    set +e
    local compose_ps
    compose_ps="$(cd "$REPO_DIR" && docker compose ps 2>&1)"
    set -e
    if printf '%s\n' "$compose_ps" | grep -Eiq 'unhealthy|exited|dead'; then
      fail_check "docker compose ps indicates unhealthy/exited services"
      COMPOSE_APP_LOG="$compose_ps"
    else
      pass_check "docker compose services are healthy/running"
    fi
  fi

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    run_additional_endpoint_checks
  fi

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    run_api_tests
  fi

  set +e
  COMPOSE_DOWN_LOG="$(cd "$REPO_DIR" && docker compose down 2>&1)"
  local down_exit=$?
  set -e
  if [[ "$down_exit" -ne 0 ]]; then
    strict_or_warn "docker compose down failed"
  else
    pass_check "docker compose down succeeded"
  fi
}

# Main entrypoint.
main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""
  API_RUNNER=""
  USED_HEALTH_URL=""
  API_TEST_OUTPUT=""
  API_LOG_SNIPPET=""
  COMPOSE_UP_LOG=""
  COMPOSE_DOWN_LOG=""
  COMPOSE_APP_LOG=""
  HEALTH_CANDIDATES=()

  parse_args "$@" || exit 2
  build_health_candidates
  run_runtime_smoke
  write_report

  echo "Runtime smoke finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  if [[ "$FAIL_ON_WARN" == "true" ]] && [[ "$WARN_COUNT" -gt 0 ]]; then
    echo "Runtime smoke failed because WARN exists and --fail-on-warn=true" >&2
    exit 1
  fi
  exit 0
}

main "$@"
