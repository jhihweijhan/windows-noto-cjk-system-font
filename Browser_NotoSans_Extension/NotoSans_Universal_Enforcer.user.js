// ==UserScript==
// @name         Noto Sans CJK 全網字型增強 (強制所有簡字採用 Noto Sans SC Bold)
// @namespace    https://github.com/jhihweijhan/windows-noto-cjk-system-font
// @version      1.1.0
// @description  強制所有網頁字型優先使用 Noto Sans TC 與 Noto Sans SC Bold，杜絕簡體字跌入宋體/細明體或 Thin 字重
// @author       jhihweijhan
// @match        *://*/*
// @run-at       document-start
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';
    const css = `
    :where(
      html, body, div, span, h1, h2, h3, h4, h5, h6, p, blockquote,
      a, abbr, address, del, em, ins, q, s, small, strong, sub, sup, b, u, i,
      dl, dt, dd, ol, ul, li, form, label, legend, table, caption, tbody, tfoot,
      thead, tr, th, td, article, aside, details, figure, figcaption, footer,
      header, nav, section, summary, input, button, textarea, select
    ):not([class*="icon"]):not([class*="fa-"]):not([class*="material-"]):not([class*="glyph"]):not([class*="v-icon"]):not([class*="codicon"]) {
        font-family: "Noto Sans TC", "Noto Sans SC Bold", "Noto Sans SC", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
    }
    :where(code, kbd, samp, pre) {
        font-family: "Cascadia Code", "Consolas", "Noto Sans TC", monospace !important;
    }
    `;
    if (typeof GM_addStyle !== 'undefined') {
        GM_addStyle(css);
    } else {
        const style = document.createElement('style');
        style.textContent = css;
        (document.head || document.documentElement).appendChild(style);
    }
})();
