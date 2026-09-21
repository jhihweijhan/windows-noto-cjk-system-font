# 🌐 瀏覽器思源黑體全網字型修正擴充套件 (Noto Sans CJK Enforcer)

徹底解決 Chromium 核心瀏覽器 (Google Chrome / Microsoft Edge / Brave 等) 在 Windows 下遇見簡體字時，因 DirectWrite 回退跌入「宋體/細明體 (SimSun)」造成的字型破裂、毛刺問題。

---

## 🚀 啟用方式（任選一種即可）

### 方案 A：直接載入擴充套件（最推薦，10 秒完成，免裝任何插件）

1. 開啟 Chrome 網址輸入 `chrome://extensions`（或 Edge 輸入 `edge://extensions`）。
2. 在右上角開啟 **「開發人員模式」 (Developer mode)**。
3. 點選左上方 **「載入未封裝項目」 (Load unpacked)**。
4. 選擇本資料夾：
   `C:\Users\Karl\Desktop\Windows_NotoSans_Font_Tool\Browser_NotoSans_Extension`
5. 完成！所有網頁重新整理後即強制生效，所有繁簡文字均呈現飽滿黑體。

---

### 方案 B：使用油猴腳本 (Tampermonkey / Violentmonkey / 腳本貓)

若您平常有使用 Tampermonkey 或 Violentmonkey：
1. 點擊安裝資料夾內的 `NotoSans_Universal_Enforcer.user.js`。
2. 點選「安裝」即可全域生效。
