---
name: domain-checklist
description: "Prompt2Repo Phase 2.5: 基于领域生成定制化检查清单，验证实现代码是否满足规格和行业标准"
---

# Domain Checklist — Prompt2Repo Phase 2.5

## 概述

本 Skill 在 Phase 2（代码执行）和 Phase 3（自测审查）之间插入**领域定制化检查清单验证**，在自测审查前先用结构化的清单检查实现是否符合规格和行业标准。

**方法论来源**: 改编自 `speckit-checklist`，适配为 P2R 全自动模式（根据项目类型自动生成并执行检查）。

**前提条件**: Phase 2 代码执行完成（`EXECUTION_COMPLETE`），以下文件必须存在：
- `docs/specs/spec.md`
- 项目代码目录

## 执行步骤

### Step 1: 读取项目上下文

读取以下文件：
- `docs/designs/_meta.md` — 项目类型和技术栈
- `docs/specs/spec.md` — 功能规格
- `docs/designs/architecture.md` — 架构设计
- 项目代码目录结构

### Step 2: 确定检查清单类型

根据 `_meta.md` 中的 `project_type` 自动选择检查清单组合：

| 项目类型 | 必选清单 | 可选清单 |
|:---|:---:|:---:|
| `pure_backend` | 安全、API、代码质量、开源合规 | 性能 |
| `pure_frontend` | UX、可访问性、代码质量、开源合规 | 性能 |
| `fullstack` | 安全、API、UX、代码质量、开源合规 | 性能 |
| `mobile_app` | 安全、UX、代码质量、开源合规 | 性能 |

### Step 3: 生成安全检查清单

输出 `docs/specs/checklists/security.md`：

```markdown
# 安全检查清单

## 认证与授权
- [ ] SEC-001: 所有受保护端点是否都有认证中间件？ [Coverage, Spec §FR-认证]
- [ ] SEC-002: JWT/Token 过期机制是否实现？ [Completeness]
- [ ] SEC-003: 登出时 Token 是否失效（黑名单/Redis 清除）？ [Coverage]
- [ ] SEC-004: 密码是否使用 bcrypt/argon2 哈希存储？ [Clarity, Spec §安全]
- [ ] SEC-005: 登录失败是否有频率限制和账户锁定？ [Completeness]

## 数据保护
- [ ] SEC-006: 敏感字段是否加密存储？ [Coverage, Spec §数据保护]
- [ ] SEC-007: API 响应是否按角色脱敏敏感数据？ [Completeness]
- [ ] SEC-008: 密钥是否通过环境变量配置，不硬编码？ [Clarity]
- [ ] SEC-009: Docker 配置中是否避免明文密码？ [Coverage]

## 输入验证
- [ ] SEC-010: 所有用户输入是否有服务端校验？ [Coverage]
- [ ] SEC-011: 文件上传是否有类型/大小限制？ [Completeness, Spec §文件上传]
- [ ] SEC-012: SQL 查询是否使用参数化（ORM/PreparedStatement）？ [Coverage]

## 访问控制
- [ ] SEC-013: API 是否有对象级授权（防止 IDOR）？ [Coverage]
- [ ] SEC-014: CORS 是否限制允许的来源？ [Clarity]
- [ ] SEC-015: 管理/调试端点是否受保护？ [Coverage]

## 日志安全
- [ ] SEC-016: 日志是否避免输出 Token/密码/密钥？ [Coverage]
- [ ] SEC-017: 错误响应是否避免泄露内部信息（不能直接抛出 Stack Trace）？ [Clarity]

### Step 3.5: 生成代码质量与规范检查清单 (P2R 核心标准)

输出 `docs/specs/checklists/code_quality.md`：

```markdown
# 代码质量与规范检查清单

## P2R 红线标准 (一票否决)
- [ ] QLT-001: 语言一致性 - 如果 Prompt 是英文，代码/注释/文档是否全英文，无任何中文？ [Consistency]
- [ ] QLT-002: 环境隔离 - 代码中是否绝对没有本地绝对路径（如 C:/Users/）？ [Coverage]
- [ ] QLT-003: 无交互输入 - 启动或测试脚本是否完全自动化，不需要人工输入 y/n 或密码？ [Completeness]
- [ ] QLT-004: 拒绝 Mock - 核心业务是否非写死数据？（除非 Prompt 明确要求） [Consistency]

## 健壮性与错误处理
- [ ] QLT-005: 优雅降级 - 接口是否统一使用带 code/msg 的 JSON 错误提示？ [Consistency]
- [ ] QLT-006: 异常兜底 - 前端在接口失败时是否有 Toast 提示或缺省页，非白屏？ [Coverage]

## 代码整洁度
- [ ] QLT-007: 冗余清理 - 提交前是否确认无大段注释/废弃代码？ [Clarity]
- [ ] QLT-008: 日志质量 - 是否删除了无意义的 `print("here")` 或 `console.log("111")`？ [Clarity]
```

### Step 4: 生成 API 检查清单（如有后端）

输出 `docs/specs/checklists/api.md`：

```markdown
# API 检查清单

