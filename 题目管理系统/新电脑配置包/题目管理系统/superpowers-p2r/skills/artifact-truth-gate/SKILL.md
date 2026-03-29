---
name: artifact-truth-gate
description: "Prompt2Repo Phase 4.5: 报告真值门禁。强制校验 post-package 报告与 TASK 包真实文件系统一致后才允许最终交付验收。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Artifact Truth Gate — Prompt2Repo Phase 4.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>ARTIFACT_TRUTH_COMPLETE</promise>` 前，必须满足：
- `.tmp/artifact-truth-gate.md` 已生成
- `FINAL_VERDICT: PASS`
- `TASK-*/repo/unit_tests` 与 `TASK-*/repo/API_tests` 均真实存在
- post-package 三轮报告与汇总报告不存在“PASS 但自相矛盾”文本

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：必须校验“文件系统事实”而不是只看报告文本。
- **MANDATORY**：如发现报告与事实不一致，必须回到对应轮次修复并重跑。
- **PROHIBITED**：在目录缺失或报告自相矛盾时放行到 delivery-checker。

## 执行步骤

### Step 1: 锁定交付包与报告

必须读取：
- 最新 `TASK-*` 目录
- `.tmp/post-package-r1-main.md`
- `.tmp/post-package-r1-subagent.md`
- `.tmp/post-package-r2-main.md`
- `.tmp/post-package-r2-subagent.md`
- `.tmp/post-package-r3-main.md`
- `.tmp/post-package-r3-subagent.md`
- `.tmp/post-package-triple-check-gate.md`

### Step 2: 文件系统真值校验（强制）

检查：
- `TASK-*/repo/unit_tests` 目录存在
- `TASK-*/repo/API_tests` 目录存在

任一缺失即 FAIL。

### Step 3: 报告一致性校验（强制）

逐份报告检查：
- 包含 `FINAL_VERDICT: PASS`
- 包含硬证据字段且为 0：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`
- 不包含矛盾短语：
  - `Known Issue`
  - `not separate directory`
  - `inherited from unit tests`
  - `consistently fail` / `consistently fails`

### Step 4: 生成门禁报告

写入 `.tmp/artifact-truth-gate.md`：

```markdown
# Artifact Truth Gate Report
FINAL_VERDICT: PASS|FAIL
## Filesystem Truth
- REPO_UNIT_TESTS_DIR_EXISTS: <PASS|FAIL>
- REPO_API_TESTS_DIR_EXISTS: <PASS|FAIL>
## Report Consistency
- R1_MAIN: <PASS|FAIL>
- R1_SUBAGENT: <PASS|FAIL>
- R2_MAIN: <PASS|FAIL>
- R2_SUBAGENT: <PASS|FAIL>
- R3_MAIN: <PASS|FAIL>
- R3_SUBAGENT: <PASS|FAIL>
- TRIPLE_CHECK: <PASS|FAIL>
## Decision
- <GO or BLOCK>
```

## Exit Criteria

- `.tmp/artifact-truth-gate.md` 存在且 `FINAL_VERDICT: PASS`
- `TASK-*/repo/unit_tests` 与 `TASK-*/repo/API_tests` 均存在
- 所有 post-package 报告均通过一致性校验，无矛盾文本

不满足时：
- 必须回到对应 post-package phase 修复并重跑
- 禁止输出完成 Promise

最后一行输出：
`<promise>ARTIFACT_TRUTH_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
