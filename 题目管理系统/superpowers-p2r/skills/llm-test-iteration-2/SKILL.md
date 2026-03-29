---
name: llm-test-iteration-2
description: "Prompt2Repo Phase 3.6: LLM 测试迭代第 2 轮。修复首轮问题后进行独立复测，主代理+子代理双 PASS。"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# LLM Test Iteration 2 — Prompt2Repo Phase 3.6

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>LLM_TEST_R2_COMPLETE</promise>` 前，必须满足：
- `.tmp/llm-test-r2-main.md` 与 `.tmp/llm-test-r2-subagent.md` 均存在
- 两份报告都包含 `FINAL_VERDICT: PASS`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：第 2 轮必须和第 1 轮形成“独立复测”，不能只复制第 1 轮结论。
- **MANDATORY**：必须进行环境重置动作（例如清理缓存/重启服务/重建关键依赖）后再测。
- **MANDATORY**：必须使用子代理独立复核；无子代理则本阶段失败。
- **PROHIBITED**：调用 `verify-*.sh` 脚本替代人工验证。

## 执行步骤

### Step 1: 主代理执行第二轮复测

1. 读取第 1 轮报告：`.tmp/llm-test-r1-main.md`、`.tmp/llm-test-r1-subagent.md`。
2. 先执行重置动作，再运行核心验证命令。
3. 生成 `.tmp/llm-test-r2-main.md`。

### Step 2: 子代理独立复核

1. 创建子代理并下达“独立复测”任务（不得复用主代理结论）。
2. 子代理至少复跑 2 条关键命令并给出证据。
3. 生成 `.tmp/llm-test-r2-subagent.md`。
4. 子代理报告必须包含 `SUBAGENT_ID: <id>`。

### Step 3: 判定与回滚

- 双 PASS 才允许通过。
- 任一 FAIL：先修复后重跑本阶段。

## 报告模板

```markdown
# LLM Test Iteration 2
FINAL_VERDICT: PASS|FAIL
## Reset Actions
- <reset action>
## Commands
- <command>
## Findings
- <finding>
## Blocking Issues
- <issue or NONE>
```

## Exit Criteria

- `.tmp/llm-test-r2-main.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r2-subagent.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r2-subagent.md` 包含 `SUBAGENT_ID: <id>`

若不满足 Exit Criteria：
- 必须在当前 Phase 自动修复并重跑，直到满足条件
- 禁止停下来等待用户手动介入
- 禁止输出完成 Promise

最后一行输出：
`<promise>LLM_TEST_R2_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
