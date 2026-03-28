# Superpowers-P2R 运行机制 & 新电脑配置指南

更新时间：2026-03-28

## 一、运行方式

```
手动启动 claude → 粘贴需求提示词 → CLAUDE.md 规则自动触发 → /superpowers:prompt2repo 全流程执行
```

**自动触发原理**：`~/.claude/CLAUDE.md` 配置了强制触发规则——识别到业务需求输入后，自动写入 `prompt.md` → 生成 TASK-ID → 执行 `/superpowers:prompt2repo`，无需任何外部脚本。

## 二、5 阶段流水线

| Phase | 名称 | 输出 |
|:---:|:---|:---|
| 0 | Prompt Parser | `docs/designs/requirement-analysis.md` |
| 1 | Writing Plans | BDD 规格 + 架构设计 + 任务拆分 |
| 2 | Executing Plans (Ralph-Loop) | 逐任务测试先行 → 实现 → 验证 |
| 3 | Self Review | 6 维度审查 + 安全审查 + 自动修复 |
| 4 | Delivery Packager | `TASK-{ID}/` 标准交付包 |

**Ralph-Loop 机制**：`stop-hook.sh` 拦截 Claude 退出 → 注入 Prompt 继续执行 → 直到输出 `<promise>DELIVERY_COMPLETE</promise>` 才终止。

## 三、新电脑配置（5 步）

### Step 1: 安装基础工具

- **Claude Code CLI**：下载 `claude.exe` 并安装
- **Git for Windows**：安装后确保 `D:\Program Files\Git\bin` 在 PATH 中

### Step 2: 设置环境变量

```powershell
[Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', 'D:\Program Files\Git\bin\bash.exe', 'User')
```

> ⚠️  必须指向 `bin\bash.exe`，不是 `git-bash.exe`。

### Step 3: 复制项目目录

将 `题目管理系统` 目录复制到新电脑，核心是以下两部分：

```
题目管理系统/
├── .claude-plugin/
│   └── marketplace.json      # 本地 marketplace 注册
└── superpowers-p2r/           # 插件核心代码
    ├── .claude-plugin/plugin.json
    ├── hooks/stop-hook.sh
    ├── scripts/setup-superpower-loop.sh
    └── skills/               # 15 个 skill 目录
```

### Step 4: 配置 Claude 全局文件

复制以下 2 个文件到 `C:\Users\{用户名}\.claude\`：

#### 4.1 settings.json

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "你的API密钥",
    "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
    "ANTHROPIC_MODEL": "MiniMax-M2.7-highspeed",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7-highspeed",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.7-highspeed",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.7-highspeed",
    "API_TIMEOUT_MS": "600000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "enabledPlugins": {
    "superpowers@xuexi-local": true
  },
  "extraKnownMarketplaces": {
    "xuexi-local": {
      "source": {
        "source": "directory",
        "path": "修改为你的题目管理系统目录路径（双反斜杠）"
      }
    }
  },
  "skipDangerousModePermissionPrompt": true
}
```

> ⚠️  `path` 必须指向包含 `.claude-plugin/marketplace.json` 的目录，路径使用 `\\` 双反斜杠。新电脑路径不同时**必须修改**。

#### 4.2 CLAUDE.md

复制现有的 `~\.claude\CLAUDE.md` 到新电脑同路径。该文件包含 Prompt2Repo 自动模式触发规则：

- 识别到"业务需求/功能需求/题目描述"时，直接进入自动流程
- 自动写入 `prompt.md` + 生成 `TASK-ID` + 执行 `/superpowers:prompt2repo`
- 禁止弹出选择菜单阻塞用户

### Step 5: 验证

```powershell
# 检查环境变量
[Environment]::GetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', 'User')
# 预期: D:\Program Files\Git\bin\bash.exe

# 检查插件
claude plugin list --json
# 预期: superpowers@xuexi-local → enabled: true
```

验证通过后，直接运行 `claude`，粘贴需求即可自动执行全流程。

## 四、迁移清单

| # | 项目 | 必需 |
|:--|:---|:---:|
| 1 | Claude Code CLI + Git for Windows | ✅ |
| 2 | `CLAUDE_CODE_GIT_BASH_PATH` 环境变量 | ✅ |
| 3 | 项目目录（含 `superpowers-p2r/` + `.claude-plugin/`） | ✅ |
| 4 | `~\.claude\settings.json`（**修改 marketplace 路径**） | ✅ |
| 5 | `~\.claude\CLAUDE.md` | ✅ |
