@echo off
setlocal
cd /d "%~dp0"
title Font Rendering Test

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-FontRendering.ps1"
pause
