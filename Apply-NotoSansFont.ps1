<#
.SYNOPSIS
    將 Windows 系統字型、視窗 UI、圖示、瀏覽器設定為 Google Fonts 思源黑體 (Noto Sans TC)，並完整支援簡體中文。
.DESCRIPTION
    1. 自動建立原始註冊表與系統字型備份 (backups/ 目錄)
    2. 自動下載並安裝 Google Fonts Noto Sans TC (繁中) 與 Noto Sans SC (簡中) 可變字型
    3. 設定 FontLink / SystemLink，使缺漏字元 (如簡中獨有字) 自動回退至 Noto Sans SC
    4. 設定 FontSubstitutes 全域取代 Segoe UI 與 Microsoft JhengHei UI
    5. 套用 WindowMetrics (桌面圖示、視窗標題、選單、訊息框、狀態列) 為粗體 (Bold 700)
    6. 設定 Chrome 與 Edge 瀏覽器標準/無襯線字型偏好
    7. 重新啟動檔案總管以立即套用
#>

[CmdletBinding()]
param(
    [ValidateSet("Bold", "Regular")]
    [string]$Weight = "Bold"
)

$ErrorActionPreference = "Continue"

# 權限檢查
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "此腳本需要系統管理員權限以修改 HKLM 註冊表與安裝字型至 C:\Windows\Fonts。"
    Write-Host "正在請求以系統管理員身分重啟..." -ForegroundColor Cyan
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -Weight $Weight"
    exit
}

$scriptDir = Split-Path -Parent $PSCommandPath
$backupDir = Join-Path $scriptDir "backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$currentBackupDir = Join-Path $backupDir "backup_$timestamp"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Windows Noto Sans CJK 系統字型替換工具 (支援簡繁雙向回退)" -ForegroundColor Cyan
Write-Host "  字重模式: $Weight" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. 備份原始註冊表設定
# -------------------------------------------------------------
Write-Host "[1/7] 正在備份目前系統字型註冊表..." -ForegroundColor Yellow
if (-not (Test-Path $currentBackupDir)) {
    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null
}

reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "$currentBackupDir\Fonts.reg" /y | Out-Null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" "$currentBackupDir\FontSubstitutes.reg" /y | Out-Null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink" "$currentBackupDir\FontLink.reg" /y | Out-Null
reg export "HKCU\Control Panel\Desktop\WindowMetrics" "$currentBackupDir\WindowMetrics.reg" /y | Out-Null

# 另外建立 latest 指向最新備份
$latestBackupDir = Join-Path $backupDir "latest"
if (Test-Path $latestBackupDir) { Remove-Item $latestBackupDir -Recurse -Force | Out-Null }
Copy-Item $currentBackupDir $latestBackupDir -Recurse -Force | Out-Null
Write-Host "  -> 備份已儲存至: $currentBackupDir" -ForegroundColor Green

# -------------------------------------------------------------
# 2. 下載並安裝 Google Fonts (Noto Sans TC / SC)
# -------------------------------------------------------------
Write-Host "[2/7] 檢查並安裝 Google Fonts 思源黑體 (TC 繁中 / SC 簡中)..." -ForegroundColor Yellow

$winFontsDir = "C:\Windows\Fonts"
$fontsToEnsure = @(
    @{
        Name = "Noto Sans TC"
        RegKey = "Noto Sans TC (TrueType)"
        File = "NotoSansTC-VF.ttf"
        Url = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"
    },
    @{
        Name = "Noto Sans SC"
        RegKey = "Noto Sans SC (TrueType)"
        File = "NotoSansSC-VF.ttf"
        Url = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
    }
)

