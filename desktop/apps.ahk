; 取消「在 Chrome 中也偵測」時，哪些視窗交給 Chrome 擴充、桌面版不處理。
; 純函式，不讀視窗、不碰其他全域變數，app.ahk 與 test.ahk 共用。

global BROWSER_APPS := Map("chrome.exe", true)

; Chrome 擴充讀不到 Google 文件（文字畫在畫布上），所以 Google 文件分頁仍由桌面版接手。
; Chrome 的視窗標題是「分頁標題 - Google Chrome」，Google 文件的分頁標題是「文件名稱 - Google 文件」，
; 實際看到的是「未命名文件 - Google 文件 - Google Chrome」（英文介面為 Google Docs）。
; 前後都要有「 - 」：只是提到 Google 文件的網頁（「如何使用 Google 文件 - 某部落格」）不算。
IsGoogleDocs(title) => (InStr(title, " - Google 文件 - ") || InStr(title, " - Google Docs - ")) ? true : false

SkipWindow(proc, title, chromeDetect) {
    if (chromeDetect || !BROWSER_APPS.Has(StrLower(proc)))
        return false
    return !IsGoogleDocs(title)
}
