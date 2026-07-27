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
; 拖曳只在「這一次」有效：位置一律自動判斷，擋到了才臨時挪開，關掉就回到自動。
global MANUALX := -1, MANUALY := -1
global DRAGGING := false, DRAGDX := 0, DRAGDY := 0
global FLIPPED := false   ; 是否已翻到插入點上方（決定一次就固定，避免展開/收起時來回跳）
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
; 螢幕縮放：AHK 只把「視窗尺寸」乘上這個係數，「位置」則是實體像素。
; 所以位置一律用實體座標，只有要跟螢幕邊界比大小時，才把尺寸換算成實體像素。
global DPIF := A_ScreenDPI / 96

; 若使用者「同時」裝了 Chrome 擴充，在 Chrome 裡就會跳出兩個候選窗。
; 但只裝桌面版的人若預設關閉，Chrome 裡會莫名其妙沒反應且看不出原因 ——
; 所以預設「在 Chrome 也偵測」，遇到重複的人再從系統列關掉即可。
global BROWSER_APPS := Map("chrome.exe", true)
global CHROME_DETECT := true
global MODE := "conservative"      ; conservative｜aggressive
global THRESH := 0.8, MINSYL := 2  ; 由 MODE 換算而來
global SETGUI := ""
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
A_TrayMenu.Add("設定…", (*) => ShowSettings())
A_TrayMenu.Add()
A_TrayMenu.Add("結束", (*) => ExitApp())
A_TrayMenu.Default := "設定…"

DICT := LoadDict(A_ScriptDir "\dict.txt")
BuildPopup()
BuildIcon()
A_IconTip := "注音亂碼偵測（" . (PAUSED ? "已暫停" : "監看中") . "）"
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
    global MDX, MDY, CLICKX, CLICKY, CLICKOK, DRAGGING, DRAGDX, DRAGDY
    MouseGetPos(&x, &y, &hwnd)
    MDX := x, MDY := y
    ; 點在自己的浮窗上不算「點進文字框」
    isOwn := false
    try isOwn := (POPUP != "" && hwnd == POPUP.Hwnd) || (ICON != "" && hwnd == ICON.Hwnd)
    if (!isOwn) {
        CLICKX := x, CLICKY := y, CLICKOK := true
    } else if (POPUP_ON && POPUP != "" && hwnd == POPUP.Hwnd) {
        ; 點在候選窗上緣（標題列）→ 開始拖曳。
        ; 浮窗是「不奪取焦點」的視窗，系統內建的拖曳機制不適用，所以自己追蹤滑鼠。
        try {
            WinGetPos(&wx, &wy, , , POPUP.Hwnd)
            if (y - wy < 32 * DPIF) {
                DRAGDX := x - wx, DRAGDY := y - wy
                DRAGGING := true
                ; 雙緩衝（WS_EX_COMPOSITED）靜態時能消除閃爍，但移動視窗時
                ; 每一格都要重畫整個緩衝區而變得很鈍 —— 拖曳期間先關掉。
                try WinSetExStyle("-0x02000000", POPUP.Hwnd)
                SetTimer(DragMove, 8)
            }
        }
    }
    ClickAway()
}

; 放開左鍵時判斷是不是「選取了文字」（拖曳，或雙擊選字）
MouseUp() {
    global LASTUPT, LASTUPX, LASTUPY
    MouseGetPos(&x, &y)
    dx := Abs(x - MDX), dy := Abs(y - MDY)
    ; 選取文字幾乎都是水平方向；在 Canva 這類程式裡「搬移物件」也是拖曳，
    ; 但多半帶有明顯的上下位移，用這點把它濾掉，避免誤觸。
    dragged := (dx > 4 && dx > dy * 1.4)
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
    global BUF, HIT, ST, MANUALX, MANUALY, FLIPPED
    BUF := "", HIT := "", ST := ""
    MANUALX := -1, MANUALY := -1     ; 拖曳只對當下那個候選窗有效
    FLIPPED := false
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
    HIT := DetectTail(BUF, DICT, THRESH, MINSYL)
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

; 視窗尺寸（AHK 單位）→ 實際佔用的實體像素
ToPhys(v) {
    return Round(v * DPIF)
}

; 取得作用中視窗的位置大小（視窗單位）；取不到就用整個螢幕
ActiveWinRect() {
    try {
        hwnd := WinExist("A")
        if (hwnd) {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            if (ww > 200 && wh > 150)
                return [wx, wy, ww, wh]
        }
    }
    return [0, 0, A_ScreenWidth, A_ScreenHeight]
}

; 取得某座標所在螢幕的可用範圍（視窗單位）
ScreenBounds(x, y, &L, &T, &R, &B) {
    L := 0, T := 0, R := A_ScreenWidth, B := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        if (x >= ml && x < mr && y >= mt - 80 && y < mb + 80) {
            L := ml, T := mt, R := mr, B := mb
            break
        }
    }
}

