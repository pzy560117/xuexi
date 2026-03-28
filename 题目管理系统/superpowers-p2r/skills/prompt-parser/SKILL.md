---
name: prompt-parser
description: "Prompt2Repo Phase 0: 自动解析 prompt.md，提取结构化需求清单、项目类型、技术栈、隐含约束，检测 Docker/SMTP/语言红线"
---

# Prompt Parser — Prompt2Repo Phase 0

## 概述

本 Skill 是 Prompt2Repo 流水线的第一阶段，负责自动读取 `prompt.md` 文件并输出结构化的需求分析。

**THIS MUST BE YOUR FIRST ACTION**: 读取当前项目根目录下的 `prompt.md` 文件。如果传入了参数路径，使用参数路径。

## 执行步骤

### Step 1: 读取 Prompt 文件

```
读取 prompt.md（或传入的路径），获取完整的业务需求描述。
```

### Step 2: 语言检测（最高优先级红线）

检测 Prompt 语言：

**🔴 红线规则**：
- 如果 Prompt 是**英文**：所有后续产物（代码注释、日志消息、UI文案、README、文档、变量命名风格、错误提示、测试描述）全部使用**英文**，**绝对禁止出现任何中文字符**
- 如果 Prompt 是**中文**：产物使用中文

将检测结果写入 `docs/designs/_meta.md`：

```markdown
---
prompt_language: "en" | "zh"
all_outputs_language: "en" | "zh"
language_enforcement: "strict"
---

## Language Policy
- Prompt Language: {en/zh}
- Output Language: {en/zh}
- Enforcement: STRICT — 英文 Prompt 产物中出现中文字符将导致一票否决
```

### Step 3: 项目类型识别

从 Prompt 内容推断项目类型，只能是以下之一：

| 类型标识 | 说明 | Docker 要求 |
|:---|:---|:---|
| `fullstack` | 全栈项目（前端+后端） | ✅ 必须 |
| `pure_backend` | 纯后端项目 | ✅ 必须 |
| `pure_frontend` | 纯前端项目 | ❌ 不要求 |
| `cross_platform_app` | 跨平台项目 | ❌ 不要求 |
| `mobile_app` | 移动端项目 | ❌ 不要求 |

### Step 4: 技术栈识别

从 Prompt 中提取：
- `frontend_tech`: 前端技术栈（react/vue/angular/none 等）
- `backend_tech`: 后端技术栈（python/java/node/go/rust 等）
- `database`: 数据库（postgresql/mysql/mongodb/sqlite/none 等）

**如 Prompt 未指定技术栈，推荐使用以下默认版本**：
- Node.js: 18.x LTS
- Python: 3.10.x
- Java: 17.x LTS
- MySQL: >= 8.0
- PostgreSQL: >= 14
- SQLite: >= 3.39

### Step 5: 核心需求点提取

逐条提取 Prompt 中**明确提出**的功能需求，格式：

```markdown
## 核心需求清单

### 功能需求
1. [F-001] 用户注册与登录
2. [F-002] 商品列表展示
...

### 非功能需求
1. [NF-001] RESTful API 设计
2. [NF-002] 响应式布局
...

### 隐含约束（必须从验收标准推导）
1. [IC-001] 鉴权与权限控制（路由级+对象级）
2. [IC-002] 输入校验（所有 API 参数）
3. [IC-003] 结构化日志（禁止裸 print/console.log）
4. [IC-004] 统一错误响应格式（HTTP状态码 + JSON body）
5. [IC-005] 安全基线（防 SQL 注入、XSS、密码明文存储）
6. [IC-006] 数据隔离（多用户场景下的资源归属校验）
```

### Step 6: 业务规则识别

**必须检测以下规则并写入约束清单**：

1. **邮箱验证码登录替换规则**：
   - 原 Prompt 中关于"邮箱验证码登录"→ 统一使用 SMTP 实现
   - 支付宝/微信/手机号登录 → **不做，不 Mock**
   - 判断 toC/toB 场景：
     - toC 场景 → 必须实现 SMTP 邮箱验证登录（测试账号用账号密码登录）
     - toB 场景 → 不需要邮箱验证

2. **支付相关功能**：
   - 使用 Mock/Stub/Fake 实现，不接真实第三方
   - 必须标注 Mock 范围和启用条件
   - **不能**生产默认启用 Mock（必须有环境变量控制）

3. **Docker 交付要求**（后端/全栈）：
   - 必须 `docker compose up` 一键启动
   - 零私有依赖、零交互式输入
   - 端口显式暴露
   - 数据库使用初始化脚本注入

4. **测试交付要求**：
   - `unit_tests/` 目录存放单元测试
   - `API_tests/` 目录存放接口功能测试
   - `run_tests.sh` + `run_tests.bat` 一键执行
   - 单元测试使用断言
   - API 测试**真实调用接口**，终端打印功能名称+返回码+message
   - 覆盖全部接口，有些接口测试需要前置接口返回值（如先登录获取 token）

### Step 7: 输出需求分析文档

将以上所有分析结果输出到 `docs/designs/requirement-analysis.md`：

```markdown
# Requirement Analysis

## Prompt Language
{en/zh}

## Language Enforcement
STRICT — {说明}

## Project Type
{fullstack/pure_backend/pure_frontend/...}

## Docker Required
{yes/no}

## Technology Stack
- Frontend: {tech}
- Backend: {tech}
- Database: {db}

## Core Requirements
{需求清单，含编号}

## Implied Constraints
{隐含约束清单}

## Business Rules
{业务规则，含 SMTP/支付/Docker/测试要求}

## Acceptance Criteria Mapping
{每个需求点对应的验收维度}
```

### Step 8: 生成 metadata.json 草稿

在项目根目录生成 `metadata.draft.json`：

```json
{
  "project_type": "{识别的项目类型}",
  "frontend_tech": "{前端技术}",
  "backend_tech": "{后端技术}",
  "database": "{数据库}"
}
```

### Step 9: 初始化 questions.md

创建 `questions.md`，使用标准格式：

```markdown
# 业务逻辑疑问记录

## 在理解 Prompt 过程中的业务逻辑疑问

（格式：问题 + 我的理解/假设 + 解决方式）

### 1. {问题标题}
- **问题**: {具体的业务逻辑不明确之处}
- **我的理解**: {基于上下文的合理假设}
- **解决方式**: {实际采用的实现策略}
```

在 Phase 0 阶段，将解析 Prompt 时发现的业务逻辑疑问记录到此文件。

## 完成条件

当以下文件全部生成后，Phase 0 完成：
- `docs/designs/_meta.md`
- `docs/designs/requirement-analysis.md`
- `metadata.draft.json`
- `questions.md`

输出 `PROMPT_PARSING_COMPLETE` 标记完成。
