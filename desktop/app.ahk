#Requires AutoHotkey v2.0
#SingleInstance Force
; 注音亂碼偵測 — 桌面版（適用 Word / PPT 等所有 Windows 程式）
; 監看輸入 → 偵測 → 候選窗（3 整句候選 + 逐字換同音字）→ 退格 + 送出中文
;
; 隱私設計：輸入緩衝只存在記憶體、永不寫入檔案、完全不連網；
; 按下 Enter/Tab/Esc/方向鍵、點滑鼠、切換視窗都會立刻清空緩衝。
;
; 效能：候選窗的控制項只建立一次，之後只更新內容與位置（避免重建造成閃爍）。
#Include engine.ahk

global DICT := ""
global BUF := ""          ; 目前累積的輸入（只在記憶體）
global HIT := ""          ; 目前偵測結果 {res, offset}
global ST := ""           ; 候選窗狀態
global BUSY := false      ; 執行替換中，暫停監看避免吃到自己送出的按鍵
global PAUSED := false
global LASTWIN := 0
global POPUP := ""
global UI := ""           ; 控制項池
global POPUP_ON := false
; 注意：所有全域初始化都必須寫在第一個熱鍵之前，
; 因為 AHK 的自動執行區在遇到熱鍵定義時就結束了。

; 版面尺寸
global PAD := 13, CANDH := 27, CELL := 32, TCELL := 30, TCOLS := 10, CCOLS := 10
global MAXCAND := 3, MAXCHAR := 24, MAXHOM := 50
global CW := TCOLS * TCELL + 4

; 配色
global C_BG := "FFFFFF", C_SEL := "E8F1FD", C_SELDIM := "F3F3F3", C_CELL := "F7F7F7"
global C_TEXT := "1E1E1E", C_MUTED := "8A8A8A", C_ACCENT := "1A5FB4", C_LINE := "ECECEC"

; ---------- 啟動 ----------
TraySetIcon(A_ScriptDir "\icon.ico", 1, true)
A_IconTip := "注音亂碼偵測（載入中…）"
A_TrayMenu.Delete()
A_TrayMenu.Add("暫停 / 繼續偵測", (*) => TogglePause())
A_TrayMenu.Add("結束", (*) => ExitApp())

DICT := LoadDict(A_ScriptDir "\dict.txt")
BuildPopup()
A_IconTip := "注音亂碼偵測（監看中）"
Tip("注音亂碼偵測已啟動`n詞庫 " . DICT.Count . " 讀音", 2000)

; ---------- 全域監看 ----------
global IH := InputHook("V")
IH.OnChar := OnChar
IH.KeyOpt("{Enter}{Tab}{Escape}{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}", "N")
IH.OnKeyDown := OnResetKey
IH.KeyOpt("{BackSpace}", "N")
IH.Start()

SetTimer(WatchWindow, 400)

OnChar(hook, ch) {
    if (BUSY || PAUSED)
        return
    if !IsRunChar(ch) {           ; 中文字等非按鍵字元 → 視為新段落
        Reset()
        return
    }
    BUF .= ch
    SetTimer(Scan, -160)          ; 去抖動
}

OnResetKey(hook, vk, sc) {
    if (BUSY || POPUP_ON)         ; 候選窗開著時，方向鍵等交給熱鍵處理
        return
    if (vk = 8) {                 ; 退格：跟著縮短緩衝
        if (BUF != "")
            BUF := SubStr(BUF, 1, StrLen(BUF) - 1)
        SetTimer(Scan, -160)
        return
    }
    Reset()
}

; 切換視窗就清空（避免把上一個視窗的輸入帶過來）
WatchWindow() {
    global LASTWIN
    w := WinExist("A")
    if (w != LASTWIN) {
        LASTWIN := w
        Reset()
    }
}

~LButton::ClickAway()
~RButton::ClickAway()

; 點在候選窗上不算「點別處」，否則會在點到候選之前就先關掉視窗
ClickAway() {
    if (POPUP != "" && POPUP_ON) {
        MouseGetPos(, , &hwnd)
        try {
            if (hwnd == POPUP.Hwnd)
                return
        }
    }
    Reset()
}

Reset() {
    global BUF, HIT, ST
    BUF := "", HIT := "", ST := ""
    HidePopup()
}

; ---------- 偵測 ----------
Scan() {
    global HIT
    if (PAUSED || BUF == "") {
        HidePopup()
        return
    }
    HIT := DetectTail(BUF, DICT)
    if (HIT == "") {
        HidePopup()
        return
    }
    OpenCandidates(HIT.res)
}

StrChars(s) {
    out := []
    Loop Parse s
        out.Push(A_LoopField)
    return out
}

