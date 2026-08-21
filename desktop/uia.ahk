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
