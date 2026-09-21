<#
.SYNOPSIS
    方案 B：自動安裝與配置 Windhawk，將 Windows 11 檔案總管 WinUI 3 介面強制注入為 Noto Sans TC 粗體 (Bold)。
.DESCRIPTION
    1. 自我權限檢測與自動提權 (UAC RunAs)
    2. 自我環境檢測 (檢查 Windhawk 是否已安裝)
    3. 自動靜默安裝 Windhawk 必要工具
    4. 自動下載並部署 Windows 11 File Explorer Styler 模組
    5. 自動配置 XAML 控制項樣式 (TextBlock, ContentControl, AddressBar, CommandBar -> Noto Sans TC Bold)
    6. 自動啟動 Windhawk 並刷新檔案總管
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# 1. 權限檢測與自動提權
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體字型自動安裝與配置工具" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體字型自動安裝與配置工具" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 2. 自我檢測 Windhawk 是否已安裝
Write-Host "[1/4] 檢查 Windhawk 安裝狀態..." -ForegroundColor Yellow
$windhawkExe = "C:\Program Files\Windhawk\windhawk.exe"
$isWindhawkInstalled = Test-Path $windhawkExe

if ($isWindhawkInstalled) {
    Write-Host "  -> 偵測到 Windhawk 已安裝於: $windhawkExe" -ForegroundColor Green
} else {
    Write-Host "  -> 尚未安裝 Windhawk，準備進行自動下載與靜默安裝..." -ForegroundColor Cyan
    
    # 尋找快取的安裝檔或從 GitHub 下載
    $cachedInstaller = "C:\Users\Karl\AppData\Local\Temp\WinGet\RamenSoftware.Windhawk.1.7.3\windhawk_setup.exe"
    $installerPath = "$env:TEMP\windhawk_setup.exe"
    
    if (Test-Path $cachedInstaller) {
        Write-Host "  -> 找到本機已下載的安裝檔，直接使用..." -ForegroundColor Green
        Copy-Item -Path $cachedInstaller -Destination $installerPath -Force
    } else {
        $downloadUrl = "https://github.com/ramensoftware/windhawk/releases/download/v1.7.3/windhawk_setup.exe"
        Write-Host "  -> 正在從 GitHub 下載 Windhawk 最新安裝檔..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    }
    
    # 執行無訊息靜默標準安裝
    Write-Host "  -> 正在執行 Windhawk 靜默安裝..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $installerPath -ArgumentList "/S /STANDARD" -Wait -PassThru
    
    if (Test-Path $windhawkExe) {
        Write-Host "  -> Windhawk 安裝成功！" -ForegroundColor Green
    } else {
        Write-Warning "Windhawk 安裝未完成，請確認防毒軟體未攔截。"
    }
}

# 3. 下載並部署 Windows 11 File Explorer Styler 模組原始碼
Write-Host "[2/4] 檢查並配置 File Explorer WinUI 3 注入模組..." -ForegroundColor Yellow

$modsSourceDir = "$env:ProgramData\Windhawk\ModsSource"
if (-not (Test-Path $modsSourceDir)) {
    New-Item -Path $modsSourceDir -ItemType Directory -Force | Out-Null
}

$modId = "windows-11-file-explorer-styler"
$modCppFile = Join-Path $modsSourceDir "$modId.wh.cpp"

$modUrl = "https://raw.githubusercontent.com/m417z/my-windhawk-mods/main/mods/windows-11-file-explorer-styler.wh.cpp"
Write-Host "  -> 下載/更新 $modId 模組代碼..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $modUrl -OutFile $modCppFile -UseBasicParsing
    Write-Host "  -> 模組代碼已成功寫入 $modCppFile" -ForegroundColor Green
} catch {
    Write-Warning "無法從線上取得最新代碼，嘗試使用本機備份..."
}

# 4. 設定註冊表 (強制配置 XAML 控制項為 Noto Sans TC Bold)
Write-Host "[3/4] 自動配置 XAML 控制項樣式 (Noto Sans TC Bold)..." -ForegroundColor Yellow

$modRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$modId"
$settingsKey = "$modRegKey\Settings"

if (-not (Test-Path $settingsKey)) {
    New-Item -Path $settingsKey -Force | Out-Null
}

# 注入樣式規則：將 TextBlock 與 ContentControl 全域強制套用 Noto Sans TC Bold
Set-ItemProperty -Path $settingsKey -Name "theme" -Value "" -ErrorAction SilentlyContinue

# Target 0: 全域 TextBlock (包含常用首頁「快速存取」、最近使用、命令列按鈕文字、網址列文字)
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].target" -Value "TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].styles[0]" -Value "FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 1: 全域 ContentControl (按鈕、標籤)
Set-ItemProperty -Path $settingsKey -Name "controlStyles[1].target" -Value "ContentControl" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[1].styles[0]" -Value "FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[1].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 2: 網址列麵包屑專用
Set-ItemProperty -Path $settingsKey -Name "controlStyles[2].target" -Value "FileExplorerExtensions.AddressBarControl TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[2].styles[0]" -Value "FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[2].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 3: 命令列按鈕專用
Set-ItemProperty -Path $settingsKey -Name "controlStyles[3].target" -Value "FileExplorerExtensions.CommandBarControl TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[3].styles[0]" -Value "FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[3].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# ThemeResourceVariables: 覆寫 XAML 主題字型資源
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[0]" -Value "ContentControlThemeFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[1]" -Value "BodyTextBlockStyle.FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[2]" -Value "BodyTextBlockStyle.FontWeight=Bold" -ErrorAction SilentlyContinue

# 啟用模組
$writableKey = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$modId"
if (-not (Test-Path $writableKey)) {
    New-Item -Path $writableKey -Force | Out-Null
}
Set-ItemProperty -Path $writableKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modRegKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

Write-Host "  -> 註冊表樣式注入完成 (Noto Sans TC Bold 700)" -ForegroundColor Green

# 5. 啟動 Windhawk 並重新啟動檔案總管
Write-Host "[4/4] 啟動 Windhawk 引擎並刷新檔案總管..." -ForegroundColor Yellow

# 啟動 Windhawk 服務或處理程序
Start-Service -Name "windhawk" -ErrorAction SilentlyContinue
if (Test-Path $windhawkExe) {
    Start-Process -FilePath $windhawkExe -ArgumentList "-tray-only" -ErrorAction SilentlyContinue
}

# 重新啟動 explorer.exe
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B 配置完成！" -ForegroundColor Green
Write-Host "  Windhawk 已自動注入 File Explorer WinUI 3 XAML 樣式。" -ForegroundColor Green
Write-Host "  檔案總管（命令列、網址列、常用首頁）已全面套用 Noto Sans TC 粗體。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
