---
name: delivery-packager
description: "Prompt2Repo Phase 4: 交付物目录规范化、清理缓存文件、生成 metadata.json、运行 validate_package.py 验证"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Delivery Packager — Prompt2Repo Phase 4

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>PACKAGE_COMPLETE</promise>` 时必须遵守：
- `TASK-{ID}/` 目录结构符合规范
- `validate_package.py` 验证通过（如可用）
- 所有排除项已清理
- 最终检查清单全部通过

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

**核心概念**: 交付打包是“从开发环境到可提交产物”的转化过程，必须确保交付包干净、完整、可复现。

- **MANDATORY**: 排除所有环境依赖（node_modules/.venv 等）
- **MANDATORY**: 排除所有运行缓存（.opencode/.codex/.vscode 等）
- **MANDATORY**: 排除数据库文件（使用初始化脚本代替）
- **MANDATORY**: metadata.json 必须包含正确的 project_type 和技术栈信息
- **PROHIBITED**: 不得将 AI 轨迹转换脚本打包到产物中
- **PROHIBITED**: 不得将自测报告打包到产物中

## 概述

本 Skill 是 Prompt2Repo 流水线的打包阶段（由后续 Delivery Checker 执行最终自动验收）。将生成的项目按照交付规范打包为标准目录结构。

**前提条件**:
- Phase 3 自测审查通过（`.tmp/self-review-report.md` 存在且无阻塞问题）
- Phase 3.5 严格测试门禁通过（`.tmp/test-gate-report.md` 存在且无 FAIL）
- Phase 3.6 运行态冒烟通过（`.tmp/runtime-smoke-report.md` 存在且无 FAIL）
- Phase 3.7 稳定性循环通过（`.tmp/stability-loop-report.md` 存在且无 FAIL）
- Phase 3.8 覆盖率门禁通过（`.tmp/coverage-gate-report.md` 存在且无 FAIL）
- Phase 3.9 策略门禁通过（`.tmp/policy-gate-report.md` 存在且无 FAIL/WARN 可接受）

## 输入参数

- `--task-id`（必填）：题目 ID，格式 `TASK-XXXXXXXX-XXXXXX`，用于命名交付包

## 执行步骤

### Step 1: 创建交付目录结构（要求使用子代理）

**强制要求**：拉起并利用 `doc-updater`（文档更新代理，需读取 `skills/doc-updater/SKILL.md`）扫描最终产出，负责合并文档、生成元数据、规整说明文档及标准化输出。

```
TASK-{ID}/
├─ docs/                         # 文档产物
│  ├─ design.md                  # 设计文档（从 docs/designs/ 合并）
│  ├─ api-spec.md                # API 规格说明（如适用）
│  └─ ...                        # 其他文档产物
├─ repo/                         # 项目代码目录
│  └─ [项目文件...]              # 清理后的项目代码
├─ sessions/                     # 会话/过程记录目录
│  └─ trajectory.json            # AI 对话轨迹（需外部提供或转换）
├─ metadata.json                 # 项目元数据文件
├─ prompt.md                     # 原始 Prompt 文件
└─ questions.md                  # AI 生产过程中的问题记录
```

### Step 2: 复制项目代码到 repo/

将项目代码复制到 `repo/` 目录，**排除**以下内容：

**环境依赖（必须排除）**：
- `node_modules/`
- `.venv/` / `venv/` / `env/`
- `.net/`
- `__pycache__/`
- `*.pyc`
- `vendor/` (部分语言)
- `target/` (Java/Rust)
- `build/` / `dist/` (视情况)

**运行缓存（必须排除）**：
- `.opencode/`
- `.codex/`
- `.vscode/`
- `.idea/`
- `pytest_cache/`
- `.pytest_cache/`
- `.mypy_cache/`
- `.next/` (Next.js)
- `.nuxt/` (Nuxt.js)
- `.cache/`

**数据库文件（必须排除）**：
- `*.db` / `*.sqlite` / `*.sqlite3`
- 使用初始化脚本代替

**其他排除**：
- `.git/`
- `docs/designs/` (已迁移到 TASK-{ID}/docs/)
- `docs/plans/` (已迁移)
- `.tmp/`
- AI 轨迹转换脚本（不打包到产物中）

### Step 3: 生成 metadata.json

从 `metadata.draft.json` 和 `docs/designs/_meta.md` 合并生成：

```json
{
  "project_type": "fullstack",
  "frontend_tech": "react",
  "backend_tech": "node",
  "database": "postgresql"
}
```

**project_type 标准值**：
- `fullstack` / `full_stack`
- `pure_backend`
- `pure_frontend`
- `cross_platform_app`
- `mobile_app`

### Step 4: 合并设计文档到 docs/

将 `docs/designs/` 下的文档整理合并到 `TASK-{ID}/docs/`：
- `bdd-specs.md` → `docs/design.md`（合并）
- `architecture.md` → `docs/design.md`（合并）
- `requirement-analysis.md` → `docs/design.md`（合并）
- 如有 API 规格 → `docs/api-spec.md`
- 复制 `.tmp/test-gate-report.md` → `docs/test-gate-report.md`（若缺失视为阻塞项）
- 复制 `.tmp/runtime-smoke-report.md` → `docs/runtime-smoke-report.md`（若缺失视为阻塞项）
- 复制 `.tmp/stability-loop-report.md` → `docs/stability-loop-report.md`（若缺失视为阻塞项）
- 复制 `.tmp/coverage-gate-report.md` → `docs/coverage-gate-report.md`（若缺失视为阻塞项）
- 复制 `.tmp/policy-gate-report.md` → `docs/policy-gate-report.md`（若缺失视为阻塞项）

### Step 5: 复制 prompt.md

将原始 `prompt.md` 复制到 `TASK-{ID}/prompt.md`。

### Step 6: 处理 questions.md

将 `questions.md` 复制到 `TASK-{ID}/questions.md`。

如果 `questions.md` 不存在，创建模板：

```markdown
# Questions & Issues

