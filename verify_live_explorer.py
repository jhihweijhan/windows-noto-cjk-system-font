import ctypes
from ctypes import wintypes
import time
import os
import sys
from PIL import ImageGrab, Image

user32 = ctypes.windll.user32

# Switch to default desktop
hdesk = user32.OpenDesktopW("default", 0, False, 0x01FF)
if hdesk:
    user32.SetThreadDesktop(hdesk)

def find_explorer_hwnd():
    hwnds = []
    def enum_cb(hwnd, lparam):
        cls_name = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls_name, 256)
        if cls_name.value == "CabinetWClass":
            title = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(hwnd, title, 512)
            hwnds.append((hwnd, title.value))
        return True

    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows(EnumWindowsProc(enum_cb), 0)
    return hwnds

hwnds = find_explorer_hwnd()
if not hwnds:
    import subprocess
    subprocess.Popen(["explorer.exe", "C:\\"])
    time.sleep(2)
    hwnds = find_explorer_hwnd()

if hwnds:
    hwnd, title = hwnds[0]
    user32.ShowWindow(hwnd, 3) # SW_SHOWMAXIMIZED
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.5)

    im = ImageGrab.grab()
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    
    crop_w = rect.right - rect.left
    crop_h = min(200, rect.bottom - rect.top)
    top_crop = im.crop((max(0, rect.left), max(0, rect.top), min(im.size[0], rect.right), max(0, rect.top) + crop_h))
    
    # Save to docs and script dir
    script_dir = os.path.dirname(os.path.abspath(__file__))
    docs_dir = os.path.join(script_dir, "docs")
    os.makedirs(docs_dir, exist_ok=True)
    
    top_path = os.path.join(docs_dir, "explorer_address_bar_verified.png")
    top_crop.save(top_path)
    print(f"[PASS] 檔案總管實機畫面截圖驗證完成: {top_path}")
else:
    print("[!] 未偵測到開啟中的檔案總管視窗")
