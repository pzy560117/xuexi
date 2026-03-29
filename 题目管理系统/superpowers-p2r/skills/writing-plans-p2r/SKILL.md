---
name: writing-plans-p2r
description: "Prompt2Repo Phase 1: 基于需求分析生成 BDD 行为规格+架构设计+Docker计划+测试结构+任务计划，内嵌全部验收标准"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# Writing Plans — Prompt2Repo Phase 1

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>PLANNING_COMPLETE</promise>` 时必须遵守：
- BDD 规格、架构设计、最佳实践文档、任务计划全部生成
- 每个任务包含验收维度映射

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 设计规划是“从需求到可执行任务”的桥梁，确保每个任务都有明确目标、输入输出和验收标准。

- **MANDATORY**: BDD 场景必须标注验收维度编号
- **MANDATORY**: 安全/鉴权场景不可省略
- **MANDATORY**: 每个任务拆分为 2-5 分钟可执行单元
- **MANDATORY**: 优先采用并行任务执行拉起子代理，失败自动降级
- **PROHIBITED**: 不得硬编码不存在的 agent type
- **PROHIBITED**: 不得省略异常路径场景（401/403/404/409/422）

## 概述

本 Skill 是 Prompt2Repo 流水线的第二阶段。在 Phase 0 完成 Prompt 解析后，本阶段将需求清单转化为可执行的任务计划。

**前提条件**: `docs/designs/requirement-analysis.md` 必须存在。

## 执行步骤

### Step 1: 读取需求分析

读取以下文件：
- `docs/designs/requirement-analysis.md` — 需求清单与约束
- `docs/designs/_meta.md` — 语言、项目类型、Docker 需求

### Step 2: 生成 BDD 行为规格

为每个核心需求点编写 BDD 场景，使用 Given-When-Then 格式。

**关键要求**：
1. 每个 BDD 场景必须标注对应的**验收维度编号**
2. 安全/鉴权场景**必选**（不可省略）
3. Then 阶段必须**明确返回的数据结构**（JSON Schema）
4. 必须包含异常路径场景（401/403/404/409/422）
5. 必须包含输入校验场景

输出到 `docs/designs/bdd-specs.md`。

### Step 3: 生成架构设计（优先并发子代理，失败自动降级）

优先采用 **并行任务执行 (Parallel Task Execution)** 拉起架构子代理。
- 可用 agent 类型以当前运行环境为准，推荐优先级：`Plan` → `Explore` → `general-purpose`。
- 先读取 `skills/architect/SKILL.md` 作为架构规则输入。
- 由子代理负责系统架构、数据流和组件划分。

兼容性要求（必须遵守）：
- **禁止硬编码不存在的 agent type**（例如 `superpowers:architect`）。
- 若当前环境不支持上述子代理或创建失败，**必须自动降级为主线程直接完成架构设计**，不得中断 Phase。

根据项目类型生成 `docs/designs/architecture.md`：

**必须包含**：
- 项目目录结构（完整树形图，含测试目录）
- 模块职责说明
- 数据库 Schema（如有）
- API 端点列表（如有后端），含请求/响应格式
- 前端路由列表（如有前端）
- 技术选型说明

**架构质量约束（对应验收维度 3）**：
- 模块职责清晰，不在单文件堆叠
- 单文件不超过 800 行
- 后端分层架构：路由 → 控制器 → 服务 → 数据访问
- 前端组件合理拆分，避免"上帝组件"
- 目录命名语义化（如 /utils, /components, /api）

**测试目录结构（必须在架构中规划）**：
```
project_root/
├── unit_tests/              # 单元测试目录
│   ├── test_xxx.py/js       # 按模块组织
│   └── ...
├── API_tests/               # API 接口功能测试
│   ├── test_xxx_api.py/js   # 按功能组织
│   └── ...
├── run_tests.sh             # Linux/Mac 测试入口
└── run_tests.bat            # Windows 测试入口
```

### Step 4: 生成最佳实践文档

生成 `docs/designs/best-practices.md`，**严格对应验收标准**：

```markdown
## 工程细节标准（对应验收维度 4）

### 错误处理
- 全局异常处理中间件
- 统一错误响应格式: { "success": false, "error": "CODE", "message": "..." }
- HTTP 状态码规范使用（200/201/400/401/403/404/409/500）
- 前端接口失败时 Toast 提示或缺省页，不能白屏

### 日志规范
- 使用结构化日志框架（winston/loguru/log4j 等）
- 日志分级：DEBUG/INFO/WARN/ERROR
- 关键业务流程必须有日志（登录、支付、数据变更）
- 禁止 console.log/print 裸输出
- 禁止将 token/密码/密钥输出到日志

