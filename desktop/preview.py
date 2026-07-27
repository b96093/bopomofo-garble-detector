# 開發用：把 preview.ahk 產生的原始像素轉成 PNG 檢視
# 用法：先跑 preview.ahk，再執行 python preview.py
from PIL import Image
import pathlib

base = pathlib.Path(__file__).parent
w, h, stride = map(int, (base / "_preview.txt").read_text(encoding="utf-8-sig").split())
data = (base / "_preview.bin").read_bytes()
rows = [data[y * stride: y * stride + w * 4] for y in range(h)]
img = Image.frombytes("RGBA", (w, h), b"".join(rows))
b, g, r, a = img.split()                    # DIB 是 BGRA 順序
img = Image.merge("RGBA", (r, g, b, a))
bg = Image.new("RGB", (w, h), (235, 235, 235))   # 疊在灰底上，看得出透明圓角
bg.paste(img, (0, 0), img)
bg.save(base / "_preview.png")
print(f"已輸出 _preview.png  {w}x{h}")
