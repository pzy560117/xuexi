---
name: delivery-checker
description: "Prompt2Repo Phase 4.5: 对 TASK 交付包执行最终自动验收，强制校验 validate_package + docker up + run_tests 硬证据"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-delivery-package.sh:*)"]
---

# Delivery Checker — Prompt2Repo Phase 4.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>DELIVERY_COMPLETE</promise>` 前必须满足：
- 已执行 `${CLAUDE_PLUGIN_ROOT}/scripts/verify-delivery-package.sh`
- 已生成 `TASK-{ID}/docs/delivery-check-report.md`
- 报告中 `FAIL=0`
- 报告中硬证据均为 0：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

- **MANDATORY**: 最终验收必须在交付包上执行，不能复用打包前结论。
- **MANDATORY**: 任一 FAIL 都必须先修复再复验。
- **MANDATORY**: `docker` 不可用或 `docker compose up` 失败视为阻塞失败。
- **PROHIBITED**: 不允许跳过本阶段，不允许在 FAIL>0 时输出 `DELIVERY_COMPLETE`。

## 输入参数

- `--task-id`（建议传入）：题目 ID，格式 `TASK-XXXXXXXX-XXXXXX`

## 执行步骤

### Step 1: 定位交付包

优先使用 `--task-id`；未传入时自动选择当前工作区最新 `TASK-*` 目录。

### Step 2: 执行最终自动验收

运行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-delivery-package.sh" --task-id TASK-XXXXXXXX-XXXXXX
```

脚本会强制执行并记录：
- `validate_package.py` 检查结果
- `docker compose config -q`
- `docker compose up -d` / `down --remove-orphans`
- `run_tests.sh` 或 `run_tests.bat`
- 全包英文红线（prompt_language=en 时）

### Step 3: 检查报告并处理失败

报告路径：`TASK-{ID}/docs/delivery-check-report.md`

若 `FAIL > 0`：
1. 修复阻塞项。
2. 重新执行 Step 2。
3. 在本 Phase 内循环直至 `FAIL=0`。

## Exit Criteria

当以下全部满足时，Phase 4.5 完成：
- `TASK-{ID}/docs/delivery-check-report.md` 存在
- 报告统计中 `FAIL=0`
- 报告包含：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`

最后一行输出：
`<promise>DELIVERY_COMPLETE</promise>`

## References

- `../../scripts/verify-delivery-package.sh`
- `../../skills/references/completion-promises.md`
