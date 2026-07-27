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
global CELLSTATE := Map() ; 每個控制項目前的內容簽章，用來跳過沒變化的更新
global LASTGEO := ""      ; 視窗目前的位置與大小
global ANCX := 0, ANCY := 0  ; 候選窗定位點（開啟時算一次，導航期間不再變動）
; 定位模式："point"＝已知座標（插入點或滑鼠）；"window"＝作用中視窗底部置中。
; 取不到插入點時「跟著滑鼠跑」會讓使用者覺得浮窗隨機出現，改用固定位置才可預期。
global ANCMODE := "point"
global ANCW := [0, 0, 0, 0]   ; 開窗當下作用中視窗的位置大小（視窗單位）
; 選取轉換用
global ICON := "", ICONTEXT := "", ICONHINT := "", ICON_ON := false
global SELRES := ""       ; 選取內容的偵測結果
global SELFROMMOUSE := true   ; 這次選取是滑鼠拖曳還是鍵盤（Ctrl+A）觸發
global MDX := 0, MDY := 0 ; 滑鼠按下的位置（用來判斷是否為拖曳選取）
; 最後一次點擊的位置：在 Canva 這類程式要打字一定得先點進文字框，
; 所以這個位置最接近文字所在，比「目前滑鼠位置」或「固定底部」都準。
global CLICKX := 0, CLICKY := 0, CLICKOK := false
global LASTUPT := 0, LASTUPX := 0, LASTUPY := 0   ; 判斷雙擊選字
; 注意：所有全域初始化都必須寫在第一個熱鍵之前，
; 因為 AHK 的自動執行區在遇到熱鍵定義時就結束了。

; 版面尺寸
global PAD := 13, CANDH := 27, CELL := 32, TCELL := 30, TCOLS := 10, CCOLS := 10
global MAXCAND := 3, MAXCHAR := 64, MAXHOM := 50
global CW := TCOLS * TCELL + 4
; 螢幕縮放：AHK 的視窗尺寸會自動乘上這個係數，但滑鼠/游標/螢幕邊界都是實體像素，
; 兩者混用會算錯位置，所以外來的實體座標一律先換算成視窗單位。
global DPIF := A_ScreenDPI / 96

; 若使用者「同時」裝了 Chrome 擴充，在 Chrome 裡就會跳出兩個候選窗。
; 但只裝桌面版的人若預設關閉，Chrome 裡會莫名其妙沒反應且看不出原因 ——
; 所以預設「在 Chrome 也偵測」，遇到重複的人再從系統列關掉即可。
global BROWSER_APPS := Map("chrome.exe", true)
global CHROME_DETECT := true
global SETTINGS_FILE := A_ScriptDir "\settings.ini"

; 配色
global C_BG := "FFFFFF", C_SEL := "E8F1FD", C_SELDIM := "F3F3F3", C_CELL := "F7F7F7"
global C_TEXT := "1E1E1E", C_MUTED := "8A8A8A", C_ACCENT := "1A5FB4", C_LINE := "ECECEC"

; ---------- 啟動 ----------
TraySetIcon(A_ScriptDir "\icon.ico", 1, true)
A_IconTip := "注音亂碼偵測（載入中…）"
LoadSettings()
A_TrayMenu.Delete()
A_TrayMenu.Add("暫停 / 繼續偵測", (*) => TogglePause())
A_TrayMenu.Add("在 Chrome 中也偵測", (*) => ToggleChromeDetect())
if (CHROME_DETECT)
    A_TrayMenu.Check("在 Chrome 中也偵測")
A_TrayMenu.Add()
A_TrayMenu.Add("結束", (*) => ExitApp())

DICT := LoadDict(A_ScriptDir "\dict.txt")
BuildPopup()
BuildIcon()
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
    global BUF          ; 函式內有指派的變數一定要宣告，否則會被當成區域變數
    if (BUSY || PAUSED)
        return
    HideIcon()          ; 一開始打字，原本的選取就沒了，icon 不能再留著
    if !IsRunChar(ch) {           ; 中文字等非按鍵字元 → 視為新段落
        Reset()
        return
    }
    BUF .= ch
    SetTimer(Scan, -160)          ; 去抖動
}

