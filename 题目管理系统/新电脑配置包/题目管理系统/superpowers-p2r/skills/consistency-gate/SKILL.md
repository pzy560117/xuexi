---
name: consistency-gate
description: "Prompt2Repo Phase 1.5: 跨制品一致性分析，检测规格-设计-任务之间的冲突、遗漏和歧义"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# Consistency Gate — Prompt2Repo Phase 1.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>ANALYSIS_COMPLETE</promise>` 时必须遵守：
- 6 项检测全部完成
- 无 CRITICAL 级别问题
- 分析报告已生成

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 一致性分析确保 spec、架构、任务三者对齐，避免“设计与测试不一致”。

- **MANDATORY**: 必须使用子代理执行多视角分析
- **MANDATORY**: 建立双向追踪矩阵（FR → BDD → 架构 → 任务）
- **MANDATORY**: CRITICAL 级问题必须自动修复
- **PROHIBITED**: 不得跳过安全对齐检测
- **PROHIBITED**: 不得在有 CRITICAL 问题时输出 Promise

## 概述

本 Skill 在 Phase 1（设计规划）和 Phase 2（代码执行）之间插入**跨制品一致性分析**，确保规格、架构设计、任务计划三者对齐，避免"设计与测试不一致"等问题。

**方法论来源**: 改编自 `speckit-analyze`，适配为 P2R 全自动模式（自动修复严重问题）。

**前提条件**: 以下文件必须存在（Phase 0.5 + Phase 1 产出）：
- `docs/specs/spec.md`
- `docs/designs/architecture.md`
- `docs/designs/bdd-specs.md`
- `docs/plans/_index.md`

## 执行步骤

### Step 1: 加载制品

读取并构建内部语义模型：

**从 spec.md 提取**：
- 功能需求清单（FR-XXX 编号 + 优先级）
- 非功能需求清单（NFR-XXX）
- 用户场景
- 关键实体

**从 architecture.md 提取**：
- 技术栈选型
- 模块划分和职责
- API 端点列表
- 数据库 Schema

**从 bdd-specs.md 提取**：
- BDD 场景（Given-When-Then）
- 验收维度编号
- 异常路径场景

**从 task 计划提取**：
- 任务 ID 和描述
- 依赖关系
- 文件变更列表

### Step 2: 构建覆盖映射

建立双向追踪矩阵：

```
FR-XXX → BDD 场景（是否有对应的 BDD？）
FR-XXX → 架构模块（是否有实现模块？）
FR-XXX → 任务计划（是否有执行任务？）
BDD 场景 → 任务计划（是否有对应的测试任务？）
```

### Step 3: 执行 6 项检测（要求使用子代理）

**强制要求**：利用 `code-reviewer` 子代理（必须先读取 `skills/code-reviewer/SKILL.md`）或分配多视角分析（Multi-Perspective Analysis）的分身验证角色（如 Consistency reviewer、Factual reviewer）来执行具体的扫描与检测，避免单一维度的遗漏。

#### 3.1 覆盖缺口检测 (Coverage Gaps)

| 检测项 | 严重级别 |
|:---|:---|
| FR 无对应 BDD 场景 | HIGH |
| FR 无对应架构模块 | HIGH |
| FR 无对应实现任务 | CRITICAL |
| BDD 场景无对应测试任务 | HIGH |
| 非功能需求无实现方案 | MEDIUM |

#### 3.2 不一致检测 (Inconsistency)

| 检测项 | 严重级别 |
|:---|:---|
| spec 中的约束与架构设计冲突 | CRITICAL |
| BDD 预期行为与 API 设计不匹配 | HIGH |
| 任务描述与 spec 需求不一致 | HIGH |
| 数据模型字段与 spec 实体不匹配 | MEDIUM |

#### 3.3 重复检测 (Duplication)

检测近似重复的需求条目和 BDD 场景，标记为 MEDIUM。

#### 3.4 歧义检测 (Ambiguity)

扫描模糊词汇（"合适的"、"尽可能"、"一些"、"等"），标记为 MEDIUM。

#### 3.5 未规定检测 (Underspecification)

| 检测项 | 严重级别 |
|:---|:---|
| 有动词但无具体度量标准的需求 | MEDIUM |
| 有接口但无错误码定义 | HIGH |
| 有权限但无具体角色映射 | HIGH |

#### 3.6 安全对齐检测 (Security Alignment)

| 检测项 | 严重级别 |
|:---|:---|
| 有认证需求但无 token 管理方案 | CRITICAL |
| 有加密需求但无密钥管理策略 | HIGH |
| 有权限需求但无越权防护设计 | HIGH |
| 有文件上传但无安全校验 | HIGH |
| Docker 配置有硬编码密钥 | CRITICAL |
| 开源项目缺少 LICENSE 需求 | HIGH |
| 缺少 .gitignore 需求 | MEDIUM |

### Step 4: 生成分析报告

输出 `docs/specs/analysis-report.md`：

```markdown
# 跨制品一致性分析报告

## 分析概要
- 分析日期: {date}
- 涉及制品: spec.md, architecture.md, bdd-specs.md, task plans
- 功能需求总数: {N}
- BDD 场景总数: {N}
- 任务总数: {N}

## 覆盖映射表
| 需求编号 | BDD 场景 | 架构模块 | 实现任务 | 覆盖状态 |
|---------|----------|---------|---------|---------|

## 发现问题
| # | 类别 | 级别 | 位置 | 问题描述 | 修复建议 |
|---|:---:|:---:|:---|:---|:---|

## 统计
- 覆盖率: {X}% (有任务的需求 / 总需求)
- CRITICAL 问题: {N}
- HIGH 问题: {N}
- MEDIUM 问题: {N}
- LOW 问题: {N}
```

### Step 5: 自动修复

对发现的问题按级别处理：

**CRITICAL**: 必须修复
- 补全缺失的任务到 `docs/plans/`
- 修正 spec 与架构的冲突
- 补全安全相关需求到 `spec.md`

**HIGH**: 尝试修复
- 补全缺失的 BDD 场景到 `bdd-specs.md`
- 添加缺失的错误码/角色映射
- 补全 .gitignore / LICENSE 需求

**MEDIUM/LOW**: 记录到 `questions.md`

修复后重新运行 Step 3-4 验证（最多 2 轮）。

## Exit Criteria

当以下全部满足时，Phase 1.5 完成：
- `docs/specs/analysis-report.md` 已生成
- 无 CRITICAL 级别问题（允许 MEDIUM/LOW 保留）
- 修复的文件已更新

输出 `<promise>ANALYSIS_COMPLETE</promise>`，且该标签必须是回复最后一行。

## 跳过条件

当传入 `--skip-analysis` 参数时，跳过本 Phase，直接进入 Phase 2。

## References

- `../code-reviewer/SKILL.md` - 代码审查子代理
- `../speckit-analyze/SKILL.md` - speckit-analyze 方法论来源
- `../../skills/references/completion-promises.md` - Promise 设计规范
