---
name: stability-loop
description: "Prompt2Repo Phase 3.7: 稳定性循环门禁。重复运行 runtime smoke（默认 5 轮）检测 flaky 启动和偶发失败。"
argument-hint: []
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-stability-loop.sh:*)"]
---

# Stability Loop — Prompt2Repo Phase 3.7

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>STABILITY_COMPLETE</promise>` 时必须遵守：
- 所有 5 轮 runtime smoke 全部通过
- `.tmp/stability-loop-report.md` 已生成
- 通过率 = 100%

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## 概述

本 Skill 通过多轮运行态冒烟验证检测不稳定行为，避免"一次成功"掩盖间歇性故障。

**前提条件**:
- Phase 3.6 `runtime-smoke` 已完成并输出 `RUNTIME_SMOKE_COMPLETE`

## Background Knowledge

**核心概念**: 单次通过不代表系统稳定。Flaky 行为（竞态条件、资源泄漏、端口冲突）需要多轮重复验证才能暴露。

- **MANDATORY**: 至少执行 5 轮完整 runtime smoke 循环
- **MANDATORY**: 通过率阈值为 100%（5/5 轮全部通过）
- **MANDATORY**: 每轮之间需要完整的容器重启（down → up），不得复用上一轮的容器状态
- **PROHIBITED**: 不得因"前 N 轮通过"而提前终止循环
- **PROHIBITED**: 不得降低通过率阈值

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

1. 基于失败轮次日志修复 flaky 原因（常见：竞态条件、端口冲突、资源泄漏、数据库连接池耗尽）。
2. 重新执行 Step 1。
3. 最多 5 轮（每轮完整 runtime smoke × 5 迭代）。

## Exit Criteria

当以下全部满足时，Phase 3.7 完成：
- `.tmp/stability-loop-report.md` 已生成
- 报告中 `FAIL=0` 且 `WARN=0`
- 5 轮 runtime smoke 通过率 = 100%

输出 `<promise>STABILITY_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/verify-stability-loop.sh` - 稳定性循环验证脚本
- `../runtime-smoke/SKILL.md` - 单轮 runtime smoke 规范
