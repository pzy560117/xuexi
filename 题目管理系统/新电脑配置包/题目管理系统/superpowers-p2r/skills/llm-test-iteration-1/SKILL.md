---
name: llm-test-iteration-1
description: "Prompt2Repo Phase 3.5: LLM 测试迭代第 1 轮。主代理执行测试验证，子代理独立复核，双 PASS 才可放行。"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# LLM Test Iteration 1 — Prompt2Repo Phase 3.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>LLM_TEST_R1_COMPLETE</promise>` 前，必须满足：
- 主代理报告：`.tmp/llm-test-r1-main.md`
- 子代理报告：`.tmp/llm-test-r1-subagent.md`
- 两份报告都包含 `FINAL_VERDICT: PASS`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：测试与验证必须由 LLM 直接执行命令完成，禁止调用任何 `verify-*.sh` 脚本。
- **MANDATORY**：必须创建子代理进行独立复核；若子代理不可用，本阶段判定为阻塞，不得输出 Promise。
- **MANDATORY**：主代理与子代理至少各自运行一组可复现命令并记录原始结果。
- **PROHIBITED**：仅凭“我认为通过”下结论。

## 执行步骤

### Step 1: 主代理执行首轮验证

1. 自动识别技术栈与测试入口（如 `pom.xml` / `package.json` / `pytest` / `go test`）。
2. 执行最小闭环验证：
   - 构建/编译检查
   - 单元测试
   - 关键 API 或核心流程验证
3. 将命令、退出码、关键输出摘要写入 `.tmp/llm-test-r1-main.md`。

报告必须包含：

```markdown
# LLM Test Iteration 1 - Main
FINAL_VERDICT: PASS|FAIL
## Commands
- <command>
## Findings
- <finding>
## Blocking Issues
- <issue or NONE>
```

### Step 2: 子代理独立复核

1. 启动一个可用子代理（优先 `general-purpose` 或 `Explore`）。
2. 向子代理下达任务：独立复跑关键命令、抽查核心文件、给出 PASS/FAIL 结论与证据。
3. 将子代理结果写入 `.tmp/llm-test-r1-subagent.md`，格式同上。
4. 子代理报告必须包含 `SUBAGENT_ID: <id>`（使用真实子代理 ID，不可留空）。

### Step 3: 双轨结论判定

- 仅当主代理与子代理均为 `FINAL_VERDICT: PASS`，且无阻塞项时才可通过。
- 任一 `FAIL`：必须先修复，再重新执行本阶段（仍输出到同一对报告文件）。

## Exit Criteria

当以下全部满足时，Phase 3.5 完成：
- `.tmp/llm-test-r1-main.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r1-subagent.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r1-subagent.md` 包含 `SUBAGENT_ID: <id>`

若不满足 Exit Criteria：
- 必须在当前 Phase 自动修复并重跑，直到满足条件
- 禁止停下来等待用户手动介入
- 禁止输出完成 Promise

最后一行输出：
`<promise>LLM_TEST_R1_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