### 输入校验
- 所有 API 端点对 Body/Query/Path 参数校验（判空/格式/长度）
- 前端表单增加前端校验
- 关键边界条件处理

### 安全要求（对应验收维度 4.1 + 硬性规则 8）
- 认证入口保护
- 路由级鉴权中间件
- 对象级授权（资源归属校验，不能仅凭 ID 读写他人资源）
- 功能级授权
- 租户/用户数据隔离
- 管理/调试接口保护
- token 不暴露于日志和前端代码
- 禁止 SQL 字符串拼接（使用参数化查询）
- 密码不得明文存储

### API 返回格式标准
- 列表接口必须分页（page/pageSize/total）
- 返回体结构清晰，JSON 格式化
- 防止返回不可读的大 JSON（做分页保证可读性）

### 测试要求
- 单元测试存放于 `unit_tests/` 目录
- API 测试存放于 `API_tests/` 目录
- 测试通过 `run_tests.sh`/`run_tests.bat` 一键启动
- 单元测试使用断言
- API 测试**真实调用接口**
- 终端打印：功能名称 + 返回码 + message
- 覆盖全部接口
- 包含 happy path + 异常路径（校验失败/401/403/404）
- 有前置依赖的接口测试需先调用依赖接口（如先登录获取 token）
```

### Step 5: 生成任务计划（优先并发子代理，失败自动降级）

优先采用 **并行任务执行 (Parallel Task Execution)** 拉起任务规划子代理。
- 可用 agent 类型以当前运行环境为准，推荐优先级：`Plan` → `Explore` → `general-purpose`。
- 先读取 `skills/planner/SKILL.md` 作为任务拆分规则输入。
- 由子代理基于架构设计与规格结果细化任务依赖队列。

兼容性要求（必须遵守）：
- **禁止硬编码不存在的 agent type**（例如 `superpowers:planner`）。
- 若当前环境不支持上述子代理或创建失败，**必须自动降级为主线程直接完成任务拆分**，不得中断 Phase。

将 BDD 场景拆分为 2-5 分钟可执行的小任务，输出到 `docs/plans/` 目录。

**任务排列顺序（标准化！）**：

```
1. task-001-setup.md — 项目初始化（脚手架/依赖/目录结构）
2. task-002-xxx-impl.md + task-002-xxx-test.md — 数据模型/数据层
3. task-003-xxx-impl.md + task-003-xxx-test.md — 业务逻辑层
4. task-004-xxx-impl.md + task-004-xxx-test.md — 路由/控制器层
5. task-005-xxx.md — 前端页面（如适用）
6. task-006-integration.md — 集成测试
7. task-007-readme.md — README 文档
8. task-008-test-scripts.md — run_tests.sh/run_tests.bat 生成
9. task-009-docker.md — Dockerfile + docker-compose.yml 生成（如需要 Docker）
10. task-010-db-init.md — 数据库初始化脚本（如适用）
```

**每个任务文件格式**：

```markdown
---
task_id: "NNN"
title: "任务标题"
estimated_minutes: 3
depends_on: ["前置任务ID"]
acceptance_dimensions: ["1.1", "2.1", "4.1"]
---

# Task NNN: 任务标题

## 目标
简要说明本任务要完成什么

## 文件变更
- [NEW] `src/controllers/authController.js` — 认证控制器
- [MODIFY] `src/routes/index.js` — 添加认证路由

## 实现要求
1. 具体实现步骤
2. 必须满足的约束

## 测试要求
- 对应的测试文件和测试用例
- 预期通过的断言

## 验证步骤
npm test -- --grep "auth"

## BDD 场景关联
- [F-001] 用户 SMTP 邮箱验证登录
```

### Step 6: 生成计划索引

创建 `docs/plans/_index.md`：

```markdown
# Execution Plan Index

## 任务概览
- Total tasks: N
- Estimated time: X minutes
- Project type: {type}
- Docker required: {yes/no}

## 任务列表
| # | Task ID | Title | Depends On | Status |
|---|---------|-------|------------|--------|
| 1 | 001 | 项目初始化 | - | pending |
| 2 | 002 | 数据模型实现 | 001 | pending |
...
```

## Exit Criteria

当以下文件全部生成后，Phase 1 完成：
- `docs/designs/bdd-specs.md`
- `docs/designs/architecture.md`
- `docs/designs/best-practices.md`
- `docs/plans/_index.md`
- `docs/plans/task-001-*.md` ~ `docs/plans/task-NNN-*.md`

输出 `<promise>PLANNING_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../architect/SKILL.md` - 架构子代理规则
- `../planner/SKILL.md` - 任务拆分子代理规则
- `../../skills/references/completion-promises.md` - Promise 设计规范
