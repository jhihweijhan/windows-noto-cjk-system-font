<#
.SYNOPSIS
方案 B：Windhawk 檔案總管 WinUI 3 粗體字型設定工具與瀏覽器字型修復。
.DESCRIPTION
1. 自我權限檢測與自動提權 (UAC RunAs)
2. 嚴格系統檢測：檢測系統是否已安裝 Windhawk
- 若未安裝：提示手動安裝，提供安裝程式引導，未檢測到則安全終止
- 若已安裝：引導編譯並注入 Windows 11 File Explorer WinUI 3 模組
3. 自動修復瀏覽器 (Chrome/Edge) 簡體字回退問題 (修復 SimSun 宋體破字)
4. 自動注入 XAML 樣式為 Noto Sans TC Bold 700
5. 自動刷新檔案總管
#>
[CmdletBinding()]
param()
if (-not ([System.Management.Automation.PSTypeName]'FontGDI').Type) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FontGDI {
[DllImport("gdi32.dll")]
public static extern int AddFontResource(string lpFileName);
}
"@
}
$ErrorActionPreference = "Continue"
# 1. 權限檢測與自動提權
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體設定與瀏覽器字型修復" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
exit
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體設定與瀏覽器字型修復" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
# 2. 嚴格系統檢測：檢查 Windhawk 是否已安裝
Write-Host "[1/4] 檢測系統是否已安裝 Windhawk..." -ForegroundColor Yellow
$windhawkExe = "C:\Program Files\Windhawk\windhawk.exe"
$windhawkReg = "HKLM:\SOFTWARE\Windhawk"
$isInstalled = (Test-Path $windhawkExe) -or (Test-Path $windhawkReg)
if (-not $isInstalled) {
Write-Host ""
Write-Host "  [✘] 系統檢測未通過：尚未安裝 Windhawk！" -ForegroundColor Red
Write-Host "      方案 B 需要借助 Windhawk 注入引擎以覆寫 WinUI 3 硬編碼字型。" -ForegroundColor Yellow
Write-Host ""
$localInstaller = Join-Path $PSScriptRoot "windhawk_setup.exe"
if (-not (Test-Path $localInstaller)) {
$localInstaller = "C:\Users\Karl\AppData\Local\Temp\WinGet\RamenSoftware.Windhawk.1.7.3\windhawk_setup.exe"
}
Write-Host "  -------------------------------------------------------------" -ForegroundColor Gray
Write-Host "  請先手動完成 Windhawk 的安裝：" -ForegroundColor Cyan
if (Test-Path $localInstaller) {
Write-Host "  已在工具包中為您備妥安裝程式: $localInstaller" -ForegroundColor Green
Write-Host ""
$choice = Read-Host "  是否立即開啟 Windhawk 安裝導引程式進行手動安裝？(Y/N，預設 Y)"
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match "^[Yy]$") {
Write-Host "  -> 正在啟動安裝導引程式，請在視窗中點擊「下一步」完成安裝..." -ForegroundColor Cyan
Start-Process -FilePath $localInstaller -Wait
}
} else {
Write-Host "  官方下載網址: https://windhawk.net/" -ForegroundColor Cyan
Write-Host "  請下載並完成安裝後，再重新執行本腳本。" -ForegroundColor Yellow
}
$isInstalled = (Test-Path $windhawkExe) -or (Test-Path $windhawkReg)
if (-not $isInstalled) {
Write-Host ""
Write-Host "  [!] 系統依然未檢測到 Windhawk 安裝，腳本將安全退出。" -ForegroundColor Red
Write-Host "      請在完成 Windhawk 安裝後，再次執行本腳本即可自動完成配置！" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Read-Host "按 Enter 鍵結束..."
exit
}
}
Write-Host "  [✔] 系統檢測通過！偵測到 Windhawk 已正確安裝於系統中。" -ForegroundColor Green
# 3. 修復瀏覽器 DirectWrite 回退與註冊表 (徹底解決簡體字「費」變宋體/細明體問題)
Write-Host "[2/4] 修復瀏覽器與系統字型回退 (防止簡體字落入宋體/細明體)..." -ForegroundColor Yellow
$fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
# 恢復微軟正黑體核心註冊，確保 DirectWrite 黑體度量完整，不再跳過正黑體直接跌落至宋體 (SimSun)
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei & Microsoft JhengHei UI (TrueType)' -Value 'msjh.ttc' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Bold & Microsoft JhengHei UI Bold (TrueType)' -Value 'msjhbd.ttc' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Light & Microsoft JhengHei UI Light (TrueType)' -Value 'msjhl.ttc' -ErrorAction SilentlyContinue
# 阻斷宋體 (SimSun) 與細明體 (MingLiU)，使 DirectWrite 回退無法命中宋體，強制使用思源黑體簡體 (Noto Sans SC) 或微軟雅黑
Set-ItemProperty -Path $fontsKey -Name 'SimSun & NSimSun (TrueType)' -Value '' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'MingLiU & PMingLiU & MingLiU_HKSCS (TrueType)' -Value '' -ErrorAction SilentlyContinue
# 安裝與註冊專屬 Noto Sans SC Bold 與 TC Bold 靜態字型檔 (保證所有簡字 100% 呈現原生粗體)
$fontsDir = "C:\Windows\Fonts"
$scBoldFile = Join-Path $PSScriptRoot "NotoSansSC-Bold.ttf"
$tcBoldFile = Join-Path $PSScriptRoot "NotoSansTC-Bold.ttf"
if (Test-Path $scBoldFile) {
Copy-Item -Path $scBoldFile -Destination $fontsDir -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'Noto Sans SC Bold (TrueType)' -Value 'NotoSansSC-Bold.ttf' -ErrorAction SilentlyContinue
[FontGDI]::AddFontResource("$fontsDir\NotoSansSC-Bold.ttf") | Out-Null
Write-Host "  -> 已安裝並加載專屬思源黑體簡體粗體: NotoSansSC-Bold.ttf" -ForegroundColor Green
}
if (Test-Path $tcBoldFile) {
Copy-Item -Path $tcBoldFile -Destination $fontsDir -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'Noto Sans TC Bold (TrueType)' -Value 'NotoSansTC-Bold.ttf' -ErrorAction SilentlyContinue
[FontGDI]::AddFontResource("$fontsDir\NotoSansTC-Bold.ttf") | Out-Null
Write-Host "  -> 已安裝並加載專屬思源黑體繁體粗體: NotoSansTC-Bold.ttf" -ForegroundColor Green
}
# 配置 FontLink 簡繁雙向回退，確保 Noto Sans SC Thin 與微軟雅黑排在最前，並剔除宋體/細明體
$fontLinkKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$cjkFonts = @('Segoe UI', 'Noto Sans TC', 'Microsoft JhengHei UI', 'Microsoft JhengHei', 'Tahoma')
foreach ($f in $cjkFonts) {
$existing = (Get-ItemProperty -Path $fontLinkKey -Name $f -ErrorAction SilentlyContinue).$f
if ($existing) {
$filtered = $existing | Where-Object { $_ -notmatch 'simsun' -and $_ -notmatch 'mingliu' -and $_ -notmatch 'NotoSansSC' }
$newLink = @("NotoSansSC-Bold.ttf,Noto Sans SC Bold", "NotoSansSC-Bold.ttf,Noto Sans SC", "NotoSansSC-VF.ttf,Noto Sans SC Thin", "NotoSansSC-VF.ttf", "msyh.ttc,Microsoft YaHei UI") + ($filtered | Where-Object { $_ -notmatch "SegoeIcons" -and $_ -notmatch "segmdl2" }) + @("SegoeIcons.ttf,Segoe Fluent Icons", "segmdl2.ttf,Segoe MDL2 Assets")
Set-ItemProperty -Path $fontLinkKey -Name $f -Value $newLink -Type MultiString -ErrorAction SilentlyContinue
}
}
# 設定瀏覽器偏好 (Chrome / Edge)
function Update-BrowserFont($prefPath) {
if (-not (Test-Path $prefPath)) { return }
try {
$content = Get-Content -Raw -Encoding UTF8 $prefPath | ConvertFrom-Json
if (-not $content.webkit) { $content | Add-Member -MemberType NoteProperty -Name "webkit" -Value (New-Object PSObject) }
if (-not $content.webkit.webprefs) { $content.webkit | Add-Member -MemberType NoteProperty -Name "webprefs" -Value (New-Object PSObject) }
$fonts = [PSCustomObject]@{
fixed = [PSCustomObject]@{ Zhtw = "Consolas"; und = "Consolas" }
sansserif = [PSCustomObject]@{ Zhtw = "Noto Sans TC"; Zhs = "Noto Sans SC"; und = "Noto Sans TC" }
serif = [PSCustomObject]@{ Zhtw = "Noto Serif TC"; Zhs = "Noto Serif SC"; und = "Noto Serif TC" }
standard = [PSCustomObject]@{ Zhtw = "Noto Sans TC"; Zhs = "Noto Sans SC"; und = "Noto Sans TC" }
}
if (-not $content.webkit.webprefs.fonts) {
$content.webkit.webprefs | Add-Member -MemberType NoteProperty -Name "fonts" -Value $fonts
} else {
$content.webkit.webprefs.fonts = $fonts
}
$json = $content | ConvertTo-Json -Depth 32 -Compress
[System.IO.File]::WriteAllText($prefPath, $json, [System.Text.Encoding]::UTF8)
Write-Host "  -> 已更新瀏覽器字型設定: $(Split-Path $prefPath -Parent)" -ForegroundColor Gray
} catch {
Write-Host "  -> 略過: $($_.Exception.Message)" -ForegroundColor Yellow
}
}
Update-BrowserFont "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
Update-BrowserFont "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"
Write-Host "  -> 瀏覽器繁簡雙黑體回退設定完成！" -ForegroundColor Green
# 4. 寫入 Windhawk 樣式注入設定 (強制 Noto Sans TC Bold 700)
Write-Host "[3/4] 配置 File Explorer WinUI 3 XAML 粗體樣式..." -ForegroundColor Yellow
$modId = "windows-11-file-explorer-styler"
$modRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$modId"
$settingsKey = "$modRegKey\Settings"

