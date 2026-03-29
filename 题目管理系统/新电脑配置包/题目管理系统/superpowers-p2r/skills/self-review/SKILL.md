---
name: self-review
description: "Prompt2Repo Phase 3: 使用完整 AI 验收提示词对项目进行 6 维度+安全+测试覆盖度自动化验收审查"
---

# Self Review — Prompt2Repo Phase 3

## 概述

本 Skill 是 Prompt2Repo 流水线的自测阶段。在 Phase 2 完成项目生成后，使用题目管理系统官方验收提示词对项目进行全面审查。

**前提条件**: 项目代码已完整生成，`docs/plans/_index.md` 中所有任务为 `done`。

**参考文档**（完整验收提示词模板）：
- 中文项目 → 参见 `references/ai-report-prompt-zh.md`
- 英文项目 → 参见 `references/ai-report-prompt-en.md`

## 执行步骤

### Step 1: 确定审查模式

读取 `docs/designs/_meta.md`，根据 `project_type` 选择审查模式：

| 项目类型 | 审查模式 |
|:---|:---|
| `pure_frontend` | **前端审查模式** |
| `fullstack` | **非前端审查模式** + **前端审查模式**（合并执行） |
| `pure_backend` | **非前端审查模式** |
| `mobile_app` | **非前端审查模式** |
| `cross_platform_app` | **非前端审查模式** |

### Step 2: 读取原始 Prompt 并加载提示词模板

读取 `prompt.md`，作为审查的业务上下文。

根据 `_meta.md` 中的 `prompt_language` 选择验收提示词模板：
- `prompt_language: "zh"` → 加载 `references/ai-report-prompt-zh.md`
- `prompt_language: "en"` → 加载 `references/ai-report-prompt-en.md`

将 `{prompt}` 占位符替换为实际 `prompt.md` 内容，形成完整的审查指令。

### Step 3: 执行验收审查（优先并发子代理，失败自动降级）

优先采用并行任务执行 (Parallel Task Execution) 拉起多个专业子代理（执行前须分别读取 `skills/code-reviewer/SKILL.md`、`skills/refactor-cleaner/SKILL.md`、`skills/e2e-runner/SKILL.md`）：
- 代码质量与覆盖审计职责
- 死代码与冗余清理职责
- E2E/黑盒验证职责（如适用）

兼容性要求（必须遵守）：
- agent 类型必须使用当前环境可用列表（如 `Plan` / `Explore` / `general-purpose`），**禁止硬编码不存在的类型**。
- 若并行子代理不可用或创建失败，**必须自动降级为主线程继续完成全部审查项**，不得中断 Phase。

按照以下验收标准逐条执行审查。每一条都必须给出：
- **结论**：Pass / Partial Pass / Fail / Not Applicable / Cannot Confirm
- **理由**：理论支撑
- **证据**：file:line
- **可复现验证方式**

#### 维度 1: 硬性门槛（一票否决）

**1.1 可运行性**
- 是否提供明确的启动说明
- 是否能在不修改核心代码的前提下启动
- 实际运行结果是否与文档一致
- Docker 项目：`docker compose up` 能否一键启动
- Docker 项目：检查端口暴露、服务声明、healthcheck

**1.2 主题偏离**
- 对比 Prompt 需求清单与实际实现
- 是否擅自替换/弱化/忽略核心需求
- 是否大幅削减功能降低开发难度

#### 维度 2: 交付完整性

**2.1 核心需求覆盖**
- 逐条检查 `docs/designs/requirement-analysis.md` 中的需求是否都已实现

**2.2 交付形态**
- 是否完整项目结构（非单文件/片段代码）
- 是否有 README
- 是否有完整配置文件（package.json/requirements.txt 等）
- 是否存在未声明的 Mock/Hardcode

#### 维度 3: 工程架构质量

**3.1 结构合理性**
- 项目结构是否清晰，模块职责明确
- 是否存在冗余/不必要文件
- 是否在单一文件中堆叠代码

**3.2 可维护性**
- 是否高耦合、混乱
- 核心逻辑是否可扩展
- 无 Magic Number、无深层 if-else 嵌套

#### 维度 4: 工程细节

**4.1 专业度**
- 错误处理：全局异常处理 + 统一响应格式 + HTTP 状态码规范
- 日志：结构化日志、分级、禁止裸输出、禁止敏感信息
- 输入校验：Body/Query/Path 参数校验
- 接口设计：列表分页、响应格式规范、可读性
- 前端容错：接口失败有 Toast/缺省页，不白屏

**4.2 产品形态**
- 是否像真实应用而非 Demo/教学示例

#### 维度 5: 需求适配度

**5.1 准确理解**
- 是否准确实现 Prompt 的核心业务目标
- 是否误解需求语义
- 是否擅自更改关键约束

