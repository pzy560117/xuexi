#!/usr/bin/env bash
# scripts/pre-flight-check.sh
# Prompt2Repo P2R 预检门禁校验 (Pre-Flight Check)
# 在执行期(Phase 3.x)结束或 Review 期结束前，硬性校验底层产物真实性，防止幻觉

set -euo pipefail

CURRENT_TASK_DIR="$1"
PHASE_NAME="$2"

echo "======================================"
echo "🚀 Pre-Flight Check: Validating $PHASE_NAME deliverables..."
echo "======================================"

cd "$CURRENT_TASK_DIR" || exit 1

FAIL=0
TARGET_DIR="."
if [ -d "repo" ]; then
    TARGET_DIR="repo"
fi

echo "- Using target directory: $TARGET_DIR"

# 1. 结构验证: tests/unit_tests 与 tests/API_tests（兼容旧结构）
if [ -d "$TARGET_DIR/tests/unit_tests" ] && [ -d "$TARGET_DIR/tests/API_tests" ]; then
    echo "- Check: canonical test dirs exist (tests/unit_tests + tests/API_tests)... PASS"
elif [ -d "$TARGET_DIR/unit_tests" ] && [ -d "$TARGET_DIR/API_tests" ]; then
    echo "- Check: legacy test dirs exist (unit_tests + API_tests)... PASS (compatibility mode)"
else
    echo "- Check: test dirs... FAIL (missing both canonical and legacy layouts)"
    FAIL=1
fi

# 2. 脚本验证: run_tests.sh または run_tests.bat
echo -n "- Check: run_tests scripts exist... "
if [ -f "$TARGET_DIR/run_tests.sh" ] || [ -f "$TARGET_DIR/run_tests.bat" ]; then
    echo "PASS"
else
    echo "FAIL (Both missing)"
    FAIL=1
fi

# 2.1 防假绿检查: 禁止吞错
if [ -f "$TARGET_DIR/run_tests.sh" ]; then
    if grep -Eq '\|\|[[:space:]]*true' "$TARGET_DIR/run_tests.sh"; then
        echo "- Check: run_tests.sh false-pass pattern... FAIL (contains '|| true')"
        FAIL=1
    else
        echo "- Check: run_tests.sh false-pass pattern... PASS"
    fi
fi

if [ -f "$TARGET_DIR/run_tests.bat" ]; then
    if grep -Eiq 'pytest|npm test|mvn test|go test|gradle test' "$TARGET_DIR/run_tests.bat"; then
        if grep -Eiq 'if[[:space:]]+errorlevel[[:space:]]+1[[:space:]]+exit[[:space:]]+/b[[:space:]]+1' "$TARGET_DIR/run_tests.bat"; then
            echo "- Check: run_tests.bat fail-fast... PASS"
        else
            echo "- Check: run_tests.bat fail-fast... FAIL (missing errorlevel fail-fast)"
            FAIL=1
        fi
    fi
fi

# 3. Docker 验证: 存在性
echo -n "- Check: Dockerfile & docker-compose.yml exist... "
if [ -f "$TARGET_DIR/docker-compose.yml" ]; then
    echo "PASS"
else
    echo "FAIL (No docker-compose.yml found)"
    FAIL=1
fi

if [ "$FAIL" -gt 0 ]; then
    echo "❌ PRE-FLIGHT CHECK FAILED."
    echo "The agent tried to complete '$PHASE_NAME' but failed hard structural checks."
    echo "You must fix the missing tests / scripts / docker configs before completing this phase!"
    exit 1
fi

echo "✅ Pre-Flight Check Passed."
exit 0
