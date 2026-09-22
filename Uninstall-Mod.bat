@echo off
setlocal
cd /d "%~dp0"
title Windhawk Noto Sans CJK Uninstaller

echo =================================================================
echo   Windhawk 思源黑體模組解除安裝與還原工具
echo =================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Mod.ps1"
if %errorlevel% neq 0 (
    echo.
    echo =================================================================
    echo   [!] 若未取得管理員權限，請在 Uninstall-Mod.bat 按滑鼠右鍵選擇：
    echo       「以系統管理員身分執行」 (Run as administrator)
    echo =================================================================
    echo.
)
pause