OnResetKey(hook, vk, sc) {
    global BUF
    if (BUSY)
        return
    ; 按住 Shift 移動＝用鍵盤選取文字，等停下來再檢查選取內容
    if (GetKeyState("Shift", "P") && (vk = 37 || vk = 38 || vk = 39 || vk = 40 || vk = 36 || vk = 35)) {
        SetTimer(() => CheckSelection(false), -280)
        return
    }
    HideIcon()                    ; 按了其他鍵就代表選取已失效
    ; 退格：緩衝要跟著縮短 —— 候選窗開著時也一樣，否則會顯示刪除前的舊結果
    if (vk = 8) {
        if (BUF != "")
            BUF := SubStr(BUF, 1, StrLen(BUF) - 1)
        SetTimer(Scan, -160)
        return
    }
    if (POPUP_ON)                 ; 其他鍵在候選窗開著時交給熱鍵處理
        return
    Reset()
}

; 切換視窗就清空（避免把上一個視窗的輸入帶過來）
WatchWindow() {
    global LASTWIN, CLICKOK
    w := WinExist("A")
    if (w != LASTWIN) {
        LASTWIN := w
        CLICKOK := false        ; 換了視窗，舊的點擊位置不再有參考價值
        Reset()
    }
}

~LButton::MouseDown()
~LButton Up::MouseUp()
~RButton::ClickAway()
; Ctrl+A 全選（Canva、PPT 這類文字方框常用）也視為選取完成
~^a::SetTimer(() => CheckSelection(false), -180)

MouseDown() {
    global MDX, MDY, CLICKX, CLICKY, CLICKOK
    MouseGetPos(&x, &y, &hwnd)
    MDX := x, MDY := y
    ; 點在自己的浮窗上不算「點進文字框」
    isOwn := false
    try isOwn := (POPUP != "" && hwnd == POPUP.Hwnd) || (ICON != "" && hwnd == ICON.Hwnd)
    if (!isOwn)
        CLICKX := x, CLICKY := y, CLICKOK := true
    ClickAway()
}

; 放開左鍵時判斷是不是「選取了文字」（拖曳，或雙擊選字）
MouseUp() {
    global LASTUPT, LASTUPX, LASTUPY
    MouseGetPos(&x, &y)
    dragged := (Abs(x - MDX) > 4 || Abs(y - MDY) > 4)
    dbl := (A_TickCount - LASTUPT < 450 && Abs(x - LASTUPX) < 5 && Abs(y - LASTUPY) < 5)
    LASTUPT := A_TickCount, LASTUPX := x, LASTUPY := y
    if (dragged || dbl)
        SetTimer(CheckSelection, -120)
}

; 點在候選窗或 icon 上不算「點別處」，否則會在點到之前就先關掉視窗
ClickAway() {
    MouseGetPos(, , &hwnd)
    try {
        if (POPUP_ON && POPUP != "" && hwnd == POPUP.Hwnd)
            return
        if (ICON_ON && ICON != "" && hwnd == ICON.Hwnd)
            return
    }
    Reset()
}

Reset() {
    global BUF, HIT, ST
    BUF := "", HIT := "", ST := ""
    HidePopup()
    HideIcon()
}

; ---------- 偵測 ----------
; 目前視窗是否交由 Chrome 擴充處理
IsExcludedApp() {
    if (CHROME_DETECT)
        return false
    try {
        hwnd := WinExist("A")
        if (hwnd)
            return BROWSER_APPS.Has(StrLower(WinGetProcessName(hwnd)))
    }
    return false
}

