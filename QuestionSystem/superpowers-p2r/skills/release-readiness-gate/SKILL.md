---
name: release-readiness-gate
description: "Prompt2Repo Phase 4.7: 最终放行门禁。仅当 delivery-check-report 显示 FAIL=0 且关键硬证据全为 0 时，允许 DELIVERY_COMPLETE。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: ["Read", "Bash(*)"]
---

# Release Readiness Gate — Prompt2Repo Phase 4.7

## Superpower Loop Integration

本 Skill 在 Prompt2Repo Ralph-Loop 内运行，是最终放行阶段。

通过本阶段前必须生成：
- `.tmp/release-readiness-gate.md`
- `FINAL_VERDICT: PASS`
- 从 `TASK-*/docs/delivery-check-report.md` 验证 `FAIL=0`

Promise 必须作为最后一行输出：
`<promise>DELIVERY_COMPLETE</promise>`

## 执行步骤

### Step 1: 读取最新交付报告

读取：
- `TASK-*/docs/delivery-check-report.md`

### Step 2: 强制放行规则

必须全部满足：
- 报告中 `FAIL=0`
- `VALIDATE_PACKAGE_EXIT_CODE: 0`
- `DOCKER_UP_EXIT_CODE: 0`
- `DOCKER_SERVICES_HEALTH_EXIT_CODE: 0`
- `RUN_TESTS_SCRIPT_LINT_EXIT_CODE: 0`
- `RUN_TESTS_EXIT_CODE: 0`

任一不满足：
- 当前阶段自动修复并回到 4.55/4.6 重跑
- 禁止输出 `DELIVERY_COMPLETE`

### Step 3: 输出最终放行报告

写入 `.tmp/release-readiness-gate.md`：

```markdown
# Release Readiness Gate Report
FINAL_VERDICT: PASS|FAIL
FAIL_COUNT: <number>
VALIDATE_PACKAGE_EXIT_CODE: <number>
DOCKER_UP_EXIT_CODE: <number>
DOCKER_SERVICES_HEALTH_EXIT_CODE: <number>
RUN_TESTS_SCRIPT_LINT_EXIT_CODE: <number>
RUN_TESTS_EXIT_CODE: <number>
DECISION: GO|BLOCK
```

## Exit Criteria

- `.tmp/release-readiness-gate.md` 存在
- `FINAL_VERDICT: PASS`
- `FAIL_COUNT: 0`

最后一行输出：
`<promise>DELIVERY_COMPLETE</promise>`
