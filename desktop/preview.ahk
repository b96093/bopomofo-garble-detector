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

w := layout.w, h := layout.h
hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
hdc := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
bi := Buffer(40, 0)
NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8)
NumPut("UShort", 1, bi, 12), NumPut("UShort", 24, bi, 14)
pBits := 0
bm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &pBits,
    "Ptr", 0, "UInt", 0, "Ptr")
ob := DllCall("SelectObject", "Ptr", hdc, "Ptr", bm, "Ptr")

RoundBox(hdc, 0, 0, w, h, 0, CO.bg)
for op in layout.ops {
    if (op.t == "box")
        RoundBox(hdc, op.x, op.y, op.w, op.h, op.r, op.fill,
            op.HasOwnProp("border") ? op.border : -1)
    else if (op.t == "text")
        DrawStr(hdc, op.x, op.y, op.w, op.h, op.s, op.c, op.pt, op.a, op.HasOwnProp("wt") ? op.wt : 400)
    else if (op.t == "logo")
        DrawIcon(hdc, op.x, op.y, op.s, A_ScriptDir . "\icon.ico")
}
DllCall("GdiFlush")

stride := ((w * 3 + 3) // 4) * 4
buf := Buffer(stride * h, 0)
DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", pBits, "UPtr", stride * h)
f := FileOpen(A_ScriptDir . "\_preview.bin", "w")
f.RawWrite(buf, stride * h)
f.Close()
try FileDelete(A_ScriptDir . "\_preview.txt")
FileAppend(w . " " . h . " " . stride, A_ScriptDir . "\_preview.txt", "UTF-8")

DllCall("SelectObject", "Ptr", hdc, "Ptr", ob)
DllCall("DeleteObject", "Ptr", bm)
DllCall("DeleteDC", "Ptr", hdc)
DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
ExitApp()
