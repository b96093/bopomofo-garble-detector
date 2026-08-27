#Requires AutoHotkey v2.0
; UI Automation：向應用程式問出「插入點／選取範圍在螢幕上的哪個矩形」。
;
; 為什麼需要這個：GetGUIThreadInfo 只對維護真正 Win32 插入點的控制項有效。
; Electron（Claude、Discord）、LINE、Chrome 網址列的文字是自己畫的，沒有真插入點，
; 候選窗只好退回滑鼠位置或視窗置中 —— 那正是使用者抱怨「亂跳、擋住字」的來源。
;
; UIA 換一個對象問：不是問系統插入點在哪，而是問應用程式「你那段文字在哪個矩形」。
; 支援的程式會直接給座標，跟微軟注音候選窗用的是同一類機制。
;
; 實測（2026-08-21，本機）：
;   可用    Word、記事本、Chrome 網址列、Chrome 網頁輸入框、Claude、LINE、Discord
;   不可用  Google 文件的選取（但插入點可用）、PowerPoint、Windows Terminal
; 拿不到就回 false，呼叫端沿用原本的邏輯，不會比以前差。
;
; 只用三個介面，vtable 索引如下（前三個一律是 IUnknown）：
;   IUIAutomation                8 = GetFocusedElement
;   IUIAutomationElement        16 = GetCurrentPattern
;   IUIAutomationTextPattern     5 = GetSelection
;   IUIAutomationTextRangeArray  3 = get_Length     4 = GetElement
;   IUIAutomationTextRange      10 = GetBoundingRectangles
; UIA_TextPatternId = 10014；矩形以 double 四個一組回傳（left, top, width, height）。

; 取得目前焦點處「選取範圍」的螢幕矩形；沒有選取時回傳的是插入點（寬度約 1）。
; 拿不到回 false。
UIA_TextRect(&x, &y, &w, &h) {
    static uia := ""
    static broken := false
    x := 0, y := 0, w := 0, h := 0
    if (broken)
        return false
    if (uia == "") {
        try uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}",
                             "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        catch {
            broken := true          ; 這台機器不支援就別再試，省下每次的例外成本
            return false
        }
    }
    el := 0, pat := 0, arr := 0, rng := 0, psa := 0
    ok := false
    try {
        ComCall(8, uia, "Ptr*", &el)
        if (el) {
            ComCall(16, el, "Int", 10014, "Ptr*", &pat)
            if (pat) {
                ComCall(5, pat, "Ptr*", &arr)
                if (arr) {
                    len := 0
                    ComCall(3, arr, "Int*", &len)
                    if (len > 0) {
                        ComCall(4, arr, "Int", 0, "Ptr*", &rng)
                        if (rng) {
                            ComCall(10, rng, "Ptr*", &psa)
                            if (psa) {
                                sa := ComValue(0x2005, psa)      ; VT_ARRAY | VT_R8
                                if (sa.MaxIndex() >= 3) {
                                    x := sa[0], y := sa[1], w := sa[2], h := sa[3]
                                    ; 高度為 0 代表拿到的是空矩形，沒有參考價值
                                    ok := (h > 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (rng)
        ObjRelease(rng)
    if (arr)
        ObjRelease(arr)
    if (pat)
        ObjRelease(pat)
    if (el)
        ObjRelease(el)
    return ok
}

; 讀取游標前 n 個字元；拿不到回空字串。
;
; 用途：判斷「工具緩衝的那串英文，到底有沒有真的出現在文件裡」。
; 桌面版攔的是輸入法之前的原始按鍵，所以使用者正常打中文時，緩衝裡同樣是一串
; 英文字母 —— 光看緩衝無法分辨「打中文」和「打出亂碼」。
;
; 原本靠 ImeChineseMode() 判斷，但實測那個查詢在不同程式回報不一致：
; 記事本回報中文模式（正確），Claude 卻回報非中文模式（錯誤，導致正常打中文時誤跳浮窗）。
; 直接讀文件內容就沒有這個問題 —— 螢幕上是什麼就是什麼。
;
; vtable：IUIAutomationTextRange 3=Clone  12=GetText  14=MoveEndpointByUnit
; TextPatternRangeEndpoint Start=0；TextUnit Character=0
UIA_TextBeforeCaret(n) {
    static uia := ""
    static broken := false
    if (broken)
        return ""
    if (uia == "") {
        try uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}",
                             "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        catch {
            broken := true
            return ""
        }
    }
    el := 0, pat := 0, arr := 0, rng := 0, cl := 0
    out := ""
    try {
        ComCall(8, uia, "Ptr*", &el)
        if (el) {
            ComCall(16, el, "Int", 10014, "Ptr*", &pat)
            if (pat) {
                ComCall(5, pat, "Ptr*", &arr)
                if (arr) {
                    len := 0
                    ComCall(3, arr, "Int*", &len)
                    if (len > 0) {
                        ComCall(4, arr, "Int", 0, "Ptr*", &rng)
                        if (rng) {
                            ComCall(3, rng, "Ptr*", &cl)          ; Clone
                            if (cl) {
                                moved := 0
                                ComCall(14, cl, "Int", 0, "Int", 0, "Int", -n, "Int*", &moved)
                                b := 0
                                ComCall(12, cl, "Int", -1, "Ptr*", &b)
                                if (b) {
                                    out := StrGet(b, "UTF-16")
                                    DllCall("oleaut32\SysFreeString", "Ptr", b)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (cl)
        ObjRelease(cl)
    if (rng)
        ObjRelease(rng)
    if (arr)
        ObjRelease(arr)
    if (pat)
        ObjRelease(pat)
    if (el)
        ObjRelease(el)
    return out
}

; 緩衝的英文有沒有真的落在文件裡？
;   1  = 有，輸入法沒轉換 → 該偵測
;   0  = 沒有，螢幕上是別的東西（多半是轉換成中文了）→ 不該出手
;  -1  = 讀不到，無法判斷 → 呼叫端自行退回舊的判斷方式
BufferLanded(buf) {
    n := StrLen(buf)
    if (n < 1)
        return -1
    seen := UIA_TextBeforeCaret(Min(n, 6))  ; 比對尾端幾個字就夠，讀太多沒必要
    return TailMatches(buf, seen)
}

; 緩衝的尾巴，跟螢幕上游標前讀到的尾巴，是不是同一段？
;   1 = 是（那串英文真的在畫面上）   0 = 不是   -1 = 資訊不足，無法判斷
;
; 抽成純函式是為了能直接測。先前把比對邏輯另外抄一份來測，抄的那份跟真正跑的
; 程式碼對不起來，SubStr 少算一個字才會沒被抓到。
;
; SubStr 的負數起點本身就代表「從尾端算起」，不必再 +1。
; 讀回來的長度不保證等於要求的長度（游標靠近開頭時會比較短），
; 所以取兩邊都有的那一段來比。
TailMatches(buf, seen) {
    n := StrLen(buf)
    if (n < 1 || seen == "")
        return -1
    k := Min(Min(n, 6), StrLen(seen))
    if (k < 1)
        return -1
    return (StrLower(SubStr(seen, -k)) == StrLower(SubStr(buf, -k))) ? 1 : 0
}
