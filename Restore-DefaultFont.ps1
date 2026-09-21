<#
.SYNOPSIS
    將 Windows 系統字型、視窗 UI、圖示、選單還原為預設字型 (微軟正黑體 / Segoe UI)。
.DESCRIPTION
    1. 優先從 backups/latest 還原備份的註冊表設定
    2. 若無備份檔，則自動還原 Windows 10/11 預設微軟正黑體與 Segoe UI 常規粗細 (Regular 400)
    3. 重新啟動檔案總管以立即套用
#>

$ErrorActionPreference = "Continue"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "還原字型需要系統管理員權限。"
    Write-Host "正在請求以系統管理員身分重啟..." -ForegroundColor Cyan
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

$scriptDir = Split-Path -Parent $PSCommandPath
$latestBackupDir = Join-Path $scriptDir "backups\latest"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  正在還原 Windows 原始預設系統字型..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

if (Test-Path "$latestBackupDir\Fonts.reg") {
    Write-Host "從備份檔還原註冊表..." -ForegroundColor Yellow
    reg import "$latestBackupDir\Fonts.reg" | Out-Null
    reg import "$latestBackupDir\FontSubstitutes.reg" | Out-Null
    reg import "$latestBackupDir\FontLink.reg" | Out-Null
    reg import "$latestBackupDir\WindowMetrics.reg" | Out-Null
    Write-Host "  -> 備份註冊表已還原！" -ForegroundColor Green
} else {
    Write-Host "未找到備份檔，執行標準 Windows 預設值還原..." -ForegroundColor Yellow
    
    # 還原 HKLM Fonts
    $fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    Set-ItemProperty -Path $fontsKey -Name 'Segoe UI (TrueType)' -Value 'segoeui.ttf' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Bold (TrueType)' -Value 'segoeuib.ttf' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Semibold (TrueType)' -Value 'seguisb.ttf' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Segoe UI Light (TrueType)' -Value 'segoeuil.ttf' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei & Microsoft JhengHei UI (TrueType)' -Value 'msjh.ttc' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Bold & Microsoft JhengHei UI Bold (TrueType)' -Value 'msjhbd.ttc' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fontsKey -Name 'Microsoft JhengHei Light & Microsoft JhengHei UI Light (TrueType)' -Value 'msjhl.ttc' -ErrorAction SilentlyContinue

    # 清除 FontSubstitutes 替換
    $subKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
    @('Segoe UI', 'Segoe UI Variable', 'Microsoft JhengHei', 'Microsoft JhengHei UI', 'MS Shell Dlg', 'MS Shell Dlg 2') | ForEach-Object {
        Remove-ItemProperty -Path $subKey -Name $_ -ErrorAction SilentlyContinue
    }
}

# 還原 WindowMetrics 為微軟正黑體 Regular (400)
$csRestore = @'
using System;
using System.Runtime.InteropServices;

public class MetricsRestorer {
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

    public static void Restore(string fontName) {
        NONCLIENTMETRICS ncm = new NONCLIENTMETRICS();
        ncm.cbSize = Marshal.SizeOf(ncm);
        if (SystemParametersInfo(SPI_GETNONCLIENTMETRICS, ncm.cbSize, ref ncm, 0)) {
            ncm.lfCaptionFont.lfFaceName = fontName;
            ncm.lfCaptionFont.lfWeight = 400;
            ncm.lfSmCaptionFont.lfFaceName = fontName;
            ncm.lfSmCaptionFont.lfWeight = 400;
            ncm.lfMenuFont.lfFaceName = fontName;
            ncm.lfMenuFont.lfWeight = 400;
            ncm.lfStatusFont.lfFaceName = fontName;
            ncm.lfStatusFont.lfWeight = 400;
            ncm.lfMessageFont.lfFaceName = fontName;
            ncm.lfMessageFont.lfWeight = 400;
            SystemParametersInfo(SPI_SETNONCLIENTMETRICS, ncm.cbSize, ref ncm, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        }

        LOGFONT lf = new LOGFONT();
        if (SystemParametersInfo(SPI_GETICONTITLELOGFONT, Marshal.SizeOf(lf), ref lf, 0)) {
            lf.lfFaceName = fontName;
            lf.lfWeight = 400;
            SystemParametersInfo(SPI_SETICONTITLELOGFONT, Marshal.SizeOf(lf), ref lf, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        }

        UIntPtr result;
        SendMessageTimeout((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "WindowMetrics", 2, 5000, out result);
    }
}
'@
Add-Type -TypeDefinition $csRestore -ErrorAction SilentlyContinue
[MetricsRestorer]::Restore("Microsoft JhengHei UI")

# 重啟 Explorer
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  還原完成！請重新開機使系統字型完全恢復原狀。" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
