#Requires AutoHotkey v2.0
; 候選窗自繪模組（GDI+）
;
; 為什麼用 GDI+ 而不是傳統 GDI：
;   分層視窗能把「位置、大小、畫面內容」一次原子性送出，系統不會出現中間畫面，
;   這正是 Chrome 版流暢不閃的原理。但它需要帶透明度的圖，而傳統 GDI 繪圖
;   不會填寫透明度；GDI+ 會，而且順便有抗鋸齒（圓角邊緣更平滑）。

; ---------- 版面尺寸（邏輯像素，實際會乘上螢幕縮放） ----------
global LY := {
    pad: 14,
    headH: 24,
    candH: 30, candR: 7,
    labelH: 18,
    cell: 38, cellGap: 5, cellR: 9,
    trayPad: 7, trayR: 10,
    tcell: 34, tcellGap: 4, tcellR: 8,
    btnH: 34, btnR: 9,
    footH: 18,
    winR: 12
}

; ---------- 配色（0xAARRGGBB） ----------
global CO := {
    bg: 0xFFFFFFFF,
    text: 0xFF1E1E1E,
    muted: 0xFF707070,
    faint: 0xFF909090,
    accent: 0xFF1A5FB4,
    accentSoft: 0xFF3A76D8,
    selBg: 0xFFE8F1FD,
    selBgDim: 0xFFF3F3F3,
    cellBg: 0xFFFFFFFF,
    cellBorder: 0xFFDCDCDC,
    cellBorderOn: 0xFF3A76D8,
    trayBg: 0xFFF7F7F7,
    line: 0xFFECECEC,
    btnBg: 0xFFE8F1FD,
    winBorder: 0xFFD8D8D8
}

global GDIP_TOKEN := 0

DPX(v) {
    return Round(v * DPIF)
}

GdipInit() {
    global GDIP_TOKEN
    if (GDIP_TOKEN)
        return
    DllCall("LoadLibrary", "Str", "gdiplus")
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)                 ; GdiplusVersion
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", si, "Ptr", 0)
    GDIP_TOKEN := token
}

; ---------- 繪圖基本元件 ----------
MakeRoundPath(x, y, w, h, r) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path := 0)
    if (r <= 0) {
        DllCall("gdiplus\GdipAddPathRectangle", "Ptr", path,
            "Float", x, "Float", y, "Float", w, "Float", h)
    } else {
        d := r * 2
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y,
            "Float", d, "Float", d, "Float", 180, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y,
            "Float", d, "Float", d, "Float", 270, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d,
            "Float", d, "Float", d, "Float", 0, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d,
            "Float", d, "Float", d, "Float", 90, "Float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    }
    return path
}

FillRound(g, x, y, w, h, r, argb, borderArgb := 0) {
    path := MakeRoundPath(x, y, w, h, r)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    if (borderArgb) {
        DllCall("gdiplus\GdipCreatePen1", "UInt", borderArgb, "Float", 1, "Int", 2, "Ptr*", &pen := 0)
        DllCall("gdiplus\GdipDrawPath", "Ptr", g, "Ptr", pen, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

; align：0=靠左 1=置中 2=靠右（皆垂直置中）
DrawStr(g, x, y, w, h, text, argb, pt, align := 0, bold := false) {
    if (text == "")
        return
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "Str", "Microsoft JhengHei",
        "Ptr", 0, "Ptr*", &family := 0)
    if (!family)
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "Str", "Microsoft YaHei",
            "Ptr", 0, "Ptr*", &family)
    px := pt * A_ScreenDPI / 72
    DllCall("gdiplus\GdipCreateFont", "Ptr", family, "Float", px, "Int", bold ? 1 : 0,
        "Int", 2, "Ptr*", &font := 0)                       ; 單位 2 = 像素
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt := 0)
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)   ; 垂直置中
    DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", 0x4000)  ; 不裁切
    rc := Buffer(16, 0)
    NumPut("Float", x, rc, 0), NumPut("Float", y, rc, 4)
    NumPut("Float", w, rc, 8), NumPut("Float", h, rc, 12)
    DllCall("gdiplus\GdipDrawString", "Ptr", g, "Str", text, "Int", -1, "Ptr", font,
        "Ptr", rc, "Ptr", fmt, "Ptr", br)
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", family)
}

; 拖曳握把：2 欄 3 列的小圓點，是通用的「可拖曳」記號
DrawGrip(g, x, y, argb) {
    d := DPX(3)          ; 點的直徑
    gap := DPX(4)        ; 點的間距
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
    Loop 2 {
        cx := x + (A_Index - 1) * gap
        Loop 3 {
            cy := y + (A_Index - 1) * gap
            DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", br,
                "Float", cx, "Float", cy, "Float", d, "Float", d)
        }
    }
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}

