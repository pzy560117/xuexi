---
name: idea2repo
description: "Idea2Repo 一键入口: 从模糊的 idea 出发，自动经过头脑风暴(Brainstorming)、计划连贯编写与执行，直达完整交付包。适合没有完整 prompt.md 的场景。"
---

# Idea2Repo — 从 Idea 到 Repo 的全自动流水线

## 概述

本 Skill 是针对“没有成熟需求提示词（prompt.md）”场景设计的自动化入口。它首先通过 `brainstorming` 与你互动澄清需求，自动产出设计文档，随后无缝对接到计划编写与执行阶段，最终输出交付包。

## 使用方式

### 一键执行

```
/superpowers:idea2repo "我想要做一个简单的待办事项管理全栈应用" --task-id TASK-20260328-001
```

### 参数说明

| 参数 | 必填 | 说明 |
|:---|:---:|:---|
| `<idea>` | ✅ | 你的初步想法或一句话需求 |
| `--task-id` | ✅ | 题目 ID，用于交付包命名 |
| `--max-iterations` | ❌ | Ralph-Loop 最大迭代次数（默认 100） |
| `--skip-checklist` | ❌ | 跳过 Phase 3 领域检查清单 |
| `--skip-review` | ❌ | 跳过 Phase 4 自测审查 |
| `--skip-package` | ❌ | 跳过 Phase 5 交付打包 |

## 执行流程

```
┌─────────────────────────────────────────────────────────┐
│              Idea2Repo Pipeline                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Phase 0: Brainstorming (头脑风暴与设计)                    │
│  ├─ 需求探索与自动澄清                                    │
│  ├─ 方案分析与自动选择                                    │
│  ├─ 生成 BDD 行为规格、架构设计等                            │
│  └─ 产出 → docs/designs/                                   │
│  ✓ BRAINSTORMING_COMPLETE                                │
│                                                          │
│  Phase 1: Writing Plans (计划编写)                        │
│  ├─ 自动读取 designs 生成任务计划                           │
│  └─ 产出 → docs/plans/                                     │
│  ✓ PLANNING_COMPLETE                                     │
│                                                          │
│  Phase 2: Executing Plans (执行计划)                      │
│  ├─ 逐任务执行：测试先行 → 实现 → 验证                      │
│  └─ 循环直到所有任务完成                                   │
│  ✓ EXECUTION_COMPLETE                                    │
│                                                          │
│  Phase 3: Domain Checklist ★ 质量门禁 (可选)               │
│  ├─ 领域检查清单扫描与修复                                 │
│  ✓ CHECKLIST_COMPLETE                                    │
│                                                          │
│  Phase 4: Self Review (代码自审)                          │
│  ├─ 自动审查代码质量并修复                                 │
│  ✓ SELF_REVIEW_COMPLETE                                  │
│                                                          │
│  Phase 5: Delivery Packager (打包交付)                    │
│  ├─ 创建交付包并验证                                      │
│  ✓ DELIVERY_COMPLETE                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 执行指令序列

按顺序调用以下 Skills：

### 1. Phase 0

```
读取传入的 <idea> 参数，执行 brainstorming skill。
等待 BRAINSTORMING_COMPLETE 信号。
```

### 2. Phase 1

```
执行 writing-plans skill，使用 docs/designs/ 作为输入。
等待 PLANNING_COMPLETE 信号。
```

### 3. Phase 2

```
执行 executing-plans skill，使用 docs/plans/ 作为输入。
此阶段自动启动 Ralph-Loop。
等待 EXECUTION_COMPLETE 信号。
```

### 4. Phase 3（可跳过）★ 质量门禁

```
如未指定 --skip-checklist：
执行 domain-checklist skill，生成并执行领域检查清单。
等待 CHECKLIST_COMPLETE 信号。
```

### 5. Phase 4（可跳过）

```
如未指定 --skip-review：
执行 self-review skill。
等待 SELF_REVIEW_COMPLETE 信号。
```

### 6. Phase 5（可跳过）

```
如未指定 --skip-package：
执行 delivery-packager skill，传入 --task-id 参数。
等待 DELIVERY_COMPLETE 信号。
```

## Ralph-Loop 配置

本 Skill 使用 Ralph-Loop 的**多阶段模式**，但以 `brainstorming` 作为起点：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  "Execute Idea2Repo pipeline for idea: $ARGUMENTS" \
  --completion-promise "DELIVERY_COMPLETE" \
  --max-iterations ${max_iterations:-100}
```

### 状态文件设计

写入 `.claude/superpower-loop.local.md` 的内容包含：

```yaml
---
active: true
iteration: 1
session_id: xxx
max_iterations: 100
completion_promise: "DELIVERY_COMPLETE"
started_at: "2026-03-28T00:00:00Z"
current_phase: 0
phases:
  - name: "brainstorming"
    status: "in_progress"
    completion_promise: "BRAINSTORMING_COMPLETE"
  - name: "writing-plans"
    status: "pending"
    completion_promise: "PLANNING_COMPLETE"
    prompt: "基于 docs/plans/ 最新生成的 design 目录开始编写任务计划。**不要询问用户确认，自动选择最新生成的 design 文件夹进行处理。**"
  - name: "executing-plans"
    status: "pending"
    completion_promise: "EXECUTION_COMPLETE"
    prompt: "基于 docs/plans/ 开始逐个执行任务并在验证后前行。**不要询问用户确认设计或计划目录，全自动处理。**"
  - name: "domain-checklist"
    status: "pending"
    completion_promise: "CHECKLIST_COMPLETE"
    skippable: true
    skip_flag: "--skip-checklist"
  - name: "self-review"
    status: "pending"
    completion_promise: "SELF_REVIEW_COMPLETE"
    skippable: true
    skip_flag: "--skip-review"
  - name: "delivery-packager"
    status: "pending"
    completion_promise: "DELIVERY_COMPLETE"
    skippable: true
    skip_flag: "--skip-package"
---
```

## 迭代机制

每次 Loop 迭代开始时：
1. 读取状态文件
2. 找到当前 `in_progress` 的 Phase
3. 继续执行该 Phase（调用对应 Skill：brainstorming 或 writing-plans 或 executing-plans 等）
4. Phase 运行完成并输出最终信号标签后，标记为 `done`，更新下一阶段为 `in_progress`
5. 所有阶段完成后，输出最后的 `DELIVERY_COMPLETE` 结束整个流水线

## 错误处理

- Phase 0/1 失败 → 终止，输出错误日志
- Phase 2 单个任务失败 → 重试 2 次，仍失败则记录到 `questions.md`，继续下一任务
- Phase 4 发现阻塞问题 → 自动修复后重新审查（最多 3 轮）
- Phase 5 validate 失败 → 执行 `--repair`，仍失败则输出错误

## 完成条件

当 `DELIVERY_COMPLETE` 输出时，整个 Idea2Repo 流程完成。

最终产物：
- `TASK-{ID}/` 目录，包含完整的可交付项目包
- `docs/designs/` 和 `docs/plans/`
- `.tmp/self-review-report.md` 自测报告（不打包）