foreach ($font in $fontsToEnsure) {
    $destPath = Join-Path $winFontsDir $font.File
    $localTemp = "$env:TEMP\$($font.File)"
    $userFont = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\$($font.File)"

    if (-not (Test-Path $destPath)) {
        if (Test-Path $userFont) {
            Write-Host "  -> 從使用者字型目錄複製 $($font.Name) 至系統字型目錄..." -ForegroundColor Cyan
            Copy-Item $userFont -Destination $destPath -Force
        } elseif (Test-Path $localTemp) {
            Write-Host "  -> 從暫存目錄複製 $($font.Name) 至系統字型目錄..." -ForegroundColor Cyan
            Copy-Item $localTemp -Destination $destPath -Force
        } else {
            Write-Host "  -> 正在從 Google Fonts 下載 $($font.Name) ($($font.File))..." -ForegroundColor Cyan
            curl.exe -L $font.Url -o $destPath --silent --show-error
        }
    } else {
        Write-Host "  -> 系統字型目錄已存在 $($font.Name)" -ForegroundColor Gray
    }

    # 註冊至 HKLM Fonts
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $font.RegKey -Value $font.File -ErrorAction SilentlyContinue
}

# 廣播 GDI FontChange
$gdiHelper = @'
using System;
using System.Runtime.InteropServices;
public class FontGDI {
    [DllImport("gdi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int AddFontResource(string lpFileName);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
'@
Add-Type -TypeDefinition $gdiHelper -ErrorAction SilentlyContinue
[FontGDI]::AddFontResource("C:\Windows\Fonts\NotoSansTC-VF.ttf") | Out-Null
[FontGDI]::AddFontResource("C:\Windows\Fonts\NotoSansSC-VF.ttf") | Out-Null
[FontGDI]::SendMessage([IntPtr]0xffff, 0x001D, [IntPtr]0, [IntPtr]0) | Out-Null # WM_FONTCHANGE

Write-Host "  -> 字型已成功安裝並載入系統字型快取。" -ForegroundColor Green

# -------------------------------------------------------------
# 3. 設定 FontLink / SystemLink (簡繁互補無缺字)
# -------------------------------------------------------------
Write-Host "[3/7] 設定字型回退關聯 (FontLink SystemLink)，確保簡中字元完整支援..." -ForegroundColor Yellow

$notoTcSystemLink = @(
    "NotoSansSC-VF.ttf,Noto Sans SC",
    "MSYH.TTC,Microsoft YaHei UI,128,96",
    "MSYH.TTC,Microsoft YaHei UI",
    "MSJH.TTC,Microsoft JhengHei UI,128,96",
    "MSJH.TTC,Microsoft JhengHei UI",
    "MINGLIU.TTC,MingLiU",
    "simsun.ttc,SimSun",
    "seguiemj.ttf,Segoe UI Emoji"
)

$notoScSystemLink = @(
    "NotoSansTC-VF.ttf,Noto Sans TC",
    "MSJH.TTC,Microsoft JhengHei UI,128,96",
    "MSJH.TTC,Microsoft JhengHei UI",
    "MSYH.TTC,Microsoft YaHei UI,128,96",
    "MSYH.TTC,Microsoft YaHei UI",
    "MINGLIU.TTC,MingLiU",
    "simsun.ttc,SimSun",
    "seguiemj.ttf,Segoe UI Emoji"
)

$linkKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
Set-ItemProperty -Path $linkKey -Name 'Noto Sans TC' -Value $notoTcSystemLink -Type MultiString
Set-ItemProperty -Path $linkKey -Name 'Noto Sans SC' -Value $notoScSystemLink -Type MultiString

# Segoe UI 與 Microsoft JhengHei UI 首選回退加上 Noto Sans TC / SC
@('Segoe UI', 'Microsoft JhengHei UI', 'Microsoft JhengHei') | ForEach-Object {
    $existing = (Get-ItemProperty -Path $linkKey -Name $_ -ErrorAction SilentlyContinue).$_
    $newList = [System.Collections.Generic.List[string]]::new()
    $newList.Add("NotoSansTC-VF.ttf,Noto Sans TC")
    $newList.Add("NotoSansSC-VF.ttf,Noto Sans SC")
    if ($existing) {
        foreach ($item in $existing) {
            if ($item -notmatch 'NotoSansTC' -and $item -notmatch 'NotoSansSC') {
                $newList.Add($item)
            }
        }
    }
    Set-ItemProperty -Path $linkKey -Name $_ -Value $newList.ToArray() -Type MultiString
}
Write-Host "  -> FontLink 簡繁雙向回退與表情符號連結完成！" -ForegroundColor Green

# -------------------------------------------------------------
# 4. 設定 FontSubstitutes 全域字型對應
# -------------------------------------------------------------
Write-Host "[4/7] 設定系統全域字型替換 (FontSubstitutes)..." -ForegroundColor Yellow

$subKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
Set-ItemProperty -Path $subKey -Name 'Segoe UI' -Value 'Noto Sans TC'
Set-ItemProperty -Path $subKey -Name 'Segoe UI Variable' -Value 'Noto Sans TC'
Set-ItemProperty -Path $subKey -Name 'Microsoft JhengHei' -Value 'Noto Sans TC'
Set-ItemProperty -Path $subKey -Name 'Microsoft JhengHei UI' -Value 'Noto Sans TC'
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg' -Value 'Noto Sans TC'
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg 2' -Value 'Noto Sans TC'

# 5. 導向 HKLM Fonts (讓 Windows 優先使用 FontSubstitutes)
$fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Bold (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Semibold (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Light (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Semilight (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Variable (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei & Microsoft JhengHei UI (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Bold & Microsoft JhengHei UI Bold (TrueType)' -Value ''
Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Light & Microsoft JhengHei UI Light (TrueType)' -Value ''

# 啟用 Windows 完整快顯選單 (確保右鍵選單直接套用 Noto Sans TC 粗體)
$clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (-not (Test-Path $clsidPath)) {
    New-Item -Path $clsidPath -Force | Out-Null
}
Set-ItemProperty -Path $clsidPath -Name "(Default)" -Value ""

Write-Host "  -> 系統全域字型替換與快顯選單已生效！" -ForegroundColor Green

# -------------------------------------------------------------
# 5. 套用 WindowMetrics (圖示、標題列、選單、對話框、狀態列)
# -------------------------------------------------------------
Write-Host "[5/7] 設定桌面圖示、視窗標題列、選單、訊息框為 Noto Sans TC ($Weight)..." -ForegroundColor Yellow

$targetWeight = if ($Weight -eq "Bold") { 700 } else { 400 }

$csMetrics = @'
using System;
using System.Runtime.InteropServices;

public class SystemMetricsApplier {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct LOGFONT {
        public int lfHeight;
        public int lfWidth;
        public int lfEscapement;
        public int lfOrientation;
        public int lfWeight;
        public byte lfItalic;
        public byte lfUnderline;
        public byte lfStrikeOut;
        public byte lfCharSet;
        public byte lfOutPrecision;
        public byte lfClipPrecision;
        public byte lfQuality;
        public byte lfPitchAndFamily;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string lfFaceName;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct NONCLIENTMETRICS {
        public int cbSize;
        public int iBorderWidth;
        public int iScrollWidth;
        public int iScrollHeight;
        public int iCaptionWidth;
        public int iCaptionHeight;
        public LOGFONT lfCaptionFont;
        public int iSmCaptionWidth;
        public int iSmCaptionHeight;
        public LOGFONT lfSmCaptionFont;
        public int iMenuWidth;
        public int iMenuHeight;
        public LOGFONT lfMenuFont;
        public LOGFONT lfStatusFont;
        public LOGFONT lfMessageFont;
        public int iPaddedBorderWidth;
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SystemParametersInfo(int uiAction, int uiParam, ref NONCLIENTMETRICS pvParam, int fWinIni);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SystemParametersInfo(int uiAction, int uiParam, ref LOGFONT pvParam, int fWinIni);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);

    public const int SPI_GETNONCLIENTMETRICS = 41;
    public const int SPI_SETNONCLIENTMETRICS = 42;
    public const int SPI_GETICONTITLELOGFONT = 31;
    public const int SPI_SETICONTITLELOGFONT = 34;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;

    public static void Apply(string fontName, int weight) {
        NONCLIENTMETRICS ncm = new NONCLIENTMETRICS();
        ncm.cbSize = Marshal.SizeOf(ncm);
        if (SystemParametersInfo(SPI_GETNONCLIENTMETRICS, ncm.cbSize, ref ncm, 0)) {
            ncm.lfCaptionFont.lfFaceName = fontName;
            ncm.lfCaptionFont.lfWeight = weight;
            ncm.lfSmCaptionFont.lfFaceName = fontName;
            ncm.lfSmCaptionFont.lfWeight = weight;
            ncm.lfMenuFont.lfFaceName = fontName;
            ncm.lfMenuFont.lfWeight = weight;
            ncm.lfStatusFont.lfFaceName = fontName;
            ncm.lfStatusFont.lfWeight = weight;
            ncm.lfMessageFont.lfFaceName = fontName;
            ncm.lfMessageFont.lfWeight = weight;
            SystemParametersInfo(SPI_SETNONCLIENTMETRICS, ncm.cbSize, ref ncm, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        }

        LOGFONT lf = new LOGFONT();
        if (SystemParametersInfo(SPI_GETICONTITLELOGFONT, Marshal.SizeOf(lf), ref lf, 0)) {
            lf.lfFaceName = fontName;
            lf.lfWeight = weight;
            SystemParametersInfo(SPI_SETICONTITLELOGFONT, Marshal.SizeOf(lf), ref lf, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        }

        UIntPtr result;
        SendMessageTimeout((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "WindowMetrics", 2, 5000, out result);
    }
}
'@
Add-Type -TypeDefinition $csMetrics -ErrorAction SilentlyContinue
[SystemMetricsApplier]::Apply("Noto Sans TC", $targetWeight)
Write-Host "  -> 視窗 UI、選單與桌面圖示文字已設定為 Noto Sans TC ($Weight)！" -ForegroundColor Green

# -------------------------------------------------------------
# 6. 設定 Chrome 與 Edge 瀏覽器字型偏好
# -------------------------------------------------------------
Write-Host "[6/7] 設定 Chrome 與 Edge 瀏覽器預設字型..." -ForegroundColor Yellow

function Set-BrowserFontConfig($prefPath) {
    if (-not (Test-Path $prefPath)) { return }
    try {
        $content = Get-Content -Raw -Encoding UTF8 $prefPath | ConvertFrom-Json
        if (-not $content.webkit) {
            $content | Add-Member -MemberType NoteProperty -Name "webkit" -Value (New-Object PSObject)
        }
        if (-not $content.webkit.webprefs) {
            $content.webkit | Add-Member -MemberType NoteProperty -Name "webprefs" -Value (New-Object PSObject)
        }
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
        Write-Host "  -> 已更新瀏覽器設定: $(Split-Path $prefPath -Parent)" -ForegroundColor Gray
    } catch {
        Write-Host "  -> 更新瀏覽器設定跳過: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Set-BrowserFontConfig "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
Set-BrowserFontConfig "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"
Write-Host "  -> 瀏覽器字型偏好設定完成！" -ForegroundColor Green

# -------------------------------------------------------------
# 7. 重啟檔案總管 (Explorer)
# -------------------------------------------------------------
Write-Host "[7/7] 重啟檔案總管以刷新桌面圖示與視窗字型..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}
Write-Host "  -> 檔案總管已重新啟動！" -ForegroundColor Green

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  全部設定套用成功！" -ForegroundColor Green
Write-Host "  建議將電腦【重新開機】以使系統核心與所有應用程式全面套用新字型。" -ForegroundColor Cyan
Write-Host "  若欲還原預設值，請執行同目錄下的 Restore-DefaultFont.bat。" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
