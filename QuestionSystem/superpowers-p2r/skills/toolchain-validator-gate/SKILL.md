---
name: toolchain-validator-gate
description: "Prompt2Repo Phase 4.55: 工具链与验收脚本路径门禁。修复并确认 rg 可用性与 validate_package.py 路径后才允许进入最终交付证据门禁。"
argument-hint: [--task-id]
user-invocable: false
allowed-tools: ["Bash(*)"]
---

# Toolchain Validator Gate — Prompt2Repo Phase 4.55

## Superpower Loop Integration

本 Skill 在 Prompt2Repo Ralph-Loop 中运行，禁止二次启动 `setup-superpower-loop.sh`。

通过本阶段前必须生成：
- `.tmp/toolchain-validator-gate.md`
- `FINAL_VERDICT: PASS`
- `RG_AVAILABLE: PASS`
- `VALIDATE_PACKAGE_SCRIPT: PASS`

Promise 必须作为最后一行输出：
`<promise>TOOLCHAIN_VALIDATOR_COMPLETE</promise>`

## 执行步骤

### Step 1: 定位交付包

定位最新 `TASK-*` 目录，并找到：
- `TASK-*/repo`
- `TASK-*/docs`

### Step 2: 校验 rg 可用性（含 fallback）

按顺序检测：
1. `command -v rg`
2. `command -v rg.exe`
3. `where rg` / `where.exe rg`

若都不可用：
- 记录 `RG_AVAILABLE: FAIL`
- 立即修复（安装或切换 fallback 扫描器）

### Step 3: 校验 validate_package.py 路径

优先检查：
1. `${WORKSPACE}/script/validate_package.py`
2. `${WORKSPACE}/validate_package.py`
3. `${TASK_DIR}/script/validate_package.py`

若缺失：
- 记录 `VALIDATE_PACKAGE_SCRIPT: FAIL`
- 在当前阶段自动修复（补齐脚本或软链接/复制）

### Step 4: 输出门禁报告

写入 `.tmp/toolchain-validator-gate.md`，至少包含：

```markdown
# Toolchain Validator Gate Report
FINAL_VERDICT: PASS|FAIL
RG_AVAILABLE: PASS|FAIL
VALIDATE_PACKAGE_SCRIPT: PASS|FAIL
TASK_DIR: <path>
```

## Exit Criteria

- `.tmp/toolchain-validator-gate.md` 存在
- `FINAL_VERDICT: PASS`
- `RG_AVAILABLE: PASS`
- `VALIDATE_PACKAGE_SCRIPT: PASS`

最后一行输出：
`<promise>TOOLCHAIN_VALIDATOR_COMPLETE</promise>`
