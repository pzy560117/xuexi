param (
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 功能：执行 Claude CLI 命令并在失败时抛出明确错误，避免静默失败。
function Invoke-ClaudeCli {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    & claude @Arguments
    $exitCode = $LASTEXITCODE
    if ((-not $AllowFailure) -and $exitCode -ne 0) {
        throw "Claude CLI 执行失败: claude $($Arguments -join ' ') (exit=$exitCode)"
    }
}

# 功能：校验插件是否已启用，确保 superpowers@xuexi-local 在目标电脑可直接使用。
function Test-PluginEnabled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PluginId
    )

    $pluginListRaw = & claude plugin list --json
    if ($LASTEXITCODE -ne 0) {
        throw "读取插件列表失败: claude plugin list --json"
    }

    $pluginList = $pluginListRaw | ConvertFrom-Json
    $target = $pluginList | Where-Object { $_.id -eq $PluginId } | Select-Object -First 1
    if (-not $target) {
        return $false
    }
    return [bool]$target.enabled
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  💻 Claude Code 自动化流水线 - 一键配置脚本" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# 1. 获取当前项目绝对路径 (假设在 新电脑配置包 目录执行)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectDir = (Resolve-Path "$scriptDir\..").Path # 回退到上一级的 `题目管理系统`
Write-Host "[1/5] 正在检测项目路径..."
Write-Host "      -> 识别到项目根目录: $projectDir" -ForegroundColor Green

# 2. 设置 Git Bash 环境变量
Write-Host "[2/5] 配置 Git Bash 环境变量..."
$gitBashPathC = "C:\Program Files\Git\bin\bash.exe"
$gitBashPathD = "D:\Program Files\Git\bin\bash.exe"
$gitBashPath = ""

if (Test-Path $gitBashPathC) {
    $gitBashPath = $gitBashPathC
} elseif (Test-Path $gitBashPathD) {
    $gitBashPath = $gitBashPathD
} else {
    Write-Host "      [警告] 未在 C 盘或 D 盘默认路径找到 Git Bash。" -ForegroundColor Yellow
    $userInput = Read-Host "      请输入真实的 bash.exe 绝对路径 (例如 C:\Program Files\Git\bin\bash.exe)"
    if (Test-Path $userInput) {
        $gitBashPath = $userInput
    } else {
        Write-Host "      [错误] 无效的路径，脚本退出。" -ForegroundColor Red
        exit 1
    }
}

try {
    [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $gitBashPath, 'User')
    Write-Host "      -> 已全局注入环境变量: CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath" -ForegroundColor Green
} catch {
    Write-Host "      [错误] 设置环境变量失败！可能是权限不足。" -ForegroundColor Red
}

# 3. 准备 ~/.claude 目录
Write-Host "[3/5] 部署全局配置 (CLAUDE.md)..."
$claudeDir = Join-Path $env:USERPROFILE "\.claude"
if (-Not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    Write-Host "      -> 创建了 ~/.claude 目录" -ForegroundColor DarkGray
}

$sourceClaudeMd = Join-Path $scriptDir "\.claude\CLAUDE.md"
$targetClaudeMd = Join-Path $claudeDir "CLAUDE.md"
if (Test-Path $sourceClaudeMd) {
    Copy-Item -Path $sourceClaudeMd -Destination $targetClaudeMd -Force
    Write-Host "      -> 已挂载全景守护规则: ~/.claude/CLAUDE.md" -ForegroundColor Green
} else {
    Write-Host "      [错误] 缺失配置源: $sourceClaudeMd" -ForegroundColor Red
}

# 4. 动态写入 settings.json
Write-Host "[4/5] 注入底层驱动与模型配置 (settings.json)..."
$sourceSettings = Join-Path $scriptDir "\.claude\settings.json"
$targetSettings = Join-Path $claudeDir "settings.json"

if (Test-Path $sourceSettings) {
    # 如果目标已经有 settings.json 并且没有加 -Force，提示一下
    if ((Test-Path $targetSettings) -and (-not $Force)) {
        $confirm = Read-Host "      [提示] $targetSettings 已经存在，是否覆盖？ (y/n)"
        if ($confirm -ne 'y') {
            Write-Host "      -> [跳过] 用户取消覆盖 settings.json" -ForegroundColor DarkGray
        } else {
            $Force = $true
        }
    } else {
        $Force = $true
    }

    if ($Force) {
        $settingsJson = Get-Content -Raw -Path $sourceSettings | ConvertFrom-Json
        
        # 动态将绝对路径填入 xuexi-local
        if ($settingsJson.extraKnownMarketplaces.'xuexi-local') {
            $settingsJson.extraKnownMarketplaces.'xuexi-local'.source.path = $projectDir
            Write-Host "      -> 自动更新 marketplace (xuexi-local) 路径为当前项目" -ForegroundColor Green
        }

        # 强制确保 superpowers@xuexi-local 在 settings 中为启用状态
        if (-not $settingsJson.enabledPlugins) {
            $settingsJson | Add-Member -MemberType NoteProperty -Name enabledPlugins -Value @{}
        }
        $settingsJson.enabledPlugins.'superpowers@xuexi-local' = $true

        # 转回 JSON 并使用格式化
        $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $targetSettings -Encoding UTF8
        Write-Host "      -> 危险权限屏蔽机制已开启，插件挂载完成！" -ForegroundColor Green
    }
} else {
    Write-Host "      [错误] 缺失配置源: $sourceSettings" -ForegroundColor Red
}

# 5. 用官方 CLI 绑定 marketplace 并安装插件（关键步骤，保证跨电脑可用）
Write-Host "[5/5] 注册本地 marketplace 并安装 superpowers 插件..."
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "      [错误] 未找到 claude 命令，请先安装 Claude Code CLI。" -ForegroundColor Red
    exit 1
}

try {
    # 基于当前项目根目录重新声明 marketplace，保证路径与新电脑实际目录一致。
    Invoke-ClaudeCli -Arguments @("plugin", "marketplace", "add", $projectDir)

    # 安装并确保启用目标插件
    Invoke-ClaudeCli -Arguments @("plugin", "install", "superpowers@xuexi-local")
    if (-not (Test-PluginEnabled -PluginId "superpowers@xuexi-local")) {
        Invoke-ClaudeCli -Arguments @("plugin", "enable", "superpowers@xuexi-local")
    }

    if (Test-PluginEnabled -PluginId "superpowers@xuexi-local") {
        Write-Host "      -> superpowers@xuexi-local 已安装并启用" -ForegroundColor Green
    } else {
        throw "插件 superpowers@xuexi-local 未启用，请手动检查 claude plugin list --json"
    }
} catch {
    Write-Host "      [错误] 插件自动配置失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🚀 配置完成！系统已装备超级流水线。后续操作：" -ForegroundColor Cyan
Write-Host "  1. 重新打开一个 Command Prompt/PowerShell 窗口（刷新环境变量）"
Write-Host "  2. 运行指令检查插件状态:   claude plugin list --json"
Write-Host "     (应看到 superpowers@xuexi-local 且 enabled=true)"
Write-Host '  3. 可选验证命令: claude --print "/superpowers:prompt2repo --help"'
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
