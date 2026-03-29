---
name: policy-gate
description: "Prompt2Repo Phase 3.9: GitHub 策略门禁。校验 workflow 并发策略、required checks 映射、分支保护（可用时）。"
---

# Policy Gate — Prompt2Repo Phase 3.9

## 概述

本 Skill 用于把质量门禁落到 CI/CD 和仓库策略，避免“本地通过、合并后失控”。

**前提条件**:
- Phase 3.8 `coverage-gate` 已完成并输出 `COVERAGE_COMPLETE`

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

## 完成条件

- `.tmp/policy-gate-report.md` 已生成
- 报告中 `FAIL=0`

输出 `<promise>POLICY_COMPLETE</promise>`，且该标签必须是回复最后一行。

