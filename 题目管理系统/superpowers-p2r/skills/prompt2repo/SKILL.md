---
name: prompt2repo
description: "Prompt2Repo 一键入口: 从 prompt.md 到完整交付包的全自动流水线，串联 Phase 0-4.5 + 多重质量门禁"
---
# Prompt2Repo — 一键全自动流水线

## 🔴 核心执行纪律 (CRITICAL RULES - READ BEFORE ACTING)

0. **唯一入口模式（Single Entry Mode）**：
   `prompt2repo` 是唯一受支持入口。禁止引导用户切换到 `idea2repo` 或其他替代入口。
1. **绝对拦截，禁止跨阶段越权**：
   无论传入的 `prompt.md` 内容多么详尽，你都**绝对禁止**在 Phase 2 (Executing Plans) 被正式激活前使用任何工具（如 `mkdir`, `Write`, `Bash` 等）直接创建业务代码文件。所有的需求和架构必须先落地为规格与设计文档。
2. **主动管理阶段状态 (State Advancement Duty) ★ 绝对不可省略**：
   Loop 脚本无法自动猜测进度！当你准备结束当前阶段（即：准备输出该阶段完成承诺标签，如 `<promise>PROMPT_PARSING_COMPLETE</promise>` 等）时，你**必须**先使用文件写入工具（Write/Replace）主动修改 `docs/runtime/superpower-loop.local.md` 文件：
   (1) 将当前 Phase 的 `status` 字段从 `in_progress` 改成 `done`。
   (2) 将链条上下一个非跳过的 Phase 的 `status` 置为 `in_progress`。
   (3) 更新属性 `current_phase` 为相应的索引。
   **只有当这三步保存成功后，你才能继续执行最后一步（输出完成信号）！**
3. **单步挂起原则 (Yield Control)**：
   一次对话回合**只能执行当前一个 Phase 的任务**。当你完成当前阶段的内容并按上述规则更新了状态文件后，你必须且只能输出对应的完成信号，然后**强制立刻停止 (STOP)**，绝不允许在同一回合继续拉起下一个阶段的动作；承诺标签必须作为最后一行输出。
4. **强制从 Phase 0 起步 (No Skipping)**：
   对于完整的工作流，第一步必须是 Phase 0 (Prompt Parser)，严禁由于认为需求已明确而自行跳过规格化与架构设计阶段。
5. **严格 Skill 对齐 (Skill Lock)**：
   每个 Phase 开始时必须先调用对应 skill（如 `prompt-parser` Phase 只能执行 `superpowers:prompt-parser`）。若当前环境无法通过 Skill 工具加载，必须立即退化为读取本地 `superpowers-p2r/skills/<phase>/SKILL.md` 并严格按该文件执行，禁止自由发挥替代流程。

## 概述

本 Skill 是 Prompt2Repo 的**统一入口**，串联 Phase 0-4.5，实现从 Prompt 到可交付产物的一次执行全自动化。

## 使用方式

### 一键执行

```
/superpowers:prompt2repo prompt.md --task-id TASK-20260327-XXXXX
```

### 参数说明

| 参数                 | 必填 | 说明                                |
| :------------------- | :--: | :---------------------------------- |
| `prompt.md`        |  ✅  | Prompt 文件路径                     |
| `--task-id`        |  ✅  | 题目 ID，用于交付包命名             |
| `--max-iterations` |  ❌  | Ralph-Loop 最大迭代次数（默认 100） |
| `--skip-spec-gate` |  ❌  | 跳过 Phase 0.5 需求规格化           |
| `--skip-analysis`  |  ❌  | 跳过 Phase 1.5 一致性分析           |
| `--skip-checklist` |  ❌  | 跳过 Phase 2.5 领域检查清单         |
| `--skip-review`    |  ❌  | 跳过 Phase 3 自测审查               |
| `--skip-test-gate` |  ❌  | 跳过 Phase 3.5 严格测试门禁         |
| `--skip-runtime-smoke` |  ❌  | 跳过 Phase 3.6 运行态冒烟门禁   |
| `--skip-stability-loop` |  ❌  | 跳过 Phase 3.7 稳定性循环门禁  |
| `--skip-coverage-gate` |  ❌  | 跳过 Phase 3.8 覆盖率门禁      |
| `--skip-policy-gate` |  ❌  | 跳过 Phase 3.9 GitHub 策略门禁    |
| `--skip-package`   |  ❌  | 跳过 Phase 4 交付打包               |
| `--skip-delivery-check` |  ❌  | 跳过 Phase 4.5 自动交付验收      |

