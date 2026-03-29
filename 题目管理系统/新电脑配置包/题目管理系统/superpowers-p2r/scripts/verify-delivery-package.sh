#!/usr/bin/env bash

# Validate CLI arguments and assign defaults.
parse_args() {
  WORKSPACE_DIR="$PWD"
  PACKAGE_DIR=""
  TASK_ID=""
  REPORT_FILE=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --task-id)
        TASK_ID="$2"
        shift 2
        ;;
      --package-dir)
        PACKAGE_DIR="$2"
        shift 2
        ;;
      --workspace)
        WORKSPACE_DIR="$2"
        shift 2
        ;;
      --report-file)
        REPORT_FILE="$2"
        shift 2
        ;;
      *)
        echo "Unknown argument: $1" >&2
        echo "Usage: verify-delivery-package.sh [--task-id TASK-XXXX] [--package-dir PATH] [--workspace PATH] [--report-file PATH]" >&2
        return 1
        ;;
    esac
  done

  if [ -n "$TASK_ID" ] && [ -z "$PACKAGE_DIR" ]; then
    PACKAGE_DIR="$WORKSPACE_DIR/$TASK_ID"
  fi

  if [ -z "$PACKAGE_DIR" ]; then
    PACKAGE_DIR="$(find "$WORKSPACE_DIR" -maxdepth 1 -type d -name 'TASK-*' -print 2>/dev/null | sort | tail -n 1)"
  fi

  if [ -z "$PACKAGE_DIR" ]; then
    echo "No TASK-* package found. Pass --task-id or --package-dir." >&2
    return 1
  fi

  if [ -z "$REPORT_FILE" ]; then
    REPORT_FILE="$PACKAGE_DIR/delivery-check-report.md"
  fi

  return 0
}

# Append one markdown line to the final report buffer.
add_report_line() {
  REPORT_LINES="${REPORT_LINES}$1"$'\n'
}

# Record a passed check.
pass_check() {
  PASS_COUNT=$((PASS_COUNT + 1))
  add_report_line "- [PASS] $1"
}

# Record a warning check.
warn_check() {
  WARN_COUNT=$((WARN_COUNT + 1))
  add_report_line "- [WARN] $1"
}

# Record a failed check.
fail_check() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  add_report_line "- [FAIL] $1"
}

# Validate required package-level files and directories.
check_required_structure() {
  local required_paths=(
    "docs"
    "repo"
    "sessions"
    "metadata.json"
    "prompt.md"
    "questions.md"
  )

  local missing=0
  local rel_path=""
  for rel_path in "${required_paths[@]}"; do
    if [ ! -e "$PACKAGE_DIR/$rel_path" ]; then
      missing=1
      fail_check "Missing required path: $rel_path"
    fi
  done

  if [ "$missing" -eq 0 ]; then
    pass_check "Required package structure exists"
  fi
}

# Validate critical repository files inside the package.
check_repo_core_files() {
  local repo_dir="$PACKAGE_DIR/repo"
  local required_repo_files=(
    "README.md"
    "docker-compose.yml"
    ".env.example"
    "run_tests.sh"
    "run_tests.bat"
  )

  local missing=0
  local rel_file=""
  for rel_file in "${required_repo_files[@]}"; do
    if [ ! -e "$repo_dir/$rel_file" ]; then
      missing=1
      fail_check "Missing repo core file: repo/$rel_file"
    fi
  done

  if [ "$missing" -eq 0 ]; then
    pass_check "Repo core files exist"
  fi
}

