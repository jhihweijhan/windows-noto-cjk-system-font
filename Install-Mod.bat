@echo off
setlocal
cd /d "%~dp0"

:: Check Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo =================================================================
    echo   Windhawk Noto Sans CJK Font Mod Installer
    echo =================================================================
    echo   Requesting Administrator Privileges (UAC)...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c ""%~dpnx0""' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Mod.ps1"
pause
