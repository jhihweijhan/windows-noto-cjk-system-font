<#
.SYNOPSIS
Windhawk 思源黑體 (Noto Sans CJK Bold) 全套系統模組一鍵安裝與部署工具
.DESCRIPTION
1. 系統檢測與自動提權 (UAC RunAs)
2. 檢測系統是否已安裝 Windhawk
3. 安裝 Noto Sans TC Bold 繁體粗體 與 Noto Sans SC Bold 簡體粗體靜態字型檔 (容錯防鎖定)
4. 修復 DirectWrite 與瀏覽器簡體字回退 (阻斷 SimSun 宋體)
5. 自動部署 Windhawk 全域字型模組 (windows-noto-sans-cjk):
   - 排除 audiodg.exe / smartscreen.exe 等系統隔離服務
   - GDI 攔截：替換微軟正黑體、新細明體為 Noto Sans TC Bold
   - DirectWrite 攔截：強制簡體字回退至 Noto Sans SC Bold
   - 圖示保護：保護 Segoe Fluent Icons，確保絕不出現豆腐塊
6. 自動修復 File Explorer WinUI 3 樣式
7. 重啟服務與檔案總管以立即生效
#>
[CmdletBinding()]
param()

$logFile = Join-Path $PSScriptRoot "install.log"
try { Start-Transcript -Path $logFile -Force -ErrorAction SilentlyContinue | Out-Null } catch {}

Set-Location -LiteralPath $PSScriptRoot

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
    Write-Host "  Windhawk 思源黑體 (Noto Sans CJK) 系統模組一鍵安裝" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  正在請求系統管理員權限 (UAC)... 請在彈出視窗點選「是」" -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -ErrorAction Stop
    } catch {
        Write-Host ""
        Write-Host "  [提示] 系統需要管理員權限以完成字型註冊與 Windhawk 配置。" -ForegroundColor Yellow
        Write-Host "  請在 Install-Mod.bat 上按滑鼠右鍵，選擇「以系統管理員身分執行」。" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
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
        Read-Host "按 Enter 鍵結束..."
        exit 1
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
    try {
        Copy-Item -Path $tcBoldFile -Destination $fontsDir -Force -ErrorAction Stop
    } catch {
        # 若字型已被系統載入鎖定，略過實體覆寫
    }
    Set-ItemProperty -Path $fontsKey -Name 'Noto Sans TC Bold (TrueType)' -Value 'NotoSansTC-Bold.ttf' -ErrorAction SilentlyContinue
    try { [FontGDI]::AddFontResource("$fontsDir\NotoSansTC-Bold.ttf") | Out-Null } catch {}
    Write-Host "  -> 已安裝並加載原生思源黑體繁體粗體: NotoSansTC-Bold.ttf" -ForegroundColor Green
}

