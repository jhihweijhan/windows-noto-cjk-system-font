@echo off
setlocal
cd /d "%~dp0"
title Windhawk Noto Sans CJK Uninstaller

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo =================================================================
    echo   Windhawk Noto Sans CJK Uninstaller
    echo =================================================================
    echo   Requesting Administrator Privileges...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin_%~n0.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c cd /d %~dp0 ^&^& %~f0", "", "runas", 1 >> "%temp%\getadmin_%~n0.vbs"
    "%temp%\getadmin_%~n0.vbs"
    del "%temp%\getadmin_%~n0.vbs" 2>nul
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Mod.ps1"
pause
