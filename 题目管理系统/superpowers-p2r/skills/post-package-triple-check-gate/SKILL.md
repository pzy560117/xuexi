---
name: post-package-triple-check-gate
description: "Prompt2Repo Phase 4.4: 打包后三轮复部署测试一致性门禁。汇总 6 份报告，全部 PASS 且硬证据为 0 才放行。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Post Package Triple Check Gate — Prompt2Repo Phase 4.4

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>POST_PACKAGE_TRIPLE_CHECK_COMPLETE</promise>` 前，必须满足：
- 三轮主代理报告全部 PASS
- 三轮子代理报告全部 PASS
- 6 份报告都包含硬证据字段并为 0：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`
- `.tmp/post-package-triple-check-gate.md` 存在且 `FINAL_VERDICT: PASS`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：必须读取并核对 6 份报告：
  - `.tmp/post-package-r1-main.md`
  - `.tmp/post-package-r1-subagent.md`
  - `.tmp/post-package-r2-main.md`
  - `.tmp/post-package-r2-subagent.md`
  - `.tmp/post-package-r3-main.md`
  - `.tmp/post-package-r3-subagent.md`
- **MANDATORY**：每份报告都要覆盖 docs 验收关键字和硬证据字段。
- **PROHIBITED**：任一轮 FAIL、缺字段、字段非 0 仍继续放行。

## 执行步骤

### Step 1: 汇总校验

1. 检查 6 份报告是否存在。
2. 检查每份是否 `FINAL_VERDICT: PASS`。
3. 检查子代理报告是否都有 `SUBAGENT_ID: <id>`。
4. 检查每份是否包含 docs 验收关键字：
   - `validate_package.py`
   - `docker compose`
   - `run_tests.sh/run_tests.bat`
   - `unit_tests`
   - `API_tests`
5. 检查每份是否包含且满足：
   - `VALIDATE_PACKAGE_EXIT_CODE: 0`
   - `DOCKER_UP_EXIT_CODE: 0`
   - `RUN_TESTS_EXIT_CODE: 0`

### Step 2: 生成门禁报告

写入 `.tmp/post-package-triple-check-gate.md`：

```markdown
# Post Package Triple Check Gate Report
FINAL_VERDICT: PASS|FAIL
## Round Summary
- R1: main=<PASS|FAIL>, subagent=<PASS|FAIL>
- R2: main=<PASS|FAIL>, subagent=<PASS|FAIL>
- R3: main=<PASS|FAIL>, subagent=<PASS|FAIL>
## Hard Evidence Summary
- VALIDATE_PACKAGE_EXIT_CODE_ALL_ZERO: <PASS|FAIL>
- DOCKER_UP_EXIT_CODE_ALL_ZERO: <PASS|FAIL>
- RUN_TESTS_EXIT_CODE_ALL_ZERO: <PASS|FAIL>
## Docs Acceptance Coverage
- validate_package.py: <PASS|FAIL>
- docker compose: <PASS|FAIL>
- run_tests.sh/run_tests.bat: <PASS|FAIL>
- unit_tests: <PASS|FAIL>
- API_tests: <PASS|FAIL>
## Release Decision
- <GO or BLOCK>
```

### Step 3: 放行规则

- 仅当三轮双轨均 PASS 且 docs 验收覆盖完整且三项硬证据全为 0 时放行。
- 否则回到对应轮次修复并重跑，再回到本门禁复核。

## Exit Criteria

- `.tmp/post-package-triple-check-gate.md` 存在且 `FINAL_VERDICT: PASS`
- 三轮 6 份报告全 PASS
- docs 验收关键字检查全通过
- 三项硬证据在 6 份报告中全部为 0

不满足时必须自动回滚到对应轮次修复重跑，不得输出 Promise。

最后一行输出：
`<promise>POST_PACKAGE_TRIPLE_CHECK_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