DrawIconImg(g, x, y, size, path) {
    hIcon := DllCall("LoadImage", "Ptr", 0, "Str", path, "UInt", 1,
        "Int", size, "Int", size, "UInt", 0x10, "Ptr")
    if (!hIcon)
        return
    DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &img := 0)
    if (img) {
        DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", img,
            "Int", x, "Int", y, "Int", size, "Int", size)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", img)
    }
    DllCall("DestroyIcon", "Ptr", hIcon)
}

; ---------- 版面計算 ----------
BuildLayout(view, homsFor) {
    global TRAYCOLS
    inSent := (view.zone == "sent")
    pad := DPX(LY.pad)
    ops := [], hits := []

    maxLen := 0
    for c in view.cands
        maxLen := Max(maxLen, StrLen(c))
    cw := Max(DPX(300), DPX(24) + maxLen * DPX(22))
    perRow := Max(6, Min(view.draft.Length, 14))
    cw := Max(cw, perRow * DPX(LY.cell + LY.cellGap))
    ; 寬度取整到 60 的倍數，避免打字時每多一個字就改變視窗大小
    step := DPX(60)
    cw := Min(((cw + step - 1) // step) * step, DPX(700))
    cols := Max(6, cw // DPX(LY.cell + LY.cellGap))

    y := pad

    ops.Push({t: "logo", x: pad, y: y + DPX(2), s: DPX(17)})
    DrawS(ops, pad + DPX(24), y, cw - DPX(120), DPX(LY.headH), "偵測到注音亂碼", CO.muted, 9)
    ; 右側：握把符號 + 說明（整條標題列都可拖曳，符號只是提示）
    ops.Push({t: "grip", x: pad + cw - DPX(72), y: y + DPX(7), c: CO.faint})
    DrawS(ops, pad + cw - DPX(60), y, DPX(60), DPX(LY.headH), "按住可拖曳", CO.faint, 8, 2)
    hits.Push({k: "drag", x: 0, y: 0, w: cw + pad * 2, h: y + DPX(LY.headH)})
    y += DPX(LY.headH) + DPX(6)

    for i, c in view.cands {
        sel := (i == view.sel)
        h := DPX(LY.candH)
        if (sel)
            ops.Push({t: "box", x: pad, y: y, w: cw, h: h, r: DPX(LY.candR),
                fill: inSent ? CO.selBg : CO.selBgDim})
        DrawS(ops, pad + DPX(10), y, cw - DPX(60), h, c, CO.text, 13, 0)
        if (sel && inSent)
            DrawS(ops, pad + cw - DPX(52), y, DPX(44), h, "Enter", CO.accentSoft, 8, 2)
        hits.Push({k: "cand", i: i, x: pad, y: y, w: cw, h: h})
        y += h + DPX(3)
    }

    y += DPX(5)
    ops.Push({t: "box", x: pad, y: y, w: cw, h: 1, r: 0, fill: CO.line})
    y += DPX(9)
    DrawS(ops, pad, y, cw, DPX(LY.labelH), "逐字換同音字（點字，或按 ↓ 進入）", CO.muted, 8.5)
    y += DPX(LY.labelH) + DPX(4)

    col := 0
    cell := DPX(LY.cell), cgap := DPX(LY.cellGap)
    for k, ch in view.draft {
        editable := homsFor(k).Length > 0
        cx := pad + col * (cell + cgap)
        if (editable) {
            focus := (!inSent && k == view.ci)
            ops.Push({t: "box", x: cx, y: y, w: cell, h: cell, r: DPX(LY.cellR),
                fill: focus ? CO.selBg : CO.cellBg,
                border: focus ? CO.cellBorderOn : CO.cellBorder})
            DrawS(ops, cx, y, cell, cell, ch, focus ? CO.accent : CO.text, 13, 1)
            hits.Push({k: "char", i: k, x: cx, y: y, w: cell, h: cell})
        } else {
            DrawS(ops, cx, y, cell, cell, ch, CO.faint, 13, 1)
        }
        col++
        if (col >= cols) {
            col := 0
            y += cell + cgap
        }
    }
    if (col > 0)
        y += cell + cgap

    if (view.zone == "tray") {
        homs := homsFor(view.ci)
        if (homs.Length) {
            tc := DPX(LY.tcell), tg := DPX(LY.tcellGap), tp := DPX(LY.trayPad)
            tcols := Max(6, (cw - tp * 2) // (tc + tg))
            TRAYCOLS := tcols
            rows := (homs.Length + tcols - 1) // tcols
            trayH := rows * (tc + tg) - tg + tp * 2
            ops.Push({t: "box", x: pad, y: y, w: cw, h: trayH, r: DPX(LY.trayR), fill: CO.trayBg})
            tx0 := pad + tp, ty := y + tp
            tcol := 0
            for i, wch in homs {
                bx := tx0 + tcol * (tc + tg)
                cur := (wch == view.draft[view.ci])
                foc := (i == view.hi)
                ops.Push({t: "box", x: bx, y: ty, w: tc, h: tc, r: DPX(LY.tcellR),
                    fill: foc ? CO.selBg : CO.cellBg,
                    border: foc ? CO.cellBorderOn : (cur ? CO.accentSoft : CO.cellBorder)})
                DrawS(ops, bx, ty, tc, tc, wch, foc ? CO.accent : CO.text, 12, 1)
                hits.Push({k: "hom", i: i, x: bx, y: ty, w: tc, h: tc})
                tcol++
                if (tcol >= tcols) {
                    tcol := 0
                    ty += tc + tg
                }
            }
            y += trayH + DPX(6)
        }
    }

    y += DPX(4)
    bh := DPX(LY.btnH)
    ops.Push({t: "box", x: pad, y: y, w: cw, h: bh, r: DPX(LY.btnR), fill: CO.btnBg})
    DrawS(ops, pad, y, cw, bh, "↵ 改為「" . view.draftText . "」", CO.accent, 12, 1)
    hits.Push({k: "commit", x: pad, y: y, w: cw, h: bh})
    y += bh + DPX(8)

    hint := inSent ? "↑↓ 選句 · ↓ 進逐字 · Enter 插入"
        : (view.zone == "chars") ? "←→ 選字 · ↓ 展開同音 · Enter 插入"
        : "←→↑↓ 選同音字 · Enter 換上 · Esc 返回"
    DrawS(ops, pad, y, cw - DPX(44), DPX(LY.footH), hint, CO.faint, 8)
    DrawS(ops, pad + cw - DPX(40), y, DPX(40), DPX(LY.footH), "Esc", CO.faint, 8, 2)
    y += DPX(LY.footH) + pad

    return {w: cw + pad * 2, h: y, ops: ops, hits: hits}
}

DrawS(ops, x, y, w, h, s, color, pt, align := 0, bold := false) {
    ops.Push({t: "text", x: x, y: y, w: w, h: h, s: s, c: color, pt: pt, a: align, b: bold})
}

; ---------- 畫成帶透明度的點陣圖（供分層視窗使用） ----------
; 回傳 {hbm, dc, old, w, h}；呼叫端用完要 ReleaseRender()
RenderLayered(layout, iconPath) {
    GdipInit()
    w := layout.w, h := layout.h
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    dc := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
    pBits := 0
    hbm := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", bi, "UInt", 0, "Ptr*", &pBits,
        "Ptr", 0, "UInt", 0, "Ptr")
    obm := DllCall("SelectObject", "Ptr", dc, "Ptr", hbm, "Ptr")

    ; 直接對這塊記憶體繪圖；PARGB 是分層視窗要求的格式
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", w * 4,
        "Int", 0xE200B, "Ptr", pBits, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)          ; 抗鋸齒
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 3)      ; 文字抗鋸齒
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0x00000000)   ; 全透明

    ; 視窗底：圓角白底 + 細邊框（角落保持透明，邊緣有抗鋸齒）
    FillRound(g, 0, 0, w - 1, h - 1, DPX(LY.winR), CO.bg, CO.winBorder)

    for op in layout.ops {
        if (op.t == "box")
            FillRound(g, op.x, op.y, op.w, op.h, op.r, op.fill,
                op.HasOwnProp("border") ? op.border : 0)
        else if (op.t == "text")
            DrawStr(g, op.x, op.y, op.w, op.h, op.s, op.c, op.pt, op.a, op.b)
        else if (op.t == "logo")
            DrawIconImg(g, op.x, op.y, op.s, iconPath)
        else if (op.t == "grip")
            DrawGrip(g, op.x, op.y, op.c)
    }

    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    return {hbm: hbm, dc: dc, old: obm, w: w, h: h}
}

ReleaseRender(r) {
    DllCall("SelectObject", "Ptr", r.dc, "Ptr", r.old)
    DllCall("DeleteObject", "Ptr", r.hbm)
    DllCall("DeleteDC", "Ptr", r.dc)
}

; 點擊落在哪一格（座標相對於視窗左上角）
HitTest(hits, x, y) {
    for hh in hits {
        if (x >= hh.x && x < hh.x + hh.w && y >= hh.y && y < hh.y + hh.h)
            return hh
    }
    return ""
}