; 第 k 個字可換的同音字（標點／數字回空陣列）
HomsAt(k) {
    if (ST == "" || k < 1 || k > ST.syls.Length)
        return []
    syl := ST.syls[k]
    if (syl == "")
        return []
    e := DictEntry(DICT, syl)
    if (e == "")
        return []
    out := []
    for pair in e
        out.Push(pair[1])
    return out
}

OpenCandidates(res) {
    global ST
    ST := {cands: res.candidates, sel: 1, draft: StrChars(res.candidates[1]),
           syls: res.syllables, zone: "sent", ci: 1, hi: 1}
    Render()
}

; 找下一個可換字的位置（跳過標點／數字）；找不到回 0
SeekChar(from, d) {
    k := from
    while (k >= 1 && k <= ST.draft.Length) {
        if (HomsAt(k).Length)
            return k
        k += d
    }
    return 0
}

; ---------- 建立候選窗（只做一次） ----------
BuildPopup() {
    global POPUP, UI
    POPUP := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    POPUP.BackColor := C_BG
    POPUP.MarginX := 0, POPUP.MarginY := 0
    UI := {cands: [], keys: [], chars: [], homs: []}

    ; 標題列（logo + 說明）
    try UI.logo := POPUP.Add("Picture", "x" . PAD . " y11 w16 h16", A_ScriptDir "\icon.ico")
    POPUP.SetFont("s9", "Microsoft JhengHei")
    UI.title := POPUP.Add("Text", "x" . (PAD + 22) . " y12 w220 h17 c" . C_MUTED, "偵測到注音亂碼")

    ; 整句候選
    POPUP.SetFont("s12", "Microsoft JhengHei")
    Loop MAXCAND {
        i := A_Index
        t := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h" . (CANDH - 3) . " Hidden Background" . C_BG . " c" . C_TEXT, "")
        t.OnEvent("Click", CandHandler(i))
        UI.cands.Push(t)
    }
    POPUP.SetFont("s8", "Microsoft JhengHei")
    Loop MAXCAND
        UI.keys.Push(POPUP.Add("Text", "x0 y0 w40 h15 Hidden Background" . C_SEL . " c3A76D8", "Enter"))

    ; 分隔線與說明
    UI.line1 := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h1 Hidden Background" . C_LINE, "")
    UI.label := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h16 Hidden c" . C_MUTED, "逐字換同音字（點字，或按 ↓ 進入）")

    ; 逐字格
    POPUP.SetFont("s12", "Microsoft JhengHei")
    Loop MAXCHAR {
        k := A_Index
        t := POPUP.Add("Text", "x0 y0 w" . (CELL - 4) . " h" . (CELL - 5) . " Center Hidden Background" . C_CELL . " c" . C_TEXT, "")
        t.OnEvent("Click", CharHandler(k))
        UI.chars.Push(t)
    }

    ; 同音字格
    POPUP.SetFont("s11", "Microsoft JhengHei")
    UI.line2 := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h1 Hidden Background" . C_LINE, "")
    Loop MAXHOM {
        i := A_Index
        t := POPUP.Add("Text", "x0 y0 w" . (TCELL - 4) . " h" . (TCELL - 4) . " Center Hidden Background" . C_CELL . " c" . C_TEXT, "")
        t.OnEvent("Click", HomHandler(i))
        UI.homs.Push(t)
    }

    ; 插入鈕與提示
    POPUP.SetFont("s11", "Microsoft JhengHei")
    UI.btn := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h27 Center Hidden Background" . C_SEL . " c" . C_ACCENT, "")
    UI.btn.OnEvent("Click", (*) => SetTimer(() => Accept(DraftText()), -1))
    POPUP.SetFont("s8", "Microsoft JhengHei")
    UI.hint := POPUP.Add("Text", "x" . PAD . " y0 w" . CW . " h16 Hidden c999999", "")

    ; Windows 11 圓角與細邊框（舊版系統會靜默略過）
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", POPUP.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", POPUP.Hwnd, "UInt", 34, "UInt*", 0x00D8D8D8, "UInt", 4)
}

; 暫停重繪 → 更新 → 一次畫完，避免閃爍
SetRedraw(hwnd, on) {
    DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", on ? 1 : 0, "Ptr", 0)
}

