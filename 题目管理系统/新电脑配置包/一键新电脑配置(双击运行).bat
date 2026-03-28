@echo off
:: Set code page to UTF-8
chcp 65001 >nul
title Claude Code 自动化流水线 - 一键配置

echo =============================================
echo   准备启动配置脚本...
echo =============================================
echo.

:: Automatically run the PowerShell script bypassing execution policies
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0setup_env.ps1'"

echo.
pause
