---
name: post-package-test-iteration-3
description: "Prompt2Repo Phase 4.3: 打包后复部署与运行测试第 3 轮。边界与随机顺序复测，主代理 + 子代理双 PASS 才放行。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Post Package Test Iteration 3 — Prompt2Repo Phase 4.3

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>POST_PACKAGE_TEST_R3_COMPLETE</promise>` 前，必须满足：
- `.tmp/post-package-r3-main.md` 与 `.tmp/post-package-r3-subagent.md` 均存在且 `FINAL_VERDICT: PASS`
- 子代理报告包含 `SUBAGENT_ID: <id>`
- 两份报告均覆盖 docs 验收关键字：`validate_package.py`、`docker compose`、`run_tests.sh/run_tests.bat`、`unit_tests`、`API_tests`
- 两份报告都包含硬证据字段：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：第 3 轮必须引入边界场景或随机顺序，验证流程稳定性。
- **MANDATORY**：保持“打包后重部署再测”，不能只读历史报告。
- **PROHIBITED**：跳过子代理复核或省略退出码证据。

## 执行步骤

1. 在 `TASK-*/repo` 重新部署并执行测试（包含边界/随机顺序场景）。
2. 覆盖 docs 核验项并记录证据：
   - 结构校验（`validate_package.py`）
   - 一键部署（`docker compose`）
   - 统一测试脚本（`run_tests.sh/.bat`）
   - `unit_tests` 与 `API_tests`
3. 输出主代理报告 `.tmp/post-package-r3-main.md`。
4. 子代理独立复核并输出 `.tmp/post-package-r3-subagent.md`（含 `SUBAGENT_ID` 与退出码）。

## 报告模板

```markdown
# Post Package Test Iteration 3 - Main|Subagent
FINAL_VERDICT: PASS|FAIL
SUBAGENT_ID: <id or N/A for main>
VALIDATE_PACKAGE_EXIT_CODE: <number>
DOCKER_UP_EXIT_CODE: <number>
RUN_TESTS_EXIT_CODE: <number>
## Docs Requirements Evidence
- validate_package.py: <command/result>
- docker compose: <command/result>
- run_tests.sh/run_tests.bat: <command/result>
- unit_tests: <coverage/result>
- API_tests: <coverage/result>
## Edge/Shuffle Scenarios
- <scenario/result>
```

## Exit Criteria

- R3 主/子报告均 PASS
- 子代理报告含真实 `SUBAGENT_ID`
- docs 验收关键字齐全
- 两份报告均包含：`VALIDATE_PACKAGE_EXIT_CODE: 0`、`DOCKER_UP_EXIT_CODE: 0`、`RUN_TESTS_EXIT_CODE: 0`

不满足时必须自动修复并重跑本轮，不得输出 Promise。

最后一行输出：
`<promise>POST_PACKAGE_TEST_R3_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
