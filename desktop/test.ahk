#Requires AutoHotkey v2.0
; 引擎移植驗證：跑與 Chrome 版相同的黃金測資，結果寫入 test-result.txt
#Include engine.ahk

global PASS := 0, FAIL := 0, RESULTS := ""

; 執行期錯誤寫進結果檔就好，不要跳對話框（否則自動化執行會卡住）
OnError(TestError)
TestError(err, mode) {
    global RESULTS
    RESULTS .= "`r`n[執行期錯誤] " . err.Message
        . "`r`n  Specifically: " . err.Extra
        . "`r`n  " . err.File . " 第 " . err.Line . " 行`r`n"
    Dump()
    ExitApp(1)
    return 1
}

Dump() {
    global RESULTS
    try FileDelete(A_ScriptDir "\test-result.txt")
    FileAppend(RESULTS, A_ScriptDir "\test-result.txt", "UTF-8")
}

Say(s) {
    global RESULTS
    RESULTS .= s . "`r`n"
}

Check(name, actual, expected) {
    global PASS, FAIL
    if (actual == expected) {
        PASS++
        Say("  [OK] " . name)
    } else {
        FAIL++
        Say("  [FAIL] " . name . "`r`n         預期: " . expected . "`r`n         實際: " . actual)
    }
}

t0 := A_TickCount
dict := LoadDict(A_ScriptDir "\dict.txt")
Say("詞庫載入：" . dict.Count . " 讀音，" . (A_TickCount - t0) . " ms")
Say("")

First(res) {
    return (res == "") ? "null" : res.candidates[1]
}

Say("── 基本轉換 ──")
Check("ji394t au04", First(Detect("ji394t au04", dict)), "我愛吃面")
r := Detect("ji394t au04", dict)
Check("ji394t au04 候選2", (r != "" && r.candidates.Length >= 2) ? r.candidates[2] : "(無)", "我愛吃麵")
Check("vu04g;4ej/ rm4j;3", First(Detect("vu04g;4ej/ rm4j;3", dict)), "線上工具網")
Check("su35 2l4a8", First(Detect("su35 2l4a8", dict)), "你知道嗎")

Say("")
Say("── 一聲（空白鍵）──")
Check("cj8 d9 （花開）", First(Detect("cj8 d9 ", dict)), "花開")

Say("")
Say("── 標點 ──")
Check("半形問號", First(Detect("su35 2l4a8 ?ji394su3", dict)), "你知道嗎?我愛你")
Check("全形標點", First(Detect("ji394su3，su35 2l4a8。", dict)), "我愛你，你知道嗎。")

Say("")
Say("── 數字 ──")
Check("落單聲調數字", First(Detect("bj6eji3a933ek7sk", dict)), "如果買3個呢")
Loop 10 {
    n := A_Index - 1
    Check("買" . n . "個", First(Detect("a93" . n . "ek7", dict)), "買" . n . "個")
}
Check("長句混合", First(Detect("ji3u/ e9 3wu0 1j4vu3w.6?c96g42wu0", dict)), "我應該3天不洗頭?還是2天")

Say("")
Say("── 英文不觸發 ──")
Check("the cat sat", First(Detect("the cat sat", dict)), "null")
Check("hello", First(Detect("hello", dict)), "null")
Check("good morning", First(Detect("good morning", dict)), "null")
Check("abc123", First(Detect("abc123", dict)), "null")
Check("r2d2", First(Detect("r2d2", dict)), "null")

Say("")
Say("── 尾段退讓 ──")
Check("整段應失敗", First(Detect("IEIEI SU3W8 A8 EP JI3D9 J06VUL4A8", dict)), "null")
tail := DetectTail("IEIEI SU3W8 A8 EP JI3D9 J06VUL4A8", dict)
Check("尾段 offset", (tail == "") ? "null" : tail.offset, 6)
Check("尾段結果", (tail == "") ? "null" : tail.res.candidates[1], "你他嗎跟我開玩笑嗎")
tail2 := DetectTail("ji394t au04", dict)
Check("整段可辨識時 offset=0", (tail2 == "") ? "null" : tail2.offset, 0)
Check("英文長句不觸發", (DetectTail("the cat sat on the mat", dict) == "") ? "null" : "觸發", "null")

Say("")
Say("── 同音字（逐字換字用）──")
r2 := Detect("su394ji3a8", dict)
Check("你愛我媽", First(r2), "你愛我媽")
homs := (r2 == "") ? "" : DictEntry(dict, r2.syllables[4])
Check("ㄇㄚ 同音字數", (homs == "") ? 0 : homs.Length, 5)
Check("ㄇㄚ 首選為嗎", (homs == "") ? "" : homs[1][1], "嗎")

Say("")
Say("── 打反順序容錯 ──")
Check("ji3uv;3t z04（打反）", First(Detect("ji3uv;3t z04", dict)), "我想吃飯")
Check("ji3vu;3t z04（正常）", First(Detect("ji3vu;3t z04", dict)), "我想吃飯")
Check("兩個聲母不硬湊", First(Detect("a932ek7", dict)), "買2個")
Check("IEIEI 仍不觸發", First(Detect("IEIEI", dict)), "null")

Say("")
Say("── 純數字不誤判 ──")
Check("手機號碼", First(Detect("0966335806", dict)), "null")
Check("市話", First(Detect("0287654321", dict)), "null")
Check("日期", First(Detect("2024/07/26", dict)), "null")
Check("含字母仍正常", First(Detect("ji394t au04", dict)), "我愛吃面")
Check("含字母的數字句", First(Detect("a930ek7", dict)), "買0個")

Say("")
Say(Format("結果：{1} 通過 / {2} 失敗", PASS, FAIL))
Dump()
ExitApp(FAIL > 0 ? 1 : 0)
