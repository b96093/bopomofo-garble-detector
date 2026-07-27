#Requires AutoHotkey v2.0
; 候選窗自繪模組
; Windows 原生文字控制項只能設背景色與文字色，做不出圓角與邊框，
; 所以整個候選窗改由這裡用繪圖 API 畫成一張圖，再貼到視窗上。
; 好處：外觀完全可控、一次畫完不閃爍。代價：滑鼠點擊要自己判斷落在哪一格。

; ---------- 版面尺寸（邏輯像素，實際會乘上螢幕縮放） ----------
global LY := {
    pad: 14,
    headH: 24,
    candH: 30, candR: 7,
    gap: 8,
    labelH: 18,
    cell: 36, cellGap: 5, cellR: 8,
    trayPad: 7, trayR: 10,
    tcell: 32, tcellGap: 4, tcellR: 7,
    btnH: 34, btnR: 9,
    footH: 18
}

; ---------- 配色 ----------
global CO := {
    bg: 0xFFFFFF,
    text: 0x1E1E1E,
    muted: 0x8A8A8A,
    faint: 0xAAAAAA,
    accent: 0x1A5FB4,
    accentSoft: 0x3A76D8,
    selBg: 0xE8F1FD,
    selBgDim: 0xF3F3F3,
    cellBg: 0xFFFFFF,
    cellBorder: 0xDCDCDC,
    cellBorderOn: 0x3A76D8,
    trayBg: 0xF7F7F7,
    line: 0xECECEC,
    btnBg: 0xE8F1FD
}

; 邏輯像素 → 實體像素
DPX(v) {
    return Round(v * DPIF)
}

; 0xRRGGBB → GDI 的 0x00BBGGRR
BGR(c) {
    return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
}

; ---------- 字型快取 ----------
global FONTS := Map()
GetFont(pt, bold := false) {
    key := pt . "|" . (bold ? 1 : 0)
    if FONTS.Has(key)
        return FONTS[key]
    h := DllCall("CreateFont", "Int", -Round(pt * A_ScreenDPI / 72), "Int", 0, "Int", 0, "Int", 0,
        "Int", bold ? 700 : 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0,
        "UInt", 4, "UInt", 0, "Str", "Microsoft JhengHei", "Ptr")
    FONTS[key] := h
    return h
}

; ---------- 基本繪圖 ----------
; 圓角矩形；borderColor 傳 -1 表示不畫邊框
RoundBox(hdc, x, y, w, h, r, fill, borderColor := -1) {
    hbr := DllCall("CreateSolidBrush", "UInt", BGR(fill), "Ptr")
    if (borderColor = -1)
        hpen := DllCall("CreatePen", "Int", 5, "Int", 0, "UInt", 0, "Ptr")   ; PS_NULL
    else
        hpen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", BGR(borderColor), "Ptr")
    ob := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbr, "Ptr")
    op := DllCall("SelectObject", "Ptr", hdc, "Ptr", hpen, "Ptr")
    if (r > 0)
        DllCall("RoundRect", "Ptr", hdc, "Int", x, "Int", y, "Int", x + w, "Int", y + h,
            "Int", r * 2, "Int", r * 2)
    else
        DllCall("Rectangle", "Ptr", hdc, "Int", x, "Int", y, "Int", x + w, "Int", y + h)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", ob)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", op)
    DllCall("DeleteObject", "Ptr", hbr)
    DllCall("DeleteObject", "Ptr", hpen)
}

; align：0=靠左 1=置中 2=靠右（皆垂直置中）
DrawStr(hdc, x, y, w, h, text, color, pt, align := 0, bold := false) {
    if (text == "")
        return
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)                  ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", hdc, "UInt", BGR(color))
    of := DllCall("SelectObject", "Ptr", hdc, "Ptr", GetFont(pt, bold), "Ptr")
    rc := Buffer(16, 0)
    NumPut("Int", x, rc, 0), NumPut("Int", y, rc, 4)
    NumPut("Int", x + w, rc, 8), NumPut("Int", y + h, rc, 12)
    fmt := 0x24 | (align = 1 ? 0x1 : (align = 2 ? 0x2 : 0))     ; VCENTER|SINGLELINE
    fmt |= 0x8000                                               ; DT_END_ELLIPSIS
    DllCall("DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", fmt)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", of)
}

