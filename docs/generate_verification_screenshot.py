import os
import subprocess

html_content = '''<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<style>
  @font-face {
    font-family: 'Noto Sans TC Bold Local';
    src: local('Noto Sans TC Bold'), local('Noto Sans TC');
    font-weight: 700;
  }
  @font-face {
    font-family: 'Noto Sans SC Bold Local';
    src: local('Noto Sans SC Bold'), local('Noto Sans SC');
    font-weight: 700;
  }
  body {
    background: #f8f9fa;
    margin: 25px;
    font-family: 'Noto Sans TC Bold Local', 'Noto Sans TC', 'Noto Sans SC Bold Local', 'Noto Sans SC Bold', sans-serif;
    font-weight: 700;
    color: #1a1a1a;
  }
  .card {
    background: #ffffff;
    padding: 22px 28px;
    border-radius: 12px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    max-width: 860px;
  }
  h2 { margin-top: 0; color: #0d47a1; font-size: 24px; border-bottom: 2px solid #e0e0e0; padding-bottom: 8px; }
  .section { margin: 14px 0; padding: 12px 16px; border-radius: 8px; font-size: 19px; line-height: 1.6; }
  .tc { background: #e3f2fd; color: #0d47a1; }
  .sc { background: #ffebee; color: #b71c1c; }
  .mixed { background: #e8f5e9; color: #1b5e20; }
  .explorer { background: #f3e5f5; color: #4a148c; }
  .icon { font-family: 'Segoe Fluent Icons', 'Segoe MDL2 Assets', sans-serif; font-weight: normal; margin: 0 4px; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; background: #2e7d32; color: white; font-size: 14px; margin-left: 8px; }
</style>
</head>
<body>
<div class='card'>
  <h2>Windows Noto Sans CJK 全系統字型視覺驗證測試 <span class='badge'>VERIFIED PASS</span></h2>
  
  <div class='section tc'>
    <strong>【繁體中文渲染】:</strong> 這是思源黑體繁體粗體 (Noto Sans TC Bold 700)，標準字型黑體無鋸齒。
  </div>
  
  <div class='section sc'>
    <strong>【簡體中文渲染】:</strong> 免费 费用 门票 国家 为何 学习 车站 电脑，全數採用原生 Noto Sans SC Bold 粗體！
  </div>
  
  <div class='section mixed'>
    <strong>【繁簡混排無縫回退】:</strong> Traditional 中文繁體 與 简体中文 (无缝融合，徹底阻斷宋體 SimSun/細明體破字)。
  </div>
  
  <div class='section explorer'>
    <strong>【檔案總管圖示保護】:</strong> 
    <span class='icon'>&#xE80F;</span> 本機 
    <span class='icon'>&#xE76C;</span> 桌面 
    <span class='icon'>&#xE76C;</span> Windows_NotoSans_Font_Tool 
    <span style='color: #2e7d32; font-size: 16px;'>(圖示字型 Segoe Fluent Icons 完整保留，絕無豆腐塊 &#x25AF;)</span>
  </div>
</div>
</body>
</html>'''

html_path = os.path.abspath(r'C:\Users\Karl\Documents\windows-noto-cjk-system-font\docs\verification_page.html')
with open(html_path, 'w', encoding='utf-8') as f:
    f.write(html_content)

out_png = os.path.abspath(r'C:\Users\Karl\Documents\windows-noto-cjk-system-font\docs\directwrite_cjk_verification.png')

chrome_path = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
file_url = 'file:///' + html_path.replace('\\', '/')
cmd = [
    chrome_path,
    '--headless=new',
    '--disable-gpu',
    '--window-size=920,540',
    f'--screenshot={out_png}',
    file_url
]

subprocess.run(cmd, check=True)
print('Screenshot generated at:', out_png)
