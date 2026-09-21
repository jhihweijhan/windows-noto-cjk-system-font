@echo off
setlocal
cd /d "%~dp0"
title 套用 Google 思源黑體 (Noto Sans TC/SC Bold) 系統字型

:: 檢查系統管理員權限，若無則請求 UAC
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [提示] 正在請求系統管理員權限...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin_notosans.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin_notosans.vbs"
    "%temp%\getadmin_notosans.vbs"
    del "%temp%\getadmin_notosans.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Apply-NotoSansFont.ps1" -Weight Bold
    echo.
    echo 請按任意鍵結束視窗...
    pause >nul
