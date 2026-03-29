---
name: executing-plans-p2r
description: "Prompt2Repo Phase 2: 按任务计划生成完整项目代码，BDD驱动+Docker生成+英文检查+工程质量内置检查，支持 Ralph-Loop"
argument-hint: []
user-invocable: false
allowed-tools: []
---

# Executing Plans — Prompt2Repo Phase 2

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>EXECUTION_COMPLETE</promise>` 时必须遵守：
- 所有任务标记为 `done`
- 项目代码完整可运行
- 测试、Docker、README 全部生成

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 代码执行阶段是“把设计变为现实”的核心环节，优先采用 Agent Team 并行实现。

- **MANDATORY**: 优先采用并行 Implementer 子代理，失败自动降级为串行执行
- **MANDATORY**: 每个 Implementer 拥有独立的文件所有权，禁止跨代理写
- **MANDATORY**: 每批任务完成后必须执行 Reviewer 交叉检查
- **MANDATORY**: 英文 Prompt 场景下产物绝对不能出现中文字符
- **PROHIBITED**: 不得硬编码不存在的 agent type
- **PROHIBITED**: 不得跳过工程质量内置检查

## 概述

本 Skill 是 Prompt2Repo 流水线的核心执行阶段。按 Phase 1 生成的任务计划逐个执行，生成完整的项目代码。

## Ralph-Loop 集成模式（关键）

本 Skill 支持两种运行模式，**必须先判断再执行**：

1. **Prompt2Repo 主流程内调用（默认）**  
   当 `docs/runtime/superpower-loop.local.md` 已存在并包含 `phases:` 时，说明主流程 Loop 已在运行。  
   **禁止再次调用** `setup-superpower-loop.sh`，否则会覆盖主状态文件并导致后续 Phase 无法自动推进。

2. **独立调用 `/superpowers:executing-plans-p2r`**  
   仅在没有主流程 Loop 时，才启动专用 Loop，且必须使用独立状态文件避免冲突：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-superpower-loop.sh" \
  "Execute the Prompt2Repo plan at <resolved-plan-path>. Follow the task index strictly. For each task: read the task file, implement changes, run verification, mark complete." \
  --completion-promise "EXECUTION_COMPLETE" \
  --max-iterations 100 \
  --state-file "docs/runtime/superpower-loop-executing-plans.local.md"
```

## 执行规则

### 每个任务的执行流程（Agent Team 并行模式，失败自动降级）

优先采用 **Agent Team 并行执行**（参考 `skills/agent-team-driven-development/SKILL.md`）：

#### 🔀 并行任务分派（Team Lead 职责）

**Phase 2 开始时**，Team Lead（主代理）须执行以下分派逻辑：

1. **分析任务依赖图**：读取 `docs/plans/_index.md`，识别无依赖关系的独立任务组
2. **Spawn Implementer 子代理**：为每组独立任务创建 Implementer，每个 Implementer 分配 5-6 个任务
3. **文件所有权隔离**：每个 Implementer 负责独立的文件/模块，**严禁跨代理编辑同一文件**
4. **上下文注入**：每个 Implementer spawn 时必须提供：
   - 分配的任务文件路径列表
   - 负责的源文件/模块范围
   - 项目编码规范（`CLAUDE.md` / coding standards）
   - TDD 要求：`Red-Green-Refactor` 循环

**Implementer 子代理 Spawn 示例**：
```
你是 Implementer-Backend。
1. 读取 CLAUDE.md 了解项目规范。
2. 依次执行 task-001, task-002, task-003。
3. 遵循 TDD：先写失败测试(RED) → 写实现(GREEN) → 重构。
4. 你只能编辑: src/api/, src/models/, unit_tests/test_api/。
5. 完成每个任务后运行验证步骤并报告结果。
```

#### 🔍 Reviewer 交叉检查（每批任务完成后）

每个 Implementer 完成分配的任务后，Spawn **Reviewer 子代理** 进行交叉审查：

