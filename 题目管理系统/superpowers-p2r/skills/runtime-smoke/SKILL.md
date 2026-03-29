---
name: runtime-smoke
description: "Prompt2Repo Phase 3.6: 运行态冒烟门禁。强制 docker 启动 + 健康检查 + API 测试，确保系统可运行。"
---

# Runtime Smoke — Prompt2Repo Phase 3.6

## 概述

本 Skill 用于在打包前执行运行态冒烟验证，防止“编译通过但服务起不来”的交付风险。

**前提条件**:
- Phase 3.5 `test-gate` 已完成并输出 `TEST_GATE_COMPLETE`
- 项目根目录存在 `docker-compose.yml`

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

## 完成条件

- `.tmp/runtime-smoke-report.md` 已生成
- 报告中 `FAIL=0` 且 `WARN=0`

输出 `<promise>RUNTIME_SMOKE_COMPLETE</promise>`，且该标签必须是回复最后一行。