; ---------- 版面計算 ----------
; 回傳 {w, h, ops, hits}；ops 是繪圖指令，hits 是可點擊區域（實體像素）
BuildLayout(view, homsFor) {   ; 參數不可命名 st，會撞到全域 ST
    global TRAYCOLS
    inSent := (view.zone == "sent")
    pad := DPX(LY.pad)
    ops := [], hits := []

    ; 內容寬度：候選字長度與逐字列長度取大者
    maxLen := 0
    for c in view.cands
        maxLen := Max(maxLen, StrLen(c))
    cw := Max(DPX(300), DPX(24) + maxLen * DPX(22))
    perRow := Max(6, Min(view.draft.Length, 14))
    cw := Max(cw, perRow * DPX(LY.cell + LY.cellGap))
    cw := Min(cw, DPX(700))
    cols := Max(6, cw // DPX(LY.cell + LY.cellGap))

    y := pad

    ; 標題列
    ops.Push({t: "logo", x: pad, y: y + DPX(2), s: DPX(17)})
    DrawS(ops, pad + DPX(24), y, cw - DPX(24), DPX(LY.headH), "偵測到注音亂碼　（按這裡拖曳）", CO.muted, 9)
    hits.Push({k: "drag", x: 0, y: 0, w: cw + pad * 2, h: y + DPX(LY.headH)})
    y += DPX(LY.headH) + DPX(6)

    ; 整句候選
    for i, c in view.cands {
        sel := (i == view.sel)
        bg := sel ? (inSent ? CO.selBg : CO.selBgDim) : CO.bg
        h := DPX(LY.candH)
        if (sel)
            ops.Push({t: "box", x: pad, y: y, w: cw, h: h, r: DPX(LY.candR), fill: bg})
        DrawS(ops, pad + DPX(10), y, cw - DPX(60), h, c, CO.text, 12)
        if (sel && inSent)
            DrawS(ops, pad + cw - DPX(48), y, DPX(40), h, "Enter", CO.accentSoft, 8, 2)
        hits.Push({k: "cand", i: i, x: pad, y: y, w: cw, h: h})
        y += h + DPX(3)
    }

    ; 分隔線與說明
    y += DPX(5)
    ops.Push({t: "box", x: pad, y: y, w: cw, h: 1, r: 0, fill: CO.line})
    y += DPX(9)
    DrawS(ops, pad, y, cw, DPX(LY.labelH), "逐字換同音字（點字，或按 ↓ 進入）", CO.muted, 8.5)
    y += DPX(LY.labelH) + DPX(4)

    ; 逐字列
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
            DrawS(ops, cx, y, cell, cell, ch, focus ? CO.accent : CO.text, 12, 1)
            hits.Push({k: "char", i: k, x: cx, y: y, w: cell, h: cell})
        } else {
            DrawS(ops, cx, y, cell, cell, ch, CO.faint, 12, 1)
        }
        col++
        if (col >= cols) {
            col := 0
            y += cell + cgap
        }
    }
    if (col > 0)
        y += cell + cgap

    ; 同音字盤
    if (view.zone == "tray") {
        homs := homsFor(view.ci)
        if (homs.Length) {
            tc := DPX(LY.tcell), tg := DPX(LY.tcellGap), tp := DPX(LY.trayPad)
            tcols := Max(6, (cw - tp * 2) // (tc + tg))
            TRAYCOLS := tcols          ; 讓鍵盤上下換行知道實際欄數
            rows := (homs.Length + tcols - 1) // tcols
            trayH := rows * (tc + tg) - tg + tp * 2
            ops.Push({t: "box", x: pad, y: y, w: cw, h: trayH, r: DPX(LY.trayR), fill: CO.trayBg})
            tx0 := pad + tp, ty := y + tp
            tcol := 0
            for i, w in homs {
                bx := tx0 + tcol * (tc + tg)
                cur := (w == view.draft[view.ci])
                foc := (i == view.hi)
                ops.Push({t: "box", x: bx, y: ty, w: tc, h: tc, r: DPX(LY.tcellR),
                    fill: foc ? CO.selBg : CO.cellBg,
                    border: foc ? CO.cellBorderOn : (cur ? CO.accentSoft : CO.cellBorder)})
                DrawS(ops, bx, ty, tc, tc, w, foc ? CO.accent : CO.text, 11, 1)
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

    ; 插入鈕
    y += DPX(4)
    bh := DPX(LY.btnH)
    ops.Push({t: "box", x: pad, y: y, w: cw, h: bh, r: DPX(LY.btnR), fill: CO.btnBg})
    DrawS(ops, pad, y, cw, bh, "↵ 改為「" . view.draftText . "」", CO.accent, 11, 1)
    hits.Push({k: "commit", x: pad, y: y, w: cw, h: bh})
    y += bh + DPX(8)

    ; 底部提示
    hint := inSent ? "↑↓ 選句 · ↓ 進逐字 · Enter 插入"
        : (view.zone == "chars") ? "←→ 選字 · ↓ 展開同音 · Enter 插入"
        : "←→↑↓ 選同音字 · Enter 換上 · Esc 返回"
    DrawS(ops, pad, y, cw - DPX(40), DPX(LY.footH), hint, CO.faint, 8)
    DrawS(ops, pad + cw - DPX(40), y, DPX(40), DPX(LY.footH), "Esc", CO.faint, 8, 2)
    y += DPX(LY.footH) + pad

    return {w: cw + pad * 2, h: y, ops: ops, hits: hits}
}

DrawS(ops, x, y, w, h, s, color, pt, align := 0) {
    ops.Push({t: "text", x: x, y: y, w: w, h: h, s: s, c: color, pt: pt, a: align})
}

; ---------- 實際畫成點陣圖 ----------
; 回傳 HBITMAP（呼叫端用完要 DeleteObject）
RenderBitmap(layout, iconPath) {
    w := layout.w, h := layout.h
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdc := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    ; 用 24 位元（不含透明度通道）：GDI 的矩形與文字不會填寫透明度，
    ; 若用 32 位元，那些像素的透明度會是 0（全透明），畫面上就只剩下圖示看得見。
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12), NumPut("UShort", 24, bi, 14)
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", 0,
        "Ptr", 0, "UInt", 0, "Ptr")
    obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")

    RoundBox(hdc, 0, 0, w, h, 0, CO.bg)          ; 底色

    for op in layout.ops {
        if (op.t == "box")
            RoundBox(hdc, op.x, op.y, op.w, op.h, op.r, op.fill,
                op.HasOwnProp("border") ? op.border : -1)
        else if (op.t == "text")
            DrawStr(hdc, op.x, op.y, op.w, op.h, op.s, op.c, op.pt, op.a)
        else if (op.t == "logo")
            DrawIcon(hdc, op.x, op.y, op.s, iconPath)
    }

    DllCall("SelectObject", "Ptr", hdc, "Ptr", obm)
    DllCall("DeleteDC", "Ptr", hdc)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    return hbm
}

DrawIcon(hdc, x, y, size, path) {
    hIcon := DllCall("LoadImage", "Ptr", 0, "Str", path, "UInt", 1,
        "Int", size, "Int", size, "UInt", 0x10, "Ptr")     ; LR_LOADFROMFILE
    if (hIcon) {
        DllCall("DrawIconEx", "Ptr", hdc, "Int", x, "Int", y, "Ptr", hIcon,
            "Int", size, "Int", size, "UInt", 0, "Ptr", 0, "UInt", 3)
        DllCall("DestroyIcon", "Ptr", hIcon)
    }
}

; 點擊落在哪一格（座標相對於視窗左上角）
HitTest(hits, x, y) {
    for hh in hits {
        if (x >= hh.x && x < hh.x + hh.w && y >= hh.y && y < hh.y + hh.h)
            return hh
    }
    return ""
}
