#Requires AutoHotkey v2.0
; 回報用的診斷文字。
;
; 單獨成檔是為了能測 —— app.ahk 有一大段自動執行的程式碼（掛鍵盤 hook、
; 開計時器、載入詞庫），測試檔 #Include 它會把整個工具跑起來，不是測試。
; engine.ahk / draw.ahk / uia.ahk 也是同樣的切法。

; 把 A_OSVersion（例如 10.0.26200）翻成人看得懂的名稱。
; 內部版本 22000 起算是 Windows 11 —— 主版本號一直是 10.0，只能看 build。
OSName(ver) {
    parts := StrSplit(ver, ".")
    build := (parts.Length >= 3) ? Integer(parts[3]) : 0
    if (build >= 22000)
        return "Windows 11 (" . build . ")"
    if (build > 0)
        return "Windows 10 (" . build . ")"
    return ver
}

; A_ScreenDPI 96 = 100%
DpiPercent(dpi) {
    return Round(dpi / 96 * 100) . "%"
}

; 產生回報文字。
;   info : {version, os, dpi, level, levelDesc, chromeDetect}
;   last : {app, read, verdict}，或 "" 代表還沒發生過偵測
;
; 刻意只接參數、不讀全域 —— 這樣測試才能餵固定值進來比對輸出。
BuildReport(info, last) {
    s := "注音亂碼偵測 " . info.version . "`r`n"
    s .= OSName(info.os) . "　顯示縮放 " . DpiPercent(info.dpi) . "`r`n"
    s .= "偵測靈敏度：" . info.level . "（" . info.levelDesc . "）`r`n"
    s .= "在 Chrome 中也偵測：" . (info.chromeDetect ? "開" : "關") . "`r`n"
    s .= "`r`n最近一次偵測`r`n"
    if (last == "") {
        s .= "　（尚未發生）`r`n"
        return s
    }
    s .= "　程式：" . last.app . "`r`n"
    s .= "　畫面讀取：" . last.read . "`r`n"
    s .= "　判定：" . last.verdict . "`r`n"
    return s
}

; landed 的三種值翻成人話
ReadDesc(landed) {
    if (landed == 1)
        return "讀到，與輸入相符"
    if (landed == 0)
        return "讀到，與輸入不符"
    return "讀不到"
}

; 從 LevelDesc() 的整句說明取出短名稱，報告裡放整句太長。
;   「積極（建議）：連單一個字也會跳出通知浮窗…」→「積極」
; 刻意用擷取而不是另外抄一份等級對照表 —— 抄的那份遲早跟本尊漂移，
; 這個專案已經為了「測試抄鏡像」吃過一次虧（SubStr 少算一個字）。
LevelName(desc) {
    p := InStr(desc, "（")
    if (!p)
        p := InStr(desc, "：")
    return p ? SubStr(desc, 1, p - 1) : desc
}