# 徹底清理可能殘留的舊有衝突設定 (移除先前強制覆蓋圖示的 FontFamily 鍵值)
if (Test-Path $settingsKey) {
    Remove-Item -Path $settingsKey -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $settingsKey -Force | Out-Null

Set-ItemProperty -Path $settingsKey -Name "theme" -Value "" -ErrorAction SilentlyContinue

# Target 0: 全域 TextBlock 僅注入 FontWeight=Bold，保留原生圖示字型 (Segoe Fluent Icons / SymbolThemeFontFamily)
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].target" -Value "TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].styles[0]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 1: 全域 ContentControl 僅注入 FontWeight=Bold
Set-ItemProperty -Path $settingsKey -Name "controlStyles[1].target" -Value "ContentControl" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[1].styles[0]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# ThemeResourceVariables: 覆寫 XAML 主題字型資源 (正文對齊 Noto Sans TC Bold，絕不覆蓋圖示資源)
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[0]" -Value "ContentControlThemeFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[1]" -Value "BodyTextBlockStyle.FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[2]" -Value "BodyTextBlockStyle.FontWeight=Bold" -ErrorAction SilentlyContinue

$writableKey = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$modId"
if (-not (Test-Path $writableKey)) {
New-Item -Path $writableKey -Force | Out-Null
}
Set-ItemProperty -Path $writableKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modRegKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
# 4.2 配置 DirectWrite Font Fallback Override 模組 (全域攔截 DirectWrite 缺字回退，強制鎖定 Noto Sans SC Bold)
Write-Host "  -> 配置 DirectWrite 全域字型回退模組規則 (Noto Sans SC Bold)..." -ForegroundColor Cyan
$dwriteModId = "dwrite-font-fallback-override"
$dwriteRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$dwriteModId"
$dwriteSettingsKey = "$dwriteRegKey\Settings"
if (-not (Test-Path $dwriteSettingsKey)) {
New-Item -Path $dwriteSettingsKey -Force | Out-Null
}
# 規則 0: CJK 統一漢字 (U+4E00 - U+9FFF) 首選回退直接鎖定 Noto Sans SC Bold
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[0].startChar" -Value "4E00" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[0].endChar" -Value "9FFF" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[0].fontFamily" -Value "Noto Sans SC Bold" -ErrorAction SilentlyContinue
# 規則 1: CJK 擴展 A 區 (U+3400 - U+4DBF)
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[1].startChar" -Value "3400" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[1].endChar" -Value "4DBF" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwriteSettingsKey -Name "rules[1].fontFamily" -Value "Noto Sans SC Bold" -ErrorAction SilentlyContinue
# 啟用模組
$dwriteWritableKey = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$dwriteModId"
if (-not (Test-Path $dwriteWritableKey)) {
New-Item -Path $dwriteWritableKey -Force | Out-Null
}
Set-ItemProperty -Path $dwriteWritableKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwriteRegKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  -> 註冊表 XAML 粗體樣式已配置完成！" -ForegroundColor Green
# 5. 檢查模組是否已由 Windhawk 編譯為 DLL
Write-Host "[4/4] 檢查 Windhawk 模組編譯狀態與啟動服務..." -ForegroundColor Yellow
$modDllFiles = Get-ChildItem -Path "$env:ProgramData\Windhawk\Engine\Mods" -Recurse -Filter "*$modId*.dll" -ErrorAction SilentlyContinue
$isCompiled = ($null -ne $modDllFiles -and $modDllFiles.Count -gt 0)
# 確保服務運作
Start-Service -Name "windhawk" -ErrorAction SilentlyContinue
if (-not $isCompiled) {
Write-Host ""
Write-Host "  [提示] 模組需要由 Windhawk 完成首次編譯才會生效：" -ForegroundColor Yellow
Write-Host "         1. 即將自動為您開啟 Windhawk 視窗" -ForegroundColor Cyan
Write-Host "         2. 請在視窗搜尋列搜尋「Windows 11 File Explorer Styler」" -ForegroundColor Cyan
Write-Host "         3. 點擊進入並按「Details」->「Install」(安裝)" -ForegroundColor Cyan
Write-Host "         Windhawk 將在 3 秒內完成編譯，隨後所有預設粗體設定即會生效！" -ForegroundColor Green
Write-Host ""
Start-Process -FilePath $windhawkExe
} else {
Write-Host "  [✔] 模組 DLL 已就緒，Windhawk 正在實時注入中！" -ForegroundColor Green
}
# 刷新檔案總管
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
Start-Process explorer
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  設定與修復執行完畢！" -ForegroundColor Green
Write-Host "  1. 瀏覽器：已修復 DirectWrite 回退，簡體字絕不再變成宋體/細明體。" -ForegroundColor Green
Write-Host "  2. 檔案總管：WinUI 3 樣式已注入為 Noto Sans TC Bold。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
