---
name: coverage-gate
description: "Prompt2Repo Phase 3.8: 覆盖率门禁。执行覆盖率阈值校验（默认 line>=80%, branch>=70%，支持 Python/Maven）。"
---

# Coverage Gate — Prompt2Repo Phase 3.8

## 概述

本 Skill 强制执行覆盖率阈值，避免“测试存在但覆盖不足”的风险。

**前提条件**:
- Phase 3.7 `stability-loop` 已完成并输出 `STABILITY_COMPLETE`

## 执行步骤

### Step 1: 运行覆盖率门禁脚本

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-coverage-gate.sh" \
  --repo-dir "." \
  --report-file ".tmp/coverage-gate-report.md" \
  --strict true \
  --fail-on-warn true \
  --min-line-coverage 80 \
  --min-branch-coverage 70
```

### Step 2: 修复并复验

若失败：

1. 增补测试并修复失败用例。
2. 重新执行 Step 1。
3. 最多 5 轮。

## 完成条件

- `.tmp/coverage-gate-report.md` 已生成
- 报告中 `FAIL=0` 且 `WARN=0`

输出 `<promise>COVERAGE_COMPLETE</promise>`，且该标签必须是回复最后一行。

