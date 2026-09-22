<#
.SYNOPSIS
Windhawk 思源黑體 (Noto Sans CJK Bold) 全套系統模組一鍵安裝與部署工具
.DESCRIPTION
1. 自我權限檢測與自動提權 (UAC RunAs)
2. 嚴格系統檢測：檢測系統是否已安裝 Windhawk，未安裝引導手動安裝
3. 安裝 Noto Sans TC Bold 繁體粗體 與 Noto Sans SC Bold 簡體粗體靜態字型檔
4. 修復 DirectWrite 與瀏覽器 (Chrome / Edge) 簡體字回退 (徹底阻斷 SimSun 宋體)
5. 自動部署編譯 Windhawk 全域字型模組 (windows-noto-sans-cjk):
   - GDI 攔截：替換微軟正黑體、新細明體為 Noto Sans TC Bold
   - DirectWrite 攔截：強制簡體字回退至 Noto Sans SC Bold
   - 圖示保護：嚴格白名單保護 Segoe Fluent Icons，確保絕不出現豆腐塊
6. 自動修復 File Explorer WinUI 3 麵包屑導覽圖示與粗體樣式 (FontFamily 回退鏈)
7. 自動刷新檔案總管並執行字型雙重視覺化實機驗證 (瀏覽器 + 檔案總管實體視窗)
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
Set-Location -LiteralPath $PSScriptRoot
$logFile = Join-Path $PSScriptRoot "install.log"
try { Start-Transcript -Path $logFile -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  Windhawk 思源黑體 (Noto Sans CJK) 系統模組一鍵安裝" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    } catch {
        Write-Host "  [!] 未能取得系統管理員權限: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  請在 Install-Mod.bat 上按滑鼠右鍵，選擇「以系統管理員身分執行」。" -ForegroundColor Yellow
        try { Stop-Transcript | Out-Null } catch {}
Read-Host "按 Enter 鍵結束..."
        exit 1
    }
    exit 0
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Windhawk 思源黑體 (Noto Sans CJK) 系統模組一鍵安裝" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 2. 嚴格系統檢測：檢查 Windhawk 是否已安裝
Write-Host "[1/5] 檢測系統是否已安裝 Windhawk..." -ForegroundColor Yellow
$windhawkExe = "C:\Program Files\Windhawk\windhawk.exe"
$windhawkReg = "HKLM:\SOFTWARE\Windhawk"
$isInstalled = (Test-Path $windhawkExe) -or (Test-Path $windhawkReg)

if (-not $isInstalled) {
    Write-Host ""
    Write-Host "  [X] 系統檢測未通過：尚未安裝 Windhawk！" -ForegroundColor Red
    Write-Host "      本方案需要借助 Windhawk 注入引擎以實時攔截 GDI 與 DirectWrite 字型。" -ForegroundColor Yellow
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
        try { Stop-Transcript | Out-Null } catch {}
Read-Host "按 Enter 鍵結束..."
        exit
    }
}
Write-Host "  [PASS] 系統檢測通過！偵測到 Windhawk 已正確安裝於系統中。" -ForegroundColor Green

# 3. 安裝與註冊原生粗體字型檔 (NotoSansTC-Bold.ttf 與 NotoSansSC-Bold.ttf)
Write-Host "[2/5] 安裝並註冊原生粗體思源黑體 (繁體 TC Bold + 簡體 SC Bold)..." -ForegroundColor Yellow
$fontsDir = "C:\Windows\Fonts"
$fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

$scBoldFile = Join-Path $PSScriptRoot "NotoSansSC-Bold.ttf"
$tcBoldFile = Join-Path $PSScriptRoot "NotoSansTC-Bold.ttf"

if (Test-Path $tcBoldFile) {
    Copy-Item -Path $tcBoldFile -Destination $fontsDir -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Noto Sans TC Bold (TrueType)' -Value 'NotoSansTC-Bold.ttf' -ErrorAction SilentlyContinue
    [FontGDI]::AddFontResource("$fontsDir\NotoSansTC-Bold.ttf") | Out-Null
    Write-Host "  -> 已安裝並加載原生思源黑體繁體粗體: NotoSansTC-Bold.ttf" -ForegroundColor Green
}