#### 维度 6: 美观度（仅前端/全栈）

**6.1 视觉交互**
- 布局整齐、元素对齐
- 配色和谐、现代化
- 交互反馈（Loading/禁用/悬停/Toast）
- 流程顺畅、无死链

### Step 4: 安全专项审查（优先子代理，失败自动降级）

优先派发给安全审计子代理执行专项检查。必须先读取 `skills/security-reviewer/SKILL.md`。

兼容性要求（必须遵守）：
- agent 类型必须使用当前环境可用列表，**禁止硬编码不存在的类型**。
- 若子代理不可用或创建失败，**必须自动降级为主线程执行安全审计**，不得跳过该步骤。

**必须逐条检查并提供证据**：
- ✅ 认证入口与登录态处理
- ✅ 路由级鉴权（中间件/路由守卫）
- ✅ 对象级授权（资源归属校验，不能仅凭 ID 访问他人资源）
- ✅ 功能级授权
- ✅ 租户/用户数据隔离
- ✅ 管理/调试接口保护
- ✅ token/密码/密钥 是否暴露到日志/响应/前端代码/localStorage

### Step 5: 测试覆盖度静态审计（必做，重点！）

**5.1 测试概览**
- 是否存在 `unit_tests/` 和 `API_tests/` 目录
- 测试框架和入口
- README 是否提供可执行测试命令
- `run_tests.sh`/`run_tests.bat` 是否存在

**5.2 覆盖映射表（必填）**

以 Prompt 需求点为行：

| 需求点/风险点 | 对应测试用例 (file:line) | 关键断言 (file:line) | 覆盖判定 | 缺口 | 最小补测建议 |
|:---|:---|:---|:---|:---|:---|

覆盖判定：充分 / 基本覆盖 / 不足 / 缺失 / 不适用 / 无法确认

**5.3 覆盖基线检查**：
- 核心业务 happy path（至少一条端到端用例）
- 核心异常路径（401/403/404/409/校验失败）
- 安全重点（鉴权测试、越权测试）
- 关键边界（分页/空数据/极值）
- 敏感信息（token/密码/密钥是否泄露到日志/响应）

**5.4 Mock/Stub 处理**：
- 允许 Mock，但必须说明范围、启用条件
- 检查是否存在"生产默认启用 Mock"风险

**5.5 总判定**：
- 结论：Pass / Partial Pass / Fail / Cannot Confirm
- 说明边界：哪些风险已覆盖、哪些未覆盖

### Step 6: Docker 启动验证（如适用）

对后端/全栈项目：
- 静态检查 `Dockerfile` 是否存在、格式正确
- 静态检查 `docker-compose.yml` 是否存在、端口暴露、服务声明
- 检查 `.dockerignore` 是否排除了 `node_modules` 等
- 检查是否依赖本地绝对路径
- 检查是否需要手动创建 `.env` 或手动导入 SQL

### Step 7: 英文红线检查（如 Prompt 为英文）

扫描全部产物代码，检查是否存在中文字符。
发现中文 → 标记为**阻塞级问题**。

### Step 8: 生成自测报告

将审查结果写入 `.tmp/self-review-report.md`：

```markdown
# Self Review Report

## 审查概要
- Project Type: {type}
- Review Mode: {前端/非前端/混合}
- Review Date: {date}
- Prompt Language: {en/zh}

## 维度 1: 硬性门槛
### 1.1 可运行性
- 结论: {Pass/Partial Pass/Fail}
- 证据: {file:line}
- 说明: ...

### 1.2 主题偏离
...

## 维度 2-6: ...

## 安全专项审查
...

## 测试覆盖度评估（静态审计）
### 测试概览
...
### 覆盖映射表
...
### 安全覆盖审计
...
### 总判定
...

## Docker 启动检查（如适用）
...

## 英文红线检查（如适用）
...

## 问题清单
| # | 级别 | 维度 | 问题 | 证据 | 影响 | 最小改进建议 |
|---|:---:|:---:|:---|:---|:---|:---|

## 总体判定
- 总结论: {Pass/Partial Pass/Fail}
- 说明: ...
```

### Step 9: 问题自动修复

对于报告中发现的问题：
- **阻塞级/高级问题**：自动修复，修复后重新审查对应维度
- **中级问题**：尝试自动修复
- **低级问题**：记录到 `questions.md`

修复后重新运行 Step 3-8，直到：
- 无阻塞/高级问题
- 或达到 3 轮修复上限

## 完成条件

当以下全部满足时，Phase 3 完成：
- `.tmp/self-review-report.md` 已生成
- 无阻塞级问题（允许低级问题保留）
- `questions.md` 已更新

输出 `SELF_REVIEW_COMPLETE` 标记完成。
