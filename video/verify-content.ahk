#Requires AutoHotkey v2.0
; 由 video\verify-content.mjs 呼叫：用產品實際的 DetectBlock／DetectTail 驗證影片內容。
; 結果寫到標準輸出，離開碼 = 失敗數。
#Include ..\desktop\engine.ahk

Say(s) => FileAppend(s . "`n", "*", "UTF-8-RAW")
OnError(Fatal)
Fatal(e, mode) {
    Say("ERROR: " . e.Message . " / " . e.Extra)
    ExitApp(99)
}

dict := LoadDict(A_ScriptDir . "\..\desktop\dict.txt")
pass := 0, fail := 0
for rec in StrSplit(FileRead(A_Args[1], "UTF-8"), Chr(0x1E)) {
    f := StrSplit(rec, Chr(0x1F))
    if (f.Length < 4)
        continue
    if (f[1] == "BLOCK") {
        r := DetectBlock(f[3], dict)
        ok := (r != "" && r.text == f[4] && r.preview == f[5] && r.hits == Integer(f[6]))
        got := (r == "") ? "（整段轉不出來）" : r.text . "｜浮窗：" . r.preview . "／" . r.hits . " 行"
    } else {
        h := DetectTail(f[3], dict, 0.6, 1)          ; 打字偵測路徑，靈敏度 4（預設）
        ok := (h != "" && h.res.candidates[1] == f[4])
        got := (h == "") ? "（偵測不到）" : h.res.candidates[1]
    }
    if (ok) {
        pass += 1
        Say("  [OK] " . f[2])
    } else {
        fail += 1
        Say("  [FAIL] " . f[2])
        Say("    期望：" . StrReplace(f[4], "`r`n", " ⏎ "))
        Say("    實際：" . StrReplace(got, "`r`n", " ⏎ "))
    }
}
Say("結果：" . pass . " 通過 / " . fail . " 失敗")
ExitApp(fail)
