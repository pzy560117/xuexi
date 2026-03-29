---
name: spec-gateway
description: "Prompt2Repo Phase 0.5: 将需求分析转化为结构化规格并自动完成歧义澄清，注入质量门禁"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# Spec Gateway — Prompt2Repo Phase 0.5

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>SPEC_COMPLETE</promise>` 时必须遵守：
- `docs/specs/spec.md` 已生成
- 需求质量检查清单已执行
- 无阻塞性歧义

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 规格化是将非结构化需求转化为可测试、可追踪的结构化规格的过程。

- **MANDATORY**: 每个 prompt 需求点必须映射到至少一个 FR-XXX
- **MANDATORY**: 每个 FR 必须可独立测试（有明确的输入/输出）
- **MANDATORY**: 歧义必须自动澄清（P2R 无人值守模式）
- **PROHIBITED**: 不得保留模糊词汇（“合适的”、“尽可能”、“等”）
- **PROHIBITED**: 不得跳过 10 分类歧义扫描

## 概述

本 Skill 在 Phase 0（需求解析）和 Phase 1（设计规划）之间插入**需求规格化与澄清**流程，确保进入设计阶段的需求是完整、无歧义的。

**方法论来源**: 改编自 `speckit-specify` + `speckit-clarify`，适配为 P2R 全自动模式（无交互式问答）。

**前提条件**: `docs/designs/requirement-analysis.md` 和 `docs/designs/_meta.md` 必须存在（Phase 0 产出）。

## 执行步骤

### Step 1: 读取需求分析产出

读取以下文件：
- `docs/designs/requirement-analysis.md` — 需求清单
- `docs/designs/_meta.md` — 项目元数据（语言、类型、技术栈）
- `prompt.md` — 原始需求描述

### Step 2: 生成结构化规格文档

将 `requirement-analysis.md` 转化为 `docs/specs/spec.md`，严格按以下结构组织：

```markdown
# Feature Specification: {项目名称}

## 概述
项目的核心业务目标和范围（从 prompt.md 提取）

## 功能需求 (Functional Requirements)
按域分组，每条需求必须：
- 有唯一编号（FR-001, FR-002, ...）
- 可测试（有明确的输入/输出）
- 标注优先级（P1/P2/P3）

### 域 1: {域名称}
- **FR-001** [P1]: {需求描述}
  - 输入: {输入约束}
  - 输出: {预期行为}
  - 约束: {业务规则}

### 域 N: ...

## 非功能需求 (Non-Functional Requirements)
- **NFR-001**: {性能/安全/可用性需求}

## 用户场景 (User Scenarios)
按角色分组的完整用户流程

## 关键实体 (Key Entities)
数据模型中的核心实体和关系

## 假设与约束 (Assumptions & Constraints)

## 澄清记录 (Clarifications)
```

**规格化规则**：

1. **每个 prompt 需求点必须映射到至少一个 FR-XXX**
   - 遍历 `requirement-analysis.md` 中的每条需求
   - 为每条生成对应的 FR 编号和可测试描述
   - 如果一条需求包含多个子功能，拆分为多个 FR

2. **隐含需求补全**
   - 登录功能 → 必须补全 token 失效/登出机制
   - 密码功能 → 必须补全强度规则、重置流程
   - 权限控制 → 必须补全越权防护
   - 数据加密 → 必须补全密钥管理策略
   - 文件上传 → 必须补全格式校验、大小限制
   - Docker 部署 → 必须补全 .gitignore/.dockerignore
   - 开源项目 → 必须补全 LICENSE 文件需求

3. **约束条件显式化**
   - 将 prompt 中的含糊描述转化为具体数值/规则
   - 例："登录失败锁定" → "10分钟内连续5次失败触发30分钟锁定"

### Step 3: 歧义扫描与自动澄清

对生成的 `spec.md` 执行 10 分类歧义扫描：

| 分类 | 扫描内容 |
|:---|:---|
| 功能范围 | 需求边界是否明确 |
| 数据模型 | 实体关系是否完整 |
| 交互流程 | 用户操作路径是否闭合 |
| 非功能属性 | 性能/安全指标是否量化 |
| 外部依赖 | 第三方服务是否明确 |
| 边界条件 | 极值/空值/异常是否覆盖 |
| 约束冲突 | 不同需求是否矛盾 |
| 术语一致 | 同一概念命名是否统一 |
| 完成信号 | 如何判断功能完成 |
| 遗漏项 | 常见必备功能是否缺失 |

**自动澄清模式**（P2R 无人值守适配）：

对于发现的歧义，按以下优先级处理：

1. **可推断的**：使用行业最佳实践作为默认值，直接写入 spec
2. **需记录的**：将假设和推理过程记录到 `## 假设与约束` 和 `questions.md`
3. **阻塞性的**：写入 `questions.md` 并标记为 `[BLOCKING]`

### Step 4: 需求质量检查清单

生成 `docs/specs/checklists/requirements.md`：

```markdown
# 需求质量检查清单

## 完整性
- [ ] CHK001: 每个 prompt 需求点是否都有对应的 FR 编号？
- [ ] CHK002: 是否覆盖所有隐含需求（安全、错误处理、日志）？
- [ ] CHK003: 非功能需求是否有量化指标？

## 清晰度
- [ ] CHK004: 每个 FR 是否可独立测试？
- [ ] CHK005: 是否消除了模糊词汇（"合适的"、"尽可能"、"等"）？

## 一致性
- [ ] CHK006: 不同域的需求是否有矛盾？
- [ ] CHK007: 术语使用是否一致？

## 可追溯性
- [ ] CHK008: 每个 FR 是否可追溯到原始 prompt 需求？
```

自动运行检查清单，未通过项记录原因和修复建议。

### Step 5: 更新 questions.md

将所有假设、澄清记录、阻塞性问题追加到 `questions.md`。

## Exit Criteria

当以下全部满足时，Phase 0.5 完成：
- `docs/specs/spec.md` 已生成
- `docs/specs/checklists/requirements.md` 已生成并自动检查
- `questions.md` 已更新

输出 `<promise>SPEC_COMPLETE</promise>`，且该标签必须是回复最后一行。

## 跳过条件

当传入 `--skip-spec-gate` 参数时，跳过本 Phase，直接进入 Phase 1。

## References

- `../../skills/references/completion-promises.md` - Promise 设计规范
- `../speckit-specify/SKILL.md` - speckit-specify 方法论来源
- `../speckit-clarify/SKILL.md` - speckit-clarify 方法论来源
