"""由 desktop/icon.ico 產生「已暫停」用的灰階圖示 desktop/icon-paused.ico。

為什麼需要：系統列圖示要能一眼看出目前是監看中還是已暫停 —— 就像 OneDrive
用灰階表示狀態一樣。單靠滑鼠停留才看得到的提示文字不夠。

只做去色，不刻意調淡。第一版把亮度拉到 1.25 的結果是 16px 下幾乎看不見 ——
暫停時使用者會找不到圖示，那比看不出狀態更糟。
目標是「明顯沒有顏色」而不是「明顯很淡」。

注意：ICO 存檔不能用 append_images（那是給 GIF/PDF/TIFF 的），
要把最大張處理好之後交給 PIL 用 sizes= 自行縮放，否則會存出 0 KB 的空檔。

用法：python build/make-paused-icon.py
"""

from pathlib import Path

from PIL import Image, ImageEnhance

SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

root = Path(__file__).resolve().parent.parent
src = root / "desktop" / "icon.ico"
dst = root / "desktop" / "icon-paused.ico"

im = Image.open(src)
im.size = (256, 256)          # 取最大張來處理，縮放交給 PIL
im = im.convert("RGBA")
alpha = im.getchannel("A")

rgb = im.convert("RGB").convert("L").convert("RGB")
rgb = ImageEnhance.Brightness(rgb).enhance(0.9)   # 略暗一點，在淺色工作列上更清楚

out = rgb.convert("RGBA")
out.putalpha(alpha)
out.save(dst, format="ICO", sizes=SIZES)

print(f"已產生 {dst.name}（{dst.stat().st_size / 1024:.0f} KB，{len(SIZES)} 種尺寸）")
