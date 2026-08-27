#Requires AutoHotkey v2.0
; TailMatches 的單元測試：直接測產品程式碼，不另外抄一份鏡像。
;   用法：AutoHotkey64.exe desktop	est-uia.ahk
;   結果寫入 %TEMP%	est-uia-result.txt，離開碼 = 失敗數
#Include uia.ahk

global PASS := 0, FAIL := 0, OUT := ""
Check(name, got, want) {
    global PASS, FAIL, OUT
    if (got = want) {
        PASS += 1
        OUT .= "  [OK] " . name . "`r`n"
    } else {
        FAIL += 1
        OUT .= "  [FAIL] " . name . "  期望 " . want . "，實際 " . got . "`r`n"
    }
}
Say(t) {
    global OUT
    OUT .= t . "`r`n"
}

Say("── 單音節：等級 4 讓一個按鍵就能觸發偵測，守門必須跟著能檢查 ──")
; 使用者正常打中文，輸入法還在組字，游標前是注音符號 —— 絕不能出手。
; 這正是 v1.1.1 誤跳的情境（打「快速」的ㄙ，跳出「司/思」）。
Check("組字中的注音不算落地", TailMatches("n", "ㄙ"), 0)
Check("已上字的中文不算落地", TailMatches("n", "快"), 0)
Check("螢幕上真的是那個字母", TailMatches("n", "n"), 1)
Check("大小寫視為相同", TailMatches("N", "n"), 1)
Check("字母不同就是沒落地", TailMatches("n", "g"), 0)

Say("")
Say("── 讀不到就是讀不到，交給呼叫端退回舊判斷 ──")
Check("讀回空字串", TailMatches("n", ""), -1)
Check("緩衝是空的", TailMatches("", "abc"), -1)

Say("")
Say("── 迴歸：多字的既有行為不能被改壞 ──")
Check("六字整串落地", TailMatches("ji3vu3t", "i3vu3t"), 1)
Check("剛好六字", TailMatches("vu;3t4", "vu;3t4"), 1)
Check("緩衝比探測長", TailMatches("abcdefgh", "cdefgh"), 1)
Check("讀回來比較短", TailMatches("abcdefgh", "efgh"), 1)
Check("轉成中文了", TailMatches("ji3vu3t", "我想吃"), 0)
Check("尾端對不上", TailMatches("abcdef", "abcxef"), 0)

Say("")
Say(Format("結果：{1} 通過 / {2} 失敗", PASS, FAIL))
p := A_Temp . "/test-uia-result.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp(FAIL)
