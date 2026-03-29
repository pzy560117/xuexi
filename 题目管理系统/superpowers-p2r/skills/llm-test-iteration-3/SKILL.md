---
name: llm-test-iteration-3
description: "Prompt2Repo Phase 3.7: LLM 测试迭代第 3 轮。主代理与子代理针对边界/随机顺序进行最终独立验证。"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# LLM Test Iteration 3 — Prompt2Repo Phase 3.7

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>LLM_TEST_R3_COMPLETE</promise>` 前，必须满足：
- `.tmp/llm-test-r3-main.md` 与 `.tmp/llm-test-r3-subagent.md` 均存在
- 两份报告都包含 `FINAL_VERDICT: PASS`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：第 3 轮必须覆盖边界与异常路径，而不只是 happy path。
- **MANDATORY**：主代理和子代理需要进行至少一次“顺序扰动”验证（不同执行顺序/不同入口组合）。
- **MANDATORY**：必须完成子代理独立复核。
- **PROHIBITED**：无证据直接宣称稳定。

## 执行步骤

### Step 1: 主代理最终验证

1. 回看前两轮报告，提取风险点。
2. 运行边界/异常/顺序扰动测试。
3. 产出 `.tmp/llm-test-r3-main.md`。

### Step 2: 子代理最终复核

1. 子代理针对前两轮高风险点独立复核。
2. 输出 `.tmp/llm-test-r3-subagent.md`。
3. 子代理报告必须包含 `SUBAGENT_ID: <id>`。

### Step 3: 通过判定

- 仅双 PASS 才放行。
- 任一 FAIL 必须修复并重跑本轮。

## 报告模板

```markdown
# LLM Test Iteration 3
FINAL_VERDICT: PASS|FAIL
## Risk Points Rechecked
- <risk>
## Commands
- <command>
## Findings
- <finding>
## Blocking Issues
- <issue or NONE>
```

## Exit Criteria

- `.tmp/llm-test-r3-main.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r3-subagent.md` 存在且 `FINAL_VERDICT: PASS`
- `.tmp/llm-test-r3-subagent.md` 包含 `SUBAGENT_ID: <id>`

若不满足 Exit Criteria：
- 必须在当前 Phase 自动修复并重跑，直到满足条件
- 禁止停下来等待用户手动介入
- 禁止输出完成 Promise

最后一行输出：
`<promise>LLM_TEST_R3_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