## 执行流程

```
┌─────────────────────────────────────────────────────────┐
│        Prompt2Repo Pipeline (Sub-agent Enhanced)          │
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
│  Phase 3.5: Test Gate ★ 质量门禁                         │
│  ├─ 测试脚本 fail-fast 校验                               │
│  ├─ 单元测试 + 覆盖率阈值（默认 line >= 80%）             │
│  ├─ API 集成测试（默认 always，重复 2 轮）                │
│  └─ 生成 .tmp/test-gate-report.md                         │
│  ✓ TEST_GATE_COMPLETE                                    │
│                                                          │
│  Phase 3.6: Runtime Smoke ★ 质量门禁                     │
│  ├─ docker compose up --build                            │
│  ├─ 健康检查等待                                          │
│  ├─ API 冒烟测试（重复 2 轮）                              │
│  └─ 生成 .tmp/runtime-smoke-report.md                     │
│  ✓ RUNTIME_SMOKE_COMPLETE                                │
│                                                          │
│  Phase 3.7: Stability Loop ★ 质量门禁                    │
│  ├─ Runtime Smoke 循环 5 轮（通过率 100%）                │
│  ├─ 捕获 flaky 启动/测试问题                              │
│  └─ 生成 .tmp/stability-loop-report.md                    │
│  ✓ STABILITY_COMPLETE                                    │
│                                                          │
│  Phase 3.8: Coverage Gate ★ 质量门禁                     │
│  ├─ 执行 verify/test                                      │
│  ├─ 覆盖率阈值校验（line>=80%, branch>=70%）               │
│  └─ 生成 .tmp/coverage-gate-report.md                     │
│  ✓ COVERAGE_COMPLETE                                     │
│                                                          │
│  Phase 3.9: Policy Gate ★ 质量门禁                       │
│  ├─ workflow 并发/取消策略检查                             │
│  ├─ required checks 映射检查                               │
│  ├─ 分支保护检查（可用时）                                 │
│  └─ 生成 .tmp/policy-gate-report.md                       │
│  ✓ POLICY_COMPLETE                                       │
│                                                          │
│  Phase 4: Delivery Packager                              │
│  ├─ 创建标准目录结构                                      │
│  ├─ 复制并清理项目代码                                    │
│  ├─ 生成 metadata.json                                   │
│  ├─ 合并文档                                              │
│  ├─ 运行 validate_package.py                             │
│  └─ 最终检查清单                                          │
│  ✓ PACKAGE_COMPLETE                                      │
│                                                          │
│  Phase 4.5: Delivery Checker ★ 质量门禁                  │
│  ├─ 运行 verify-delivery-package.sh                      │
│  ├─ 输出 delivery-check-report.md                        │
│  ├─ 修复阻塞项并复验                                      │
│  └─ 通过后输出最终完成信号                                 │
│  ✓ DELIVERY_COMPLETE                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 执行指令序列

按顺序调用以下 Skills：

### -1. Prompt Ingress Auto-Capture（必须）

```
在进入 Loop Bootstrap 前，先确保 prompt 文件可用，且不向用户发确认问题：

1) 若传入的 prompt 文件不存在或为空：
   - 自动使用“最近一条用户需求文本”写入该文件（默认目标: prompt.md）。
   - 写入后继续，不中断流程。

2) 若 --task-id 仅为前缀（例如 `TASK-` 或以 `-` 结尾）：
   - 自动补全为 `TASK-YYYYMMDD-HHMMSS`（本地时间）。
   - 后续阶段统一使用补全后的 task-id。
```

### 0. Loop Bootstrap（必须，先于 Phase 0）

```
如当前工作目录不存在 `docs/runtime/superpower-loop.local.md`：
立即执行：
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  --prompt-file "<传入的 prompt 文件路径>" \
  --completion-promise "DELIVERY_COMPLETE" \
  --max-iterations ${max_iterations:-100} \
  --state-file "docs/runtime/superpower-loop.local.md"