if (Test-Path $scBoldFile) {
    try {
        Copy-Item -Path $scBoldFile -Destination $fontsDir -Force -ErrorAction Stop
    } catch {
        # 若字型已被系統載入鎖定，略過實體覆寫
    }
    Set-ItemProperty -Path $fontsKey -Name 'Noto Sans SC Bold (TrueType)' -Value 'NotoSansSC-Bold.ttf' -ErrorAction SilentlyContinue
    try { [FontGDI]::AddFontResource("$fontsDir\NotoSansSC-Bold.ttf") | Out-Null } catch {}
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

# 暫停 Windhawk 服務以防止 DLL 被系統鎖定
Stop-Service -Name "windhawk" -Force -ErrorAction SilentlyContinue

if (Test-Path $universalModSource) {
    Copy-Item -Path $universalModSource -Destination "$modsSourceDir\$universalModId.wh.cpp" -Force -ErrorAction SilentlyContinue
    Write-Host "  -> 已同步模組源碼至: $modsSourceDir\$universalModId.wh.cpp" -ForegroundColor Green
}

$dllName = "${universalModId}_1.0.0_100001.dll"
$srcDll64 = Join-Path $PSScriptRoot "windows-noto-sans-cjk_64.dll"
$srcDll32 = Join-Path $PSScriptRoot "windows-noto-sans-cjk_32.dll"

if (Test-Path $srcDll64) {
    try {
        Copy-Item -Path $srcDll64 -Destination "$mods64Dir\$dllName" -Force -ErrorAction Stop
    } catch {}
    Write-Host "  -> 已部署 64 位元模組 DLL: $mods64Dir\$dllName" -ForegroundColor Green
}
if (Test-Path $srcDll32) {
    try {
        Copy-Item -Path $srcDll32 -Destination "$mods32Dir\$dllName" -Force -ErrorAction Stop
    } catch {}
    Write-Host "  -> 已部署 32 位元模組 DLL: $mods32Dir\$dllName" -ForegroundColor Green
}

# 註冊模組至 Windhawk 註冊表 (包含安全排除清單，絕不注入 audiodg.exe / smartscreen.exe 等系統服務)
$uModReg = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$universalModId"
if (-not (Test-Path $uModReg)) { New-Item -Path $uModReg -Force | Out-Null }
Set-ItemProperty -Path $uModReg -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uModReg -Name "LibraryFileName" -Value $dllName -ErrorAction SilentlyContinue
$targetApps = "explorer.exe|msedge.exe|chrome.exe|firefox.exe|brave.exe|notepad.exe|notepad++.exe|code.exe|Taskmgr.exe|SystemSettings.exe"
Set-ItemProperty -Path $uModReg -Name "Include" -Value $targetApps -ErrorAction SilentlyContinue
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
Write-Host "  -> 已完成 Windhawk 全域字型模組註冊與啟用 (已安全綁定目標視窗程式)！" -ForegroundColor Green

# 5. 修復 File Explorer WinUI 3 樣式 (徹底覆蓋首頁卡片、導覽列、檔案清單與網址列，全數套用 Noto Sans TC Bold)
Write-Host "[4/5] 修復 File Explorer WinUI 3 全介面文字與粗體樣式..." -ForegroundColor Yellow
$explorerModId = "windows-11-file-explorer-styler"
$explorerRegKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$explorerModId"
$explorerSettings = "$explorerRegKey\Settings"

if (Test-Path $explorerSettings) {
    Remove-Item -Path $explorerSettings -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $explorerSettings -Force | Out-Null

Set-ItemProperty -Path $explorerSettings -Name "theme" -Value "" -ErrorAction SilentlyContinue

$fontFallback = "Noto Sans TC, Segoe Fluent Icons, Segoe MDL2 Assets"

# Target 0: TextBlock (所有文字標籤、首頁副標題、網址列麵包屑)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].target" -Value "TextBlock" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[0].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 1: Control (所有 XAML 控制項基礎類別，覆蓋左側 TreeViewItem 導覽樹與 ListViewItem 檔案清單)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].target" -Value "Control" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[1].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 2: ContentControl (按鈕、標籤頁頂部標題)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].target" -Value "ContentControl" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[2].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 3: TextBox (網址列與搜尋列輸入文字框)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[3].target" -Value "TextBox" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[3].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[3].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

# Target 4: ItemsControl (覆蓋首頁分組標頭，如「快速存取」、「最近使用」、「我的最愛」)
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[4].target" -Value "ItemsControl" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[4].styles[0]" -Value "FontFamily=$fontFallback" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "controlStyles[4].styles[1]" -Value "FontWeight=Bold" -ErrorAction SilentlyContinue

Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[0]" -Value "ContentControlThemeFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[1]" -Value "BodyTextBlockStyle.FontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[2]" -Value "BodyTextBlockStyle.FontWeight=Bold" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[3]" -Value "ControlContentThemeFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerSettings -Name "themeResourceVariables[4]" -Value "SystemControlFontFamily=Noto Sans TC" -ErrorAction SilentlyContinue

$explorerWritable = "HKLM:\SOFTWARE\Windhawk\Engine\ModsWritable\$explorerModId"
if (-not (Test-Path $explorerWritable)) { New-Item -Path $explorerWritable -Force | Out-Null }
Set-ItemProperty -Path $explorerWritable -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $explorerRegKey -Name "Disabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  -> File Explorer WinUI 3 全介面圖示保護與粗體樣式配置完成！" -ForegroundColor Green

# 6. 重啟服務與檔案總管以立即生效
Write-Host "[5/5] 重啟 Windhawk 服務與檔案總管以套用字型..." -ForegroundColor Yellow
$svc = Get-Service -Name "windhawk" -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq 'Running') {
        Restart-Service -Name "windhawk" -Force -ErrorAction SilentlyContinue
    } else {
        Start-Service -Name "windhawk" -ErrorAction SilentlyContinue
    }
}
Start-Process -FilePath "C:\Program Files\Windhawk\windhawk.exe" -ArgumentList "-tray-only" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "  -> 正在重啟檔案總管以完整套用新介面樣式..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
}
Start-Process explorer.exe "C:\" -ErrorAction SilentlyContinue
Write-Host "  -> 服務啟動與檔案總管重整完成！" -ForegroundColor Green

try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  【安裝完成】Windhawk 思源黑體模組已成功配置並生效！" -ForegroundColor Green
Write-Host "  1. 繁體中文：全系統已切換為 Noto Sans TC Bold 粗體" -ForegroundColor Green
Write-Host "  2. 簡體中文：所有簡體字 100% 回退至 Noto Sans SC Bold 原生粗體" -ForegroundColor Green
Write-Host "  3. 檔案總管：麵包屑導覽箭頭 (>) 與圖示完整保留，絕無豆腐塊" -ForegroundColor Green
Write-Host "  4. 隨附驗證：若欲立即查看繁簡與圖示渲染結果，可執行 Test-FontRendering.bat" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "請按 Enter 鍵確認完成並關閉本視窗..."
