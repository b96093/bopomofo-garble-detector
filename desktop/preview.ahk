#Requires AutoHotkey v2.0
; 開發用：把候選窗渲染成原始像素檔，供 preview.py 轉成圖片檢視
; 用途是調整版面／字型時，不必實際執行程式就能看到結果
;   執行：AutoHotkey64.exe preview.ahk  然後  python preview.py
global DPIF := A_ScreenDPI / 96
global TRAYCOLS := 10
#Include draw.ahk

view := {
    cands: ["我想說你愛我媽", "我想說妳愛我媽"],
    sel: 2,
    draft: ["我", "想", "說", "妳", "愛", "我", "媽"],
    zone: "tray",
    ci: 4,
    hi: 2,
    draftText: "我想說妳愛我媽"
}
homs := ["你", "妳", "擬", "昵", "旎", "薿", "禰", "抳", "儗", "坭", "柅", "袮", "苨", "秜"]
layout := BuildLayout(view, (k) => (k = 4 ? homs : ["甲", "乙", "丙"]))

r := RenderLayered(layout, A_ScriptDir . "\icon.ico")
w := r.w, h := r.h
; 把 PARGB 內容倒出來（預覽用；正式程式是直接交給分層視窗）
bi2 := Buffer(40, 0)
NumPut("UInt", 40, bi2, 0), NumPut("Int", w, bi2, 4), NumPut("Int", -h, bi2, 8)
NumPut("UShort", 1, bi2, 12), NumPut("UShort", 32, bi2, 14)
tmpDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
pBits := 0
tmp := DllCall("CreateDIBSection", "Ptr", tmpDC, "Ptr", bi2, "UInt", 0, "Ptr*", &pBits,
    "Ptr", 0, "UInt", 0, "Ptr")
ot := DllCall("SelectObject", "Ptr", tmpDC, "Ptr", tmp, "Ptr")
DllCall("BitBlt", "Ptr", tmpDC, "Int", 0, "Int", 0, "Int", w, "Int", h,
    "Ptr", r.dc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
DllCall("GdiFlush")
buf := Buffer(w * h * 4, 0)
DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", pBits, "UPtr", w * h * 4)
f := FileOpen(A_ScriptDir . "\_preview.bin", "w")
f.RawWrite(buf, w * h * 4)
f.Close()
try FileDelete(A_ScriptDir . "\_preview.txt")
FileAppend(w . " " . h . " " . (w * 4), A_ScriptDir . "\_preview.txt", "UTF-8")
DllCall("SelectObject", "Ptr", tmpDC, "Ptr", ot)
DllCall("DeleteObject", "Ptr", tmp)
DllCall("DeleteDC", "Ptr", tmpDC)
ReleaseRender(r)
ExitApp()
