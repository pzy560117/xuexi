---
name: test-gate
description: "Prompt2Repo Phase 3.5: 严格测试门禁。执行单元测试覆盖率阈值、API 集成测试、测试脚本 fail-fast 校验，并输出标准报告。"
---

# Test Gate — Prompt2Repo Phase 3.5

## 概述

本 Skill 用于在打包前执行**硬性测试门禁**，防止“脚本看似通过但实际失败”的交付风险。

**前提条件**:
- Phase 3（Self Review）已完成并输出 `SELF_REVIEW_COMPLETE`
- 项目根目录存在 `unit_tests/`、`API_tests/`、`run_tests.sh`、`run_tests.bat`

## 执行步骤

### Step 1: 执行测试门禁脚本（强制）

执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-test-gate.sh" \
  --repo-dir "." \
  --report-file ".tmp/test-gate-report.md" \
  --min-unit-test-files 3 \
  --min-api-test-files 3 \
  --min-unit-coverage 70 \
  --run-api-tests auto \
  --strict true
```

### Step 2: 处理失败项并复验

若脚本返回失败：

1. 修复失败项（如：测试脚本吞错、单测失败、覆盖率不足、API 测试失败）。
2. 重新执行 Step 1。
3. 最多复验 3 轮；若仍失败，写入 `questions.md` 并标记阻塞原因。

### Step 3: 输出结论

回复中必须包含：
- `PASS/WARN/FAIL` 汇总
- 报告路径：`.tmp/test-gate-report.md`
- 阻塞项修复状态

## 完成条件

当以下全部满足时，Phase 3.5 完成：
- `verify-test-gate.sh` 执行完成
- `.tmp/test-gate-report.md` 已生成
- 无 `FAIL` 级问题

输出 `TEST_GATE_COMPLETE` 标记完成。
