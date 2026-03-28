---
name: prompt2repo
description: "Prompt2Repo 一键入口: 从 prompt.md 到完整交付包的全自动流水线，串联 Phase 0-4 + 3 个质量门禁"
---

# Prompt2Repo — 一键全自动流水线

## 概述

本 Skill 是 Prompt2Repo 的**统一入口**，串联 Phase 0-4，实现从 Prompt 到可交付产物的一次执行全自动化。

## 使用方式

### 一键执行

```
/superpowers:prompt2repo prompt.md --task-id TASK-20260327-XXXXX
```

### 参数说明

| 参数 | 必填 | 说明 |
|:---|:---:|:---|
| `prompt.md` | ✅ | Prompt 文件路径 |
| `--task-id` | ✅ | 题目 ID，用于交付包命名 |
| `--max-iterations` | ❌ | Ralph-Loop 最大迭代次数（默认 100） |
| `--skip-spec-gate` | ❌ | 跳过 Phase 0.5 需求规格化 |
| `--skip-analysis` | ❌ | 跳过 Phase 1.5 一致性分析 |
| `--skip-checklist` | ❌ | 跳过 Phase 2.5 领域检查清单 |
| `--skip-review` | ❌ | 跳过 Phase 3 自测审查 |
| `--skip-package` | ❌ | 跳过 Phase 4 交付打包 |

## 执行流程

```
┌─────────────────────────────────────────────────────────┐
│              Prompt2Repo Pipeline (Enhanced)              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Phase 0: Prompt Parser                                  │
│  ├─ 读取 prompt.md                                       │
│  ├─ 语言检测 → 全局语言策略                                │
│  ├─ 项目类型识别                                          │
│  ├─ 技术栈识别                                            │
│  ├─ 核心需求提取                                          │
│  └─ 输出 → docs/designs/requirement-analysis.md          │
│           → docs/designs/_meta.md                        │
│           → metadata.draft.json                          │
│  ✓ PROMPT_PARSING_COMPLETE                               │
│                                                          │
│  Phase 0.5: Spec Gateway ★ 质量门禁                      │
│  ├─ 需求 → 结构化规格 (spec.md)                           │
│  ├─ 歧义扫描 + 自动澄清                                   │
│  ├─ 隐含需求补全 (LICENSE/安全/错误处理)                    │
│  └─ 需求质量检查清单                                       │
│  ✓ SPEC_COMPLETE                                         │
│                                                          │
│  Phase 1: Writing Plans                                  │
│  ├─ BDD 行为规格（验收标准注入）                           │
│  ├─ 架构设计                                              │
│  ├─ 最佳实践文档                                          │
│  └─ 任务计划拆分                                          │
│  ✓ PLANNING_COMPLETE                                     │
│                                                          │
│  Phase 1.5: Consistency Gate ★ 质量门禁                   │
│  ├─ spec ↔ 架构 ↔ 任务 跨制品覆盖映射                     │
│  ├─ 6 项检测 (覆盖/不一致/重复/歧义/未规定/安全)            │
│  ├─ CRITICAL/HIGH 问题自动修复                             │
│  └─ 一致性分析报告                                         │
│  ✓ ANALYSIS_COMPLETE                                     │
│                                                          │
│  Phase 2: Executing Plans (Ralph-Loop)                   │
│  ├─ 启动 Ralph-Loop                                      │
│  ├─ 逐任务执行：测试先行 → 实现 → 验证                    │
│  ├─ 工程质量内置检查                                      │
│  ├─ README + 测试脚本生成                                 │
│  └─ 循环直到所有任务完成                                   │
│  ✓ EXECUTION_COMPLETE                                    │
│                                                          │
│  Phase 2.5: Domain Checklist ★ 质量门禁                   │
│  ├─ 安全检查清单 (17项)                                    │
│  ├─ API 检查清单 (10项)                                    │
│  ├─ 开源合规检查清单 (11项)                                 │
│  ├─ 自动修复 (LICENSE/.gitignore/CORS/Docker密钥)          │
│  └─ 检查清单执行汇总                                       │
│  ✓ CHECKLIST_COMPLETE                                    │
│                                                          │
│  Phase 3: Self Review                                    │
│  ├─ 6 维度自动审查                                        │
│  ├─ 安全专项审查                                          │
│  ├─ 测试覆盖度静态审计                                    │
│  ├─ 问题自动修复（高/阻塞级）                              │
│  └─ 生成自测报告                                          │
│  ✓ SELF_REVIEW_COMPLETE                                  │
│                                                          │
│  Phase 4: Delivery Packager                              │
│  ├─ 创建标准目录结构                                      │
│  ├─ 复制并清理项目代码                                    │
│  ├─ 生成 metadata.json                                   │
│  ├─ 合并文档                                              │
│  ├─ 运行 validate_package.py                             │
│  └─ 最终检查清单                                          │
│  ✓ DELIVERY_COMPLETE                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 执行指令序列

按顺序调用以下 Skills：

### 1. Phase 0

```
读取传入的 prompt.md 路径，执行 prompt-parser skill。
等待 PROMPT_PARSING_COMPLETE 信号。
```

### 2. Phase 0.5（可跳过）★ 质量门禁

```
如未指定 --skip-spec-gate：
执行 spec-gateway skill，将需求分析转化为结构化规格。
等待 SPEC_COMPLETE 信号。
```

### 3. Phase 1

```
执行 writing-plans-p2r skill，使用 docs/designs/ 和 docs/specs/ 作为输入。
等待 PLANNING_COMPLETE 信号。
```

### 4. Phase 1.5（可跳过）★ 质量门禁

```
如未指定 --skip-analysis：
执行 consistency-gate skill，检测 spec ↔ 架构 ↔ 任务 一致性。
等待 ANALYSIS_COMPLETE 信号。
```

### 5. Phase 2

```
执行 executing-plans-p2r skill，使用 docs/plans/ 作为输入。
此阶段自动启动 Ralph-Loop。
等待 EXECUTION_COMPLETE 信号。
```

### 6. Phase 2.5（可跳过）★ 质量门禁

```
如未指定 --skip-checklist：
执行 domain-checklist skill，生成并执行领域检查清单。
等待 CHECKLIST_COMPLETE 信号。
```

### 7. Phase 3（可跳过）

```
如未指定 --skip-review：
执行 self-review skill。
等待 SELF_REVIEW_COMPLETE 信号。
```

### 8. Phase 4（可跳过）

```
如未指定 --skip-package：
执行 delivery-packager skill，传入 --task-id 参数。
等待 DELIVERY_COMPLETE 信号。
```

## Ralph-Loop 配置

本 Skill 使用 Ralph-Loop 的**多阶段模式**：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  "Execute Prompt2Repo pipeline: Parse prompt, generate plans, execute code, self-review, package delivery." \
  --completion-promise "DELIVERY_COMPLETE" \
  --max-iterations ${max_iterations:-100}
```

