@echo off
setlocal
cd /d "%~dp0"
title Windhawk Noto Sans CJK Uninstaller

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Mod.ps1"
if %errorlevel% neq 0 (
    echo.
    echo =================================================================
    echo   [!] Uninstaller encountered an issue [Exit Code: %errorlevel%]
    echo   Please right-click "Uninstall-Mod.bat" and select:
    echo   "Run as administrator"
    echo =================================================================
    echo.
    pause
)
