<#
.SYNOPSIS
    微調 Windows 11 現代 WinUI 3 (檔案總管路徑列、命令列、搜尋列) 的文字大小與份量感。
.DESCRIPTION
    修改 HKCU:\SOFTWARE\Microsoft\Accessibility\TextScaleFactor
    預設設為 110 (即 110%)，使細體文字的筆畫加粗加深，與上方標籤頁粗體更協調。
#>

param(
    [ValidateRange(100, 225)]
    [int]$Scale = 110
)

$ErrorActionPreference = "Continue"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Windows 11 UI 文字縮放與份量感調節工具" -ForegroundColor Cyan
Write-Host "  目標縮放比例: $Scale%" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. 寫入使用者層級註冊表 (無需系統管理員權限)
$accessKey = "HKCU:\SOFTWARE\Microsoft\Accessibility"
if (-not (Test-Path $accessKey)) {
    New-Item -Path $accessKey -Force | Out-Null
}

if ($Scale -eq 100) {
    Remove-ItemProperty -Path $accessKey -Name "TextScaleFactor" -ErrorAction SilentlyContinue
    Write-Host "  -> 已還原文字大小為系統預設 (100%)" -ForegroundColor Green
} else {
    Set-ItemProperty -Path $accessKey -Name "TextScaleFactor" -Value $Scale -Type DWord
    Write-Host "  -> 已將 TextScaleFactor 設定為 $Scale%" -ForegroundColor Green
}

# 2. 廣播系統設定變更 (WM_SETTINGCHANGE)
$cs = @'
using System;
using System.Runtime.InteropServices;
public class SettingBroadcaster {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    public static void Notify() {
        UIntPtr res;
        SendMessageTimeout((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "Environment", 2, 5000, out res);
        SendMessageTimeout((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "Accessibility", 2, 5000, out res);
    }
}
'@
Add-Type -TypeDefinition $cs -ErrorAction SilentlyContinue
[SettingBroadcaster]::Notify()

# 3. 重新啟動檔案總管即時刷新
Write-Host "  -> 正在重新啟動檔案總管以套用新字型大小..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  設定成功！已立即套用至檔案總管 (路徑列、命令列、搜尋列)。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