```
你是 Reviewer。
1. 检查 Implementer-Backend 的代码变更 (git diff)。
2. 验证是否遵循 TDD（测试先于实现）。
3. 检查代码质量（错误处理/日志/输入校验）。
4. 检查安全问题（SQL注入/XSS/密钥暴露）。
5. 提供具体的改进建议。
```

- **TDD 导师职责**：先读取 `skills/tdd-guide/SKILL.md`，主导 `Red-Green-Refactor` 循环。
- **构建修复职责**：先读取 `skills/build-error-resolver/SKILL.md`，在编译/类型错误出现时快速修复。

**兼容性要求（必须遵守）**：
- agent 类型必须使用当前环境可用列表（如 `Plan` / `Explore` / `general-purpose`），**禁止硬编码不存在的类型**。
- 若 Agent Team 不可用或创建失败，**必须自动降级为主线程串行执行**，不得中断 Phase。
- 降级时仍须执行完整的 TDD 流程和质量检查。

### 工程质量内置检查（每个任务完成后）

**文件规模检查**：
- 单个文件不超过 800 行 → 超过则拆分
- 单个函数不超过 50 行 → 超过则重构

**代码质量检查**：
- ✅ 是否有适当的错误处理（try-catch/error middleware + 统一响应格式）
- ✅ 是否使用结构化日志（禁止裸 console.log/print，使用日志框架）
- ✅ 是否有输入校验（所有 API 参数 Body/Query/Path）
- ✅ 是否有必要的注释（函数级注释，语言取决于 Prompt 语言）
- ✅ 是否暴露敏感信息（token/密码/密钥不得出现在日志/代码/前端）
- ✅ 是否有 hardcode（如有需标注为 TODO 或说明原因）
- ✅ API 返回是否规范（列表接口分页、响应体结构清晰）
- ✅ 是否删除了调试用的 print/console.log 语句
- ✅ 是否删除了被注释掉的大段废弃代码

**安全检查**：
- ✅ 认证中间件是否应用到受保护路由
- ✅ 对象级授权（不能仅凭 ID 访问他人资源，需校验资源归属）
- ✅ 功能级授权
- ✅ 管理/调试端点是否有保护
- ✅ CORS 配置是否合理
- ✅ SQL 是否使用参数化查询（禁止字符串拼接）
- ✅ 密码是否加密存储（不得明文）
- ✅ 前端不得明文存储密码

**架构检查**：
- ✅ 是否遵循计划中的目录结构
- ✅ 模块职责是否清晰（不在路由文件中写业务逻辑）
- ✅ 是否有冗余文件
- ✅ 是否出现数千行的"上帝文件/组件"

### 🔴 英文语言链路检查（英文 Prompt 场景）

读取 `docs/designs/_meta.md`，如 `prompt_language: "en"`：

**每个任务完成后必须检查所有新增/修改文件**：
- ✅ 代码注释不含中文
- ✅ 日志消息不含中文
- ✅ UI 文案/按钮/标签不含中文
- ✅ 错误提示不含中文
- ✅ 变量名/函数名不含中文
- ✅ 测试描述不含中文
- ✅ README 内容不含中文

**发现中文字符 → 立即替换为英文后继续**。这是最高红线，不可忽略。

### README 自动生成

在所有功能任务完成后生成 `README.md`：

```markdown
# {Project Name}

## Overview
{从 Prompt 提取的核心描述}

## Technology Stack
- Frontend: {tech}
- Backend: {tech}
- Database: {db}

## Quick Start

### Prerequisites
- Docker (recommended)
- {或：Node.js >= 18 / Python >= 3.10 / Java >= 17}

### Using Docker (Recommended)
```bash
docker compose up
```
The application will be available at:
- Frontend: http://localhost:{port}
- Backend API: http://localhost:{api_port}

### Manual Setup
{具体安装/启动命令}

### Database Initialization
{数据库初始化说明（Docker 自动完成 / 手动脚本）}

## Running Tests
```bash
# Linux/Mac
./run_tests.sh

