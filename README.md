# Windows Noto Sans CJK - Windhawk 系統字型替換模組

> **專業級 Windows 10 / 11 全系統思源黑體粗體 (Noto Sans TC/SC Bold) 記憶體動態攔截模組**  
> 徹底告別微軟正黑體、新細明體與破舊宋體（SimSun），實現全系統 GDI、DirectWrite、WinUI 3 檔案總管與主流瀏覽器高清晰黑體渲染，**100% 杜絕圖示豆腐塊（▯）與缺字問題**。

![實機視覺渲染展示](docs/font_visual_verification_test.png)

---

## 🌟 核心特色與技術架構

傳統修改 Windows 註冊表替換字型容易遭遇「瀏覽器簡體字退回宋體/細明體」、「檔案總管麵包屑圖示變豆腐塊 ▯」、「系統更新後失效」等難題。本專案透過 **Windhawk 記憶體動態注入引擎**，從根本架構上解決：

| 特色項目 | 本專案 Windhawk 模組方案 | 傳統註冊表修改方案 |
| :--- | :--- | :--- |
| **繁體中文渲染** | 全域 GDI + DirectWrite 統一注入 **Noto Sans TC Bold 700** | 僅部分文字粗體，多數地方仍為細體 |
| **簡體中文回退** | DirectWrite 與瀏覽器 100% 強制回退 **Noto Sans SC Bold** | 遇到簡體字常退回破舊細明體或宋體（SimSun） |
| **圖示保護機制** | 內建嚴格圖示白名單，保護 `Segoe Fluent Icons` 絕無豆腐塊 | 網址列麵包屑箭頭、按鈕圖示容易變成方塊 ▯ |
| **檔案總管 WinUI 3** | 透過專屬 XAML 樣式注入回退鏈，網址列與標籤頁全粗體 | 網址列維持預設細體，無法統一風格 |
| **系統安全性** | 記憶體實時攔截，不破壞 Windows 系統核心字型檔案 | 破壞性修改註冊表，升級系統易崩潰或失效 |
| **還原便利性** | 一鍵停用模組，立即 100% 還原 Windows 官方預設 | 備份註冊表若缺失則極難乾淨還原 |

---

## 📥 支援環境與前置需求

