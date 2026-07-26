#Requires AutoHotkey v2.0
#SingleInstance Force
; 注音亂碼偵測 — 桌面版（適用 Word / PPT 等所有 Windows 程式）
; 階段 2：監看輸入 → 偵測 → 極簡浮窗 → 退格+貼上替換（完整候選窗於階段 3）
;
; 隱私設計：輸入緩衝只存在記憶體、永不寫入檔案、完全不連網；
; 按下 Enter/Tab/Esc/方向鍵、點滑鼠、切換視窗都會立刻清空緩衝。
#Include engine.ahk

global DICT := ""
global BUF := ""          ; 目前累積的輸入（只在記憶體）
global HIT := ""          ; 目前偵測結果 {res, offset}
global BUSY := false      ; 執行替換中，暫停監看避免吃到自己送出的按鍵
global PAUSED := false
global LASTWIN := 0
global POPUP_ON := false
; 注意：所有全域初始化都必須寫在第一個熱鍵之前，
; 因為 AHK 的自動執行區在遇到熱鍵定義時就結束了。

; ---------- 啟動 ----------
TraySetIcon(A_ScriptDir "\icon.ico", 1, true)
A_IconTip := "注音亂碼偵測（載入中…）"
A_TrayMenu.Delete()
A_TrayMenu.Add("暫停 / 繼續偵測", (*) => TogglePause())
A_TrayMenu.Add("結束", (*) => ExitApp())

DICT := LoadDict(A_ScriptDir "\dict.txt")
A_IconTip := "注音亂碼偵測（監看中）"
Tip("注音亂碼偵測已啟動`n詞庫 " . DICT.Count . " 讀音", 2000)

; ---------- 浮窗（不奪取焦點） ----------
global POPUP := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
POPUP.BackColor := "FFFFFF"
POPUP.MarginX := 12, POPUP.MarginY := 9
POPUP.SetFont("s12", "Microsoft JhengHei")
; 注意：文字控制項的寬度在建立時就固定了，之後改內容不會自動變寬，
; 所以要給初始寬度，並在每次顯示時依內容 Move 調整。
global POPUP_TEXT := POPUP.Add("Text", "w240 cBlack", " ")
POPUP.SetFont("s8")
global POPUP_HINT := POPUP.Add("Text", "w240 c888888", "Enter 插入 · Esc 忽略")

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
    global BUF, BUSY
    if (BUSY)
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

~LButton::Reset()
~RButton::Reset()

Reset() {
    global BUF, HIT
    BUF := "", HIT := ""
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
    ShowPopup(HIT.res.candidates[1])
}

; ---------- 浮窗顯示 ----------
ShowPopup(text) {
    global POPUP, POPUP_TEXT, POPUP_HINT, POPUP_ON
    POPUP_TEXT.Value := "→ " . text
    w := Max(170, StrLen(text) * 21 + 44)   ; 依字數估寬（中文字約 21px）
    POPUP_TEXT.Move(, , w)
    POPUP_HINT.Move(, , w)
    x := 0, y := 0
    if !CaretPos(&x, &y)
        MouseGetPos(&x, &y), y += 22
    POPUP.Show("AutoSize NoActivate x" . x . " y" . (y + 24))
    POPUP_ON := true
}

HidePopup() {
    global POPUP, POPUP_ON
    if (POPUP_ON) {
        POPUP.Hide()
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

; ---------- 替換 ----------
#HotIf POPUP_ON
Enter:: Accept()
Escape:: Reset()
#HotIf

Accept() {
    global BUF, HIT, BUSY, IH
    if (HIT == "")
        return
    text := HIT.res.candidates[1]
    n := StrLen(BUF) - HIT.offset          ; 只替換被辨識的那一段
    HidePopup()

    BUSY := true
    IH.Stop()
    ; 直接送出 Unicode 文字，完全不動剪貼簿
    ;（先前用「暫存剪貼簿→貼上→還原」會因為程式讀取剪貼簿較慢而貼到舊內容）
    if (n > 0)
        Send("{BackSpace " . n . "}")
    SendText(text)
    Sleep(30)
    BUF := "", HIT := ""
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