## AI 生产过程中发现的问题

### 问题 1
- 描述: {...}
- 影响: {...}
- 处理方式: {...}

（如无问题，请说明"本次生产过程未发现显著问题"）
```

### Step 7: 创建 sessions/ 目录并生成 trajectory.json

创建 `TASK-{ID}/sessions/` 目录。

**自动生成 trajectory.json**（如工具可用）：

1. 检查 `script/merge_claude_subagents_trajectory.py` 是否存在
2. 如果存在，执行：
   ```bash
   python script/merge_claude_subagents_trajectory.py --output TASK-{ID}/sessions/trajectory.json
   ```
3. 如果不存在，检查 `script/convert_ai_session.py`：
   ```bash
   python script/convert_ai_session.py --output TASK-{ID}/sessions/trajectory.json
   ```
4. 如果两个脚本都不可用，记录到 `questions.md`：
   ```
   ### trajectory.json 未自动生成
   - **问题**: 未找到 merge_claude_subagents_trajectory.py 或 convert_ai_session.py
   - **影响**: sessions/ 目录为空，需手动生成 trajectory.json
   - **解决方式**: 做题完成后通过外部工具生成并放入 sessions/ 目录
   ```

> **注意**：trajectory.json 的生成依赖完整的 Claude Code 会话记录。如果在流水线执行期间脚本不可用或会话记录不完整，本阶段仅创建空目录并记录问题。

### Step 8: 清理和验证

1. **检查语言一致性**：
   - 如 Prompt 是英文，检查 repo/ 中的注释、日志、UI 是否全部英文
   - 发现中文则标记为问题

2. **检查敏感信息**：
   - 扫描代码中是否有硬编码的 API Key / Token / 密码
   - 检查 `.env` 文件是否应加入 `.gitignore`

3. **运行 validate_package.py**（如可用）：

```bash
python validate_package.py TASK-{ID}/
```

如发现问题，自动执行：
```bash
python validate_package.py TASK-{ID}/ --repair
```

### Step 9: 最终检查清单

逐条确认：

- [ ] `TASK-{ID}/repo/` 不包含 `node_modules` / `.venv` 等环境依赖
- [ ] `TASK-{ID}/repo/` 不包含 `.opencode` / `.codex` / `.vscode` 等缓存
- [ ] `TASK-{ID}/repo/` 不包含数据库文件
- [ ] `TASK-{ID}/repo/README.md` 包含启动和测试说明
- [ ] `TASK-{ID}/metadata.json` 存在且字段正确
- [ ] `TASK-{ID}/prompt.md` 是原始 Prompt（可修改版）
- [ ] `TASK-{ID}/questions.md` 存在
- [ ] `TASK-{ID}/sessions/` 目录存在

### Step 5: 复制 prompt.md

将原始 `prompt.md` 复制到 `TASK-{ID}/prompt.md`。

### Step 6: 处理 questions.md

将 `questions.md` 复制到 `TASK-{ID}/questions.md`。

如果 `questions.md` 不存在，创建模板：

```markdown
# Questions & Issues

