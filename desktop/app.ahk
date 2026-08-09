#Requires AutoHotkey v2.0
#SingleInstance Force

; 編譯後 exe 的版本資訊。空白的 metadata 會提高防毒的啟發式可疑度 ——
; AHK 編譯檔本來就容易被誤判（直譯器+腳本像加殼、全域鍵盤 hook 像側錄器），
; 填齊這些欄位是免費且該做的一步。CompanyName 可改成你的名字或 GitHub 帳號。
;@Ahk2Exe-SetProductName 注音亂碼偵測
;@Ahk2Exe-SetCompanyName 注音亂碼偵測
;@Ahk2Exe-SetDescription 注音亂碼偵測 — 把打錯的英文亂碼還原成中文
;@Ahk2Exe-SetVersion 1.0.0.0
;@Ahk2Exe-SetProductVersion 1.0.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 — MIT License
;@Ahk2Exe-SetOrigFilename 注音亂碼偵測.exe
;@Ahk2Exe-SetLanguage 0x0404
; 注音亂碼偵測 — 桌面版（適用 Word / PPT 等所有 Windows 程式）
; 監看輸入 → 偵測 → 候選窗（3 整句候選 + 逐字換同音字）→ 退格 + 送出中文
;
; 隱私設計：輸入緩衝只存在記憶體、永不寫入檔案、完全不連網；
; 按下 Enter/Tab/Esc/方向鍵、點滑鼠、切換視窗都會立刻清空緩衝。
;
; 效能：候選窗的控制項只建立一次，之後只更新內容與位置（避免重建造成閃爍）。
#Include engine.ahk
#Include draw.ahk

global DICT := ""
; 詞庫要載入好幾秒，但熱鍵一開始就生效了 ——
; 沒有這個旗標，使用者在載入期間點滑鼠就會拿空詞庫去偵測而崩潰。
global READY := false
global BUF := ""          ; 目前累積的輸入（只在記憶體）
global HIT := ""          ; 目前偵測結果 {res, offset}
global ST := ""           ; 候選窗狀態
global BUSY := false      ; 執行替換中，暫停監看避免吃到自己送出的按鍵
global PAUSED := false
global LASTWIN := 0
global POPUP := ""
global HITS := []         ; 目前畫面上的可點擊區域
global TRAYCOLS := 10     ; 同音字盤實際欄數（繪圖時算出，鍵盤換行要用）
global POPUP_ON := false
; 目前環境能否顯示候選窗。#HotIf 每按一次鍵就會求值，不能在裡面直接做
; DllCall 與視窗查詢，所以由 WatchWindow 每 400ms 更新這個快取。
global CANSHOW := true
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
global FLIPDONE := false  ; 翻面是否已經決定過。決定時會預留同音字盤展開後的高度，
                          ; 所以之後不論展開或收起，浮窗都不會再改變位置。
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

; 螢幕縮放：AHK 只把「視窗尺寸」乘上這個係數，「位置」則是實體像素。
; 所以位置一律用實體座標，只有要跟螢幕邊界比大小時，才把尺寸換算成實體像素。
global DPIF := A_ScreenDPI / 96

; 若使用者「同時」裝了 Chrome 擴充，在 Chrome 裡就會跳出兩個候選窗。
; 但只裝桌面版的人若預設關閉，Chrome 裡會莫名其妙沒反應且看不出原因 ——
; 所以預設「在 Chrome 也偵測」，遇到重複的人再從系統列關掉即可。
global BROWSER_APPS := Map("chrome.exe", true)
global CHROME_DETECT := true
global LEVEL := 2                  ; 靈敏度 1(很保守)～5(很積極)，2 是先前一路測試的設定
global THRESH := 0.8, MINSYL := 2  ; 由 LEVEL 換算而來
global SETGUI := ""
global WELGUI := ""
global SETTINGS_FILE := A_ScriptDir "\settings.ini"
; 贊助連結：填入後，系統列選單與設定頁才會出現「支持開發」入口。
; 留空＝完全不顯示，避免發布時出現點了沒反應的死連結。
;
; 指向自家頁面而非收款平台，是為了讓收款方式能隨時更換 —— 這個常數編進 exe，
; 一改就得重新編譯，hash 一變防毒白名單就失效，得整套複驗流程重來一次。
; 指到 GitHub Pages 之後，換收款平台只要改 docs/support.md，exe 完全不用動。
global SUPPORT_URL := "https://b96093.github.io/bopomofo-garble-detector/support"
; 問題回報管道。本工具刻意不做任何遙測，所以這是唯一會有的回饋來源 ——
; 沒有它，使用者遇到問題只會默默解除安裝，而你永遠不會知道。
global ISSUES_URL := "https://github.com/b96093/bopomofo-garble-detector/issues"


