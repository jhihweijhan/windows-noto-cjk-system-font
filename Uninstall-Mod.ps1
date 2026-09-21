<#
.SYNOPSIS
Windhawk 思源黑體模組一鍵解除安裝與預設字型還原工具
.DESCRIPTION
1. 自動提權 (UAC RunAs)
2. 停用並解除註冊 windows-noto-sans-cjk 模組
3. 清除 File Explorer Styler 中的自訂字型覆寫規則
4. 還原系統 FontLink 與字型回退設定
5. 重啟 Windhawk 與檔案總管以恢復 Windows 預設字型
#>
[CmdletBinding()]
param()

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  Windhawk 思源黑體模組解除安裝與還原工具" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Windhawk 思源黑體模組解除安裝與還原工具" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. 停用並移除 Windhawk 模組註冊
Write-Host "[1/4] 從 Windhawk 中移除 windows-noto-sans-cjk 模組..." -ForegroundColor Yellow
$uModReg = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-noto-sans-cjk"
if (Test-Path $uModReg) {
    Remove-Item -Path $uModReg -Recurse -Force -ErrorAction SilentlyContinue
}
$uWritable = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\windows-noto-sans-cjk"
if (Test-Path $uWritable) {
    Remove-Item -Path $uWritable -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  -> 已解除模組註冊！" -ForegroundColor Green

# 2. 清除 File Explorer Styler 中的字型覆寫
Write-Host "[2/4] 清除檔案總管自訂字型樣式..." -ForegroundColor Yellow
$stylerSettings = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-file-explorer-styler\Settings"
if (Test-Path $stylerSettings) {
    Remove-Item -Path $stylerSettings -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $stylerSettings -Force | Out-Null
    Set-ItemProperty -Path $stylerSettings -Name "theme" -Value "" -ErrorAction SilentlyContinue
}
Write-Host "  -> 檔案總管樣式已恢復預設！" -ForegroundColor Green

# 3. 還原系統字型與 FontLink
Write-Host "[3/4] 還原系統字型註冊與 FontLink 設定..." -ForegroundColor Yellow
$fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
Set-ItemProperty -Path $fontsKey -Name 'SimSun & NSimSun (TrueType)' -Value 'simsun.ttc' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'MingLiU & PMingLiU & MingLiU_HKSCS (TrueType)' -Value 'mingliu.ttc' -ErrorAction SilentlyContinue

$fontLinkKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$cjkFonts = @('Segoe UI', 'Noto Sans TC', 'Microsoft JhengHei UI', 'Microsoft JhengHei', 'Tahoma')
foreach ($f in $cjkFonts) {
    $existing = (Get-ItemProperty -Path $fontLinkKey -Name $f -ErrorAction SilentlyContinue).$f
    if ($existing) {
        $restored = $existing | Where-Object { $_ -notmatch 'NotoSansSC' }
        Set-ItemProperty -Path $fontLinkKey -Name $f -Value $restored -Type MultiString -ErrorAction SilentlyContinue
    }
}
Write-Host "  -> 字型鏈結已恢復！" -ForegroundColor Green

# 4. 重啟服務與檔案總管
Write-Host "[4/4] 重啟 Windhawk 服務與檔案總管..." -ForegroundColor Yellow
Restart-Service -Name "windhawk" -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  [SUCCESS] 解除安裝完成！全系統字型已完全恢復 Windows 官方預設狀態。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Read-Host "按 Enter 鍵結束..."