## 接口规范 (P2R 标准)
- [ ] API-001: 所有端点是否使用统一响应格式（包含 success/data/error 等结构）？ [Consistency]
- [ ] API-002: 列表接口是否支持分页（page/pageSize/total），避免不可读的大 JSON？ [Completeness]
- [ ] API-003: 错误响应是否包含错误码和描述（不抛异常堆栈）？ [Clarity]
- [ ] API-004: HTTP 状态码使用是否规范 (200/201/400/401/403/404/409/500)？ [Consistency]

## 测试覆盖 (P2R 一票否决)
- [ ] API-005: 目录结构 - 是否*必须存在* `unit_tests/` 和 `API_tests/` 目录？ [Coverage]
- [ ] API-006: API 测试要求 - API 测试是否*真实调用接口*并在终端打印返回码和 message？ [Coverage]
- [ ] API-007: 测试路径 - 是否覆盖所有 API 端点，并包含异常路径 (401/403/404/409)？ [Coverage]
- [ ] API-008: 自动化测试 - 是否提供了可一键执行的 `run_tests.sh` 及 `run_tests.bat` 脚本？ [Completeness]

## 文档
- [ ] API-009: README 是否包含启动说明？ [Completeness]
- [ ] API-010: API 文档 (Swagger/ReDoc) 是否可访问？ [Completeness]
```

### Step 5: 生成开源合规检查清单

输出 `docs/specs/checklists/opensource.md`：

```markdown
# 开源合规检查清单

## 必备文件
- [ ] OSS-001: 是否存在 LICENSE 文件？ [Completeness]
- [ ] OSS-002: LICENSE 内容是否与 README 声明一致？ [Consistency]
- [ ] OSS-003: 是否存在 .gitignore 文件？ [Completeness]
- [ ] OSS-004: .gitignore 是否覆盖 __pycache__/node_modules/venv/.env 等？ [Coverage]

## 配置安全与隔离 (P2R 一票否决)
- [ ] OSS-005: 宿主依赖 - 容器内的服务是否*没有*尝试连接宿主机的数据库/Redis等？ [Coverage]
- [ ] OSS-006: 端口暴露 - docker-compose.yml 中是否显式暴露了服务端口？ [Completeness]
- [ ] OSS-007: README 声称的端口是否与实际上 docker-compose 暴露的端口完全一致？ [Consistency]
- [ ] OSS-008: 是否提供 .env.example 而非真实 .env？ [Clarity]
- [ ] OSS-009: 配置文件中是否无真实密钥/密码？ [Coverage]
- [ ] OSS-010: Docker 配置是否使用环境变量而非硬编码？ [Clarity]

## 文档完整性
- [ ] OSS-008: README 是否包含项目简介和功能列表？ [Completeness]
- [ ] OSS-009: 是否包含安装/启动/测试说明？ [Completeness]
- [ ] OSS-010: 是否包含 requirements.txt / package.json 等依赖声明？ [Completeness]
- [ ] OSS-011: 依赖版本是否锁定（避免纯 >= 约束）？ [Clarity]
```

### Step 6: 自动执行检查（要求使用子代理）

**强制要求**：拉起 `security-reviewer`（安全审计代理）主导执行安全及合规检查清单的校验。执行前必须先读取 `skills/security-reviewer/SKILL.md`。确保安全底线在代码合并前满足要求（"Before commits" 原则）。

对每个检查清单逐条检查：

1. **静态扫描代码**：通过文件内容和目录结构验证
2. **标记结果**：通过 → `[x]`，未通过 → `[ ]` 并附原因
3. **生成汇总**：

```markdown
# 检查清单执行汇总

| 清单 | 总项 | 通过 | 未通过 | 状态 |
|------|------|------|--------|------|
| code_quality.md | 8 | 8 | 0 | ✅ PASS |
| security.md | 17 | 14 | 3 | ⚠️ WARN |
| api.md | 10 | 9 | 1 | ⚠️ WARN |
| opensource.md | 14 | 11 | 3 | ⚠️ WARN |

## 未通过项汇总
| 编号 | 问题 | 影响 | 修复建议 |
|------|------|------|---------|
```

### Step 7: 自动修复未通过项

对未通过的检查项尝试自动修复：

**可自动修复**：
- 缺少 LICENSE 文件 → 根据 README 声明生成
- 缺少 .gitignore → 根据技术栈生成
- Docker 硬编码密码 → 改为环境变量引用
- CORS 全开放 → 收紧为配置化

**需记录**：
- 复杂逻辑问题 → 记录到 `questions.md`
- 需要用户决策的 → 标记为建议

修复后重新执行 Step 6 验证（最多 2 轮）。

## 完成条件

当以下全部满足时，Phase 2.5 完成：
- 所有适用的检查清单已生成并执行
- 检查清单汇总报告已输出
- 可自动修复的项已修复
- 未修复项已记录到 `questions.md`

输出 `CHECKLIST_COMPLETE` 标记完成。

## 跳过条件

当传入 `--skip-checklist` 参数时，跳过本 Phase，直接进入 Phase 3。
