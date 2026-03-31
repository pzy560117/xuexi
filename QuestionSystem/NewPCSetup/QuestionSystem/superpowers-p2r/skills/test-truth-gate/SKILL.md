---
name: test-truth-gate
description: "Prompt2Repo Phase 3.9: 防假绿门禁。真实测试双跑 + run_tests 脚本吞错检查，证据齐全后才允许进入打包。"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# Test Truth Gate — Prompt2Repo Phase 3.9

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>TEST_TRUTH_COMPLETE</promise>` 前，必须满足：
- `.tmp/test-truth-gate.md` 已生成
- `FINAL_VERDICT: PASS`
- `TEST_RUN_1_EXIT_CODE: 0`
- `TEST_RUN_2_EXIT_CODE: 0`
- `RUN_TESTS_SCRIPT_LINT_EXIT_CODE: 0`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：必须执行真实测试命令，且连续两轮结果一致，禁止仅引用历史报告。
- **MANDATORY**：必须检查 `run_tests.sh` / `run_tests.bat` 是否存在吞错模式（如 `|| true`）。
- **MANDATORY**：若第二轮测试与第一轮不一致，必须判定 FAIL 并在本阶段修复后重跑。
- **PROHIBITED**：以“我认为通过”替代命令证据。

## 执行步骤

### Step 1: 识别测试入口并执行双跑

1. 在项目根目录识别测试命令（优先：
   - Python：`python -m pytest -q`
   - Node：`npm test -- --runInBand`
   - Java：`mvn -q test`
   - Go：`go test ./...`
2. 连续执行两轮相同测试命令，记录退出码与摘要。
3. 任一轮退出码非 0，或两轮结论不一致，直接 FAIL。

### Step 2: run_tests 脚本防假绿检查

检查并记录：
- `run_tests.sh` 不得包含 `|| true` 这类吞错模式。
- `run_tests.sh` 应包含 `set -e`。
- `run_tests.bat` 若包含测试命令，必须有 `if errorlevel 1 exit /b 1` 的失败短路。

任一不满足，`RUN_TESTS_SCRIPT_LINT_EXIT_CODE` 必须为非 0，并判定 FAIL。

### Step 3: 生成门禁报告

写入 `.tmp/test-truth-gate.md`：

```markdown
# Test Truth Gate Report
FINAL_VERDICT: PASS|FAIL
## Test Evidence
- TEST_COMMAND: <command>
- TEST_RUN_1_EXIT_CODE: <code>
- TEST_RUN_2_EXIT_CODE: <code>
- TEST_RUN_1_SUMMARY: <summary>
- TEST_RUN_2_SUMMARY: <summary>
## Script Lint
- RUN_TESTS_SCRIPT_LINT_EXIT_CODE: <code>
- LINT_NOTES: <notes>
## Decision
- <GO or BLOCK>
```

## Exit Criteria

- `.tmp/test-truth-gate.md` 存在且 `FINAL_VERDICT: PASS`
- 报告中包含：
  - `TEST_RUN_1_EXIT_CODE: 0`
  - `TEST_RUN_2_EXIT_CODE: 0`
  - `RUN_TESTS_SCRIPT_LINT_EXIT_CODE: 0`

不满足时：
- 必须在当前 Phase 自动修复并重跑
- 禁止输出完成 Promise

最后一行输出：
`<promise>TEST_TRUTH_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`

