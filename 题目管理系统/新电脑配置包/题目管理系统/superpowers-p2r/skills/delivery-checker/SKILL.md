---
name: delivery-checker
description: "Prompt2Repo Phase 4.5: 对 TASK 交付包执行自动化验收，输出统一检查报告并作为最终结束门禁"
---

# Delivery Checker — Prompt2Repo Phase 4.5

## 概述

本 Skill 在打包阶段之后执行自动验收，确保 `TASK-{ID}/` 可以作为可交付产物。

**前提条件**:
- Phase 4 已完成并输出 `PACKAGE_COMPLETE`
- `TASK-{ID}/` 目录已生成

## 输入参数

- `--task-id`（建议传入）：题目 ID，格式 `TASK-XXXXXXXX-XXXXXX`

## 执行步骤

### Step 1: 定位交付包目录

优先使用 `--task-id` 定位：

```
TASK-{ID}/
```

如果未传 `--task-id`，自动选择当前工作区最新的 `TASK-*` 目录。

### Step 2: 运行多重质量门禁（先测后验）

先在交付包内 `repo/` 执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-test-gate.sh" \
  --repo-dir TASK-{ID}/repo \
  --report-file TASK-{ID}/docs/test-gate-report.md \
  --min-unit-test-files 3 \
  --min-api-test-files 3 \
  --min-unit-coverage 70 \
  --run-api-tests auto \
  --strict true

"${CLAUDE_PLUGIN_ROOT}/scripts/verify-runtime-smoke.sh" \
  --repo-dir TASK-{ID}/repo \
  --report-file TASK-{ID}/docs/runtime-smoke-report.md \
  --strict true

"${CLAUDE_PLUGIN_ROOT}/scripts/verify-stability-loop.sh" \
  --repo-dir TASK-{ID}/repo \
  --report-file TASK-{ID}/docs/stability-loop-report.md \
  --iterations 3 \
  --strict true

"${CLAUDE_PLUGIN_ROOT}/scripts/verify-coverage-gate.sh" \
  --repo-dir TASK-{ID}/repo \
  --report-file TASK-{ID}/docs/coverage-gate-report.md \
  --strict true \
  --min-line-coverage 70 \
  --min-branch-coverage 50

"${CLAUDE_PLUGIN_ROOT}/scripts/verify-github-policy-gate.sh" \
  --repo-dir TASK-{ID}/repo \
  --report-file TASK-{ID}/docs/policy-gate-report.md \
  --strict false \
  --required-checks "test-gate,runtime-smoke,stability-loop,coverage-gate,delivery-check"
```

若任一门禁失败，先修复后再继续后续验收。

### Step 3: 运行自动验收脚本

执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-delivery-package.sh" --task-id TASK-XXXXXXXX-XXXXXX
```

脚本输出：
- `PASS/WARN/FAIL` 统计
- `TASK-{ID}/delivery-check-report.md`

### Step 4: 处理阻塞项并复验

若脚本返回失败（`FAIL > 0`）：

1. 修复阻塞问题（例如：缺失核心文件、目录结构错误、缓存污染文件、metadata 必填字段缺失）。
2. 重新执行 Step 2 复验。
3. 最多复验 3 轮；若仍失败，将阻塞项写入 `questions.md` 并明确给出修复建议。

### Step 5: 输出结论

在回复中给出：
- 总检查结果（PASS/WARN/FAIL）
- 阻塞项修复状态
- 报告文件路径

## 完成条件

当以下全部满足时，Phase 4.5 完成：
- `verify-delivery-package.sh` 执行完成
- `TASK-{ID}/delivery-check-report.md` 已生成
- 无 FAIL 级阻塞项

输出 `<promise>DELIVERY_COMPLETE</promise>` 标记完成整个流水线，且该标签必须是回复最后一行。

## 跳过条件

当传入 `--skip-delivery-check` 参数时，跳过本 Phase，直接输出 `<promise>DELIVERY_COMPLETE</promise>`（最后一行）。

