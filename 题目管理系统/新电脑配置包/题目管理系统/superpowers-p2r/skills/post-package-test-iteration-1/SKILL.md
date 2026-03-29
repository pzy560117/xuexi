---
name: post-package-test-iteration-1
description: "Prompt2Repo Phase 4.1: 打包后复部署与运行测试第 1 轮。主代理 + 子代理独立验证，双 PASS 才放行。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Post Package Test Iteration 1 — Prompt2Repo Phase 4.1

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>POST_PACKAGE_TEST_R1_COMPLETE</promise>` 前，必须满足：
- 主代理报告：`.tmp/post-package-r1-main.md`
- 子代理报告：`.tmp/post-package-r1-subagent.md`
- 两份报告都包含 `FINAL_VERDICT: PASS`
- 子代理报告包含 `SUBAGENT_ID: <id>`
- 两份报告都包含 docs 验收关键字：`validate_package.py`、`docker compose`、`run_tests.sh/run_tests.bat`、`unit_tests`、`API_tests`
- 两份报告都包含硬证据字段：
  - `VALIDATE_PACKAGE_EXIT_CODE: 0`
  - `DOCKER_UP_EXIT_CODE: 0`
  - `RUN_TESTS_EXIT_CODE: 0`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：在 `TASK-*/repo` 上执行“打包后重新部署 + 运行测试”，不得只复用打包前结论。
- **MANDATORY**：必须创建子代理进行独立复核并写入真实 `SUBAGENT_ID`。
- **PROHIBITED**：只写“已通过”但没有命令退出码证据。

## 执行步骤

### Step 1: 主代理验证

1. 定位 `TASK-*` 目录。
2. 执行结构校验：`python script/validate_package.py TASK-*`
3. 在 `TASK-*/repo` 执行：
   - `docker compose config --quiet`
   - `docker compose up -d`
   - `run_tests.sh` 或 `run_tests.bat`
   - `docker compose down --remove-orphans`
4. 记录命令与退出码到 `.tmp/post-package-r1-main.md`。

### Step 2: 子代理独立复核

1. 启动子代理，独立重跑关键路径（部署 + 测试 + 结构校验）。
2. 产出 `.tmp/post-package-r1-subagent.md`，包含真实 `SUBAGENT_ID` 与退出码证据。

### Step 3: 报告模板（必须包含）

```markdown
# Post Package Test Iteration 1 - Main|Subagent
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
## Blocking Issues
- <issue or NONE>
```

## Exit Criteria

- `.tmp/post-package-r1-main.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/post-package-r1-subagent.md` 存在且 `FINAL_VERDICT: PASS`
- 子代理报告含 `SUBAGENT_ID: <id>`
- 两份报告均包含 docs 验收关键字
- 两份报告均包含：`VALIDATE_PACKAGE_EXIT_CODE: 0`、`DOCKER_UP_EXIT_CODE: 0`、`RUN_TESTS_EXIT_CODE: 0`

若不满足 Exit Criteria：
- 必须在当前 Phase 自动修复并重跑
- 禁止停下来等待用户介入
- 禁止输出完成 Promise

最后一行输出：
`<promise>POST_PACKAGE_TEST_R1_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