; 把視窗夾在螢幕可用範圍內（只做最小幅度的位移，不翻面）
ClampToScreen(&x, &y, w, h) {
    ScreenBounds(x, y, &L, &T, &R, &B)
    if (x + w > R - 8)
        x := R - 8 - w
    if (x < L + 8)
        x := L + 8
    if (y + h > B - 8)
        y := B - 8 - h
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
            ANCMODE := "point", ANCX := px, ANCY := py + 6
        } else if (CLICKOK) {                ; 畫布類程式 → 用「你點進文字框的位置」
            ANCMODE := "point", ANCX := CLICKX, ANCY := CLICKY + 30
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
    UI.title := POPUP.Add("Text", "x" . (PAD + 22) . " y12 w220 h17 c" . C_MUTED, "偵測到注音亂碼　（按這裡拖曳）")

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
        ix := mx + 8, iy := my + 18
    } else if (CLICKOK) {                   ; 鍵盤選取 → 用「你點進文字框的位置」
        ix := CLICKX, iy := CLICKY + 30
    } else {                                ; 真的沒線索 → 視窗底部置中
        r := ActiveWinRect()
        ix := r[1] + (r[3] - ToPhys(w)) // 2
        iy := r[2] + r[4] - ToPhys(58) - 50
    }
    ClampToScreen(&ix, &iy, ToPhys(w), ToPhys(58))
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
        OpenCandidates(res, "selection", mx, my + 18)
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
    global POPUP_ON, LASTGEO, FLIPPED
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
    pw := ToPhys(winW), ph := ToPhys(winH)  ; 視窗實際佔用的實體像素
    if (MANUALX >= 0) {                     ; 使用者拖曳指定過位置 → 一律用它
        px := MANUALX, py := MANUALY
    } else if (ANCMODE == "window") {       ; 固定在作用中視窗底部置中
        px := ANCW[1] + (ANCW[3] - pw) // 2
        py := ANCW[2] + ANCW[4] - ph - 50
    } else {
        px := ANCX, py := ANCY
        ; 下方放不下就翻到插入點上方 —— 但這個決定只做一次並固定住，
        ; 否則展開/收起同音字時視窗高度一變，就會在上下兩個位置之間彈跳。
        ; 變數名不能用 sT/sB 之類 —— AHK 不分大小寫，會撞到全域的 ST
        ScreenBounds(px, py, &scrL, &scrT, &scrR, &scrB)
        if (!FLIPPED && py + ph > scrB - 10)
            FLIPPED := true
        if (FLIPPED)
            py := ANCY - ph - 36
    }
    ClampToScreen(&px, &py, pw, ph)
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
    global BUF, HIT, BUSY, ST, MANUALX, MANUALY
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
    BUF := "", HIT := "", ST := "", MANUALX := -1, MANUALY := -1
    IH.Start()
    BUSY := false
}

; 拖曳中：跟著滑鼠移動；放開左鍵就記住這個位置
DragMove() {
    global DRAGGING, MANUALX, MANUALY, LASTGEO
    if (!DRAGGING || POPUP == "")
        return
    if (!GetKeyState("LButton", "P")) {
        DRAGGING := false
        SetTimer(DragMove, 0)
        try WinSetExStyle("+0x02000000", POPUP.Hwnd)   ; 放開後恢復雙緩衝
        try {
            WinGetPos(&wx, &wy, , , POPUP.Hwnd)
            MANUALX := wx, MANUALY := wy       ; 實體座標，只影響目前這個候選窗
            LASTGEO := ""            ; 位置變了，下次 Render 要重新定位
        }
        return
    }
    MouseGetPos(&mx, &my)
    ; SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE = 0x0015，只搬位置最省事
    try DllCall("SetWindowPos", "Ptr", POPUP.Hwnd, "Ptr", 0,
        "Int", mx - DRAGDX, "Int", my - DRAGDY, "Int", 0, "Int", 0, "UInt", 0x0015)
}

; ---------- 設定 ----------
LoadSettings() {
    global CHROME_DETECT, PAUSED, MODE
    CHROME_DETECT := (IniRead(SETTINGS_FILE, "settings", "chromeDetect", "1") != "0")
    PAUSED := (IniRead(SETTINGS_FILE, "settings", "enabled", "1") == "0")
    MODE := IniRead(SETTINGS_FILE, "settings", "mode", "conservative")
    ApplyMode()
}

SaveSettings() {
    try {
        IniWrite(CHROME_DETECT ? 1 : 0, SETTINGS_FILE, "settings", "chromeDetect")
        IniWrite(PAUSED ? 0 : 1, SETTINGS_FILE, "settings", "enabled")
        IniWrite(MODE, SETTINGS_FILE, "settings", "mode")
    }
}

