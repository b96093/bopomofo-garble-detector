#Requires AutoHotkey v2.0
#SingleInstance Force
; 注音亂碼偵測 — 桌面版（適用 Word / PPT 等所有 Windows 程式）
; 監看輸入 → 偵測 → 候選窗（3 整句候選 + 逐字換同音字）→ 退格 + 送出中文
;
; 隱私設計：輸入緩衝只存在記憶體、永不寫入檔案、完全不連網；
; 按下 Enter/Tab/Esc/方向鍵、點滑鼠、切換視窗都會立刻清空緩衝。
#Include engine.ahk

global DICT := ""
global BUF := ""          ; 目前累積的輸入（只在記憶體）
global HIT := ""          ; 目前偵測結果 {res, offset}
global ST := ""           ; 候選窗狀態
global BUSY := false      ; 執行替換中，暫停監看避免吃到自己送出的按鍵
global PAUSED := false
global LASTWIN := 0
global POPUP := ""
global POPUP_ON := false
; 注意：所有全域初始化都必須寫在第一個熱鍵之前，
; 因為 AHK 的自動執行區在遇到熱鍵定義時就結束了。

; 版面尺寸
global PAD := 12, CANDH := 27, CELL := 31, TRAYCELL := 29, TRAYCOLS := 10, CHARCOLS := 10
global CW := TRAYCOLS * TRAYCELL + 6      ; 內容寬度

; ---------- 啟動 ----------
TraySetIcon(A_ScriptDir "\icon.ico", 1, true)
A_IconTip := "注音亂碼偵測（載入中…）"
A_TrayMenu.Delete()
A_TrayMenu.Add("暫停 / 繼續偵測", (*) => TogglePause())
A_TrayMenu.Add("結束", (*) => ExitApp())