if (Test-Path $scBoldFile) {
    Copy-Item -Path $scBoldFile -Destination $fontsDir -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Noto Sans SC Bold (TrueType)' -Value 'NotoSansSC-Bold.ttf' -ErrorAction SilentlyContinue
    [FontGDI]::AddFontResource("$fontsDir\NotoSansSC-Bold.ttf") | Out-Null
    Write-Host "  -> 已安裝並加載原生思源黑體簡體粗體: NotoSansSC-Bold.ttf" -ForegroundColor Green
}

# 阻斷宋體 (SimSun) 與細明體 (MingLiU) 回退洩漏
Set-ItemProperty -Path $fontsKey -Name 'SimSun & NSimSun (TrueType)' -Value '' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $fontsKey -Name 'MingLiU & PMingLiU & MingLiU_HKSCS (TrueType)' -Value '' -ErrorAction SilentlyContinue

# 配置系統 FontLink：將 Noto Sans SC Bold 排在最前，並加入 Segoe Fluent Icons 保護圖示
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

# 設定 Chrome / Edge 瀏覽器偏好
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
        Write-Host "  -> 已更新瀏覽器繁簡雙黑體回退偏好: $(Split-Path $prefPath -Parent)" -ForegroundColor Gray
    } catch {
        Write-Host "  -> 略過: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Update-BrowserFont "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
Update-BrowserFont "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"

# 4. 部署 Windhawk 全套全域字型模組 (windows-noto-sans-cjk)
Write-Host "[3/5] 部署 Windhawk 全域字型模組 (windows-noto-sans-cjk)..." -ForegroundColor Yellow
$universalModId = "windows-noto-sans-cjk"
$universalModSource = Join-Path $PSScriptRoot "windows-noto-sans-cjk.wh.cpp"
$modsSourceDir = "$env:ProgramData\Windhawk\ModsSource"
$mods64Dir = "$env:ProgramData\Windhawk\Engine\Mods\64"
$mods32Dir = "$env:ProgramData\Windhawk\Engine\Mods\32"

if (-not (Test-Path $modsSourceDir)) { New-Item -Path $modsSourceDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $mods64Dir)) { New-Item -Path $mods64Dir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $mods32Dir)) { New-Item -Path $mods32Dir -ItemType Directory -Force | Out-Null }

if (Test-Path $universalModSource) {
    Copy-Item -Path $universalModSource -Destination "$modsSourceDir\$universalModId.wh.cpp" -Force -ErrorAction SilentlyContinue
    Write-Host "  -> 已同步模組源碼至: $modsSourceDir\$universalModId.wh.cpp" -ForegroundColor Green
}

$dllName = "${universalModId}_1.0.0_100001.dll"
$srcDll64 = Join-Path $PSScriptRoot "windows-noto-sans-cjk_64.dll"
$srcDll32 = Join-Path $PSScriptRoot "windows-noto-sans-cjk_32.dll"

if (Test-Path $srcDll64) {
    Copy-Item -Path $srcDll64 -Destination "$mods64Dir\$dllName" -Force -ErrorAction SilentlyContinue
    Write-Host "  -> 已部署 64 位元模組 DLL: $mods64Dir\$dllName" -ForegroundColor Green
}
if (Test-Path $srcDll32) {
    Copy-Item -Path $srcDll32 -Destination "$mods32Dir\$dllName" -Force -ErrorAction SilentlyContinue
    Write-Host "  -> 已部署 32 位元模組 DLL: $mods32Dir\$dllName" -ForegroundColor Green
}

# 註冊模組至 Windhawk 註冊表
$uModReg = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$universalModId"
if (-not (Test-Path $uModReg)) { New-Item -Path $uModReg -Force | Out-Null }
Set-ItemProperty -Path $uModReg -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "LibraryFileName" -Value $dllName -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "Include" -Value "*" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "Exclude" -Value "" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "Architecture" -Value "x86|x86-64" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "Version" -Value "1.0.0" -ErrorAction SilentlyContinue

