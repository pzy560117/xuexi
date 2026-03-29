---
name: policy-gate
description: "Prompt2Repo Phase 3.9: GitHub 策略门禁。校验 workflow 并发策略、required checks 映射、分支保护（可用时）。"
argument-hint: []
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-github-policy-gate.sh:*)"]
---

# Policy Gate — Prompt2Repo Phase 3.9

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>POLICY_COMPLETE</promise>` 时必须遵守：
- 策略门禁脚本执行完成
- `.tmp/policy-gate-report.md` 已生成
- 无 FAIL 级问题

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## 概述

本 Skill 用于把质量门禁落到 CI/CD 和仓库策略，避免"本地通过、合并后失控"。

**前提条件**:
- Phase 3.8 `coverage-gate` 已完成并输出 `COVERAGE_COMPLETE`

## Background Knowledge

**核心概念**: 代码质量不仅靠本地检查，还需要 CI/CD 策略和分支保护规则来持续强制执行。

- **MANDATORY**: 检查 GitHub Actions workflow 是否存在且配置合理
- **MANDATORY**: 检查 required checks 是否映射到关键门禁（test-gate, runtime-smoke 等）
- **MANDATORY**: 在离线/无 GitHub 凭据场景下允许 WARN 但不阻断
- **PROHIBITED**: 不得在有 FAIL 级问题时标记通过

## 执行步骤

### Step 1: 运行策略门禁脚本

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-github-policy-gate.sh" \
  --repo-dir "." \
  --report-file ".tmp/policy-gate-report.md" \
  --strict false \
  --required-checks "test-gate,runtime-smoke,stability-loop,coverage-gate,delivery-check"
```

> 说明：`--strict false` 允许在离线/无 GitHub 凭据场景下给出 WARN，不阻断本地流水线。

### Step 2: 修复并复验

若失败：

1. 修复 workflow 或仓库保护策略缺口。
2. 重新执行 Step 1。
3. 最多 3 轮。

## Exit Criteria

当以下全部满足时，Phase 3.9 完成：
- `.tmp/policy-gate-report.md` 已生成
- 报告中 `FAIL=0`

输出 `<promise>POLICY_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/verify-github-policy-gate.sh` - GitHub 策略门禁验证脚本