# Enforce gate artifacts and hardened test execution scripts.
check_gate_artifacts() {
  local repo_dir="$PACKAGE_DIR/repo"
  local docs_dir="$PACKAGE_DIR/docs"
  local min_unit_files="${MIN_UNIT_TEST_FILES:-3}"
  local min_api_files="${MIN_API_TEST_FILES:-3}"

  if [ ! -d "$repo_dir/unit_tests" ]; then
    fail_check "Missing test directory: repo/unit_tests"
  else
    pass_check "repo/unit_tests exists"
  fi

  if [ ! -d "$repo_dir/API_tests" ]; then
    fail_check "Missing test directory: repo/API_tests"
  else
    pass_check "repo/API_tests exists"
  fi

  local unit_count=0
  local api_count=0
  unit_count=$(find "$repo_dir/unit_tests" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')
  api_count=$(find "$repo_dir/API_tests" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')

  if [ "$unit_count" -lt "$min_unit_files" ]; then
    fail_check "Unit test files too few: $unit_count (required >= $min_unit_files)"
  else
    pass_check "Unit test file count is sufficient: $unit_count"
  fi

  if [ "$api_count" -lt "$min_api_files" ]; then
    fail_check "API test files too few: $api_count (required >= $min_api_files)"
  else
    pass_check "API test file count is sufficient: $api_count"
  fi

  if [ -f "$repo_dir/run_tests.sh" ]; then
    if grep -Eq '\|\|\s*echo|may have failed - this is expected' "$repo_dir/run_tests.sh"; then
      fail_check "run_tests.sh is not fail-fast (contains failure-swallow pattern)"
    else
      pass_check "run_tests.sh fail-fast check passed"
    fi
  fi

  if [ -f "$repo_dir/run_tests.bat" ]; then
    if grep -Ei '\|\|\s*echo|may have failed - this is expected' "$repo_dir/run_tests.bat" >/dev/null 2>&1; then
      fail_check "run_tests.bat is not fail-fast (contains failure-swallow pattern)"
    else
      pass_check "run_tests.bat fail-fast check passed"
    fi
  fi

  local gate_reports=(
    "test-gate-report.md"
    "runtime-smoke-report.md"
    "stability-loop-report.md"
    "coverage-gate-report.md"
    "policy-gate-report.md"
  )

  local report=""
  for report in "${gate_reports[@]}"; do
    if [ ! -f "$docs_dir/$report" ]; then
      fail_check "Missing docs/$report (quality gate evidence)"
      continue
    fi

    if grep -Eq 'FAIL=0|FAIL: 0|FAIL\): 0|FAIL\] 0' "$docs_dir/$report"; then
      pass_check "$report indicates zero FAIL"
    else
      warn_check "$report present but FAIL=0 pattern not found; review manually"
    fi
  done
}

# Ensure heavy artifacts and cache files are not shipped.
check_forbidden_artifacts() {
  local repo_dir="$PACKAGE_DIR/repo"
  local forbidden_dirs=(
    "node_modules"
    "__pycache__"
    ".git"
    ".venv"
    "venv"
    "env"
    ".opencode"
    ".codex"
    ".vscode"
    ".idea"
    ".pytest_cache"
    ".mypy_cache"
    ".next"
    ".nuxt"
    ".cache"
  )

  local has_forbidden=0
  local name=""
  for name in "${forbidden_dirs[@]}"; do
    if find "$repo_dir" -type d -name "$name" -print -quit 2>/dev/null | grep -q .; then
      has_forbidden=1
      fail_check "Forbidden directory detected in repo/: $name"
    fi
  done

  if find "$repo_dir" -type f \( -name '*.pyc' -o -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print -quit 2>/dev/null | grep -q .; then
    has_forbidden=1
    fail_check "Forbidden compiled/cache/database file detected in repo/"
  fi

  if [ "$has_forbidden" -eq 0 ]; then
    pass_check "No forbidden cache/dependency artifacts found"
  fi
}

# Check Chinese character leakage for English prompts.
check_language_cleanliness() {
  local repo_dir="$PACKAGE_DIR/repo"
  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped language cleanliness scan"
    ZH_HITS=""
    return
  fi
  if command -v rg >/dev/null 2>&1; then
    if rg -n --no-heading --pcre2 "[\x{4e00}-\x{9fff}]" "$repo_dir" >/tmp/delivery-check-zh.txt 2>/dev/null; then
      fail_check "Chinese characters found in repo/ (see report appendix)"
      ZH_HITS="$(head -n 20 /tmp/delivery-check-zh.txt 2>/dev/null)"
    else
      pass_check "No Chinese characters found in repo/"
      ZH_HITS=""
    fi
  else
    warn_check "rg is unavailable; skipped Chinese character scan"
    ZH_HITS=""
  fi
}

# Validate metadata fields needed by downstream automation.
check_metadata_fields() {
  local metadata_file="$PACKAGE_DIR/metadata.json"
  local required_fields=(
    "project_type"
    "frontend_tech"
    "backend_tech"
    "database"
    "prompt_language"
    "docker_required"
  )
  local recommended_fields=(
    "task_id"
    "created_at"
  )

  if [ ! -f "$metadata_file" ]; then
    fail_check "metadata.json is missing"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    local missing_required=0
    local key=""
    for key in "${required_fields[@]}"; do
      if ! jq -e "has(\"$key\")" "$metadata_file" >/dev/null 2>&1; then
        missing_required=1
        fail_check "metadata.json missing required field: $key"
      fi
    done

    for key in "${recommended_fields[@]}"; do
      if ! jq -e "has(\"$key\")" "$metadata_file" >/dev/null 2>&1; then
        warn_check "metadata.json missing recommended field: $key"
      fi
    done

    if [ "$missing_required" -eq 0 ]; then
      pass_check "metadata.json required fields are valid"
    fi
  else
    warn_check "jq is unavailable; skipped metadata schema validation"
  fi
}

# Validate docker compose file syntax and common warnings.
check_docker_compose() {
  local repo_dir="$PACKAGE_DIR/repo"
  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped docker compose validation"
    return
  fi
  if ! command -v docker >/dev/null 2>&1; then
    warn_check "docker not available; skipped docker compose validation"
    return
  fi

  local compose_log=""
  compose_log="$(cd "$repo_dir" && docker compose -f docker-compose.yml config -q 2>&1)"
  local compose_code=$?
  if [ "$compose_code" -ne 0 ]; then
    fail_check "docker compose config failed"
    COMPOSE_LOG="$compose_log"
    return
  fi

  pass_check "docker compose config passed"
  COMPOSE_LOG="$compose_log"

  if echo "$compose_log" | grep -q "attribute \`version\` is obsolete"; then
    warn_check "docker-compose.yml contains obsolete 'version' field"
  fi
}

# Run lightweight placeholder secret checks to catch common mistakes.
check_placeholder_secrets() {
  local repo_dir="$PACKAGE_DIR/repo"
  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped placeholder secret scan"
    SECRET_HITS=""
    return
  fi
  if command -v rg >/dev/null 2>&1; then
    local pattern='(your-super-secret-key-change-in-production|POSTGRES_PASSWORD:\s*postgres|MYSQL_ROOT_PASSWORD:\s*rootpassword|MYSQL_PASSWORD:\s*petpassword|defaultSecretKeyForDevelopmentOnly)'
    if rg -n --no-heading --pcre2 "$pattern" "$repo_dir" >/tmp/delivery-check-secret.txt 2>/dev/null; then
      warn_check "Placeholder/default secret values detected (see report appendix)"
      SECRET_HITS="$(head -n 20 /tmp/delivery-check-secret.txt 2>/dev/null)"
    else
      pass_check "No placeholder/default secrets detected"
      SECRET_HITS=""
    fi
  else
    warn_check "rg is unavailable; skipped placeholder secret scan"
    SECRET_HITS=""
  fi
}

# Check whether sessions folder contains trajectory artifacts.
check_sessions_artifacts() {
  local sessions_dir="$PACKAGE_DIR/sessions"
  if [ ! -d "$sessions_dir" ]; then
    fail_check "sessions directory is missing"
    return
  fi

  if find "$sessions_dir" -type f -print -quit 2>/dev/null | grep -q .; then
    pass_check "sessions directory contains trajectory artifact(s)"
  else
    warn_check "sessions directory is empty"
  fi
}

# Persist markdown report for later audit.
write_report() {
  local now=""
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Delivery Check Report"
    echo
    echo "- Package: \`$PACKAGE_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"
    if [ -n "${ZH_HITS:-}" ]; then
      echo
      echo "## Chinese Character Hits (Top 20)"
      echo
      echo '```text'
      echo "$ZH_HITS"
      echo '```'
    fi
    if [ -n "${SECRET_HITS:-}" ]; then
      echo
      echo "## Placeholder Secret Hits (Top 20)"
      echo
      echo '```text'
      echo "$SECRET_HITS"
      echo '```'
    fi
    if [ -n "${COMPOSE_LOG:-}" ]; then
      echo
      echo "## Docker Compose Output"
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
  ZH_HITS=""
  SECRET_HITS=""
  COMPOSE_LOG=""

  parse_args "$@" || exit 2

  check_required_structure
  check_repo_core_files
  check_gate_artifacts
  check_forbidden_artifacts
  check_language_cleanliness
  check_metadata_fields
  check_docker_compose
  check_placeholder_secrets
  check_sessions_artifacts

  write_report

  echo "Delivery check finished: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
  echo "Report: $REPORT_FILE"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"