Scan() {
    global HIT, BUF
    if (PAUSED || BUF == "") {
        HidePopup()
        return
    }
    if (IsExcludedApp()) {        ; Chrome 裡交給擴充，避免兩個候選窗同時出現
        BUF := ""
        HidePopup()
        return
    }
    ; 輸入法在中文模式 → 使用者正常打中文，不該出手
    if (ImeChineseMode()) {
        BUF := ""
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

; ---------- 選取轉換 ----------
; Windows 不讓程式直接讀別的程式裡選取的文字，只能靠送出「複製」再從剪貼簿讀回，
; 讀完立刻還原原本的剪貼簿內容。整個過程只在記憶體，不寫檔、不外傳。
GetSelectedText() {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    text := ClipWait(0.4) ? A_Clipboard : ""
    A_Clipboard := saved
    return text
}

CheckSelection(fromMouse := true) {
    global SELRES, SELFROMMOUSE
    if (BUSY || PAUSED || POPUP_ON || IsExcludedApp())
        return
    SELFROMMOUSE := fromMouse
    text := Trim(GetSelectedText(), " `t`r`n")
    if (text == "" || StrLen(text) > 120) {   ; 太長的選取不是我們的使用情境
        HideIcon()
        return
    }
    ; 使用者主動選取＝已表明意圖，門檻放寬（跳過常見英文那關、單字也能轉）
    res := Detect(text, DICT, 0.5, 1, true)
    if (res == "") {
        HideIcon()
        return
    }
    SELRES := res
    ShowIcon(res.candidates[1])
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

; 長句子需要比較寬的視窗，依內容決定（上限避免超出螢幕）
CalcWidth() {
    maxLen := 0
    for c in ST.cands
        maxLen := Max(maxLen, StrLen(c))
    w := maxLen * 21 + 34
    w := Max(w, ST.draft.Length * CELL + 10)   ; 讓逐字列盡量排成一行
    return Max(304, Min(w, 720))
}

; 實體像素 → 視窗單位
ToGui(v) {
    return Round(v / DPIF)
}

; 取得作用中視窗的位置大小（視窗單位）；取不到就用整個螢幕
ActiveWinRect() {
    try {
        hwnd := WinExist("A")
        if (hwnd) {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            if (ww > 200 && wh > 150)
                return [ToGui(wx), ToGui(wy), ToGui(ww), ToGui(wh)]
        }
    }
    return [0, 0, ToGui(A_ScreenWidth), ToGui(A_ScreenHeight)]
}

; 把視窗夾在螢幕可用範圍內；下方放不下就翻到插入點上方
; x/y/w/h 皆為「視窗單位」，螢幕邊界取得後要換算過來才能比較
ClampToScreen(&x, &y, w, h) {
    L := 0, T := 0, R := ToGui(A_ScreenWidth), B := ToGui(A_ScreenHeight)
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        ml := ToGui(ml), mt := ToGui(mt), mr := ToGui(mr), mb := ToGui(mb)
        if (x >= ml && x < mr && y >= mt - 60 && y < mb + 60) {
            L := ml, T := mt, R := mr, B := mb
            break
        }
    }
    if (x + w > R - 8)
        x := R - 8 - w
    if (x < L + 8)
        x := L + 8
    if (y + h > B - 8)
        y := y - h - 28          ; 翻到插入點上方
    if (y < T + 8)
        y := T + 8
}

; 放不下時截斷顯示（實際插入的仍是完整內容）
Fit(s, maxChars) {
    if (maxChars < 4 || StrLen(s) <= maxChars)
        return s
    return SubStr(s, 1, maxChars - 1) . "…"
}

; src："typing"（邊打邊偵測，用退格取代）或 "selection"（選取轉換，直接覆蓋選取）
OpenCandidates(res, src := "typing", ax := -1, ay := -1) {
    global ST, ANCX, ANCY, ANCMODE, ANCW, CW, CCOLS, TCOLS
    ; 定位只在開啟時算一次：插入點會閃爍，重算會讓視窗在游標與滑鼠位置之間跳動
    if (ST == "") {
        ANCW := ActiveWinRect()
        if (ax >= 0) {                       ; 呼叫端已指定（滑鼠選取）
            ANCMODE := "point", ANCX := ax, ANCY := ay
        } else if (CaretPos(&px, &py)) {     ; 有插入點 → 貼在文字行下方
            ANCMODE := "point", ANCX := ToGui(px), ANCY := ToGui(py) + 4
        } else if (CLICKOK) {                ; 畫布類程式 → 用「你點進文字框的位置」
            ANCMODE := "point", ANCX := ToGui(CLICKX), ANCY := ToGui(CLICKY) + 26
        } else {                             ; 真的沒線索 → 視窗底部置中
            ANCMODE := "window"
        }
    }
    ST := {cands: res.candidates, sel: 1, draft: StrChars(res.candidates[1]),
           syls: res.syllables, zone: "sent", ci: 1, hi: 1, src: src}
    CW := CalcWidth()                       ; 視窗寬度依這次的內容決定
    CCOLS := Max(6, CW // CELL)
    TCOLS := Max(6, CW // TCELL)
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
    ; E0x08000000 = 不奪取焦點；E0x02000000 = 子控制項雙緩衝（消除閃爍的關鍵）
    POPUP := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x02000000")
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

; ---------- 選取後浮出的小 icon ----------
BuildIcon() {
    global ICON, ICONTEXT, ICONHINT
    ICON := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x02000000")
    ICON.BackColor := C_BG
    ICON.MarginX := 0, ICON.MarginY := 0
    try {
        pic := ICON.Add("Picture", "x9 y8 w18 h18", A_ScriptDir "\icon.ico")
        pic.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    }
    ICON.SetFont("s11", "Microsoft JhengHei")
    ICONTEXT := ICON.Add("Text", "x32 y9 w240 h22 c" . C_TEXT, "")
    ICONTEXT.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    ICON.SetFont("s9", "Microsoft JhengHei")
    ICONHINT := ICON.Add("Text", "x32 y32 w240 h18 c" . C_ACCENT, "↵ 轉中文或編輯")
    ICONHINT.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ICON.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ICON.Hwnd, "UInt", 34, "UInt*", 0x00D8D8D8, "UInt", 4)
}

ShowIcon(preview) {
    global ICON_ON
    shown := Fit(preview, 32)                  ; 先決定要顯示多少字
    w := Max(230, 56 + StrLen(shown) * 20)     ; 再依實際顯示長度決定寬度
    ICONTEXT.Value := "→ " . shown
    ICONTEXT.Move(32, 9, w - 44, 22)
    ICONHINT.Move(32, 32, w - 44, 18)
    if (SELFROMMOUSE) {                     ; 滑鼠選取 → 出現在剛放開滑鼠的地方
        MouseGetPos(&mx, &my)
        ix := ToGui(mx) + 8, iy := ToGui(my) + 18
    } else if (CLICKOK) {                   ; 鍵盤選取 → 用「你點進文字框的位置」
        ix := ToGui(CLICKX), iy := ToGui(CLICKY) + 26
    } else {                                ; 真的沒線索 → 視窗底部置中
        r := ActiveWinRect()
        ix := r[1] + (r[3] - w) // 2
        iy := r[2] + r[4] - 58 - 40
    }
    ClampToScreen(&ix, &iy, w, 58)
    ICON.Show("NoActivate x" . ix . " y" . iy . " w" . w . " h58")
    ICON_ON := true
}

HideIcon() {
    global ICON_ON, SELRES
    if (ICON_ON && ICON != "") {
        try ICON.Hide()
        ICON_ON := false
    }
    SELRES := ""
}

IconClicked() {
    global SELRES
    if (SELRES == "")
        return
    res := SELRES
    HideIcon()
    if (SELFROMMOUSE) {
        MouseGetPos(&mx, &my)
        OpenCandidates(res, "selection", ToGui(mx), ToGui(my) + 18)
    } else {
        OpenCandidates(res, "selection")     ; 沿用固定位置規則
    }
}

; ---------- 更新候選窗內容 ----------
; 只有在內容真的改變時才動控制項 —— 沒變化就完全不碰，這是消除閃爍的關鍵
SetCell(ctrl, val, bg, fg, x, y, w, h) {
    global CELLSTATE
    sig := val . "|" . bg . "|" . fg . "|" . x . "|" . y . "|" . w . "|" . h
    key := ctrl.Hwnd
    if (CELLSTATE.Has(key) && CELLSTATE[key] == sig)
        return false
    CELLSTATE[key] := sig
    ctrl.Value := val
    ctrl.Opt("Background" . bg . " c" . fg)
    ctrl.Move(x, y, w, h)
    ctrl.Visible := true
    ctrl.Redraw()          ; 只重繪這一格，不動其他控制項
    return true
}

HideCell(ctrl) {
    global CELLSTATE
    key := ctrl.Hwnd
    if (CELLSTATE.Has(key) && CELLSTATE[key] == "hidden")
        return false
    CELLSTATE[key] := "hidden"
    ctrl.Visible := false
    return true
}

Render() {
    global POPUP_ON, LASTGEO
    if (ST == "")
        return
    changed := false

    inSent := (ST.zone == "sent")
    y := 34

    ; 整句候選
    for i, ctrl in UI.cands {
        key := UI.keys[i]
        if (i > ST.cands.Length) {
            changed := HideCell(ctrl) || changed
            changed := HideCell(key) || changed
            continue
        }
        bg := (i == ST.sel) ? (inSent ? C_SEL : C_SELDIM) : C_BG
        changed := SetCell(ctrl, "  " . Fit(ST.cands[i], (CW - 34) // 21), bg, C_TEXT, PAD, y, CW, CANDH - 3) || changed
        if (i == ST.sel && inSent)
            changed := SetCell(key, "Enter", bg, "3A76D8", PAD + CW - 44, y + 6, 40, 15) || changed
        else
            changed := HideCell(key) || changed
        y += CANDH
    }

    ; 分隔線與說明
    y += 5
    changed := SetCell(UI.line1, "", C_LINE, C_LINE, PAD, y, CW, 1) || changed
    y += 7
    changed := SetCell(UI.label, "逐字換同音字（點字，或按 ↓ 進入）", C_BG, C_MUTED, PAD, y, CW, 16) || changed
    y += 20

    ; 逐字格
    col := 0
    for k, ctrl in UI.chars {
        if (k > ST.draft.Length) {
            changed := HideCell(ctrl) || changed
            continue
        }
        editable := HomsAt(k).Length > 0
        bg := C_CELL, fg := C_TEXT
        if (!editable) {
            bg := C_BG, fg := C_MUTED
        } else if (!inSent && k == ST.ci) {
            bg := C_SEL, fg := C_ACCENT
        }
        changed := SetCell(ctrl, ST.draft[k], bg, fg, PAD + col * CELL, y, CELL - 4, CELL - 5) || changed
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
        changed := SetCell(UI.line2, "", C_LINE, C_LINE, PAD, y, CW, 1) || changed
        y += 6
    } else {
        changed := HideCell(UI.line2) || changed
    }
    tcol := 0
    for i, ctrl in UI.homs {
        if (i > homs.Length) {
            changed := HideCell(ctrl) || changed
            continue
        }
        bg := C_CELL, fg := C_TEXT
        if (i == ST.hi) {
            bg := C_SEL, fg := C_ACCENT
        } else if (homs[i] == ST.draft[ST.ci]) {
            bg := "F0F6FF"
        }
        changed := SetCell(ctrl, homs[i], bg, fg, PAD + tcol * TCELL, y, TCELL - 4, TCELL - 4) || changed
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
    changed := SetCell(UI.btn, "↵ 改為「" . Fit(DraftText(), (CW - 96) // 21) . "」", C_SEL, C_ACCENT, PAD, y, CW, 27) || changed
    y += 31

    ; 操作提示
    hint := inSent ? "↑↓ 選句 · ↓ 進逐字 · Enter 插入"
        : (ST.zone == "chars") ? "←→ 選字 · ↓ 展開同音 · Enter 插入"
        : "←→↑↓ 選同音字 · Enter 換上 · Esc 返回"
    changed := SetCell(UI.hint, hint, C_BG, "999999", PAD, y, CW, 16) || changed
    y += 20

    ; 位置或大小沒變就不要再 Show 一次（Show 本身也會造成閃爍）
    winW := CW + PAD * 2, winH := y
    if (ANCMODE == "window") {              ; 固定在作用中視窗底部置中
        px := ANCW[1] + (ANCW[3] - winW) // 2
        py := ANCW[2] + ANCW[4] - winH - 40
    } else {
        px := ANCX, py := ANCY
    }
    ClampToScreen(&px, &py, winW, winH)
    geo := px . "," . py . "," . winW . "," . winH
    if (!POPUP_ON || geo != LASTGEO) {
        POPUP.Show("NoActivate x" . px . " y" . py . " w" . winW . " h" . winH)
        LASTGEO := geo
        POPUP_ON := true
        changed := true
    }

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

; 取得插入點的「下緣」螢幕座標，讓浮窗貼在文字行下方而不是蓋住它；取不到回 false
CaretPos(&x, &y) {
    hwnd := WinExist("A")
    if (!hwnd)
        return false
    try {
        tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        gti := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
        NumPut("UInt", gti.Size, gti, 0)
        if DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", gti) {
            hCaret := NumGet(gti, A_PtrSize = 8 ? 48 : 28, "Ptr")
            off := A_PtrSize = 8 ? 56 : 32
            left := NumGet(gti, off, "Int"), top := NumGet(gti, off + 4, "Int")
            bottom := NumGet(gti, off + 12, "Int")
            if (left != 0 || top != 0 || bottom != 0) {
                pt := Buffer(8, 0)
                NumPut("Int", left, pt, 0)
                NumPut("Int", bottom, pt, 4)   ; 用下緣，浮窗才不會蓋到這一行文字
                DllCall("ClientToScreen", "Ptr", hCaret ? hCaret : hwnd, "Ptr", pt)
                x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
                return true
            }
        }
    }
    ; 退而求其次：用 AHK 內建（只給上緣，補一個行高）
    try {
        if (CaretGetPos(&cx, &cy) && (cx != 0 || cy != 0)) {
            x := cx, y := cy + 20
            return true
        }
    }
    return false
}

; 輸入法目前是不是中文模式？
; 桌面版攔的是「輸入法之前」的原始按鍵，所以你正常打中文時我們看到的也是英文鍵；
; 唯一能分辨的辦法就是問系統輸入法的狀態 —— 中文模式代表使用者打得好好的，不該出手。
ImeChineseMode() {
    hwnd := WinExist("A")
    if (!hwnd)
        return false
    try {
        hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        if (!hIME)
            return false
        res := 0
        ok := DllCall("SendMessageTimeout", "Ptr", hIME, "UInt", 0x0283, "Ptr", 0x0001, "Ptr", 0,
                      "UInt", 0x0002, "UInt", 80, "Ptr*", &res)   ; WM_IME_CONTROL / IMC_GETCONVERSIONMODE
        if (!ok)
            return false
        return (res & 0x1) != 0        ; IME_CMODE_NATIVE = 中文模式
    }
    return false
}

; ---------- 鍵盤操作 ----------
; icon 顯示中：Enter 進候選窗、Esc 收起（畫面上寫了 ↵ 就要真的能用）
#HotIf ICON_ON && !POPUP_ON
Enter:: IconClicked()
Escape:: HideIcon()
#HotIf

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
            ; ↓ 展開同音字（注音輸入法的慣例）；跨行移動交給 ←→ 連續走
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
    if (ST == "")
        return
    fromTyping := (ST.src == "typing")
    if (fromTyping && HIT == "")
        return
    n := fromTyping ? StrLen(BUF) - HIT.offset : 0   ; 只替換被辨識的那一段
    HidePopup()

    BUSY := true
    IH.Stop()
    ; 直接送出 Unicode 文字，完全不動剪貼簿
    ; 選取模式不必退格 —— 選取狀態還在，送字就會直接覆蓋掉
    if (n > 0)
        Send("{BackSpace " . n . "}")
    SendText(text)
    Sleep(30)
    BUF := "", HIT := "", ST := ""
    IH.Start()
    BUSY := false
}

; ---------- 設定 ----------
LoadSettings() {
    global CHROME_DETECT
    v := IniRead(SETTINGS_FILE, "settings", "chromeDetect", "1")
    CHROME_DETECT := (v != "0")
}

SaveSettings() {
    try IniWrite(CHROME_DETECT ? 1 : 0, SETTINGS_FILE, "settings", "chromeDetect")
}

ToggleChromeDetect() {
    global CHROME_DETECT
    CHROME_DETECT := !CHROME_DETECT
    SaveSettings()
    if (CHROME_DETECT)
        A_TrayMenu.Check("在 Chrome 中也偵測")
    else
        A_TrayMenu.Uncheck("在 Chrome 中也偵測")
    Reset()
    Tip(CHROME_DETECT
        ? "已開啟：Chrome 中也會偵測`n（若你另外裝了 Chrome 擴充，會跳出兩個候選窗）"
        : "已關閉：Chrome 中交給擴充處理", 2600)
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
