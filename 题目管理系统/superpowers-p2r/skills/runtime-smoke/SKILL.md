---
name: runtime-smoke
description: "Prompt2Repo Phase 3.6: 运行态冒烟门禁。强制 docker 启动 + 健康检查 + API 测试，确保系统可运行。"
argument-hint: []
user-invocable: false
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-runtime-smoke.sh:*)"]
---

# Runtime Smoke — Prompt2Repo Phase 3.6

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>RUNTIME_SMOKE_COMPLETE</promise>` 时必须遵守：
- 所有步骤全部完成
- `.tmp/runtime-smoke-report.md` 已生成
- 无 FAIL/WARN 级问题

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## 概述

本 Skill 用于在打包前执行运行态冒烟验证，防止"编译通过但服务起不来"的交付风险。

**前提条件**:
- Phase 3.5 `test-gate` 已完成并输出 `TEST_GATE_COMPLETE`
- 项目根目录存在 `docker-compose.yml`

## Background Knowledge

**核心概念**: 运行态验证是测试金字塔的最顶层——确认系统在容器化环境中可以正确启动、响应健康检查、处理 API 请求。

- **MANDATORY**: Docker 容器必须完全启动并通过健康检查后才能执行 API 探测
- **MANDATORY**: API 冒烟测试必须覆盖至少 `/health` 和主要业务端点
- **PROHIBITED**: 不得跳过容器启动验证直接执行 API 测试
- **PROHIBITED**: 不得在 API 测试失败时手动标记为 PASS

## 执行步骤

### Step 1: 运行 runtime smoke 脚本

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-runtime-smoke.sh" \
  --repo-dir "." \
  --report-file ".tmp/runtime-smoke-report.md" \
  --strict true \
  --fail-on-warn true \
  --api-wait-seconds 240 \
  --api-repeat 2 \
  --smoke-paths "/health,/api/v1/system/health"
```

### Step 2: 修复并复验

若执行失败：

1. 修复服务启动/健康检查/API 测试问题。
2. 重新执行 Step 1。
3. 最多 5 轮；仍失败则写入 `questions.md` 并标记阻塞。

## Exit Criteria

当以下全部满足时，Phase 3.6 完成：
- `.tmp/runtime-smoke-report.md` 已生成
- 报告中 `FAIL=0` 且 `WARN=0`
- Docker 容器可成功启动并响应健康检查

输出 `<promise>RUNTIME_SMOKE_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/verify-runtime-smoke.sh` - 运行态冒烟验证脚本