; ---------- 啟動 ----------
TraySetIcon(A_ScriptDir "\icon.ico", 1, true)
A_IconTip := "注音亂碼偵測（詞庫載入中，請稍候…）"
LoadSettings()
A_TrayMenu.Delete()
; 托盤選單只放會反覆用到的動作。「支持開發」與「移除本工具」都是一次性的，
; 放在這裡只會讓每次右鍵都得多掃過兩行 —— 移進設定頁。
;
; 「暫停偵測」用打勾表示目前狀態，而不是把兩個動作寫成「暫停 / 繼續偵測」——
; 後者看不出現在是哪個狀態，也讓人分不清它和「結束」的差別。
A_TrayMenu.Add("暫停偵測", (*) => TogglePause())
A_TrayMenu.Add("使用說明…", (*) => ShowWelcome())
A_TrayMenu.Add("設定…", (*) => ShowSettings())
A_TrayMenu.Add()
A_TrayMenu.Add("結束", (*) => ExitApp())
A_TrayMenu.Default := "設定…"
SyncPauseMenu()

DICT := LoadDict(A_ScriptDir "\dict.txt")
READY := true
BuildPopup()
BuildIcon()
SyncTrayIcon()
Tip("注音亂碼偵測已啟動`n詞庫 " . DICT.Count . " 讀音", 2000)

