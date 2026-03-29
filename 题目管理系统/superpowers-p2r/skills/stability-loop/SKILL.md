---
name: stability-loop
description: "Prompt2Repo Phase 3.7: 稳定性循环门禁。重复运行 runtime smoke（默认 5 轮）检测 flaky 启动和偶发失败。"
---

# Stability Loop — Prompt2Repo Phase 3.7

## 概述

本 Skill 通过多轮运行态冒烟验证检测不稳定行为，避免“一次成功”掩盖间歇性故障。

**前提条件**:
- Phase 3.6 `runtime-smoke` 已完成并输出 `RUNTIME_SMOKE_COMPLETE`

## 执行步骤

### Step 1: 运行稳定性循环脚本

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-stability-loop.sh" \
  --repo-dir "." \
  --report-file ".tmp/stability-loop-report.md" \
  --iterations 5 \
  --strict true \
  --fail-on-warn true \
  --stop-on-first-fail false \
  --min-pass-rate 100
```

### Step 2: 修复并复验

若失败：

1. 基于失败轮次日志修复 flaky 原因。
2. 重新执行 Step 1。
3. 最多 5 轮（每轮完整 runtime smoke）。

## 完成条件

- `.tmp/stability-loop-report.md` 已生成
- 报告中 `FAIL=0` 且 `WARN=0`

输出 `<promise>STABILITY_COMPLETE</promise>`，且该标签必须是回复最后一行。

