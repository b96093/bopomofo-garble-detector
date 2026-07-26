#Requires AutoHotkey v2.0
#SingleInstance Force

; 階段 0：可行性驗證。只測三件事，不含完整功能。
;   1) 詞庫載入速度  2) 全域監聽是否可用  3) 退格+貼上替換是否正確
; 設計原則：緩衝只存在記憶體、不寫檔、不連網；Enter/Tab/Esc/方向鍵立即清空。

buf := ""
paused := false

; ---------- 1) 詞庫載入 ----------
dictPath := A_ScriptDir "\dict.txt"
if !FileExist(dictPath) {
    MsgBox("找不到 dict.txt`n請確認它與本腳本在同一資料夾。", "驗證失敗", "Icon!")
    ExitApp()
}
t0 := A_TickCount
dict := Map()
raw := FileRead(dictPath, "UTF-8")
Loop Parse raw, "`n", "`r"
{
    if (A_LoopField = "")
        continue
    p := InStr(A_LoopField, "`t")
    if (p)
        dict[SubStr(A_LoopField, 1, p - 1)] := SubStr(A_LoopField, p + 1)
}
raw := ""
loadMs := A_TickCount - t0

; ---------- 系統列 ----------
A_TrayMenu.Delete()
A_TrayMenu.Add("暫停 / 繼續監聽", TogglePause)
A_TrayMenu.Add("結束", (*) => ExitApp())
A_IconTip := "注音亂碼偵測（階段 0 驗證）"

MsgBox(
    "① 詞庫載入完成`n`n"
    . "讀音數：" dict.Count "`n"
    . "耗時：" loadMs " ms`n`n"
    . "接下來請測：`n"
    . "② 到記事本或 Word 打幾個英文字 → 畫面應出現「緩衝」提示`n"
    . "③ 按 Ctrl+Alt+Z → 剛打的字應被換成「測試中文」`n`n"
    . "測完請從系統列圖示結束程式。",
    "階段 0 驗證", "Iconi")

; ---------- 2) 全域監聽（只觀察，不攔截按鍵） ----------
ih := InputHook("V")
ih.OnChar := OnChar
ih.KeyOpt("{Enter}{Tab}{Escape}{Left}{Right}{Up}{Down}{BackSpace}", "N")
ih.OnKeyDown := OnKeyDown
ih.Start()

OnChar(hook, ch) {
    global buf, paused
    if (paused)
        return
    buf .= ch
    ShowTip("緩衝：" buf "`n（按 Ctrl+Alt+Z 測試替換）")
}

OnKeyDown(hook, vk, sc) {
    global buf
    if (buf != "") {
        buf := ""
        ShowTip("已清空緩衝")
    }
}

ShowTip(s) {
    ToolTip(s)
    SetTimer(() => ToolTip(), -1800)
}

TogglePause(*) {
    global paused, buf
    paused := !paused
    buf := ""
    ShowTip(paused ? "已暫停監聽" : "已繼續監聽")
}

; ---------- 3) 替換測試：退格 N 次 + 貼上中文 ----------
^!z:: {
    global buf
    if (buf = "") {
        ShowTip("緩衝是空的，請先打幾個字")
        return
    }
    n := StrLen(buf)
    saved := ClipboardAll()
    A_Clipboard := "測試中文"
    if !ClipWait(1) {
        ShowTip("剪貼簿設定失敗")
        return
    }
    Send("{BackSpace " n "}")
    Send("^v")
    Sleep(180)
    A_Clipboard := saved
    buf := ""
    ShowTip("已替換：退格 " n " 次 + 貼上")
}