DICT := LoadDict(A_ScriptDir "\dict.txt")
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
    global BUF, BUSY, PAUSED
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
    global BUF, BUSY, POPUP_ON
    if (BUSY)
        return
    if (POPUP_ON)                 ; 候選窗開著時，方向鍵等交給熱鍵處理
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
    global POPUP
    if (POPUP != "") {
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
    global BUF, HIT, DICT, PAUSED
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

; ---------- 候選窗狀態 ----------
StrChars(s) {
    out := []
    Loop Parse s
        out.Push(A_LoopField)
    return out
}

; 第 k 個字可換的同音字（標點／數字回空陣列）
HomsAt(k) {
    global ST, DICT
    if (k < 1 || k > ST.syls.Length)
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
    global ST
    k := from
    while (k >= 1 && k <= ST.draft.Length) {
        if (HomsAt(k).Length)
            return k
        k += d
    }
    return 0
}

; ---------- 繪製 ----------
Render() {
    global ST, POPUP, POPUP_ON, PAD, CANDH, CELL, TRAYCELL, TRAYCOLS, CHARCOLS, CW

    if (POPUP != "") {
        try POPUP.Destroy()
        POPUP := ""
    }
    POPUP := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    POPUP.BackColor := "FFFFFF"
    POPUP.MarginX := 0, POPUP.MarginY := 0

    inSent := (ST.zone == "sent")
    y := PAD

    ; 整句候選
    POPUP.SetFont("s12", "Microsoft JhengHei")
    for i, c in ST.cands {
        bg := (i == ST.sel) ? (inSent ? "BackgroundE8F1FD" : "BackgroundF2F2F2") : "BackgroundFFFFFF"
        t := POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h" . (CANDH - 3) . " " . bg . " cBlack", "  " . c)
        t.OnEvent("Click", CandHandler(i))
        if (i == ST.sel && inSent) {
            POPUP.SetFont("s8")
            POPUP.Add("Text", "x" . (PAD + CW - 42) . " y" . (y + 6) . " w40 h16 " . bg . " c3A76D8", "Enter")
            POPUP.SetFont("s12", "Microsoft JhengHei")
        }
        y += CANDH
    }

    ; 分隔線 + 說明
    y += 4
    POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h1 BackgroundEEEEEE", "")
    y += 6
    POPUP.SetFont("s8", "Microsoft JhengHei")
    POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h16 c888888", "逐字換同音字（點字，或按 ↓ 進入）")
    y += 19

    ; 逐字列
    POPUP.SetFont("s12", "Microsoft JhengHei")
    col := 0
    for k, ch in ST.draft {
        editable := HomsAt(k).Length > 0
        cx := PAD + col * CELL
        if (!editable) {
            POPUP.Add("Text", "x" . cx . " y" . y . " w" . (CELL - 3) . " h" . (CELL - 4) . " Center BackgroundFFFFFF c999999", ch)
        } else {
            bg := "BackgroundFFFFFF"
            fg := "cBlack"
            if (!inSent && k == ST.ci) {
                bg := "BackgroundE8F1FD"
                fg := "c1A5FB4"
            }
            t := POPUP.Add("Text", "x" . cx . " y" . y . " w" . (CELL - 3) . " h" . (CELL - 4) . " Center " . bg . " " . fg, ch)
            t.OnEvent("Click", CharHandler(k))
        }
        col++
        if (col >= CHARCOLS) {
            col := 0
            y += CELL
        }
    }
    if (col > 0)
        y += CELL
    y += 2

    ; 同音字盤
    if (ST.zone == "tray") {
        homs := HomsAt(ST.ci)
        POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h1 BackgroundEEEEEE", "")
        y += 5
        tcol := 0
        for i, w in homs {
            tx := PAD + tcol * TRAYCELL
            bg := "BackgroundF7F7F7"
            fg := "cBlack"
            if (i == ST.hi) {
                bg := "BackgroundE8F1FD"
                fg := "c1A5FB4"
            } else if (w == ST.draft[ST.ci]) {
                bg := "BackgroundF0F6FF"
            }
            t := POPUP.Add("Text", "x" . tx . " y" . y . " w" . (TRAYCELL - 3) . " h" . (TRAYCELL - 3) . " Center " . bg . " " . fg, w)
            t.OnEvent("Click", HomHandler(i))
            tcol++
            if (tcol >= TRAYCOLS) {
                tcol := 0
                y += TRAYCELL
            }
        }
        if (tcol > 0)
            y += TRAYCELL
        y += 2
    }

    ; 插入鈕
    y += 4
    POPUP.SetFont("s11", "Microsoft JhengHei")
    draftStr := ""
    for ch in ST.draft
        draftStr .= ch
    b := POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h26 Center BackgroundE8F1FD c1A5FB4", "插入「" . draftStr . "」")
    b.OnEvent("Click", (*) => SetTimer(() => Accept(DraftText()), -1))
    y += 30

    ; 操作提示
    POPUP.SetFont("s8", "Microsoft JhengHei")
    hint := inSent ? "↑↓ 選句 · ↓ 進逐字 · Enter 插入"
        : (ST.zone == "chars") ? "←→ 選字 · ↓ 展開同音 · Enter 插入"
        : "←→↑↓ 選同音字 · Enter 換上 · Esc 返回"
    POPUP.Add("Text", "x" . PAD . " y" . y . " w" . CW . " h16 c999999", hint)
    y += 20

    px := 0, py := 0
    if !CaretPos(&px, &py)
        MouseGetPos(&px, &py), py += 22
    POPUP.Show("NoActivate x" . px . " y" . (py + 24) . " w" . (CW + PAD * 2) . " h" . y)
    POPUP_ON := true
}

; 事件處理工廠（在迴圈裡直接寫箭頭函式會共用同一個變數，必須用工廠函式）
; 動作一律延後到事件處理結束後才執行 —— 因為這些動作會銷毀視窗本身
CandHandler(i) {
    return (*) => SetTimer(() => Accept(ST.cands[i]), -1)
}
CharHandler(k) {
    return (*) => SetTimer(() => ToggleChar(k), -1)
}
HomHandler(i) {
    return (*) => SetTimer(() => PickHom(i), -1)
}

DraftText() {
    global ST
    s := ""
    for ch in ST.draft
        s .= ch
    return s
}

ToggleChar(k) {
    global ST
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
    global ST
    for i, w in HomsAt(k)
        if (w == ST.draft[k])
            return i
    return 1
}

PickHom(i) {
    global ST
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
    global POPUP, POPUP_ON
    if (POPUP != "") {
        try POPUP.Destroy()
        POPUP := ""
    }
    POPUP_ON := false
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
    global ST
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
    global ST
    if (ST != "" && ST.zone == "tray") {
        ST.zone := "chars"
        Render()
        return
    }
    Reset()
}

Move(dir) {
    global ST
    if (ST == "")
        return
    zone := ST.zone

    if (dir == "down") {
        if (zone == "sent") {
            if (ST.sel < ST.cands.Length)
                SelectCand(ST.sel + 1)
            else {
                k := SeekChar(1, 1)
                if (k) {
                    ST.zone := "chars"
                    ST.ci := k
                }
            }
        } else if (zone == "chars") {
            if (HomsAt(ST.ci).Length) {
                ST.zone := "tray"
                ST.hi := CurrentHomIdx(ST.ci)
            }
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
            if (k) {
                ST.zone := "chars"
                ST.ci := k
            }
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
    global ST
    ST.sel := i
    ST.draft := StrChars(ST.cands[i])   ; 換句就重置逐字修改
    ST.zone := "sent"
}

; 同音字盤是固定欄數的格子，上下就是 ±欄數
MoveHomRow(d) {
    global ST, TRAYCOLS
    n := HomsAt(ST.ci).Length
    if (!n)
        return false
    target := ST.hi + d * TRAYCOLS
    if (target < 1 || target > n)
        return false
    ST.hi := target
    return true
}

; ---------- 替換 ----------
Accept(text) {
    global BUF, HIT, BUSY, IH, ST
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
