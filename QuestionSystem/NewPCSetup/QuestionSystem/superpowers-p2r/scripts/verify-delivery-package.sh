#!/usr/bin/env bash

set -u

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
    REPORT_FILE="$PACKAGE_DIR/docs/delivery-check-report.md"
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

# Resolve a usable ripgrep command across Linux/macOS/Windows bash environments.
resolve_rg_command() {
  if command -v rg >/dev/null 2>&1; then
    RG_CMD="rg"
    return 0
  fi
  if command -v rg.exe >/dev/null 2>&1; then
    RG_CMD="rg.exe"
    return 0
  fi
  if command -v where.exe >/dev/null 2>&1; then
    local rg_win_path=""
    rg_win_path="$(where.exe rg 2>/dev/null | head -n 1 | tr -d '\r')"
    if [ -n "$rg_win_path" ] && [ -f "$rg_win_path" ]; then
      RG_CMD="$rg_win_path"
      return 0
    fi
  fi
  RG_CMD=""
  return 1
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

# Resolve preferred test dirs:
# - canonical: repo/tests/unit_tests + repo/tests/API_tests
# - legacy: repo/unit_tests + repo/API_tests
resolve_test_dirs() {
  local repo_dir="$1"
  TEST_UNIT_DIR=""
  TEST_API_DIR=""
  TEST_LAYOUT="none"

  if [ -d "$repo_dir/tests/unit_tests" ] && [ -d "$repo_dir/tests/API_tests" ]; then
    TEST_UNIT_DIR="$repo_dir/tests/unit_tests"
    TEST_API_DIR="$repo_dir/tests/API_tests"
    TEST_LAYOUT="nested"
    return 0
  fi

  if [ -d "$repo_dir/unit_tests" ] && [ -d "$repo_dir/API_tests" ]; then
    TEST_UNIT_DIR="$repo_dir/unit_tests"
    TEST_API_DIR="$repo_dir/API_tests"
    TEST_LAYOUT="legacy-root"
    return 0
  fi

  return 1
}

# Validate mandatory test directory structure and minimal test file counts.
check_test_structure() {
  local repo_dir="$PACKAGE_DIR/repo"
  local min_unit_files="${MIN_UNIT_TEST_FILES:-1}"
  local min_api_files="${MIN_API_TEST_FILES:-1}"
  local unit_dir=""
  local api_dir=""

  if resolve_test_dirs "$repo_dir"; then
    unit_dir="$TEST_UNIT_DIR"
    api_dir="$TEST_API_DIR"
    if [ "$TEST_LAYOUT" = "nested" ]; then
      pass_check "Canonical test dirs exist: repo/tests/unit_tests + repo/tests/API_tests"
    else
      warn_check "Legacy test dirs in use: repo/unit_tests + repo/API_tests (recommended: repo/tests/*)"
    fi
  else
    fail_check "Missing required test directories: repo/tests/unit_tests + repo/tests/API_tests (or legacy repo/unit_tests + repo/API_tests)"
  fi

  local unit_count=0
  local api_count=0
  if [ -d "$unit_dir" ]; then
    unit_count=$(find "$unit_dir" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ -d "$api_dir" ]; then
    api_count=$(find "$api_dir" -type f \( -name 'test_*.py' -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \) 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [ "$unit_count" -ge "$min_unit_files" ]; then
    pass_check "unit_tests file count check passed: $unit_count >= $min_unit_files"
  else
    fail_check "unit_tests file count check failed: $unit_count < $min_unit_files"
  fi

  if [ "$api_count" -ge "$min_api_files" ]; then
    pass_check "API_tests file count check passed: $api_count >= $min_api_files"
  else
    fail_check "API_tests file count check failed: $api_count < $min_api_files"
  fi
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
    PROMPT_LANGUAGE=""
    ENGLISH_MODE=0
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

    PROMPT_LANGUAGE="$(jq -r '.prompt_language // ""' "$metadata_file" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    if [ "$missing_required" -eq 0 ]; then
      pass_check "metadata.json required fields are valid"
    fi

    if [ "$PROMPT_LANGUAGE" = "en" ] || [ "$PROMPT_LANGUAGE" = "english" ]; then
      ENGLISH_MODE=1
    else
      ENGLISH_MODE=0
    fi
  else
    warn_check "jq is unavailable; skipped metadata schema validation"
    PROMPT_LANGUAGE=""
    ENGLISH_MODE=0
  fi
}

# Enforce Chinese character policy for English prompts across the whole package.
check_language_cleanliness() {
  if [ "$ENGLISH_MODE" -ne 1 ]; then
    pass_check "Prompt language is not English; skip full-package Chinese scan"
    ZH_HITS=""
    return
  fi

  if resolve_rg_command; then
    if "$RG_CMD" -n --no-heading --pcre2 "[\x{4e00}-\x{9fff}]" "$PACKAGE_DIR" \
      --glob '!.tmp/**' \
      --glob '!.backup/**' \
      --glob '!.git/**' \
      --glob '!**/.git/**' \
      >/tmp/delivery-check-zh.txt 2>/dev/null; then
      fail_check "Chinese characters found in delivery package while prompt_language=en (see report appendix)"
      ZH_HITS="$(head -n 40 /tmp/delivery-check-zh.txt 2>/dev/null)"
    else
      pass_check "No Chinese characters found in full delivery package"
      ZH_HITS=""
    fi
  elif command -v python >/dev/null 2>&1; then
    if python - "$PACKAGE_DIR" >/tmp/delivery-check-zh.txt 2>/dev/null <<'PY'
import os, re, sys
root = sys.argv[1]
pat = re.compile(r'[\u4e00-\u9fff]')
skip_dirs = {'.git', '.tmp', '.backup'}
hits = []
for base, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for f in files:
        path = os.path.join(base, f)
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh, 1):
                    if pat.search(line):
                        hits.append(f"{path}:{idx}:{line.rstrip()}")
                        if len(hits) >= 40:
                            break
            if len(hits) >= 40:
                break
        except Exception:
            continue
    if len(hits) >= 40:
        break
if hits:
    print("\n".join(hits))
    sys.exit(1)
sys.exit(0)
PY
    then
      pass_check "No Chinese characters found in full delivery package (python fallback)"
      ZH_HITS=""
    else
      fail_check "Chinese characters found in delivery package while prompt_language=en (python fallback, see report appendix)"
      ZH_HITS="$(head -n 40 /tmp/delivery-check-zh.txt 2>/dev/null)"
    fi
  else
    fail_check "No scanner available for English-redline (rg/python both unavailable)"
    ZH_HITS=""
  fi
}

# Validate static package policy with official validator.
check_validate_package() {
  local validator_candidates=(
    "$WORKSPACE_DIR/script/validate_package.py"
    "$WORKSPACE_DIR/validate_package.py"
  )
  local validator_path=""
  local candidate=""

  for candidate in "${validator_candidates[@]}"; do
    if [ -f "$candidate" ]; then
      validator_path="$candidate"
      break
    fi
  done

  if [ -z "$validator_path" ]; then
    VALIDATE_PACKAGE_EXIT_CODE=127
    fail_check "validate_package.py not found (expected at script/validate_package.py)"
    VALIDATE_PACKAGE_LOG="validator script not found"
    return
  fi

  if ! command -v python >/dev/null 2>&1; then
    VALIDATE_PACKAGE_EXIT_CODE=127
    fail_check "python command not available; cannot run validate_package.py"
    VALIDATE_PACKAGE_LOG="python not found"
    return
  fi

  VALIDATE_PACKAGE_LOG="$(python "$validator_path" "$PACKAGE_DIR" 2>&1)"
  VALIDATE_PACKAGE_EXIT_CODE=$?

  if [ "$VALIDATE_PACKAGE_EXIT_CODE" -eq 0 ]; then
    pass_check "validate_package.py passed"
  else
    fail_check "validate_package.py failed with exit code $VALIDATE_PACKAGE_EXIT_CODE"
  fi
}

# Validate docker compose config + runtime startup.
check_docker_runtime() {
  local repo_dir="$PACKAGE_DIR/repo"

  DOCKER_CONFIG_EXIT_CODE=127
  DOCKER_UP_EXIT_CODE=127
  DOCKER_SERVICES_HEALTH_EXIT_CODE=127
  DOCKER_DOWN_EXIT_CODE=127

  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped docker validation"
    DOCKER_LOG="repo directory missing"
    return
  fi

  if [ ! -f "$repo_dir/docker-compose.yml" ]; then
    fail_check "repo/docker-compose.yml missing; cannot run docker checks"
    DOCKER_LOG="docker-compose.yml missing"
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    fail_check "docker is unavailable; strict delivery check requires docker"
    DOCKER_LOG="docker not found"
    return
  fi

  local config_log=""
  local up_log=""
  local ps_log=""
  local down_log=""

  config_log="$(cd "$repo_dir" && docker compose -f docker-compose.yml config -q 2>&1)"
  DOCKER_CONFIG_EXIT_CODE=$?
  if [ "$DOCKER_CONFIG_EXIT_CODE" -eq 0 ]; then
    pass_check "docker compose config --quiet passed"
  else
    fail_check "docker compose config --quiet failed (exit=$DOCKER_CONFIG_EXIT_CODE)"
  fi

  up_log="$(cd "$repo_dir" && docker compose -f docker-compose.yml up -d 2>&1)"
  DOCKER_UP_EXIT_CODE=$?
  if [ "$DOCKER_UP_EXIT_CODE" -eq 0 ]; then
    pass_check "docker compose up -d passed"
  else
    fail_check "docker compose up -d failed (exit=$DOCKER_UP_EXIT_CODE)"
  fi

  # Health gate: every declared service must be Up (not Exited/Restarting/Dead).
  local services=""
  local health_fail=0
  services="$(cd "$repo_dir" && docker compose -f docker-compose.yml config --services 2>/dev/null || true)"
  ps_log="$(cd "$repo_dir" && docker compose -f docker-compose.yml ps -a 2>&1 || true)"
  if [ -z "$services" ]; then
    health_fail=1
    ps_log="${ps_log}"$'\n'"[health] failed to resolve services via docker compose config --services"
  else
    local svc=""
    for svc in $services; do
      local svc_line=""
      svc_line="$(printf "%s\n" "$ps_log" | grep -E "[[:space:]]${svc}[[:space:]]" | tail -n 1 || true)"
      if [ -z "$svc_line" ]; then
        health_fail=1
        ps_log="${ps_log}"$'\n'"[health] service '$svc' not found in docker compose ps -a"
        continue
      fi
      if printf "%s\n" "$svc_line" | grep -Eiq 'Exited|Exit|Restarting|Dead|Created'; then
        health_fail=1
        ps_log="${ps_log}"$'\n'"[health] service '$svc' unhealthy status: $svc_line"
      elif ! printf "%s\n" "$svc_line" | grep -Eiq 'Up'; then
        health_fail=1
        ps_log="${ps_log}"$'\n'"[health] service '$svc' not Up: $svc_line"
      fi
    done
  fi

  if [ "$health_fail" -eq 0 ]; then
    DOCKER_SERVICES_HEALTH_EXIT_CODE=0
    pass_check "docker compose service health check passed (all declared services Up)"
  else
    DOCKER_SERVICES_HEALTH_EXIT_CODE=1
    fail_check "docker compose service health check failed (at least one service not Up)"
  fi

  down_log="$(cd "$repo_dir" && docker compose -f docker-compose.yml down --remove-orphans 2>&1)"
  DOCKER_DOWN_EXIT_CODE=$?
  if [ "$DOCKER_DOWN_EXIT_CODE" -eq 0 ]; then
    pass_check "docker compose down --remove-orphans passed"
  else
    fail_check "docker compose down --remove-orphans failed (exit=$DOCKER_DOWN_EXIT_CODE)"
  fi

  DOCKER_LOG="[docker compose config -q]\n${config_log}\n\n[docker compose up -d]\n${up_log}\n\n[docker compose ps -a]\n${ps_log}\n\n[docker compose down --remove-orphans]\n${down_log}"
}

# Prevent false-positive test passes due to lax scripts.
check_run_tests_script_integrity() {
  local repo_dir="$PACKAGE_DIR/repo"
  RUN_TESTS_SCRIPT_LINT_EXIT_CODE=127

  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped run_tests script lint"
    RUN_TESTS_SCRIPT_LINT_LOG="repo directory missing"
    return
  fi

  local lint_fail=0
  local lint_notes=""

  if [ -f "$repo_dir/run_tests.sh" ]; then
    if grep -Eq '\|\|[[:space:]]*true' "$repo_dir/run_tests.sh"; then
      lint_fail=1
      lint_notes="${lint_notes}run_tests.sh contains '|| true' that can hide test failures"$'\n'
    fi
    if ! grep -Eq '^[[:space:]]*set[[:space:]]+-e([[:space:]]|$)' "$repo_dir/run_tests.sh"; then
      lint_fail=1
      lint_notes="${lint_notes}run_tests.sh missing 'set -e' fail-fast"$'\n'
    fi
  fi

  if [ -f "$repo_dir/run_tests.bat" ]; then
    if grep -Eiq 'pytest|npm test|mvn test|go test|gradle test' "$repo_dir/run_tests.bat"; then
      if ! grep -Eiq 'if[[:space:]]+errorlevel[[:space:]]+1[[:space:]]+exit[[:space:]]+/b[[:space:]]+1' "$repo_dir/run_tests.bat"; then
        lint_fail=1
        lint_notes="${lint_notes}run_tests.bat missing 'if errorlevel 1 exit /b 1' after test command"$'\n'
      fi
    fi
  fi

  if [ "$lint_fail" -eq 0 ]; then
    RUN_TESTS_SCRIPT_LINT_EXIT_CODE=0
    RUN_TESTS_SCRIPT_LINT_LOG="run_tests scripts pass strict lint"
    pass_check "run_tests script lint passed (no false-pass pattern)"
  else
    RUN_TESTS_SCRIPT_LINT_EXIT_CODE=1
    RUN_TESTS_SCRIPT_LINT_LOG="$lint_notes"
    fail_check "run_tests script lint failed (false-pass risk detected)"
  fi
}

# Execute unified tests from packaged repo.
check_run_tests() {
  local repo_dir="$PACKAGE_DIR/repo"
  RUN_TESTS_EXIT_CODE=127

  if [ ! -d "$repo_dir" ]; then
    fail_check "repo directory is missing; skipped run_tests execution"
    RUN_TESTS_LOG="repo directory missing"
    return
  fi

  if [ -f "$repo_dir/run_tests.sh" ]; then
    RUN_TESTS_LOG="$(cd "$repo_dir" && bash ./run_tests.sh 2>&1)"
    RUN_TESTS_EXIT_CODE=$?
  elif [ -f "$repo_dir/run_tests.bat" ]; then
    if command -v cmd.exe >/dev/null 2>&1; then
      RUN_TESTS_LOG="$(cd "$repo_dir" && cmd.exe /c run_tests.bat 2>&1)"
      RUN_TESTS_EXIT_CODE=$?
    else
      RUN_TESTS_LOG="run_tests.bat exists but cmd.exe is unavailable"
      RUN_TESTS_EXIT_CODE=127
    fi
  else
    RUN_TESTS_LOG="run_tests.sh and run_tests.bat are both missing"
    RUN_TESTS_EXIT_CODE=127
  fi

  if [ "$RUN_TESTS_EXIT_CODE" -eq 0 ]; then
    pass_check "run_tests script execution passed"
  else
    fail_check "run_tests script execution failed (exit=$RUN_TESTS_EXIT_CODE)"
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
  if resolve_rg_command; then
    local pattern='(your-super-secret-key-change-in-production|POSTGRES_PASSWORD:\s*postgres|MYSQL_ROOT_PASSWORD:\s*rootpassword|MYSQL_PASSWORD:\s*petpassword|defaultSecretKeyForDevelopmentOnly)'
    if "$RG_CMD" -n --no-heading --pcre2 "$pattern" "$repo_dir" >/tmp/delivery-check-secret.txt 2>/dev/null; then
      warn_check "Placeholder/default secret values detected (see report appendix)"
      SECRET_HITS="$(head -n 40 /tmp/delivery-check-secret.txt 2>/dev/null)"
    else
      pass_check "No placeholder/default secrets detected"
      SECRET_HITS=""
    fi
  elif command -v python >/dev/null 2>&1; then
    if python - "$repo_dir" >/tmp/delivery-check-secret.txt 2>/dev/null <<'PY'
import os, re, sys
root = sys.argv[1]
pat = re.compile(r'(your-super-secret-key-change-in-production|POSTGRES_PASSWORD:\s*postgres|MYSQL_ROOT_PASSWORD:\s*rootpassword|MYSQL_PASSWORD:\s*petpassword|defaultSecretKeyForDevelopmentOnly)')
hits = []
for base, dirs, files in os.walk(root):
    if '.git' in dirs:
        dirs.remove('.git')
    for f in files:
        path = os.path.join(base, f)
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh, 1):
                    if pat.search(line):
                        hits.append(f"{path}:{idx}:{line.rstrip()}")
                        if len(hits) >= 40:
                            break
            if len(hits) >= 40:
                break
        except Exception:
            continue
    if len(hits) >= 40:
        break
if hits:
    print("\n".join(hits))
    sys.exit(1)
sys.exit(0)
PY
    then
      pass_check "No placeholder/default secrets detected (python fallback)"
      SECRET_HITS=""
    else
      warn_check "Placeholder/default secret values detected (python fallback, see report appendix)"
      SECRET_HITS="$(head -n 40 /tmp/delivery-check-secret.txt 2>/dev/null)"
    fi
  else
    warn_check "No scanner available for placeholder secret scan (rg/python unavailable)"
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
  local verifier_signature_payload=""
  local verifier_signature="UNAVAILABLE"

  verifier_signature_payload="v2|${VALIDATE_PACKAGE_EXIT_CODE}|${DOCKER_CONFIG_EXIT_CODE}|${DOCKER_UP_EXIT_CODE}|${DOCKER_SERVICES_HEALTH_EXIT_CODE}|${RUN_TESTS_SCRIPT_LINT_EXIT_CODE}|${RUN_TESTS_EXIT_CODE}|${PASS_COUNT}|${WARN_COUNT}|${FAIL_COUNT}"
  if command -v sha256sum >/dev/null 2>&1; then
    verifier_signature="$(printf "%s" "$verifier_signature_payload" | sha256sum | awk '{print $1}')"
  fi

  mkdir -p "$(dirname "$REPORT_FILE")"

  {
    echo "# Delivery Check Report"
    echo
    echo "- Package: \`$PACKAGE_DIR\`"
    echo "- Generated At (UTC): \`$now\`"
    echo "- Result: PASS=$PASS_COUNT, WARN=$WARN_COUNT, FAIL=$FAIL_COUNT"
    echo
    echo "## Hard Evidence"
    echo
    echo "- VALIDATE_PACKAGE_EXIT_CODE: ${VALIDATE_PACKAGE_EXIT_CODE}"
    echo "- DOCKER_CONFIG_EXIT_CODE: ${DOCKER_CONFIG_EXIT_CODE}"
    echo "- DOCKER_UP_EXIT_CODE: ${DOCKER_UP_EXIT_CODE}"
    echo "- DOCKER_SERVICES_HEALTH_EXIT_CODE: ${DOCKER_SERVICES_HEALTH_EXIT_CODE}"
    echo "- DOCKER_DOWN_EXIT_CODE: ${DOCKER_DOWN_EXIT_CODE}"
    echo "- RUN_TESTS_SCRIPT_LINT_EXIT_CODE: ${RUN_TESTS_SCRIPT_LINT_EXIT_CODE}"
    echo "- RUN_TESTS_EXIT_CODE: ${RUN_TESTS_EXIT_CODE}"
    echo "- VERIFIER_VERSION: 2"
    echo "- VERIFIER_SIGNATURE: ${verifier_signature}"
    echo
    echo "## Checks"
    echo
    printf "%s" "$REPORT_LINES"

    if [ -n "${ZH_HITS:-}" ]; then
      echo
      echo "## Chinese Character Hits (Top 40)"
      echo
      echo '```text'
      echo "$ZH_HITS"
      echo '```'
    fi

    if [ -n "${SECRET_HITS:-}" ]; then
      echo
      echo "## Placeholder Secret Hits (Top 40)"
      echo
      echo '```text'
      echo "$SECRET_HITS"
      echo '```'
    fi

    if [ -n "${VALIDATE_PACKAGE_LOG:-}" ]; then
      echo
      echo "## validate_package.py Output"
      echo
      echo '```text'
      echo "$VALIDATE_PACKAGE_LOG"
      echo '```'
    fi

    if [ -n "${DOCKER_LOG:-}" ]; then
      echo
      echo "## Docker Output"
      echo
      echo '```text'
      echo "$DOCKER_LOG"
      echo '```'
    fi

    if [ -n "${RUN_TESTS_LOG:-}" ]; then
      echo
      echo "## run_tests Output"
      echo
      echo '```text'
      echo "$RUN_TESTS_LOG"
      echo '```'
    fi

    if [ -n "${RUN_TESTS_SCRIPT_LINT_LOG:-}" ]; then
      echo
      echo "## run_tests Script Lint Output"
      echo
      echo '```text'
      echo "$RUN_TESTS_SCRIPT_LINT_LOG"
      echo '```'
    fi
  } >"$REPORT_FILE"

  local report_json_file=""
  report_json_file="$(dirname "$REPORT_FILE")/delivery-check-result.json"
  {
    echo "{"
    echo "  \"package\": \"${PACKAGE_DIR}\","
    echo "  \"generated_at_utc\": \"${now}\","
    echo "  \"pass\": ${PASS_COUNT},"
    echo "  \"warn\": ${WARN_COUNT},"
    echo "  \"fail\": ${FAIL_COUNT},"
    echo "  \"hard_evidence\": {"
    echo "    \"validate_package_exit_code\": ${VALIDATE_PACKAGE_EXIT_CODE},"
    echo "    \"docker_config_exit_code\": ${DOCKER_CONFIG_EXIT_CODE},"
    echo "    \"docker_up_exit_code\": ${DOCKER_UP_EXIT_CODE},"
    echo "    \"docker_services_health_exit_code\": ${DOCKER_SERVICES_HEALTH_EXIT_CODE},"
    echo "    \"docker_down_exit_code\": ${DOCKER_DOWN_EXIT_CODE},"
    echo "    \"run_tests_script_lint_exit_code\": ${RUN_TESTS_SCRIPT_LINT_EXIT_CODE},"
    echo "    \"run_tests_exit_code\": ${RUN_TESTS_EXIT_CODE},"
    echo "    \"verifier_version\": 2,"
    echo "    \"verifier_signature\": \"${verifier_signature}\""
    echo "  }"
    echo "}"
  } >"$report_json_file"
}

main() {
  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0
  REPORT_LINES=""
  ZH_HITS=""
  SECRET_HITS=""

  PROMPT_LANGUAGE=""
  ENGLISH_MODE=0

  VALIDATE_PACKAGE_EXIT_CODE=127
  DOCKER_CONFIG_EXIT_CODE=127
  DOCKER_UP_EXIT_CODE=127
  DOCKER_SERVICES_HEALTH_EXIT_CODE=127
  DOCKER_DOWN_EXIT_CODE=127
  RUN_TESTS_SCRIPT_LINT_EXIT_CODE=127
  RUN_TESTS_EXIT_CODE=127

  VALIDATE_PACKAGE_LOG=""
  DOCKER_LOG=""
  RUN_TESTS_SCRIPT_LINT_LOG=""
  RUN_TESTS_LOG=""

  parse_args "$@" || exit 2

  check_required_structure
  check_repo_core_files
  check_test_structure
  check_forbidden_artifacts
  check_metadata_fields
  check_language_cleanliness
  check_validate_package
  check_docker_runtime
  check_run_tests_script_integrity
  check_run_tests
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