; 靈敏度：保守＝很有把握才跳；積極＝寧可多跳
ApplyMode() {
    global THRESH, MINSYL
    if (MODE == "aggressive")
        THRESH := 0.6, MINSYL := 1
    else
        THRESH := 0.8, MINSYL := 2
}

; ---------- 開機自動啟動 ----------
StartupLink() {
    return A_Startup . "\注音亂碼偵測.lnk"
}

IsAutoStart() {
    return FileExist(StartupLink()) ? true : false
}

SetAutoStart(on) {
    try {
        if (on) {
            ; 未編譯時要透過 AutoHotkey 執行檔帶入腳本路徑
            target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
            args := A_IsCompiled ? "" : Chr(34) . A_ScriptFullPath . Chr(34)
            FileCreateShortcut(target, StartupLink(), A_ScriptDir, args,
                "注音亂碼偵測", A_ScriptDir . "\icon.ico")
        } else if (IsAutoStart()) {
            FileDelete(StartupLink())
        }
        return true
    }
    return false
}

; ---------- 設定視窗 ----------
ShowSettings() {
    global SETGUI
    if (SETGUI != "") {
        try {
            SETGUI.Show()
            return
        }
    }
    g := Gui("+AlwaysOnTop", "注音亂碼偵測 — 設定")
    g.BackColor := "FFFFFF"
    g.MarginX := 18, g.MarginY := 16

    g.SetFont("s10", "Microsoft JhengHei")
    g.Add("Checkbox", "vEnabled Checked" . (PAUSED ? 0 : 1), "啟用偵測")
    g.SetFont("s9")
    g.Add("Text", "xm+22 y+2 c888888", "關閉後不會跳出任何候選窗。")

    g.SetFont("s10")
    g.Add("Text", "xm y+16", "偵測靈敏度")
    g.SetFont("s9")
    g.Add("Radio", "xm y+8 vModeCon Checked" . (MODE == "aggressive" ? 0 : 1), "保守（建議）")
    g.Add("Text", "xm+22 y+2 c888888", "很有把握才跳，幾乎不打擾；偶爾會漏接短亂碼。")
    g.Add("Radio", "xm y+8 vModeAgg Checked" . (MODE == "aggressive" ? 1 : 0), "積極")
    g.Add("Text", "xm+22 y+2 c888888", "寧可多跳、抓好抓滿；打英文時偶爾會被打擾。")

    g.SetFont("s10")
    g.Add("Checkbox", "xm y+18 vChrome Checked" . (CHROME_DETECT ? 1 : 0), "在 Chrome 中也偵測")
    g.SetFont("s9")
    g.Add("Text", "xm+22 y+2 w400 c888888", "若你另外裝了 Chrome 擴充，請關閉這項，否則會跳出兩個候選窗。")

    g.SetFont("s10")
    g.Add("Checkbox", "xm y+18 vAuto Checked" . (IsAutoStart() ? 1 : 0), "開機時自動啟動")

    g.SetFont("s9")
    g.Add("Text", "xm y+20 w420 c888888",
        "偵測內容只存在記憶體，不寫入檔案、不連上網路。")

    g.SetFont("s10")
    g.Add("Button", "xm y+16 w96 h30 Default", "儲存").OnEvent("Click", (*) => SaveFromGui(g))
    g.Add("Button", "x+8 yp w96 h30", "關閉").OnEvent("Click", (*) => g.Hide())
    g.OnEvent("Close", (*) => g.Hide())
    SETGUI := g
    g.Show("AutoSize")
}

SaveFromGui(g) {
    global CHROME_DETECT, PAUSED, MODE
    v := g.Submit(false)
    PAUSED := !v.Enabled
    MODE := v.ModeAgg ? "aggressive" : "conservative"
    CHROME_DETECT := v.Chrome ? true : false
    ApplyMode()
    SaveSettings()
    if (!SetAutoStart(v.Auto))
        MsgBox("開機自動啟動設定失敗，可能是權限不足。", "注音亂碼偵測", "Icon!")
    A_IconTip := "注音亂碼偵測（" . (PAUSED ? "已暫停" : "監看中") . "）"
    Reset()
    g.Hide()
    Tip("設定已儲存", 1500)
}

; ---------- 其他 ----------
TogglePause() {
    global PAUSED
    PAUSED := !PAUSED
    SaveSettings()
    Reset()
    A_IconTip := "注音亂碼偵測（" . (PAUSED ? "已暫停" : "監看中") . "）"
    Tip(PAUSED ? "已暫停偵測" : "已繼續偵測", 1200)
}

Tip(s, ms) {
    ToolTip(s)
    SetTimer(() => ToolTip(), -ms)
}