; ---------- 更新候選窗內容 ----------
Render() {
    global POPUP_ON
    if (ST == "")
        return
    SetRedraw(POPUP.Hwnd, false)

    inSent := (ST.zone == "sent")
    y := 34

    ; 整句候選
    for i, ctrl in UI.cands {
        key := UI.keys[i]
        if (i > ST.cands.Length) {
            ctrl.Visible := false, key.Visible := false
            continue
        }
        bg := (i == ST.sel) ? (inSent ? C_SEL : C_SELDIM) : C_BG
        ctrl.Value := "  " . ST.cands[i]
        ctrl.Opt("Background" . bg)
        ctrl.Move(PAD, y, CW, CANDH - 3)
        ctrl.Visible := true
        if (i == ST.sel && inSent) {
            key.Opt("Background" . bg)
            key.Move(PAD + CW - 44, y + 6, 40, 15)
            key.Visible := true
        } else {
            key.Visible := false
        }
        y += CANDH
    }

    ; 分隔線與說明
    y += 5
    UI.line1.Move(PAD, y, CW, 1), UI.line1.Visible := true
    y += 7
    UI.label.Move(PAD, y, CW, 16), UI.label.Visible := true
    y += 20

    ; 逐字格
    col := 0
    for k, ctrl in UI.chars {
        if (k > ST.draft.Length) {
            ctrl.Visible := false
            continue
        }
        editable := HomsAt(k).Length > 0
        bg := C_CELL, fg := C_TEXT
        if (!editable) {
            bg := C_BG, fg := C_MUTED
        } else if (!inSent && k == ST.ci) {
            bg := C_SEL, fg := C_ACCENT
        }
        ctrl.Value := ST.draft[k]
        ctrl.Opt("Background" . bg . " c" . fg)
        ctrl.Move(PAD + col * CELL, y, CELL - 4, CELL - 5)
        ctrl.Visible := true
        col++
        if (col >= CCOLS) {
            col := 0
            y += CELL
        }
    }
    if (col > 0)
        y += CELL
    y += 3

    ; 同音字格
    homs := (ST.zone == "tray") ? HomsAt(ST.ci) : []
    if (homs.Length) {
        UI.line2.Move(PAD, y, CW, 1), UI.line2.Visible := true
        y += 6
    } else {
        UI.line2.Visible := false
    }
    tcol := 0
    for i, ctrl in UI.homs {
        if (i > homs.Length) {
            ctrl.Visible := false
            continue
        }
        bg := C_CELL, fg := C_TEXT
        if (i == ST.hi) {
            bg := C_SEL, fg := C_ACCENT
        } else if (homs[i] == ST.draft[ST.ci]) {
            bg := "F0F6FF"
        }
        ctrl.Value := homs[i]
        ctrl.Opt("Background" . bg . " c" . fg)
        ctrl.Move(PAD + tcol * TCELL, y, TCELL - 4, TCELL - 4)
        ctrl.Visible := true
        tcol++
        if (tcol >= TCOLS) {
            tcol := 0
            y += TCELL
        }
    }
    if (tcol > 0)
        y += TCELL
    if (homs.Length)
        y += 3

    ; 插入鈕
    y += 4
    UI.btn.Value := "插入「" . DraftText() . "」"
    UI.btn.Move(PAD, y, CW, 27)
    UI.btn.Visible := true
    y += 31

    ; 操作提示
    UI.hint.Value := inSent ? "↑↓ 選句 · ↓ 進逐字 · Enter 插入"
        : (ST.zone == "chars") ? "←→ 選字 · ↓ 展開同音 · Enter 插入"
        : "←→↑↓ 選同音字 · Enter 換上 · Esc 返回"
    UI.hint.Move(PAD, y, CW, 16)
    UI.hint.Visible := true
    y += 20

    px := 0, py := 0
    if !CaretPos(&px, &py)
        MouseGetPos(&px, &py), py += 22
    POPUP.Show("NoActivate x" . px . " y" . (py + 24) . " w" . (CW + PAD * 2) . " h" . y)
    POPUP_ON := true

    SetRedraw(POPUP.Hwnd, true)
    DllCall("RedrawWindow", "Ptr", POPUP.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
}

; 事件處理工廠（在迴圈裡直接寫箭頭函式會共用同一個變數，必須用工廠函式）
; 動作延後到事件處理結束後執行
CandHandler(i) {
    return (*) => SetTimer(() => (ST != "" && i <= ST.cands.Length) ? Accept(ST.cands[i]) : 0, -1)
}
CharHandler(k) {
    return (*) => SetTimer(() => ToggleChar(k), -1)
}
HomHandler(i) {
    return (*) => SetTimer(() => PickHom(i), -1)
}

DraftText() {
    s := ""
    if (ST == "")
        return s
    for ch in ST.draft
        s .= ch
    return s
}

ToggleChar(k) {
    if (ST == "" || !HomsAt(k).Length)
        return
    if (ST.zone == "tray" && ST.ci == k) {
        ST.zone := "chars"
    } else {
        ST.zone := "tray"
        ST.ci := k
        ST.hi := CurrentHomIdx(k)
    }
    Render()
}

CurrentHomIdx(k) {
    for i, w in HomsAt(k)
        if (w == ST.draft[k])
            return i
    return 1
}

PickHom(i) {
    if (ST == "")
        return
    homs := HomsAt(ST.ci)
    if (!homs.Length)
        return
    if (i < 1)
        i := 1
    if (i > homs.Length)
        i := homs.Length
    ST.draft[ST.ci] := homs[i]
    ST.zone := "chars"
    Render()
}

HidePopup() {
    global POPUP_ON
    if (POPUP_ON && POPUP != "") {
        try POPUP.Hide()
        POPUP_ON := false
    }
}

; 取得游標（插入點）螢幕座標；取不到回 false
CaretPos(&x, &y) {
    try {
        ; 有些程式取不到會回傳 0,0 —— 視為失敗，改用滑鼠位置
        if (CaretGetPos(&cx, &cy) && (cx != 0 || cy != 0)) {
            x := cx, y := cy
            return true
        }
    }
    return false
}

; ---------- 鍵盤操作 ----------
#HotIf POPUP_ON
Enter:: OnEnter()
Escape:: OnEsc()
Up:: Move("up")
Down:: Move("down")
Left:: Move("left")
Right:: Move("right")
#HotIf

OnEnter() {
    if (ST == "")
        return
    if (ST.zone == "tray")
        PickHom(ST.hi)
    else if (ST.zone == "sent")
        Accept(ST.cands[ST.sel])
    else
        Accept(DraftText())
}

OnEsc() {
    if (ST != "" && ST.zone == "tray") {
        ST.zone := "chars"
        Render()
        return
    }
    Reset()
}

Move(dir) {
    if (ST == "")
        return
    zone := ST.zone

    if (dir == "down") {
        if (zone == "sent") {
            if (ST.sel < ST.cands.Length)
                SelectCand(ST.sel + 1)
            else {
                k := SeekChar(1, 1)
                if (k)
                    ST.zone := "chars", ST.ci := k
            }
        } else if (zone == "chars") {
            if (HomsAt(ST.ci).Length)
                ST.zone := "tray", ST.hi := CurrentHomIdx(ST.ci)
        } else {
            MoveHomRow(1)
        }
    } else if (dir == "up") {
        if (zone == "sent")
            SelectCand(ST.sel > 1 ? ST.sel - 1 : ST.cands.Length)
        else if (zone == "chars")
            ST.zone := "sent"
        else if (!MoveHomRow(-1))
            ST.zone := "chars"
    } else {
        d := (dir == "right") ? 1 : -1
        if (zone == "sent") {
            k := SeekChar(d > 0 ? 1 : ST.draft.Length, d)
            if (k)
                ST.zone := "chars", ST.ci := k
        } else if (zone == "chars") {
            k := SeekChar(ST.ci + d, d)
            if (k)
                ST.ci := k
        } else {
            n := HomsAt(ST.ci).Length
            if (n) {
                ST.hi += d
                if (ST.hi < 1)
                    ST.hi := n
                if (ST.hi > n)
                    ST.hi := 1
            }
        }
    }
    Render()
}

SelectCand(i) {
    ST.sel := i
    ST.draft := StrChars(ST.cands[i])   ; 換句就重置逐字修改
    ST.zone := "sent"
}

; 同音字盤是固定欄數的格子，上下就是 ±欄數
MoveHomRow(d) {
    n := HomsAt(ST.ci).Length
    if (!n)
        return false
    target := ST.hi + d * TCOLS
    if (target < 1 || target > n)
        return false
    ST.hi := target
    return true
}

; ---------- 替換 ----------
Accept(text) {
    global BUF, HIT, BUSY, ST
    if (HIT == "")
        return
    n := StrLen(BUF) - HIT.offset          ; 只替換被辨識的那一段
    HidePopup()

    BUSY := true
    IH.Stop()
    ; 直接送出 Unicode 文字，完全不動剪貼簿
    if (n > 0)
        Send("{BackSpace " . n . "}")
    SendText(text)
    Sleep(30)
    BUF := "", HIT := "", ST := ""
    IH.Start()
    BUSY := false
}

; ---------- 其他 ----------
TogglePause() {
    global PAUSED
    PAUSED := !PAUSED
    Reset()
    A_IconTip := "注音亂碼偵測（" . (PAUSED ? "已暫停" : "監看中") . "）"
    Tip(PAUSED ? "已暫停偵測" : "已繼續偵測", 1200)
}

Tip(s, ms) {
    ToolTip(s)
    SetTimer(() => ToolTip(), -ms)
}
