<#
.SYNOPSIS
思源黑體系統字型模組一鍵解除安裝與預設字型還原工具
.DESCRIPTION
1. 自動提權 (UAC RunAs)
2. 停用並解除註冊 windows-noto-sans-cjk 模組
3. 清除 File Explorer Styler 中的自訂字型覆寫規則
4. 還原 Windows 官方原生字型註冊 (msjh.ttc, SegUIVar.ttf, segoeui.ttf 等)
5. 還原系統 FontSubstitutes 與 FontLink 設定
6. 安全重整檔案總管以恢復 Windows 預設介面
#>
[CmdletBinding()]
param()

# 1. 權限檢測與自動提權
Set-Location -LiteralPath $PSScriptRoot
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  思源黑體系統字型解除安裝與還原工具" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    } catch {
        Write-Host "  [!] 未能取得系統管理員權限: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  請在 Uninstall-Mod.bat 上按滑鼠右鍵，選擇「以系統管理員身分執行」。" -ForegroundColor Yellow
        Read-Host "按 Enter 鍵結束..."
        exit 1
    }
    exit 0
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  思源黑體系統字型解除安裝與還原工具" -ForegroundColor Cyan
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
Write-Host "[3/4] 還原系統官方字型註冊、FontSubstitutes 與 FontLink 設定..." -ForegroundColor Yellow
$fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontRestores = @{
    'Microsoft JhengHei & Microsoft JhengHei UI (TrueType)'       = 'msjh.ttc'
    'Microsoft JhengHei Bold & Microsoft JhengHei UI Bold (TrueType)' = 'msjhbd.ttc'
    'Microsoft JhengHei Light & Microsoft JhengHei UI Light (TrueType)' = 'msjhl.ttc'
    'Segoe UI (TrueType)'                                         = 'segoeui.ttf'
    'Segoe UI Bold (TrueType)'                                    = 'segoeuib.ttf'
    'Segoe UI Semibold (TrueType)'                                = 'seguisb.ttf'
    'Segoe UI Light (TrueType)'                                   = 'segoeuil.ttf'
    'Segoe UI Semilight (TrueType)'                               = 'segoeuisl.ttf'
    'Segoe UI Variable (TrueType)'                                = 'SegUIVar.ttf'
    'SimSun & NSimSun (TrueType)'                                 = 'simsun.ttc'
    'MingLiU & PMingLiU & MingLiU_HKSCS (TrueType)'               = 'mingliu.ttc'
    'Noto Sans TC (TrueType)'                                     = 'NotoSansTC-VF.ttf'
    'Noto Sans SC (TrueType)'                                     = 'NotoSansSC-VF.ttf'
}
foreach ($kv in $fontRestores.GetEnumerator()) {
    Set-ItemProperty -Path $fontsKey -Name $kv.Key -Value $kv.Value -ErrorAction SilentlyContinue
}

$subKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
$removeSubs = @(
    'Microsoft JhengHei', 'Microsoft JhengHei UI', '微軟正黑體',
    'Segoe UI', 'Segoe UI Variable', 'Segoe UI Variable Text', 'Segoe UI Variable Display', 'Segoe UI Variable Small',
    'Segoe UI Variable Text Bold', 'Segoe UI Variable Display Bold', 'Segoe UI Variable Small Bold',
    'Segoe UI Variable Text Semibold', 'Segoe UI Variable Display Semibold', 'Segoe UI Variable Small Semibold',
    'SimSun', 'NSimSun', 'MingLiU', 'PMingLiU',
    'Microsoft JhengHei,0', 'Microsoft JhengHei UI,0', 'Microsoft JhengHei,136', 'Microsoft JhengHei UI,136',
    'Segoe UI,0', 'Segoe UI,136'
)
foreach ($s in $removeSubs) {
    Remove-ItemProperty -Path $subKey -Name $s -ErrorAction SilentlyContinue
}

$fontLinkKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$cjkFonts = @(
    'Segoe UI', 'Segoe UI Bold', 'Segoe UI Semibold', 'Segoe UI Light', 'Segoe UI Semilight',
    'Segoe UI Variable Text', 'Segoe UI Variable Text Bold', 'Segoe UI Variable Text Semibold',
    'Segoe UI Variable Display', 'Segoe UI Variable Display Bold', 'Segoe UI Variable Display Semib',
    'Segoe UI Variable Small', 'Segoe UI Variable Small Bold', 'Segoe UI Variable Small Semibol',
    'Microsoft JhengHei UI', 'Microsoft JhengHei UI Bold',
    'Microsoft JhengHei', 'Microsoft JhengHei Bold',
    'Noto Sans TC', 'Noto Sans TC Bold',
    'Tahoma', 'Arial'
)
foreach ($f in $cjkFonts) {
    $existing = (Get-ItemProperty -Path $fontLinkKey -Name $f -ErrorAction SilentlyContinue).$f
    if ($existing) {
        $restored = $existing | Where-Object { $_ -notmatch 'NotoSans' }
        Set-ItemProperty -Path $fontLinkKey -Name $f -Value $restored -Type MultiString -ErrorAction SilentlyContinue
    }
}
Write-Host "  -> 系統字型與鏈結已恢復為官方預設！" -ForegroundColor Green

# 4. 安全重啟檔案總管
Write-Host "[4/4] 安全重整檔案總管..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "explorer.exe" -ErrorAction SilentlyContinue | Out-Null
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  [SUCCESS] 解除安裝完成！全系統字型已完全恢復 Windows 官方預設狀態。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Read-Host "按 Enter 鍵結束..."