- **作業系統**：Windows 10 / Windows 11 (x64 / ARM64 / x86)
- **前置工具**：[Windhawk](https://windhawk.net/)（官方開源 Windows 客製化注入平台，工具包內已附安裝檔）
- **字型資源**：Google Fonts 思源黑體（專案內已包含 `NotoSansTC-Bold.ttf` 與 `NotoSansSC-Bold.ttf`）

---

## 🚀 安裝方式

您可以選擇 **「方式一：一鍵自動化安裝（推薦）」** 或 **「方式二：Windhawk 官方介面手動安裝」**。

### 方式一：一鍵自動化安裝（推薦首選）

工具包內已預先編譯好原生 64 位元與 32 位元模組 DLL，並配置好完整的檔案總管樣式與字型註冊：

1. 開啟本專案資料夾（或桌面上的 `Windows_NotoSans_Font_Tool`）。
2. 對 **`Install-Mod.bat`** 按滑鼠右鍵，選擇 **「以系統管理員身分執行」**（或直接雙擊，彈出 UAC 權限確認視窗時點選「是」）。
3. 腳本將自動執行：
   - 檢測 Windhawk 是否已安裝（未安裝將引導手動安裝）
   - 安裝並載入思源黑體繁體粗體（TC Bold）與簡體粗體（SC Bold）
   - 阻斷宋體（SimSun）與細明體（MingLiU）回退洩漏
   - 部署並註冊 `windows-noto-sans-cjk` Windhawk 全域字型模組
   - 自動配置檔案總管 WinUI 3 網址列字型回退鏈（解決圖示並保證粗體）
   - 重啟 Windhawk 服務與檔案總管即時生效
   - 自動啟動實機字型渲染檢驗，輸出測試成果。

---

### 方式二：Windhawk 官方介面手動編譯安裝

如果您偏好透過 Windhawk 官方圖形介面自源碼編譯並安裝模組：

1. **安裝 Windhawk**：若尚未安裝，請至 [Windhawk 官方網站](https://windhawk.net/) 下載安裝。
2. **開啟進階開發模式**：
   - 開啟 Windhawk 主視窗，點擊右上角 **設定 (齒輪圖示)**。
   - 切換至 **「進階 (Advanced)」** 標籤頁。
   - 找到 **「模組開發 (Mod development)」** 並勾選啟用。
3. **建立新模組**：
   - 回到 Windhawk 主畫面，點選左側或右上角的 **「新增模組 (+ New Mod)」**。
4. **貼上模組源碼**：
   - 開啟本專案中的 **`windows-noto-sans-cjk.wh.cpp`**，全選並複製內容。
   - 貼入 Windhawk 的模組編輯器中，覆蓋原有範本程式碼。
5. **編譯並安裝**：
   - 點擊編輯器右上角或上方的 **「Compile Mod (編譯模組)」**。
   - 編譯成功（0 errors）後，點擊 **「Install (安裝)」**。
6. **配置檔案總管樣式**（選用，使網址列粗體）：
   - 在 Windhawk 模組市集中搜尋並安裝 **`Windows 11 File Explorer Styler`**。
   - 進入該模組的「Settings (設定)」，在 `controlStyles[0]` 的樣式中加入：
     - Target: `TextBlock`
     - Styles: `FontFamily=Noto Sans TC, Segoe Fluent Icons, Segoe MDL2 Assets`, `FontWeight=Bold`
   - 點擊「Save (儲存)」即刻生效。

---

## ⚙️ 模組自訂設定說明

安裝完成後，您可在 Windhawk 軟體主介面中的 `windows-noto-sans-cjk` 模組卡片點擊 **「Details」->「Settings」** 自訂以下參數：

| 設定項目 | 預設值 | 說明 |
| :--- | :--- | :--- |
| `targetFontTC` | `Noto Sans TC` | 繁體中文與預設系統 UI 替換字型名稱 |
| `targetFontSC` | `Noto Sans SC Bold` | 簡體中文字元強制回退字型名稱 |
| `enforceBold` | `true` (啟用) | 是否強制全系統 UI 字型以 Bold 700 粗體權重呈現 |

---

## 🔍 實機視覺檢驗工具

為確保每一項字型改變皆能正確呈現，專案內建專屬自動化實機檢驗工具：

- 雙擊執行 **`Test-FontRendering.bat`**：
  1. **瀏覽器 DirectWrite 實測**：透過 Chrome / Edge 進行無頭渲染，檢驗繁體、簡體「費」「門」「國」及混排回退，儲存至 `docs/font_visual_verification_test.png`。
  2. **檔案總管實體視窗實測**：透過 Win32 Desktop API 直接截取真實運作中的檔案總管視窗，檢驗網址列粗體、麵包屑箭頭與各功能按鈕，儲存至 `docs/explorer_address_bar_verified.png`。

---

## 🔄 一鍵解除安裝與還原

若需要移除模組並完全還原回 Windows 原廠預設字型：

1. 對 **`Uninstall-Mod.bat`** 按右鍵以管理員身分執行。
2. 腳本會自動從 Windhawk 卸載模組、清除檔案總管樣式、還原註冊表 FontLink 與預設字型。
3. 重啟檔案總管後，系統將 100% 恢復 Windows 原廠狀態。

---

## 📂 乾淨精簡的專案結構

```
windows-noto-cjk-system-font/
│
├── windows-noto-sans-cjk.wh.cpp     # 【核心】Windhawk 官方規範模組源碼 (含元數據、Readme、設定與 C++ Hook)
├── windows-noto-sans-cjk_64.dll     # 預先編譯 64 位元模組 DLL
├── windows-noto-sans-cjk_32.dll     # 預先編譯 32 位元模組 DLL
│
├── NotoSansTC-Bold.ttf              # 思源黑體繁體粗體字型 (Bold 700)
├── NotoSansSC-Bold.ttf              # 思源黑體簡體粗體字型 (Bold 700)
│
├── Install-Mod.bat                  # 一鍵自動安裝啟動器 (管理員提權)
├── Install-Mod.ps1                  # 核心安裝部署與檢測腳本
├── Uninstall-Mod.bat                # 一鍵乾淨解除安裝啟動器
├── Uninstall-Mod.ps1                # 核心還原腳本
│
├── Test-FontRendering.bat           # 實機雙重視覺化檢驗工具啟動器
├── Test-FontRendering.ps1           # 雙重視覺化檢測邏輯
├── verify_live_explorer.py          # 實體檔案總管視窗動態截圖檢驗核心
│
├── docs/                            # 實機驗證成果截圖目錄
│   ├── preview.png                  # 全系統預覽圖
│   ├── font_visual_verification_test.png # DirectWrite 繁簡混排實測圖
│   └── explorer_address_bar_verified.png # 檔案總管網址列與圖示實測圖
│
├── LICENSE                          # MIT 開源授權
└── README.md                        # 專案說明文件
```

---

## ❓ 常見問答 (FAQ)

#### Q1: 為什麼瀏覽器上的部分簡體字先前會變成宋體（SimSun）或細明體？
A: Windows 的 DirectWrite 字型回退機制在找不到簡體對應字時，預設會回退至系統內建的 `SimSun` 或 `MingLiU`。本模組直接攔截 DirectWrite 的 `IDWriteFontFallback` 介面，並將 `Noto Sans SC Bold` 注入為首選回退，同時由安裝腳本阻斷 SimSun 回退，徹底杜絕破字現象。

#### Q2: 檔案總管網址列的箭頭符號（>）為什麼會變豆腐塊？
A: 檔案總管的麵包屑分隔箭頭與電腦圖示為 Segoe Fluent Icons 字元（如 `\uE76C`）。如果直接將 `FontFamily` 設定為單一 `Noto Sans TC`，因該字型沒有圖示編碼而出現豆腐塊。本專案採用 XAML 字型回退鏈 `Noto Sans TC, Segoe Fluent Icons, Segoe MDL2 Assets`，中文走思源黑體粗體，圖示符號自動順延至 Segoe 圖示，完美兼顧粗體與圖示完整。

---

## 📄 授權條款 (License)

- 程式碼與安裝腳本：遵循 [MIT License](LICENSE)。
- 思源黑體字型（Noto Sans TC / SC）：遵循 [SIL Open Font License (OFL)](https://openfontlicense.org/) 開源字型授權。