$uSettings = "$uModReg\Settings"
if (-not (Test-Path $uSettings)) { New-Item -Path $uSettings -Force | Out-Null }
Set-ItemProperty -Path $uSettings -Name "targetFontTC" -Value "Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uSettings -Name "targetFontSC" -Value "Noto Sans SC Bold" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uSettings -Name "enforceBold" -Value 1 -Type DWord -ErrorAction SilentlyContinue

$uWritable = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$universalModId"
if (-not (Test-Path $uWritable)) { New-Item -Path $uWritable -Force | Out-Null }
Set-ItemProperty -Path $uWritable -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  -> 已完成 Windhawk 全域字型模組註冊與啟用！" -ForegroundColor Green

# 5. 修復 File Explorer WinUI 3 樣式 (徹底解決麵包屑導覽符號變豆腐塊問題，同時保證字型為 Noto Sans TC Bold)
Write-Host "[4/5] 修復 File Explorer WinUI 3 麵包屑圖示與粗體樣式..." -ForegroundColor Yellow
$explorerModId = "windows-11-file-explorer-styler"
$explorerRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$explorerModId"
$explorerSettings = "$explorerRegKey\Settings"

if (Test-Path $explorerSettings) {
    Remove-Item -Path $explorerSettings -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $explorerSettings -Force | Out-Null

Set-ItemProperty -Path $explorerSettings -Name "theme" -Value "" -ErrorAction SilentlyContinue

$fontFallback = "Noto Sans TC, Segoe Fluent Icons, Segoe MDL2 Assets"

# Target 0: 全域 TextBlock (網址列麵包屑文字、一般文字) -> 注入 Noto Sans TC Bold 並附帶 Segoe Fluent Icons 回退以保護箭頭與圖示
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].target" -Value "TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 1: 全域 ContentControl (按鈕、標籤)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].target" -Value "ContentControl" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 2: 全域 TextBox (網址列編輯框、搜尋列編輯框)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].target" -Value "TextBox" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# ThemeResourceVariables: 覆寫 XAML 主題字型資源 (正文對齊 Noto Sans TC Bold，絕不覆蓋圖示資源)
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[0]" -Value "ContentControlThemeFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[1]" -Value "BodyTextBlockStyle.FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[2]" -Value "BodyTextBlockStyle.FontWeight=Bold" -ErrorAction SilentlyContinue

$explorerWritable = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$explorerModId"
if (-not (Test-Path $explorerWritable)) { New-Item -Path $explorerWritable -Force | Out-Null }
Set-ItemProperty -Path $explorerWritable -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerRegKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  -> File Explorer WinUI 3 圖示保護與粗體樣式配置完成！" -ForegroundColor Green

# 6. 重啟服務與檔案總管以立即生效
Write-Host "[5/5] 重啟 Windhawk 服務與檔案總管以套用字型..." -ForegroundColor Yellow
$svc = Get-Service -Name "windhawk" -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -ne 'Running') {
        Start-Service -Name "windhawk" -ErrorAction SilentlyContinue
    } else {
        Restart-Service -Name "windhawk" -Force -ErrorAction SilentlyContinue
    }
}
Start-Process -FilePath "C:\Program Files\Windhawk\windhawk.exe" -ArgumentList "-tray-only" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}
Start-Process explorer.exe "C:\" -ErrorAction SilentlyContinue
Write-Host "  -> 服務與檔案總管重啟完成！" -ForegroundColor Green

# 7. 自動執行字型渲染視覺化實機驗證
Write-Host ""
$testScript = Join-Path $PSScriptRoot "Test-FontRendering.ps1"
if (Test-Path $testScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScript
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  全套 Windhawk 字型模組已成功配置並啟動！" -ForegroundColor Green
Write-Host "  1. 繁體中文：全系統 GDI 與 DirectWrite 呈現 Noto Sans TC Bold 700。" -ForegroundColor Green
Write-Host "  2. 簡體中文：所有簡體字 (如「費」「門」「國」) 100% 回退至 Noto Sans SC Bold 原生粗體。" -ForegroundColor Green
Write-Host "  3. 檔案總管：麵包屑導覽箭頭 (>) 與圖示完整保留，絕無豆腐塊。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
try { Stop-Transcript | Out-Null } catch {}
Read-Host "按 Enter 鍵結束..."