### 状态文件

`.claude/superpower-loop.local.md` 内容示例：

```yaml
---
active: true
iteration: 1
session_id: xxx
max_iterations: 100
completion_promise: "DELIVERY_COMPLETE"
started_at: "2026-03-27T23:00:00Z"
current_phase: 0
phases:
  - name: "prompt-parser"
    status: "in_progress"
    completion_promise: "PROMPT_PARSING_COMPLETE"
  - name: "spec-gateway"
    status: "pending"
    completion_promise: "SPEC_COMPLETE"
    skippable: true
    skip_flag: "--skip-spec-gate"
  - name: "writing-plans-p2r"
    status: "pending"
    completion_promise: "PLANNING_COMPLETE"
  - name: "consistency-gate"
    status: "pending"
    completion_promise: "ANALYSIS_COMPLETE"
    skippable: true
    skip_flag: "--skip-analysis"
  - name: "executing-plans-p2r"
    status: "pending"
    completion_promise: "EXECUTION_COMPLETE"
  - name: "domain-checklist"
    status: "pending"
    completion_promise: "CHECKLIST_COMPLETE"
    skippable: true
    skip_flag: "--skip-checklist"
  - name: "self-review"
    status: "pending"
    completion_promise: "SELF_REVIEW_COMPLETE"
  - name: "delivery-packager"
    status: "pending"
    completion_promise: "DELIVERY_COMPLETE"
---
```

每次 Loop 迭代开始时：
1. 读取状态文件
2. 找到当前 `in_progress` 的 Phase
3. 继续执行该 Phase
4. Phase 完成后，标记为 `done`，下一个 Phase 改为 `in_progress`
5. 所有 Phase 完成 → 输出最终 `DELIVERY_COMPLETE`

## 错误处理

- Phase 0/1 失败 → 终止，输出错误日志
- Phase 2 单个任务失败 → 重试 2 次，仍失败则记录到 `questions.md`，继续下一任务
- Phase 3 发现阻塞问题 → 自动修复后重新审查（最多 3 轮）
- Phase 4 validate 失败 → 执行 `--repair`，仍失败则输出错误

## 分步执行模式

如果不使用一键入口，也可以分步执行各 Phase：

```
/superpowers:prompt-parser prompt.md                              # Phase 0
/superpowers:spec-gateway                                         # Phase 0.5 ★
/superpowers:writing-plans-p2r docs/designs/                      # Phase 1
/superpowers:consistency-gate                                     # Phase 1.5 ★
/superpowers:executing-plans-p2r docs/plans/                      # Phase 2
/superpowers:domain-checklist                                     # Phase 2.5 ★
/superpowers:self-review                                          # Phase 3
/superpowers:delivery-packager --task-id TASK-20260327-XXXXX      # Phase 4
```

## 完成条件

当 `DELIVERY_COMPLETE` 输出时，整个 Prompt2Repo 流程完成。

最终产物：
- `TASK-{ID}/` 目录，包含完整的可交付项目包
- `.tmp/self-review-report.md` 自测报告（不打包）