; 第一次執行先把使用說明打開。這是背景常駐工具 —— 若什麼都不說就開始監看，
; 使用者打字時突然冒出一個浮窗，第一反應會是中毒而不是「功能生效了」。
; 要等詞庫載入完（READY）才開，說明視窗裡的試打框才真的能用。
if (IniRead(SETTINGS_FILE, "settings", "welcomed", "0") != "1") {
    CreateDesktopShortcut()
    ShowWelcome()
}

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
    if (!READY || BUSY || PAUSED)
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
    global LASTWIN, CLICKOK, CANSHOW
    CANSHOW := CanShowOverlay()
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
        ; 自繪的候選窗沒有子控制項，要自己判斷點到哪一格
        try {
            WinGetPos(&wx, &wy, , , POPUP.Hwnd)
            hitCell := HitTest(HITS, x - wx, y - wy)
            if (hitCell != "") {
                if (hitCell.k == "drag") {
                    ; 標題列 → 開始拖曳（不奪焦視窗不吃系統內建拖曳，自己追蹤滑鼠）
                    DRAGDX := x - wx, DRAGDY := y - wy
                    DRAGGING := true
                    SetTimer(DragMove, 8)
                } else if (hitCell.k == "cand") {
                    SetTimer(() => Accept(ST.cands[hitCell.i]), -1)
                } else if (hitCell.k == "char") {
                    SetTimer(() => ToggleChar(hitCell.i), -1)
                } else if (hitCell.k == "hom") {
                    SetTimer(() => PickHom(hitCell.i), -1)
                } else if (hitCell.k == "commit") {
                    SetTimer(() => Accept(DraftText()), -1)
                }
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
    global BUF, HIT, ST, MANUALX, MANUALY, FLIPPED, FLIPDONE
    BUF := "", HIT := "", ST := ""
    MANUALX := -1, MANUALY := -1     ; 拖曳只對當下那個候選窗有效
    FLIPPED := false, FLIPDONE := false
    HidePopup()
    HideIcon()
}

; ---------- 偵測 ----------
; 現在的環境能不能顯示候選窗？
;
; 全螢幕遊戲（例如英雄聯盟）會獨佔畫面，我們的分層視窗畫不上去。但程式並不知道
; 自己沒被畫出來 —— POPUP_ON 仍為 true，於是 Enter 被熱鍵攔截並直接套用第一個候選。
; 使用者按 Enter 是想送出聊天訊息，結果訊息沒送出、文字卻自己變成中文，
; 而且完全沒有選字的機會。這違背了「永不自動替換，一定要你確認」——
; 確認介面看不見時，那個確認等於不存在。比不支援更糟。
;
; 所以：顯示不了 UI 的環境，就完全不偵測。
CanShowOverlay() {
    ; Windows 自己就是用這個 API 判斷「現在適不適合彈通知」
    ; 變數不可命名為 st —— AHK 不分大小寫，會撞到全域的 ST（候選窗狀態）
    notifState := 0
    try {
        if (DllCall("shell32\SHQueryUserNotificationState", "Int*", &notifState) == 0) {
            if (notifState == 3 || notifState == 4)     ; D3D 全螢幕 / 簡報模式
                return false
        }
    }
    ; 無邊框全螢幕未必會被上面抓到，再用幾何條件補一刀：
    ; 作用中視窗鋪滿某個螢幕、且沒有標題列
    try {
        hwnd := WinExist("A")
        if (hwnd) {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            if (!(WinGetStyle(hwnd) & 0x00C00000)) {      ; 無 WS_CAPTION
                Loop MonitorGetCount() {
                    MonitorGet(A_Index, &ml, &mt, &mr, &mb)
                    if (ww >= mr - ml && wh >= mb - mt && wx <= ml && wy <= mt)
                        return false
                }
            }
        }
    }
    return true
}

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
    if (!READY || PAUSED || BUF == "") {
        HidePopup()
        return
    }
    if (IsExcludedApp()) {        ; Chrome 裡交給擴充，避免兩個候選窗同時出現
        BUF := ""
        HidePopup()
        return
    }
    ; 全螢幕遊戲等環境畫不出候選窗。若還是偵測，Enter 會被攔截並直接替換文字，
    ; 使用者卻看不到任何候選 —— 寧可完全不作用。
    if (!CanShowOverlay()) {
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
ClipSeq() {
    return DllCall("GetClipboardSequenceNumber", "UInt")
}

; Windows 不讓程式直接讀別的程式裡選取的文字，只能靠送出「複製」再從剪貼簿讀回，
; 讀完立刻還原原本的剪貼簿內容。整個過程只在記憶體，不寫檔、不外傳。
;
; 舊寫法是「先清空剪貼簿 → ClipWait 等內容出現」。問題是這個函式在每次水平拖曳
; 滑鼠、每次 Ctrl+A 都會被呼叫，而多數時候根本沒有選到文字 —— 那時 ClipWait 會
; 等滿逾時（實測 437ms），期間使用者的剪貼簿是空的：按 Ctrl+V 會貼到空白，
; 剛截好的圖也會被結尾的「還原」蓋掉。
;
; 改用剪貼簿序號判斷複製是否真的發生。沒發生就直接返回，剪貼簿一個位元組都不動。
GetSelectedText() {
    seq0 := ClipSeq()
    saved := ClipboardAll()          ; 唯讀，不會改變序號
    Send("^c")
    deadline := A_TickCount + 220
    while (A_TickCount < deadline && ClipSeq() == seq0)
        Sleep(10)
    if (ClipSeq() == seq0)
        return ""                    ; 沒有選取 —— 使用者的剪貼簿完全沒被碰過
    seqOurs := ClipSeq()             ; 我們的 ^c 造成的序號
    text := A_Clipboard
    ; 讀取期間若剪貼簿又被別人寫入（例如使用者剛好按了截圖），就不要還原，
    ; 否則會把對方的內容蓋掉
    if (ClipSeq() == seqOurs)
        A_Clipboard := saved
    return text
}

CheckSelection(fromMouse := true) {
    global SELRES, SELFROMMOUSE
    if (!READY || BUSY || PAUSED || POPUP_ON || IsExcludedApp() || !CanShowOverlay())
        return
    SELFROMMOUSE := fromMouse
    text := Trim(NormalizeTyped(GetSelectedText()), " `t`r`n")
    if (text == "" || StrLen(text) > 120) {   ; 太長的選取不是我們的使用情境
        HideIcon()
        return
    }
    ; 用和打字路徑一樣的門檻。這裡是「被動」提示 —— 每次滑鼠拖曳、每次 Ctrl+A 都會跑，
    ; 選字複製是日常動作而非意圖。放寬成 (0.5, 1, manual) 會讓版本號、IP、電話號碼
    ; 統統跳出圖示打擾人，而那些正是使用者最常選取來複製的東西。
    res := Detect(text, DICT, THRESH, MINSYL)
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
    global ST, ANCX, ANCY, ANCMODE, ANCW
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

; ---------- 選取後浮出的小 icon ----------
BuildIcon() {
    global ICON, ICONTEXT, ICONHINT
    ICON := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    ICON.BackColor := "FFFFFF"
    ICON.MarginX := 0, ICON.MarginY := 0
    try {
        iconPic := ICON.Add("Picture", "x11 y10 w18 h18", A_ScriptDir . "\icon.ico")
        iconPic.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    }
    ICON.SetFont("s11", "Microsoft JhengHei")
    ICONTEXT := ICON.Add("Text", "x35 y9 w240 h22 c1E1E1E", "")
    ICONTEXT.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    ICON.SetFont("s9", "Microsoft JhengHei")
    ICONHINT := ICON.Add("Text", "x35 y33 w240 h18 c1A5FB4", "↵ 轉中文或編輯")
    ICONHINT.OnEvent("Click", (*) => SetTimer(IconClicked, -1))
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ICON.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ICON.Hwnd, "UInt", 34, "UInt*", 0x00DCDCDC, "UInt", 4)
}

ShowIcon(preview) {
    global ICON_ON
    shown := Fit(preview, 32)                  ; 先決定要顯示多少字
    w := Max(230, 60 + StrLen(shown) * 20)     ; 再依實際顯示長度決定寬度
    ICONTEXT.Value := "→ " . shown
    ICONTEXT.Move(35, 9, w - 46, 22)
    ICONHINT.Move(35, 33, w - 46, 18)
    ; 滑鼠選取 → 出現在「放開滑鼠的位置」，而不是現在的滑鼠位置。
    ; 從放開滑鼠到這裡中間隔了去抖動 120ms + 讀剪貼簿最多 220ms，
    ; 期間滑鼠早就移開了 —— 用當下位置會讓浮窗看起來隨機亂跳。
    if (SELFROMMOUSE && LASTUPX != 0) {
        ix := LASTUPX + 8, iy := LASTUPY + 18
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

; ---------- 建立候選窗（只做一次） ----------
BuildPopup() {
    global POPUP
    ; -DPIScale：自繪一律用實體像素，避免 AHK 再縮放一次
    ; 分層視窗（0x80000）：位置、大小、畫面內容可以一次原子性送出，
    ; 系統不會出現「新尺寸、舊內容」的中間畫面 —— 這就是不閃爍的關鍵。
    ; 圓角與邊框由我們自己畫（角落透明），所以不需要 DWM 的圓角設定。
    POPUP := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080000 -DPIScale")
    POPUP.MarginX := 0, POPUP.MarginY := 0
}

; ---------- 畫出候選窗 ----------
Render() {
    global POPUP_ON, LASTGEO, HITS, FLIPPED, FLIPDONE
    if (ST == "")
        return
    ; 變數名不可用 st —— AHK 不分大小寫，會撞到全域的 ST
    view := {cands: ST.cands, sel: ST.sel, draft: ST.draft, zone: ST.zone,
             ci: ST.ci, hi: ST.hi, draftText: DraftText()}
    layout := BuildLayout(view, (k) => HomsAt(k))
    HITS := layout.hits


    pw := layout.w, ph := layout.h
    if (MANUALX >= 0) {
        px := MANUALX, py := MANUALY
    } else if (ANCMODE == "window") {
        px := ANCW[1] + (ANCW[3] - pw) // 2
        py := ANCW[2] + ANCW[4] - ph - 50
    } else {
        px := ANCX, py := ANCY
        ; 翻面在開窗時就決定，而且用「同音字盤展開後」的高度來判斷。
        ; 舊寫法用當下高度判斷 —— 展開同音字讓浮窗變高才觸發翻面，
        ; 使用者眼中就是浮窗突然跳到另一個位置。
        ScreenBounds(px, py, &scrL, &scrT, &scrR, &scrB)
        if (!FLIPDONE) {
            FLIPPED := (ANCY + ph + MaxTrayExtra() > scrB - 10)
            FLIPDONE := true
        }
        ; 未翻面＝上緣釘在插入點、向下長；翻面＝下緣釘在插入點上方、向上長。
        ; 兩種都只往單一方向展開，位置可預期。
        if (FLIPPED)
            py := ANCY - ph - 36
    }
    ClampToScreen(&px, &py, pw, ph)

    ; 位置、大小、內容一次送出（分層視窗），系統不會有中間畫面
    r := RenderLayered(layout, A_ScriptDir . "\icon.ico")
    pt := Buffer(8, 0)
    NumPut("Int", px, pt, 0), NumPut("Int", py, pt, 4)
    sz := Buffer(8, 0)
    NumPut("Int", pw, sz, 0), NumPut("Int", ph, sz, 4)
    srcPt := Buffer(8, 0)
    blend := Buffer(4, 0)
    NumPut("UChar", 0, blend, 0), NumPut("UChar", 0, blend, 1)
    NumPut("UChar", 255, blend, 2), NumPut("UChar", 1, blend, 3)   ; AC_SRC_ALPHA
    DllCall("UpdateLayeredWindow", "Ptr", POPUP.Hwnd, "Ptr", 0, "Ptr", pt, "Ptr", sz,
        "Ptr", r.dc, "Ptr", srcPt, "UInt", 0, "Ptr", blend, "UInt", 2)   ; ULW_ALPHA
    ReleaseRender(r)
    if (!POPUP_ON) {
        DllCall("ShowWindow", "Ptr", POPUP.Hwnd, "Int", 8)      ; SW_SHOWNA（顯示但不奪焦）
        POPUP_ON := true
    }
    LASTGEO := px . "," . py . "," . pw . "," . ph
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
    global POPUP_ON, LASTGEO
    if (POPUP_ON && POPUP != "") {
        try DllCall("ShowWindow", "Ptr", POPUP.Hwnd, "Int", 0)   ; SW_HIDE
        POPUP_ON := false
        LASTGEO := ""
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
#HotIf ICON_ON && !POPUP_ON && CANSHOW
Enter:: IconClicked()
Escape:: HideIcon()
#HotIf

; 加上 CANSHOW：全螢幕遊戲裡條件不成立，Enter／方向鍵完全不被攔截，
; 原樣穿透給遊戲。若只在 OnEnter 裡擋，Enter 仍會被吃掉，
; 使用者會發現「聊天訊息按 Enter 送不出去」。
#HotIf POPUP_ON && CANSHOW
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
    target := ST.hi + d * TRAYCOLS
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
    global CHROME_DETECT, PAUSED, LEVEL
    CHROME_DETECT := (IniRead(SETTINGS_FILE, "settings", "chromeDetect", "1") != "0")
    PAUSED := (IniRead(SETTINGS_FILE, "settings", "enabled", "1") == "0")
    LEVEL := Integer(IniRead(SETTINGS_FILE, "settings", "level", "2"))
    if (LEVEL < 1 || LEVEL > 5)
        LEVEL := 2
    ApplyLevel()
}

SaveSettings() {
    try {
        IniWrite(CHROME_DETECT ? 1 : 0, SETTINGS_FILE, "settings", "chromeDetect")
        IniWrite(PAUSED ? 0 : 1, SETTINGS_FILE, "settings", "enabled")
        IniWrite(LEVEL, SETTINGS_FILE, "settings", "level")
    }
}

; 靈敏度換算：門檻＝轉出來要有多像中文；最少音節＝至少幾個字才理會
ApplyLevel() {
    global THRESH, MINSYL
    switch LEVEL {
        case 1: THRESH := 0.9,  MINSYL := 3
        case 3: THRESH := 0.7,  MINSYL := 2
        case 4: THRESH := 0.6,  MINSYL := 1
        case 5: THRESH := 0.5,  MINSYL := 1
        default: THRESH := 0.8, MINSYL := 2
    }
}

LevelDesc(n) {
    switch n {
        case 1: return "很保守：非常確定才跳出通知浮窗，幾乎不會打擾你，但容易漏接。"
        case 3: return "標準：一般情況都會跳出通知浮窗。"
        case 4: return "積極：連單一個字也會跳出通知浮窗；打英文時偶爾會被打擾。"
        case 5: return "很積極：盡量不漏接，寧可多跳出通知浮窗；打英文時較常被打擾。"
        default: return "保守（建議）：很有把握才跳出通知浮窗；偶爾會漏接很短的亂碼。"
    }
}

; ---------- 桌面捷徑 ----------
; 免安裝程式沒有安裝流程，不會出現在開始功能表，Windows 搜尋也找不到。
; 使用者從系統列選「結束」之後，往往就想不起來 exe 解壓在哪個資料夾了。
; 首次執行時建一個桌面捷徑；不想要的人直接刪掉即可，不需要任何設定。
CreateDesktopShortcut() {
    link := A_Desktop . "\注音亂碼偵測.lnk"
    if (FileExist(link))
        return
    try {
        ; 未編譯時要透過 AutoHotkey 執行檔帶入腳本路徑
        target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        args := A_IsCompiled ? "" : Chr(34) . A_ScriptFullPath . Chr(34)
        ; 工作目錄要設在程式所在資料夾 —— dict.txt 是外部檔案，找不到就無法運作
        FileCreateShortcut(target, link, A_ScriptDir, args,
            "注音亂碼偵測", A_ScriptDir . "\icon.ico")
    }
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

; ---------- 使用說明 ----------
ShowWelcome() {
    global WELGUI
    if (WELGUI != "") {
        try {
            WELGUI.Show()
            return
        }
    }
    ; 刻意不加 AlwaysOnTop：候選窗本身是置頂的，說明視窗若也置頂又拿到焦點，
    ; 就會蓋住它正要示範的那個候選窗。
    ;
    ; 排版全部用明確座標、且不使用輔助函式。理由各有一個實測教訓：
    ;   · y+N 相對定位與 AutoSize 都會少算頁尾色帶，視窗高度不足而截斷內容
    ;   · 曾把輔助函式的參數命名為 w，AHK 不分大小寫，它就是外層的寬度變數 W，
    ;     第一次呼叫就把 W 設成 0，之後所有文字控制項寬度變 0、整片消失
    ; 攤平寫雖然囉嗦，但每個座標都看得見、改得動、驗證得了。
    g := Gui("", "注音亂碼偵測 — 使用說明")
    g.BackColor := "FFFFFF"
    g.MarginX := 0, g.MarginY := 0
    PAD := 26, FN := "Microsoft JhengHei"

    ; ── 標題帶 ──
    g.Add("Text", "x0 y0 w612 h84 Background1A5FB4")
    g.SetFont("s14 w600 cFFFFFF", FN)
    g.Add("Text", "x" . PAD . " y22 w560 BackgroundTrans", "打字忘了切換輸入法時，幫你救回來")
    g.SetFont("s10 w400 cD6E4F7", FN)
    g.Add("Text", "x" . PAD . " y52 w560 BackgroundTrans", "你不用做任何事，照常打字就好。")

    ; ── 示範卡：整份說明最重要的一句 ──
    g.Add("Text", "x0 y96 w612 h58 BackgroundF2F6FC")
    g.SetFont("s14 w600 c1A5FB4", "Consolas")
    g.Add("Text", "x" . PAD . " y113 w160 BackgroundTrans", "ji394t au04")
    g.SetFont("s12 w400 cAAAAAA", FN)
    g.Add("Text", "x" . (PAD + 172) . " y114 w40 BackgroundTrans", "→")
    g.SetFont("s14 w600 c1E1E1E", FN)
    g.Add("Text", "x" . (PAD + 214) . " y111 w200 BackgroundTrans", "我愛吃麵")

    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y174 w560 BackgroundTrans", "先試試看")
    g.SetFont("s12 w400 c1E1E1E", FN)
    g.Add("Edit", "x" . PAD . " y198 w560 h42 -VScroll")
    g.SetFont("s9 w400 c999999", FN)
    g.Add("Text", "x" . PAD . " y248 w560 BackgroundTrans",
        "在上面打 ji394t au04，候選窗會真的跳出來 —— 這是完整功能，不是模擬畫面。")

    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y286 w560 BackgroundTrans", "候選窗跳出來之後")
    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y312 w70 BackgroundTrans", "↑ ↓")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . (PAD + 78) . " y312 w482 BackgroundTrans", "換一個候選句")
    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y338 w70 BackgroundTrans", "Enter")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . (PAD + 78) . " y338 w482 BackgroundTrans", "換成中文")
    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y364 w70 BackgroundTrans", "Esc")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . (PAD + 78) . " y364 w482 BackgroundTrans", "不要，繼續打英文")
    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y390 w70 BackgroundTrans", "→")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . (PAD + 78) . " y390 w482 BackgroundTrans", "展開同音字（把「面」換成「麵」）")

    g.SetFont("s9 w400 c888888", FN)
    g.Add("Text", "x" . PAD . " y422 w560 BackgroundTrans",
        "永遠不會自動替換 —— 一定要你按 Enter 或用滑鼠點，才會動到你的文字。")

    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y458 w560 BackgroundTrans", "打完才發現打錯了？")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . PAD . " y484 w560 BackgroundTrans",
        "把那段亂碼用滑鼠選取起來，旁邊會出現小按鈕，點它就能轉換。")

    g.SetFont("s10 w600 c1A5FB4", FN)
    g.Add("Text", "x" . PAD . " y524 w560 BackgroundTrans", "之後在哪裡找到它")
    ; 直接把真正的圖示畫出來 —— 使用者要在系統列一堆小圖裡找它，
    ; 光用文字說「本工具的圖示」沒有幫助
    g.Add("Picture", "x" . PAD . " y548 w22 h22", A_ScriptDir . "\icon.ico")
    g.SetFont("s10 w400 c444444", FN)
    g.Add("Text", "x" . (PAD + 30) . " y550 w530 BackgroundTrans",
        "找這個圖示。在它上面按右鍵可暫停偵測、開啟設定、重看這份說明。")

    ; ── 頁尾 ──
    g.Add("Text", "x0 y590 w612 h74 BackgroundF7F7F7")
    g.SetFont("s10 w400 c1E1E1E", FN)
    g.Add("Button", "x" . PAD . " y602 w104 h32 Default", "開始使用").OnEvent("Click", (*) => g.Hide())
    g.Add("Button", "x+8 yp w104 h32", "開啟設定…").OnEvent("Click", (*) => ShowSettings())

    ; 贊助放頁尾右側：與主要動作分開，但用強調色與較大字級，不會被當成註腳。
    ; 這是使用者剛看完說明、對工具最有好感的時刻。
    if (SUPPORT_URL != "") {
        ; 用 Button 而不是彩色文字：文字再顯眼也不會把游標變成手指，
        ; 使用者看不出可以點（設定頁的「移除本工具」就踩過同一個坑）。
        ; 稱呼用「開發者」而非「我」—— 使用者不認識視窗裡的「我」是誰。
        g.SetFont("s10 w400 c1E1E1E", FN)
        g.Add("Button", "x" . (PAD + 386) . " y602 w174 h32", "請開發者喝杯咖啡")
            .OnEvent("Click", (*) => OpenSupport())
    }
    g.SetFont("s9 w400 c999999", FN)
    g.Add("Text", "x" . PAD . " y640 w560 BackgroundTrans",
        "完全離線 · 不寫檔 · 不蒐集內容　　這個工具永久免費")

    g.OnEvent("Close", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    WELGUI := g
    ; Show() 的 h 是「視窗」高度而非客戶區，標題列會吃掉一部分，
    ; 所以要比內容底緣（664）再多留一些，否則頁尾會被切掉。
    g.Show("w616 h692")
    MarkWelcomed()
}

; 記下「已經看過說明」。獨立於 SaveSettings：使用者可能從沒改過任何設定，
; 那樣 settings.ini 永遠不會產生，說明就會每次開機都跳一次。
MarkWelcomed() {
    try IniWrite(1, SETTINGS_FILE, "settings", "welcomed")
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
    g.Add("Text", "xm y+18", "偵測靈敏度")
    sld := g.Add("Slider", "xm y+8 w420 Range1-5 TickInterval1 Line1 Page1 vLevel", LEVEL)
    g.SetFont("s9")
    g.Add("Text", "xm y+2 w200 c888888", "← 保守（不容易被打擾）")
    g.Add("Text", "x+20 yp w200 Right c888888", "積極（盡量抓到）→")
    lbl := g.Add("Text", "xm y+8 w420 c555555", LevelDesc(LEVEL))
    sld.OnEvent("Change", (*) => lbl.Value := LevelDesc(sld.Value))

    g.SetFont("s10")
    g.Add("Checkbox", "xm y+18 vChrome Checked" . (CHROME_DETECT ? 1 : 0), "在 Chrome 中也偵測")
    g.SetFont("s9")
    g.Add("Text", "xm+22 y+2 w400 c888888", "若你另外裝了 Chrome 擴充，請關閉這項，否則會跳出兩個候選窗。")

    g.SetFont("s10")
    g.Add("Checkbox", "xm y+18 vAuto Checked" . (IsAutoStart() ? 1 : 0), "開機時自動啟動")

    g.SetFont("s9")
    g.Add("Text", "xm y+20 w420 c888888",
        "偵測內容只存在記憶體，不寫入檔案、不連上網路。")
    if (SUPPORT_URL != "") {
        ; 同說明視窗：用 Button，文字連結看不出可以點
        g.Add("Text", "xm y+10 w420 c888888", "這個工具永久免費，也不會有廣告。")
        g.SetFont("s10")
        g.Add("Button", "xm y+8 w174 h32", "請開發者喝杯咖啡")
            .OnEvent("Click", (*) => OpenSupport())
        g.SetFont("s9")
    }

    ; 版本號與回報管道。使用者回報問題時若不知道版本，幾乎無從查起 ——
    ; 這個 exe 光是開發期間就重編了七次。
    g.SetFont("s9")
    g.Add("Text", "xm y+18 w200 c888888", "注音亂碼偵測　" . AppVersion())
    g.Add("Button", "x+0 yp-6 w96 h28", "回報問題").OnEvent("Click", (*) => OpenIssues())

    g.SetFont("s10")
    g.Add("Button", "xm y+16 w96 h30 Default", "儲存").OnEvent("Click", (*) => SaveFromGui(g))
    g.Add("Button", "x+8 yp w96 h30", "關閉").OnEvent("Click", (*) => g.Hide())
    ; 移除放在最右下，與儲存／關閉隔開。原本做成灰色 Text 想低調，結果反效果：
    ; 看起來像停用、滑鼠移上去也不會變成手指，使用者以為按不動。
    ; 用真正的 Button —— 外觀與游標都會告訴使用者「這可以按」。
    g.SetFont("s9")
    g.Add("Button", "x+110 yp w110 h30", "移除本工具…").OnEvent("Click", (*) => Uninstall())
    g.OnEvent("Close", (*) => g.Hide())
    SETGUI := g
    g.Show("AutoSize")
}

SaveFromGui(g) {
    global CHROME_DETECT, PAUSED, LEVEL
    v := g.Submit(false)
    PAUSED := !v.Enabled
    LEVEL := v.Level
    CHROME_DETECT := v.Chrome ? true : false
    ApplyLevel()
    SaveSettings()
    SyncPauseMenu()
    if (!SetAutoStart(v.Auto))
        MsgBox("開機自動啟動設定失敗，可能是權限不足。", "注音亂碼偵測", "Icon!")
    SyncTrayIcon()
    Reset()
    g.Hide()
    Tip("設定已儲存", 1500)
}

; 版本號取自編譯進 exe 的版本資訊（來源就是檔頭的 Ahk2Exe 指示詞），
; 不另外維護一份常數，免得改了一邊忘了另一邊。
AppVersion() {
    if (A_IsCompiled) {
        try {
            v := FileGetVersion(A_ScriptFullPath)
            if (v != "")
                return RegExReplace(v, "\.0$")      ; 1.0.0.0 → 1.0.0
        }
    }
    return "開發版"
}

OpenIssues() {
    try Run(ISSUES_URL)
}

OpenSupport() {
    if (SUPPORT_URL != "")
        try Run(SUPPORT_URL)
}

; ---------- 移除 ----------
; 程式本身完全自包含，但會在資料夾外留下兩個捷徑（桌面、開機啟動）。
; 使用者只刪資料夾的話，開機啟動捷徑會殘留，Windows 每次開機都會去
; 嘗試啟動一個已經不存在的檔案 —— 所以要提供一個清乾淨的方式。
Uninstall() {
    msg := "即將進行：`n`n"
         . "・刪除桌面捷徑`n"
         . "・取消開機自動啟動`n"
         . "・結束程式`n`n"
         . "完成後會開啟程式所在資料夾，你直接刪掉整個資料夾就完全移除了。`n"
         . "（設定檔在資料夾內；你打過的文字從未被記錄，沒有其他殘留）`n`n"
         . "確定要移除嗎？"
    ; 設定視窗是 AlwaysOnTop。不指定 Owner 的話，這個確認框會被壓在它後面 ——
    ; 使用者看不到任何反應，會以為按鈕壞了，直到關掉設定視窗才發現它一直在。
    opt := "YesNo Icon?"
    try {
        if (SETGUI != "" && WinExist("ahk_id " . SETGUI.Hwnd))
            opt .= " Owner" . SETGUI.Hwnd
    }
    if (MsgBox(msg, "移除注音亂碼偵測", opt) != "Yes")
        return
    try FileDelete(A_Desktop . "\注音亂碼偵測.lnk")
    SetAutoStart(false)
    ; 開資料夾並選取程式本身，讓使用者不必自己找路徑
    try Run('explorer.exe /select,"' . A_ScriptFullPath . '"')
    ExitApp()
}

; ---------- 其他 ----------
TogglePause() {
    global PAUSED
    PAUSED := !PAUSED
    SaveSettings()
    Reset()
    SyncPauseMenu()
    SyncTrayIcon()
    Tip(PAUSED ? "已暫停偵測（圖示仍在系統列）" : "已繼續偵測", 1500)
}

; 系統列圖示要能一眼看出狀態：監看中＝彩色，已暫停＝灰階（比照 OneDrive 的做法）。
; 只靠滑鼠停留才看得到的提示文字不夠 —— 圖示本身就該說明狀態。
SyncTrayIcon() {
    try TraySetIcon(A_ScriptDir . (PAUSED ? "\icon-paused.ico" : "\icon.ico"), 1, true)
    A_IconTip := "注音亂碼偵測（" . (PAUSED ? "已暫停" : "監看中") . "）"
}

; 讓選單上的打勾反映目前狀態。設定頁也會改 PAUSED，所以兩邊都要呼叫。
SyncPauseMenu() {
    try {
        if (PAUSED)
            A_TrayMenu.Check("暫停偵測")
        else
            A_TrayMenu.Uncheck("暫停偵測")
    }
}

Tip(s, ms) {
    ToolTip(s)
    SetTimer(() => ToolTip(), -ms)
}