# Windows
run_tests.bat
```

## Project Structure
```
{实际生成的目录树}
```

## API Documentation
| Method | Endpoint | Description |
|:---|:---|:---|
{主要 API 端点列表}

## Features
{已实现功能列表}

## Test Accounts
{如有测试账号，列出}
```

### 测试脚本生成

生成 `run_tests.sh`：

```bash
#!/bin/bash
set -e

echo "======================================"
echo "Running Unit Tests..."
echo "======================================"
cd unit_tests/
{单元测试命令}
cd ..

echo ""
echo "======================================"
echo "Running API Tests..."
echo "======================================"
echo "Note: Ensure the application is running before executing API tests."
cd API_tests/
{API测试命令}
cd ..

echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "All tests completed."
```

生成 `run_tests.bat`（Windows 版本）：

```batch
@echo off
echo ======================================
echo Running Unit Tests...
echo ======================================
cd unit_tests
{单元测试命令}
cd ..

echo.
echo ======================================
echo Running API Tests...
echo ======================================
echo Note: Ensure the application is running before executing API tests.
cd API_tests
{API测试命令}
cd ..

echo.
echo ======================================
echo Test Summary
echo ======================================
echo All tests completed.
```

**测试脚本要求**：
- 使用断言
- API 测试真实调用接口
- 终端打印：**功能名称 + 返回码 + message**
- 覆盖全部接口
- 有些接口测试需要另外接口的返回值（如先登录获取 token，再用 token 调用其他接口）

### Docker 配置生成（如需要）

当项目需要 Docker 时，执行 `docker-generator` Skill 的逻辑：
- 生成 `Dockerfile`
- 生成 `docker-compose.yml`（含数据库服务、healthcheck、端口暴露）
- 生成 `.dockerignore`
- 生成 `init-db/` 初始化脚本

**全栈项目特殊处理**：
- 前后端分离项目（存在 `frontend/` + `backend/` 目录）→ 使用三服务模板（frontend Nginx + backend API + db）
- SSR 框架项目（Next.js/Nuxt.js）→ 使用单服务模板（app + db）
- 前端 Dockerfile 采用多阶段构建：builder 阶段 `npm run build` → Nginx 阶段 serve 静态文件
- 生成 `nginx.conf` 配置 API 反向代理到后端容器
- 参见 `docker-generator` Skill 的"全栈项目多容器编排模板"章节

### 数据库初始化脚本

如项目使用数据库，生成初始化脚本（置于 `init-db/` 目录）：
- 建表语句（使用 IF NOT EXISTS）
- 必要的种子数据（测试账号等）
- **不打包数据库文件本身**

## Loop 状态管理

每完成一个任务：
1. 更新 `docs/plans/_index.md` 中对应任务状态为 `done`
2. 如果所有任务完成，执行最终质量全检
3. 输出 `<promise>EXECUTION_COMPLETE</promise>`（必须作为回复最后一行）

每次 Loop 迭代开始时：
1. 读取 `docs/plans/_index.md` 获取进度
2. 找到第一个 `pending` 状态的任务
3. 执行该任务

## Exit Criteria

当以下全部满足时，Phase 2 完成：
- `docs/plans/_index.md` 中所有任务标记为 `done`
- `README.md` 已生成，包含启动和测试说明
- `run_tests.sh` / `run_tests.bat` 已生成
- `unit_tests/` 和 `API_tests/` 目录已创建
- 数据库初始化脚本已生成（如适用）
- Docker 配置已生成（如适用）
- 英文 Prompt 场景下全部产物无中文字符

输出 `<promise>EXECUTION_COMPLETE</promise>`，且该标签必须是回复最后一行。

## References

- `../agent-team-driven-development/SKILL.md` - Agent Team 协作框架
- `../agent-team-driven-development/references/` - 子代理通信模板
- `../code-reviewer/SKILL.md` - 代码审查子代理
- `../../skills/references/completion-promises.md` - Promise 设计规范


