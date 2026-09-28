#Requires AutoHotkey v2.0
; DetectBlock 的單元測試：直接測產品程式碼，不另外抄一份鏡像。
;   用法（PowerShell）：
;     & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" desktop\test-block.ahk
;   結果寫入 %TEMP%\test-block-result.txt，離開碼 = 失敗數
#Include engine.ahk

global PASS := 0, FAIL := 0, OUT := ""

; 執行期錯誤寫進結果檔就好，不要跳對話框（否則自動化執行會卡住）
OnError(TestError)
TestError(err, mode) {
    global OUT, FAIL
    FAIL += 1
    OUT .= "`r`n[執行期錯誤] " . err.Message
        . "`r`n  Specifically: " . err.Extra
        . "`r`n  " . err.File . " 第 " . err.Line . " 行`r`n"
    p := A_Temp . "/test-block-result.txt"
    try FileDelete(p)
    FileAppend(OUT, p, "UTF-8")
    ExitApp(1)
    return 1
}

Check(name, got, want) {
    global PASS, FAIL, OUT
    if (got = want) {
        PASS += 1
        OUT .= "  [OK] " . name . "`r`n"
    } else {
        FAIL += 1
        OUT .= "  [FAIL] " . name . "`r`n    期望：" . want . "`r`n    實際：" . got . "`r`n"
    }
}
Say(t) {
    global OUT
    OUT .= t . "`r`n"
}

DICT := LoadDict(A_ScriptDir . "\dict.txt")

; 已驗證字串（2026-09-28 於靈敏度 4 複驗，首選＝原句）
A := "ji3u3ru/ 2l4x.6vu84xk7"                          ; 我已經到樓下了
B := "au/6wu0 yl3g;392u03d9 cjo31j4ul t62l4"           ; 明天早上9點開會不要遲到

Say("── 多行 ──")
r := DetectBlock(A . "`n" . B, DICT)
Check("兩行都還原", r.text, "我已經到樓下了`n明天早上9點開會不要遲到")
Check("兩行都算命中", r.hits, 2)
Check("總行數", r.total, 2)

Say("")
Say("── 中英混雜：不是亂碼的行原樣保留 ──")
r := DetectBlock("今天的會議紀錄`n" . A, DICT)
Check("中文行不動", r.text, "今天的會議紀錄`n我已經到樓下了")
Check("只有一行是亂碼", r.hits, 1)

Say("")
Say("── 空行保留 ──")
r := DetectBlock(A . "`n`n" . B, DICT)
Check("空行還在", r.text, "我已經到樓下了`n`n明天早上9點開會不要遲到")
Check("空行不算命中", r.hits, 2)

Say("")
Say("── 縮排保留 ──")
r := DetectBlock("    " . A, DICT)
Check("前面的空白不動", r.text, "    我已經到樓下了")

Say("")
Say("── Windows 換行 ──")
r := DetectBlock(A . "`r`n" . B, DICT)
Check("組回去仍是 CRLF", r.text, "我已經到樓下了`r`n明天早上9點開會不要遲到")

Say("")
Say("── 沒有任何一行是亂碼 ──")
Check("整段中文回傳空字串", DetectBlock("今天天氣很好`n明天也是", DICT), "")

Say("")
Say("── 迴歸：單行結果必須與 Detect 相同 ──")
single := Detect(A, DICT, 0.5, 1, true)
r := DetectBlock(A, DICT)
Check("單行走 DetectBlock 結果一致", r.text, single.candidates[1])
Check("單行命中數為 1", r.hits, 1)

Say("")
Say("── 預覽字串供 icon 使用 ──")
r := DetectBlock("今天的會議紀錄`n" . A, DICT)
Check("預覽是第一個被還原的行", r.preview, "我已經到樓下了")

Say("")
Say("── Critical：純數字／符號的行不能被逐行路徑誤判 ──")
; 整段是逐行獨立判斷，使用者從來沒有指著筆記裡的那行日期／時間／英文說「轉這個」。
; manual 若沿用單行路徑的 true，會關掉「至少一個字母」與常見英文兩道守門，
; 2/4、10:30、no 這種筆記裡常見的行會被默默改成亂七八糟的中文。
r := DetectBlock(A . "`n2/4", DICT)
Check("日期行原樣保留", r.text, "我已經到樓下了`n2/4")
r := DetectBlock(A . "`n10:30", DICT)
Check("時間行原樣保留", r.text, "我已經到樓下了`n10:30")
r := DetectBlock(A . "`nno", DICT)
Check("英文行原樣保留", r.text, "我已經到樓下了`nno")

Say("")
Say("── Important：CRLF 與 LF 混用時，沒被要求修改的行不能被連帶改掉換行字元 ──")
r := DetectBlock(A . "`r`n" . A . "`n" . A, DICT)
crCount := 0
Loop Parse r.text
    if (A_LoopField == "`r")
        crCount += 1
Check("只有原本是 CRLF 的那一行還是 CRLF", crCount, 1)

Say("")
Say("── 行尾空白保留 ──")
r := DetectBlock(A . "   ", DICT)
Check("行尾空白原樣接回去", SubStr(r.text, -3), "   ")

Say("")
Say("── 只有空白的行原樣保留（不是命中，也不是被清空）──")
r := DetectBlock(A . "`n   `n" . A, DICT)
lines := StrSplit(r.text, "`n")
Check("中間那行還是三個空白", lines[2], "   ")

Say("")
Say("── Important：從 contenteditable 複製出來的 U+00A0 要能正常轉換 ──")
withNbsp := StrReplace(A, " ", Chr(0xA0))
r := DetectBlock(withNbsp, DICT)
Check("U+00A0 正規化後仍轉得出來", r.text, "我已經到樓下了")

Say("")
Say("── 結尾換行保留 ──")
r := DetectBlock(A . "`n", DICT)
Check("結尾還是換行", SubStr(r.text, -1), "`n")

Say("")
Say(Format("結果：{1} 通過 / {2} 失敗", PASS, FAIL))
p := A_Temp . "/test-block-result.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp(FAIL)
