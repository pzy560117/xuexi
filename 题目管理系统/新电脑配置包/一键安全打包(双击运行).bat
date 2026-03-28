@echo off
:: Set code page to UTF-8
chcp 65001 >nul
title 题目管理系统 - 一键打包发送工具

echo =============================================
echo   准备启动安全打包脚本...
echo =============================================
echo.

:: Automatically run the PowerShell script bypassing execution policies
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0package_for_new_pc.ps1'"

echo.
pause
