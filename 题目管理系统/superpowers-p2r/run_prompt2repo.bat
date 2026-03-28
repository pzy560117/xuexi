@echo off
REM Prompt2Repo 一键入口脚本 (Windows CMD)
REM 用法: run_prompt2repo.bat <prompt文件路径> <TASK-ID>
REM 示例: run_prompt2repo.bat prompt.md TASK-20260328-ABC123

setlocal enabledelayedexpansion

REM 参数校验
if "%~1"=="" (
    echo [ERROR] 缺少必填参数
    echo.
    echo 用法: run_prompt2repo.bat ^<prompt文件路径^> ^<TASK-ID^>
    echo 示例: run_prompt2repo.bat prompt.md TASK-20260328-ABC123
    echo.
    echo 参数说明:
    echo   prompt文件路径  - Prompt 需求描述文件（如 prompt.md）
    echo   TASK-ID         - 题目 ID，用于交付包命名
    exit /b 1
)

set "PROMPT_FILE=%~1"
set "TASK_ID=%~2"

REM 检查 prompt 文件是否存在
if not exist "%PROMPT_FILE%" (
    echo [ERROR] Prompt 文件不存在: %PROMPT_FILE%
    exit /b 1
)

REM 检查 TASK_ID 是否提供
if "%TASK_ID%"=="" (
    echo [WARN] 未提供 TASK-ID，将仅执行 Phase 0-3（不打包）
    set "SKIP_PACKAGE=--skip-package"
) else (
    set "SKIP_PACKAGE="
)

echo ============================================================
echo  Prompt2Repo 全自动流水线
echo ============================================================
echo  Prompt 文件: %PROMPT_FILE%
echo  TASK ID:     %TASK_ID%
echo  时间:        %date% %time%
echo ============================================================
echo.

REM 检查 Claude Code 是否可用
where claude >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Claude Code CLI 未找到，请先安装 Claude Code
    echo   安装指南: https://docs.anthropic.com/claude-code/install
    exit /b 1
)

REM 复制 prompt 到项目根目录（如不在根目录）
if not "%PROMPT_FILE%"=="prompt.md" (
    copy /Y "%PROMPT_FILE%" "prompt.md" >nul
    echo [INFO] 已复制 %PROMPT_FILE% 到 prompt.md
)

REM 复制 CLAUDE.md 模板（如存在且项目根目录无 CLAUDE.md）
set "SCRIPT_DIR=%~dp0"
if not exist "CLAUDE.md" (
    if exist "%SCRIPT_DIR%CLAUDE.md.template" (
        copy /Y "%SCRIPT_DIR%CLAUDE.md.template" "CLAUDE.md" >nul
        echo [INFO] 已部署 CLAUDE.md 项目级配置
    )
)

echo.
echo [START] 启动 Prompt2Repo 流水线...
echo [INFO]  使用 /superpowers:prompt2repo 命令
echo.

REM 调用 Claude Code 执行流水线
if defined TASK_ID (
    if not "%TASK_ID%"=="" (
        claude --print "/superpowers:prompt2repo prompt.md --task-id %TASK_ID%"
    ) else (
        claude --print "/superpowers:prompt2repo prompt.md %SKIP_PACKAGE%"
    )
) else (
    claude --print "/superpowers:prompt2repo prompt.md %SKIP_PACKAGE%"
)

echo.
echo ============================================================
echo  Prompt2Repo 流水线执行完毕
echo ============================================================

endlocal