## AI 生产过程中发现的问题

### 问题 1
- 描述: {...}
- 影响: {...}
- 处理方式: {...}

（如无问题，请说明"本次生产过程未发现显著问题"）
```

### Step 7: 创建 sessions/ 目录并生成 trajectory.json

创建 `TASK-{ID}/sessions/` 目录。

**自动生成 trajectory.json**（如工具可用）：

1. 检查 `script/merge_claude_subagents_trajectory.py` 是否存在
2. 如果存在，执行：
   ```bash
   python script/merge_claude_subagents_trajectory.py --output TASK-{ID}/sessions/trajectory.json
   ```
3. 如果不存在，检查 `script/convert_ai_session.py`：
   ```bash
   python script/convert_ai_session.py --output TASK-{ID}/sessions/trajectory.json
   ```
4. 如果两个脚本都不可用，记录到 `questions.md`：
   ```
   ### trajectory.json 未自动生成
   - **问题**: 未找到 merge_claude_subagents_trajectory.py 或 convert_ai_session.py
   - **影响**: sessions/ 目录为空，需手动生成 trajectory.json
   - **解决方式**: 做题完成后通过外部工具生成并放入 sessions/ 目录
   ```

> **注意**：trajectory.json 的生成依赖完整的 Claude Code 会话记录。如果在流水线执行期间脚本不可用或会话记录不完整，本阶段仅创建空目录并记录问题。

### Step 8: 清理和验证

1. **检查语言一致性**：
   - 如 Prompt 是英文，检查 repo/ 中的注释、日志、UI 是否全部英文
   - 发现中文则标记为问题

2. **检查敏感信息**：
   - 扫描代码中是否有硬编码的 API Key / Token / 密码
   - 检查 `.env` 文件是否应加入 `.gitignore`

3. **运行 validate_package.py**（如可用）：

```bash
python validate_package.py TASK-{ID}/
```

如发现问题，自动执行：
```bash
python validate_package.py TASK-{ID}/ --repair
```

### Step 9: 最终检查清单

逐条确认：

- [ ] `TASK-{ID}/repo/` 不包含 `node_modules` / `.venv` 等环境依赖
- [ ] `TASK-{ID}/repo/` 不包含 `.opencode` / `.codex` / `.vscode` 等缓存
- [ ] `TASK-{ID}/repo/` 不包含数据库文件
- [ ] `TASK-{ID}/repo/README.md` 包含启动和测试说明
- [ ] `TASK-{ID}/metadata.json` 存在且字段正确
- [ ] `TASK-{ID}/prompt.md` 是原始 Prompt（可修改版）
- [ ] `TASK-{ID}/questions.md` 存在
- [ ] `TASK-{ID}/sessions/` 目录存在
- [ ] `TASK-{ID}/docs/` 包含设计文档
- [ ] 不包含 AI 轨迹转换脚本
- [ ] 英文 Prompt 的产物无中文字符
- [ ] 自测报告不打包到产物中

## Exit Criteria

当以下全部满足时，Phase 4 完成：
- `TASK-{ID}/` 目录结构符合规范
- `validate_package.py` 验证通过（如可用）
- 所有排除项已清理
- 最终检查清单全部通过

输出 `<promise>PACKAGE_COMPLETE</promise>` 标记完成，且该标签必须是回复最后一行。

## References

- `../doc-updater/SKILL.md` - 文档更新子代理
- `../../skills/references/completion-promises.md` - Promise 设计规范
- `./scripts/validate_package.py` - 交付包验证脚本
