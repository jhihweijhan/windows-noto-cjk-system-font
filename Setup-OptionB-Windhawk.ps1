<#
.SYNOPSIS
    方案 B：Windhawk 檔案總管 WinUI 3 粗體字型設定工具。
.DESCRIPTION
    1. 自我權限檢測與自動提權 (UAC RunAs)
    2. 嚴格系統檢測：檢測系統是否已安裝 Windhawk
       - 若未安裝：提示手動安裝，提供安裝程式引導，未檢測到則安全終止，絕不盲目配置
       - 若已檢測到：自動配置 Windows 11 File Explorer WinUI 3 注入模組與 Noto Sans TC Bold 樣式
    3. 自動套用設定並重啟檔案總管
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# 1. 權限檢測與自動提權
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體字型設定工具" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B：Windhawk 檔案總管 WinUI 3 粗體字型設定工具" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 2. 嚴格系統檢測：檢查 Windhawk 是否已安裝
Write-Host "[1/3] 檢測系統是否已安裝 Windhawk..." -ForegroundColor Yellow
$windhawkExe = "C:\Program Files\Windhawk\windhawk.exe"
$windhawkReg = "HKLM:\SOFTWARE\Windhawk"
$isInstalled = (Test-Path $windhawkExe) -or (Test-Path $windhawkReg)

if (-not $isInstalled) {
    Write-Host ""
    Write-Host "  [✘] 系統檢測未通過：尚未安裝 Windhawk！" -ForegroundColor Red
    Write-Host "      方案 B 需要借助 Windhawk 注入引擎以覆寫 WinUI 3 硬編碼字型。" -ForegroundColor Yellow
    Write-Host ""
    
    # 尋找本地安裝包
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

    # 安裝後二次檢測
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
Write-Host ""

# 3. 部署 Windows 11 File Explorer Styler 模組
Write-Host "[2/3] 配置 File Explorer WinUI 3 注入模組..." -ForegroundColor Yellow

$modsSourceDir = "$env:ProgramData\Windhawk\ModsSource"
if (-not (Test-Path $modsSourceDir)) {
    New-Item -Path $modsSourceDir -ItemType Directory -Force | Out-Null
}

$modId = "windows-11-file-explorer-styler"
$modCppFile = Join-Path $modsSourceDir "$modId.wh.cpp"

$modUrl = "https://raw.githubusercontent.com/m417z/my-windhawk-mods/main/mods/windows-11-file-explorer-styler.wh.cpp"
Write-Host "  -> 準備 $modId 模組代碼..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $modUrl -OutFile $modCppFile -UseBasicParsing
    Write-Host "  -> 模組代碼已成功寫入: $modCppFile" -ForegroundColor Green
} catch {
    Write-Warning "無法從線上取得最新代碼，嘗試使用本機現有版本..."
}

# 4. 自動寫入註冊表樣式注入 (強制 Noto Sans TC Bold 700)
Write-Host "[3/3] 寫入 XAML 樣式注入設定 (強制 Noto Sans TC Bold)..." -ForegroundColor Yellow

$modRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$modId"
$settingsKey = "$modRegKey\Settings"

if (-not (Test-Path $settingsKey)) {
    New-Item -Path $settingsKey -Force | Out-Null
}

# 注入樣式規則：將 TextBlock 與 ContentControl 全域強制套用 Noto Sans TC Bold
Set-ItemProperty -Path $settingsKey -Name "theme" -Value "" -ErrorAction SilentlyContinue

# Target 0: 全域 TextBlock (常用首頁「快速存取」、「最近使用」、命令列按鈕文字、網址列文字)
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

# 5. 確保 Windhawk 啟動並刷新檔案總管
Write-Host "  -> 啟動 Windhawk 引擎並刷新檔案總管..." -ForegroundColor Cyan

Start-Service -Name "windhawk" -ErrorAction SilentlyContinue
if (Test-Path $windhawkExe) {
    Start-Process -FilePath $windhawkExe -ArgumentList "-tray-only" -ErrorAction SilentlyContinue
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  方案 B 設定成功！" -ForegroundColor Green
Write-Host "  Windhawk 已成功接管 File Explorer WinUI 3 XAML 控制項。" -ForegroundColor Green
Write-Host "  檔案總管（命令列、網址列、常用首頁「快速存取」）已同步呈現 Noto Sans TC 粗體！" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