执行后必须确认以下文件已生成：
- `docs/runtime/superpower-loop.local.md`（循环状态文件）
- `docs/runtime/superpower-loop.bootstrap.md`（启动确认文档）
```

### 1. Phase 0

```
读取传入的 prompt.md 路径，执行 prompt-parser skill。
等待 `<promise>PROMPT_PARSING_COMPLETE</promise>` 信号。
```

### 2. Phase 0.5★ 质量门禁

```
如未指定 --skip-spec-gate：
执行 spec-gateway skill，将需求分析转化为结构化规格。
等待 `<promise>SPEC_COMPLETE</promise>` 信号。
```

### 3. Phase 1

```
执行 writing-plans-p2r skill，使用 docs/designs/ 和 docs/specs/ 作为输入。
等待 `<promise>PLANNING_COMPLETE</promise>` 信号。
```

### 4. Phase 1.5★ 质量门禁

```
如未指定 --skip-analysis：
执行 consistency-gate skill，检测 spec ↔ 架构 ↔ 任务 一致性。
等待 `<promise>ANALYSIS_COMPLETE</promise>` 信号。
```

### 5. Phase 2

```
执行 executing-plans-p2r skill，使用 docs/plans/ 作为输入。
此阶段复用主 Ralph-Loop 执行，禁止二次启动 setup-superpower-loop.sh 覆盖主状态文件。
等待 `<promise>EXECUTION_COMPLETE</promise>` 信号。
```

### 6. Phase 2.5★ 质量门禁

```
如未指定 --skip-checklist：
执行 domain-checklist skill，生成并执行领域检查清单。
等待 `<promise>CHECKLIST_COMPLETE</promise>` 信号。
```

### 7. Phase 3

```
如未指定 --skip-review：
执行 self-review skill。
等待 `<promise>SELF_REVIEW_COMPLETE</promise>` 信号。
```

### 8. Phase 3.5★ 质量门禁

```
如未指定 --skip-test-gate：
执行 test-gate skill，运行严格测试门禁并生成报告（files/cases/coverage 多阈值 + 重复执行 + WARN 阻断）。
等待 `<promise>TEST_GATE_COMPLETE</promise>` 信号。
```

### 9. Phase 3.6★ 质量门禁

```
如未指定 --skip-runtime-smoke：
执行 runtime-smoke skill，运行容器启动 + 健康检查 + 多端点探测 + API 冒烟重复测试。
等待 `<promise>RUNTIME_SMOKE_COMPLETE</promise>` 信号。
```

### 10. Phase 3.7★ 质量门禁

```
如未指定 --skip-stability-loop：
执行 stability-loop skill，循环执行 runtime smoke（默认 5 轮，要求 100% 通过率）。
等待 `<promise>STABILITY_COMPLETE</promise>` 信号。
```

### 11. Phase 3.8★ 质量门禁

```
如未指定 --skip-coverage-gate：
执行 coverage-gate skill，执行覆盖率阈值验证（line>=80%, branch>=70%，Python/Maven 均可执行）。
等待 `<promise>COVERAGE_COMPLETE</promise>` 信号。
```

### 12. Phase 3.9★ 质量门禁

```
如未指定 --skip-policy-gate：
执行 policy-gate skill，执行 CI/workflow/分支保护策略检查。
等待 `<promise>POLICY_COMPLETE</promise>` 信号。
```

### 13. Phase 4

```
如未指定 --skip-package：
执行 delivery-packager skill，传入 --task-id 参数。
等待 `<promise>PACKAGE_COMPLETE</promise>` 信号。
```

### 14. Phase 4.5★ 质量门禁

```
如未指定 --skip-delivery-check：
执行 delivery-checker skill，传入 --task-id 参数。
等待 `<promise>DELIVERY_COMPLETE</promise>` 信号。
```

## Ralph-Loop 配置

本 Skill 使用 Ralph-Loop 的**多阶段模式**，且必须在进入 Phase 0 前完成 bootstrap：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  --prompt-file "<传入的 prompt 文件路径>" \
  --completion-promise "DELIVERY_COMPLETE" \
  --max-iterations ${max_iterations:-100} \
  --state-file "docs/runtime/superpower-loop.local.md"
```

