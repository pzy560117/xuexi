---
name: delivery-packager
description: "Prompt2Repo Phase 4: 交付物目录规范化、清理缓存文件、生成 metadata.json，并在打包阶段执行静态交付校验"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: []
---

# Delivery Packager — Prompt2Repo Phase 4

## Superpower Loop Integration

本 Skill 在 Prompt2Repo 主流程 Ralph-Loop 内运行，**禁止**二次启动 `setup-superpower-loop.sh`。

**CRITICAL**: 输出 `<promise>PACKAGE_COMPLETE</promise>` 时必须满足：
- `TASK-{ID}/` 目录结构符合交付规范
- 交付包不包含环境依赖、缓存和数据库文件
- `metadata.json` 字段完整且有效
- 打包阶段静态检查通过（`validate_package.py` 如可用）

**ABSOLUTE LAST OUTPUT RULE**: Promise 标签必须是回复的**最后一行**，后面不得有任何内容。

## Background Knowledge

- **MANDATORY**: 仅在前置阶段完成后执行打包：
  - `self-review` 已完成
  - `llm-test-iteration-1/2/3` 全部完成
  - `llm-triple-check-gate` 已通过
- **MANDATORY**: 交付目录必须使用 `repo/ + docs/ + sessions/ + metadata.json + prompt.md + questions.md`
- **MANDATORY**: `project_type` 必须写入 `metadata.json`，不得用目录名表达项目类型
- **PROHIBITED**: 不得把 `.tmp`、测试缓存、IDE 配置、AI 轨迹转换脚本打包进交付物

## 输入参数

- `--task-id`（必填）：题目 ID，格式 `TASK-XXXXXXXX-XXXXXX`

## 执行步骤

### Step 1: 创建标准交付结构

```text
TASK-{ID}/
├─ docs/
├─ repo/
├─ sessions/
├─ metadata.json
├─ prompt.md
└─ questions.md
```

### Step 2: 拷贝并清理 repo/

复制项目源码到 `TASK-{ID}/repo`，并排除以下内容：
- 环境依赖：`node_modules/.venv/venv/env/target/build/dist/vendor`
- 缓存目录：`.opencode/.codex/.vscode/.idea/.pytest_cache/.mypy_cache/__pycache__`
- 本地数据库：`*.db/*.sqlite/*.sqlite3`
- Git 与临时目录：`.git/.tmp/.backup`
- 轨迹转换脚本及本地工具脚本

### Step 3: 生成 metadata.json

从 `metadata.draft.json` 生成并补全 `TASK-{ID}/metadata.json`，最少包含：
- `project_type`
- `frontend_tech`
- `backend_tech`
- `database`
- `prompt_language`
- `docker_required`

### Step 4: 整理 docs/

将设计与规格文档合并整理到 `TASK-{ID}/docs/`：
- `design.md`（合并 requirement-analysis / architecture / bdd）
- `api-spec.md`（如适用）
- 其他交付所需文档

> 不要求复制 `.tmp` 下的旧门禁报告；这些由后续 post-package、artifact-truth-gate 与 delivery-checker 重新生成。

### Step 5: 复制 prompt 与问题记录

- 复制 `prompt.md` 到 `TASK-{ID}/prompt.md`
- 复制或生成 `TASK-{ID}/questions.md`

### Step 6: 处理 sessions/

- 创建 `TASK-{ID}/sessions/`
- 若可用，执行轨迹转换脚本生成 `trajectory*.json`
- 若不可用，记录到 `questions.md`

### Step 7: 执行打包阶段静态校验

优先执行：

```bash
python script/validate_package.py TASK-{ID}
```

若校验失败：
1. 修复结构或脏文件问题。
2. 重新执行校验。
3. 本阶段内循环直到通过。

## Exit Criteria

当以下全部满足时，Phase 4 完成：
- `TASK-{ID}/` 目录结构完整
- `repo/` 无依赖污染与缓存污染
- `metadata.json` 字段完整
- `validate_package.py` 校验通过（脚本可用时）

最后一行输出：
`<promise>PACKAGE_COMPLETE</promise>`

## References

- `../../skills/references/completion-promises.md`
- `../../script/validate_package.py`
