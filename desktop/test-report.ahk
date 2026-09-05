#Requires AutoHotkey v2.0
; BuildReport 的單元測試 —— 直接測產品程式碼，不另抄鏡像。
;   結果寫入 %TEMP%/test-report-result.txt，離開碼 = 失敗數
#Include report.ahk

global PASS := 0, FAIL := 0, OUT := ""
Check(name, got, want) {
    global PASS, FAIL, OUT
    if (got == want) {
        PASS += 1
        OUT .= "  [OK] " . name . "`r`n"
    } else {
        FAIL += 1
        OUT .= "  [FAIL] " . name . "`r`n"
        OUT .= "     期望：" . StrReplace(want, "`r`n", "⏎") . "`r`n"
        OUT .= "     實際：" . StrReplace(got, "`r`n", "⏎") . "`r`n"
    }
}
Say(t) {
    global OUT
    OUT .= t . "`r`n"
}

Say("── 作業系統名稱 ──")
Check("Windows 11", OSName("10.0.26200"), "Windows 11 (26200)")
Check("Windows 10", OSName("10.0.19045"), "Windows 10 (19045)")
Check("認不出來就原樣回傳", OSName("怪東西"), "怪東西")

Say("")
Say("── 顯示縮放 ──")
Check("100%", DpiPercent(96), "100%")
Check("125%", DpiPercent(120), "125%")
Check("150%", DpiPercent(144), "150%")

Say("")
Say("── landed 翻成人話 ──")
Check("落地了", ReadDesc(1), "讀到，與輸入相符")
Check("沒落地", ReadDesc(0), "讀到，與輸入不符")
Check("讀不到", ReadDesc(-1), "讀不到")

Say("")
Say("── 靈敏度短名稱 ──")
Check("取出括號前", LevelName("積極（建議）：連單一個字也會跳出通知浮窗；打英文時偶爾會被打擾。"), "積極")
Check("沒括號就取冒號前", LevelName("標準：一般情況都會跳出通知浮窗。"), "標準")
Check("兩者都沒有就原樣", LevelName("怪東西"), "怪東西")

Say("")
Say("── 報告內容 ──")
info := {version: "1.1.5", os: "10.0.26200", dpi: 120, level: 4,
         levelDesc: "積極", chromeDetect: true}
last := {app: "LINE.exe", read: "讀不到", verdict: "退回輸入法查詢"}

want := "注音亂碼偵測 1.1.5`r`n"
      . "Windows 11 (26200)　顯示縮放 125%`r`n"
      . "偵測靈敏度：4（積極）`r`n"
      . "在 Chrome 中也偵測：開`r`n"
      . "`r`n最近一次偵測`r`n"
      . "　程式：LINE.exe`r`n"
      . "　畫面讀取：讀不到`r`n"
      . "　判定：退回輸入法查詢`r`n"
Check("完整報告", BuildReport(info, last), want)

Say("")
Say("── 還沒發生過偵測時 ──")
wantNone := "注音亂碼偵測 1.1.5`r`n"
          . "Windows 11 (26200)　顯示縮放 125%`r`n"
          . "偵測靈敏度：4（積極）`r`n"
          . "在 Chrome 中也偵測：開`r`n"
          . "`r`n最近一次偵測`r`n"
          . "　（尚未發生）`r`n"
Check("顯示尚未發生", BuildReport(info, ""), wantNone)

Say("")
Say("── 報告裡不該出現使用者打的內容 ──")
; 這是這個功能的核心承諾，用測試釘住：即使把亂碼塞進狀態，也不該出現在輸出裡
leaky := {app: "LINE.exe", read: "讀不到", verdict: "退回輸入法查詢"}
rep := BuildReport(info, leaky)
Check("不含緩衝內容", InStr(rep, "ji394t") ? "有洩漏" : "乾淨", "乾淨")
Check("不含使用者文字", InStr(rep, "你說什麼") ? "有洩漏" : "乾淨", "乾淨")

Say("")
Say(Format("結果：{1} 通過 / {2} 失敗", PASS, FAIL))
p := A_Temp . "/test-report-result.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp(FAIL)
