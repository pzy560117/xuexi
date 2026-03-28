# Prompt2Repo 一键入口脚本 (PowerShell)
# 用法: .\run_prompt2repo.ps1 -PromptFile prompt.md -TaskId TASK-20260328-ABC123

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Prompt 需求描述文件路径")]
    [string]$PromptFile,

    [Parameter(Position=1, HelpMessage="题目 ID，用于交付包命名")]
    [string]$TaskId = "",

    [Parameter(HelpMessage="跳过 Phase 3 自测审查")]
    [switch]$SkipReview,

    [Parameter(HelpMessage="跳过 Phase 4 交付打包")]
    [switch]$SkipPackage,

    [Parameter(HelpMessage="Ralph-Loop 最大迭代次数")]
    [int]$MaxIterations = 100
)

# 参数校验
if (-not (Test-Path $PromptFile)) {
    Write-Error "Prompt 文件不存在: $PromptFile"
    exit 1
}

# 检查 Claude Code CLI
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Error "Claude Code CLI 未找到，请先安装 Claude Code"
    Write-Host "安装指南: https://docs.anthropic.com/claude-code/install" -ForegroundColor Yellow
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Prompt2Repo 全自动流水线" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Prompt 文件: $PromptFile"
Write-Host " TASK ID:     $(if ($TaskId) { $TaskId } else { '(未指定)' })"
Write-Host " 最大迭代:    $MaxIterations"
Write-Host " 时间:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 复制 prompt 到项目根目录
if ($PromptFile -ne "prompt.md") {
    Copy-Item -Path $PromptFile -Destination "prompt.md" -Force
    Write-Host "[INFO] 已复制 $PromptFile 到 prompt.md" -ForegroundColor Green
}

# 部署 CLAUDE.md 模板
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path $scriptDir "CLAUDE.md.template"
if (-not (Test-Path "CLAUDE.md") -and (Test-Path $templatePath)) {
    Copy-Item -Path $templatePath -Destination "CLAUDE.md" -Force
    Write-Host "[INFO] 已部署 CLAUDE.md 项目级配置" -ForegroundColor Green
}

# 构建命令参数
$cmdArgs = "/superpowers:prompt2repo prompt.md"

if ($TaskId) {
    $cmdArgs += " --task-id $TaskId"
}
if ($SkipReview) {
    $cmdArgs += " --skip-review"
}
if ($SkipPackage -or -not $TaskId) {
    $cmdArgs += " --skip-package"
    if (-not $TaskId) {
        Write-Host "[WARN] 未提供 TASK-ID，将跳过交付打包" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[START] 启动 Prompt2Repo 流水线..." -ForegroundColor Green
Write-Host "[INFO]  命令: claude --print `"$cmdArgs`"" -ForegroundColor DarkGray
Write-Host ""

# 执行 Claude Code
& claude --print $cmdArgs

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Prompt2Repo 流水线执行完毕" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
