---
name: post-package-test-iteration-2
description: "Prompt2Repo Phase 4.2: 打包后复部署与运行测试第 2 轮。清理重启后复测，主代理 + 子代理双 PASS 才放行。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Post Package Test Iteration 2 — Prompt2Repo Phase 4.2

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>POST_PACKAGE_TEST_R2_COMPLETE</promise>` 前，必须满足：
- `.tmp/post-package-r2-main.md` 与 `.tmp/post-package-r2-subagent.md` 都存在且 `FINAL_VERDICT: PASS`
- 子代理报告包含 `SUBAGENT_ID: <id>`
- 两份报告都包含 docs 验收关键字：`validate_package.py`、`docker compose`、`run_tests.sh/run_tests.bat`、`unit_tests`、`API_tests`
- 两份报告都包含硬证据字段：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：第 2 轮必须在“清理/重启后”重新部署和复测，避免首轮缓存假阳性。
- **MANDATORY**：子代理独立复核，不得直接复述主代理结论。
- **PROHIBITED**：未跑命令或无退出码证据就判定通过。

## 执行步骤

1. 在 `TASK-*/repo` 执行清理后重新部署。
2. 重新执行 docs 要求核验：
   - `validate_package.py`
   - `docker compose config --quiet`
   - `docker compose up -d` → `run_tests.sh/.bat` → `docker compose down --remove-orphans`
3. 生成 `.tmp/post-package-r2-main.md`（写入命令+退出码）。
4. 启动子代理独立复跑关键路径，生成 `.tmp/post-package-r2-subagent.md`（含 `SUBAGENT_ID` 与退出码）。

## 报告模板

```markdown
# Post Package Test Iteration 2 - Main|Subagent
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
## Regression Check
- <regression or NONE>
```

## Exit Criteria

- R2 主/子报告均 PASS
- 子代理报告含真实 `SUBAGENT_ID`
- docs 验收关键字齐全
- 两份报告均包含：`VALIDATE_PACKAGE_EXIT_CODE: 0`、`DOCKER_UP_EXIT_CODE: 0`、`RUN_TESTS_EXIT_CODE: 0`

不满足时必须自动修复并重跑本轮，不得输出 Promise。

最后一行输出：
`<promise>POST_PACKAGE_TEST_R2_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
