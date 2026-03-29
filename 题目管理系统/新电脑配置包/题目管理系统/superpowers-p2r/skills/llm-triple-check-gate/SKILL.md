---
name: llm-triple-check-gate
description: "Prompt2Repo Phase 3.8: 三轮双轨测试一致性门禁。汇总 6 份报告并做最终放行判定。"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# LLM Triple Check Gate — Prompt2Repo Phase 3.8

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

输出 `<promise>LLM_TRIPLE_CHECK_COMPLETE</promise>` 前，必须满足：
- 三轮主代理报告全部 PASS
- 三轮子代理报告全部 PASS
- `.tmp/llm-triple-check-gate.md` 存在且 `FINAL_VERDICT: PASS`

**ABSOLUTE LAST OUTPUT RULE**：Promise 标签必须是回复最后一行。

## Background Knowledge

- **MANDATORY**：必须读取并核对以下 6 份报告：
  - `.tmp/llm-test-r1-main.md`
  - `.tmp/llm-test-r1-subagent.md`
  - `.tmp/llm-test-r2-main.md`
  - `.tmp/llm-test-r2-subagent.md`
  - `.tmp/llm-test-r3-main.md`
  - `.tmp/llm-test-r3-subagent.md`
- **MANDATORY**：若任一报告为 FAIL，必须回到对应轮次修复，禁止直接放行。
- **PROHIBITED**：跳过任一轮次的双轨证据检查。

## 执行步骤

### Step 1: 收集与校验

1. 检查 6 份报告是否存在。
2. 检查每份报告是否包含 `FINAL_VERDICT: PASS`。
3. 对比主代理与子代理是否有冲突结论。

### Step 2: 输出一致性结论

生成 `.tmp/llm-triple-check-gate.md`，模板：

```markdown
# LLM Triple Check Gate Report
FINAL_VERDICT: PASS|FAIL
## Round Summary
- R1: main=<PASS|FAIL>, subagent=<PASS|FAIL>
- R2: main=<PASS|FAIL>, subagent=<PASS|FAIL>
- R3: main=<PASS|FAIL>, subagent=<PASS|FAIL>
## Conflicts
- <conflict or NONE>
## Release Decision
- <GO or BLOCK>
```

### Step 3: 放行规则

- 仅当 R1/R2/R3 全部双 PASS 且无冲突，才可输出 Promise。
- 否则保持 BLOCK，修复后重新执行本 Skill。

## Exit Criteria

- `.tmp/llm-triple-check-gate.md` 存在
- 报告含 `FINAL_VERDICT: PASS`
- 三轮 6 份报告均为 PASS

若不满足 Exit Criteria：
- 必须回到对应轮次自动修复并重跑，再回到本门禁重新汇总
- 禁止停下来等待用户手动介入
- 禁止输出完成 Promise

最后一行输出：
`<promise>LLM_TRIPLE_CHECK_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