Bootstrap 成功判据：
- `docs/runtime/superpower-loop.local.md` 存在
- `docs/runtime/superpower-loop.bootstrap.md` 存在

### 状态文件

`docs/runtime/superpower-loop.local.md` 内容示例：

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
    prompt: "基于前序阶段最新生成的 spec 与 design 目录开始编写并拆分任务计划。**不要询问用户确认，自动处理。**"
  - name: "consistency-gate"
    status: "pending"
    completion_promise: "ANALYSIS_COMPLETE"
    skippable: true
    skip_flag: "--skip-analysis"
    prompt: "自动执行一致性扫描。**除非发现无法自行修复的 CRITICAL/HIGH 阻塞问题，否则请自动完成修复并产出报告，不要向用户提问。**"
  - name: "executing-plans-p2r"
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
  - name: "test-gate"
    status: "pending"
    completion_promise: "TEST_GATE_COMPLETE"
    skippable: true
    skip_flag: "--skip-test-gate"
  - name: "runtime-smoke"
    status: "pending"
    completion_promise: "RUNTIME_SMOKE_COMPLETE"
    skippable: true
    skip_flag: "--skip-runtime-smoke"
  - name: "stability-loop"
    status: "pending"
    completion_promise: "STABILITY_COMPLETE"
    skippable: true
    skip_flag: "--skip-stability-loop"
  - name: "coverage-gate"
    status: "pending"
    completion_promise: "COVERAGE_COMPLETE"
    skippable: true
    skip_flag: "--skip-coverage-gate"
  - name: "policy-gate"
    status: "pending"
    completion_promise: "POLICY_COMPLETE"
    skippable: true
    skip_flag: "--skip-policy-gate"
  - name: "delivery-packager"
    status: "pending"
    completion_promise: "PACKAGE_COMPLETE"
    skippable: true
    skip_flag: "--skip-package"
  - name: "delivery-checker"
    status: "pending"
    completion_promise: "DELIVERY_COMPLETE"
    skippable: true
    skip_flag: "--skip-delivery-check"
---
```

每次 Loop 迭代开始时：

1. 读取状态文件
2. 找到当前 `in_progress` 的 Phase
3. 继续执行该 Phase
4. Phase 完成后，标记为 `done`，下一个 Phase 改为 `in_progress`
5. 所有 Phase 完成 → 输出最终 `<promise>DELIVERY_COMPLETE</promise>`（最后一行）

## 错误处理

- Phase 0/1 失败 → 终止，输出错误日志
- Phase 2 单个任务失败 → 重试 2 次，仍失败则记录到 `questions.md`，继续下一任务
- Phase 3 发现阻塞问题 → 自动修复后重新审查（最多 3 轮）
- Phase 3.6 运行态冒烟失败 → 修复启动/健康检查/API 调用后复验
- Phase 3.7 稳定性循环失败 → 标记 flaky，修复后重跑循环
- Phase 3.8 覆盖率门禁失败 → 增补测试并重跑 verify
- Phase 3.9 策略门禁失败 → 修复 workflow/policy 后复验
- Phase 4 validate 失败 → 执行 `--repair`，仍失败则输出错误
- Phase 4.5 验收失败 → 修复后自动复验，仍失败则输出阻塞项

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
/superpowers:test-gate                                            # Phase 3.5 ★
/superpowers:runtime-smoke                                        # Phase 3.6 ★
/superpowers:stability-loop                                       # Phase 3.7 ★
/superpowers:coverage-gate                                        # Phase 3.8 ★
/superpowers:policy-gate                                          # Phase 3.9 ★
/superpowers:delivery-packager --task-id TASK-20260327-XXXXX      # Phase 4
/superpowers:delivery-checker --task-id TASK-20260327-XXXXX       # Phase 4.5 ★
```

## 完成条件

当 `<promise>DELIVERY_COMPLETE</promise>` 输出且位于最后一行时，整个 Prompt2Repo 流程完成。

最终产物：

- `TASK-{ID}/` 目录，包含完整的可交付项目包
- `.tmp/self-review-report.md` 自测报告（不打包）


