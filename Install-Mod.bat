@echo off
setlocal
cd /d "%~dp0"
title Windhawk Noto Sans CJK Installer

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Mod.ps1"
if %errorlevel% neq 0 (
    echo.
    echo =================================================================
    echo   [!] Installer encountered an issue [Exit Code: %errorlevel%]
    echo   Please right-click "Install-Mod.bat" and select:
    echo   "Run as administrator"
    echo =================================================================
    echo.
    pause
)
