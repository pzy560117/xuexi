---
name: coverage-gate
description: "Prompt2Repo Phase 3.8: 覆盖率门禁。执行覆盖率阈值校验（默认 line>=80%, branch>=70%，支持 Python/Maven）。"
argument-hint: []
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-coverage-gate.sh:*)"]
---

# Coverage Gate — Prompt2Repo Phase 3.8

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>COVERAGE_COMPLETE</promise>` 时必须遵守：
- 覆盖率阈值全部达标
- `.tmp/coverage-gate-report.md` 已生成
- 无 FAIL/WARN 级问题

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## 概述

本 Skill 强制执行覆盖率阈值，避免"测试存在但覆盖不足"的风险。

**前提条件**:
- Phase 3.7 `stability-loop` 已完成并输出 `STABILITY_COMPLETE`

## Background Knowledge

**核心概念**: 覆盖率是测试充分性的底线指标。行覆盖率 ≥ 80% 和分支覆盖率 ≥ 70% 是行业标准的最低门槛。

- **MANDATORY**: 行覆盖率（line coverage）≥ 80%
- **MANDATORY**: 分支覆盖率（branch coverage）≥ 70%
- **MANDATORY**: 覆盖率数据必须来自实际执行（非估算）
- **PROHIBITED**: 不得通过排除核心文件来人为提高覆盖率
- **PROHIBITED**: 不得将测试文件本身计入覆盖率统计

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

1. 增补测试并修复失败用例（优先覆盖核心业务逻辑和异常路径）。
2. 重新执行 Step 1。
3. 最多 5 轮。

## Exit Criteria

当以下全部满足时，Phase 3.8 完成：
- `.tmp/coverage-gate-report.md` 已生成
- 行覆盖率 ≥ 80%，分支覆盖率 ≥ 70%
- 报告中 `FAIL=0` 且 `WARN=0`

输出 `<promise>COVERAGE_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/verify-coverage-gate.sh` - 覆盖率门禁验证脚本
