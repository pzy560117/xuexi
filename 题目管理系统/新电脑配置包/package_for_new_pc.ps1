Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  📦 题目管理系统 - 一键打包脚本" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 获取当前工作目录路径（假设在 新电脑配置包 执行）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectDir = (Resolve-Path "$scriptDir\..").Path

# 定义输出文件名
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipFileName = "题目管理系统_新电脑环境包_$timestamp.zip"
$tempStagingDir = Join-Path $scriptDir "temp_packaging"

Write-Host "1. 准备打包环境..."
if (Test-Path $tempStagingDir) {
    Remove-Item -Path $tempStagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempStagingDir | Out-Null

$targetProjectDir = Join-Path $tempStagingDir "题目管理系统"
New-Item -ItemType Directory -Path $targetProjectDir | Out-Null

Write-Host "2. 正在复制核心代码文件 (过滤临时文件)..."
# 排除的大文件夹，提升打包速度，去除环境依赖
$excludeList = @('.git', 'node_modules', '.venv', '__pycache__', '.claude\logs', '.agent')

# 复制项目主目录
Get-ChildItem -Path $projectDir -Directory | Where-Object { $excludeList -notcontains $_.Name -and $_.Name -ne "新电脑配置包" } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $targetProjectDir -Recurse -Force
}
# 复制根目录下的文件
Get-ChildItem -Path $projectDir -File | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $targetProjectDir -Force
}

Write-Host "3. 整合 新电脑环境配置包..."
$targetConfigDir = Join-Path $targetProjectDir "新电脑配置包"
New-Item -ItemType Directory -Path $targetConfigDir | Out-Null

Copy-Item -Path (Join-Path $scriptDir "*.md") -Destination $targetConfigDir -Force
Copy-Item -Path (Join-Path $scriptDir "*.ps1") -Destination $targetConfigDir -Force
Copy-Item -Path (Join-Path $scriptDir "*.bat") -Destination $targetConfigDir -Force
Copy-Item -Path (Join-Path $scriptDir ".claude") -Destination $targetConfigDir -Recurse -Force

Write-Host "4. 正在压缩归档为 ZIP..."
# 如果使用的是 PowerShell 5.1，自带 Compress-Archive
Compress-Archive -Path $tempStagingDir\* -DestinationPath (Join-Path $scriptDir $zipFileName) -Force

Write-Host "5. 清理临时环境..."
Remove-Item -Path $tempStagingDir -Recurse -Force

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "✅ 打包完成！" -ForegroundColor Green
Write-Host "归档文件: $zipFileName"
Write-Host "使用方法: 将 ZIP 发送到新电脑解压，进入 [题目管理系统/新电脑配置包] 目录，右键运行 setup_env.ps1 即可自动部署！"
Write-Host "=============================================" -ForegroundColor Cyan
