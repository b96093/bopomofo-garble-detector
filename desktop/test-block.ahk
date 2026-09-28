#Requires AutoHotkey v2.0
; DetectBlock 的單元測試：直接測產品程式碼，不另外抄一份鏡像。
;   用法（PowerShell）：
;     & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" desktop\test-block.ahk
;   結果寫入 %TEMP%\test-block-result.txt，離開碼 = 失敗數
#Include engine.ahk

global PASS := 0, FAIL := 0, OUT := ""
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
Say(Format("結果：{1} 通過 / {2} 失敗", PASS, FAIL))
p := A_Temp . "/test-block-result.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp(FAIL)
