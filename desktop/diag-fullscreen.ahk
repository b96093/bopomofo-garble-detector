#Requires AutoHotkey v2.0
#SingleInstance Force
; 開發／測試用：即時顯示「本工具現在認為能不能顯示候選窗」，以及判斷依據。
;
; 用途：切換到各種程式（遊戲、簡報、F11 全螢幕瀏覽器…），看右上角的即時判讀，
; 就能知道偵測會不會被停用、以及是哪一道判斷造成的。
;
; 執行：AutoHotkey64.exe diag-fullscreen.ahk　　結束：Esc

STATE_NAME := Map(
    1, "未登入/鎖定", 2, "忙碌", 3, "D3D 獨佔全螢幕",
    4, "簡報模式", 5, "可接受通知（正常）", 6, "勿擾時間", 7, "全螢幕市集App")

g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
g.BackColor := "1E1E1E"
g.SetFont("s10 cWhite", "Consolas")
txt := g.Add("Text", "w560 r11")
g.Show("NoActivate x20 y20")

SetTimer(Update, 250)

Update() {
    notifState := 0
    api := "（查詢失敗）"
    apiBlocks := false
    try {
        if (DllCall("shell32\SHQueryUserNotificationState", "Int*", &notifState) == 0) {
            api := notifState . " = " . (STATE_NAME.Has(notifState) ? STATE_NAME[notifState] : "?")
            apiBlocks := (notifState == 3 || notifState == 4)
        }
    }

    geoBlocks := false, info := "（取不到作用中視窗）"
    try {
        hwnd := WinExist("A")
        if (hwnd) {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            style := WinGetStyle(hwnd)
            hasCaption := (style & 0x00C00000) != 0
            proc := WinGetProcessName(hwnd)
            covers := false, mon := "-"
            Loop MonitorGetCount() {
                MonitorGet(A_Index, &ml, &mt, &mr, &mb)
                if (ww >= mr - ml && wh >= mb - mt && wx <= ml && wy <= mt) {
                    covers := true, mon := A_Index . " (" . (mr - ml) . "x" . (mb - mt) . ")"
                    break
                }
            }
            geoBlocks := (!hasCaption && covers)
            info := proc . "`n"
                . "    視窗位置大小 : " . wx . "," . wy . " " . ww . "x" . wh . "`n"
                . "    有標題列     : " . (hasCaption ? "是" : "否 ←") . "`n"
                . "    鋪滿螢幕     : " . (covers ? "是 ← 螢幕 " . mon : "否")
        }
    }

    can := !apiBlocks && !geoBlocks
    txt.Value := "【本工具現在能否顯示候選窗】`n`n"
        . "  結論：" . (can ? "✅ 可以 —— 偵測正常運作" : "❌ 不行 —— 偵測已停用") . "`n`n"
        . "  判斷① 通知狀態 API : " . api . (apiBlocks ? "   ← 觸發停用" : "") . "`n"
        . "  判斷② 視窗幾何     : " . (geoBlocks ? "觸發停用" : "未觸發") . "`n"
        . "    作用中程式   : " . info . "`n`n"
        . "  （Esc 結束）"
}

Esc:: ExitApp()
