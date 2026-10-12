# 桌面版接手 Google 文件 — 設計

日期：2026-10-12　對應版本：桌面版 v1.1.8

## 問題

首頁建議「兩個都裝」，並請使用者到桌面版設定**取消勾選「在 Chrome 中也偵測」**，
否則網頁上會同時跳出兩個候選窗。但取消之後，桌面版會略過**整個 Chrome**
（`desktop/app.ahk` 的 `IsExcludedApp()`：視窗程式是 `chrome.exe` 就略過）。
Chrome 擴充本來就讀不到 Google 文件（文字畫在畫布上），所以：

> 照建議兩個都裝的人，在 Google 文件裡**兩邊都不會幫忙**。

2026-10-12 使用者實測 v1.1.7 證實：取消勾選後在 Google 文件打亂碼，沒有任何候選窗；
一般網頁輸入框則正常跳出 Chrome 版候選窗。

## 要做什麼

取消勾選「在 Chrome 中也偵測」時，桌面版仍然**接手 Chrome 裡的 Google 文件分頁**。
結果是兩邊自動分工：網頁交給 Chrome 擴充，Google 文件與其他程式交給桌面版，不重複跳窗。

## 判斷規則

是否略過目前視窗：

| 在 Chrome 中也偵測 | 程式 | 視窗標題 | 略過？ |
| --- | --- | --- | --- |
| 勾選 | 任何 | 任何 | 否 |
| 取消 | 不是 `chrome.exe` | 任何 | 否 |
| 取消 | `chrome.exe` | 含 ` - Google 文件 - ` 或 ` - Google Docs - ` | **否（新）** |
| 取消 | `chrome.exe` | 其他 | 是 |

- 程式名稱比對不分大小寫（沿用現有的 `StrLower`）。
- 標題比對以 2026-10-12 在使用者電腦上實際讀到的標題為準：`未命名文件 - Google 文件 - Google Chrome`。
  英文介面的 Google 文件是 `… - Google Docs - Google Chrome`。
- 前後都要有「 - 」：標題只是**提到** Google 文件的網頁（例如「如何使用 Google 文件 - 某某部落格」）
  不會被當成 Google 文件。
- **只處理 Google 文件。** 試算表、簡報沒有證據顯示 Chrome 擴充讀不到，
  擴大範圍反而可能在那些頁面重複跳窗。

## 程式結構

- 新檔 `desktop/apps.ahk`：純函式 `SkipWindow(proc, title, chromeDetect)`，回傳 true／false，
  不讀視窗、不碰全域變數。`app.ahk` 與 `test.ahk` 都 `#Include` 它。
- `app.ahk` 的 `IsExcludedApp()` 改成讀出目前視窗的程式名稱與標題，交給 `SkipWindow` 判斷。
  讀取失敗時沿用現狀：不略過。
- `BROWSER_APPS`（目前只有 `chrome.exe`）保留，`SkipWindow` 用它判斷是不是瀏覽器。

## 測試

`desktop/test.ahk` 新增一組 `SkipWindow` 測試：

| 情境 | 預期 |
| --- | --- |
| 勾選，`chrome.exe`，一般網頁標題 | 不略過 |
| 取消，`chrome.exe`，`YouTube - Google Chrome` | 略過 |
| 取消，`chrome.exe`，`未命名文件 - Google 文件 - Google Chrome` | 不略過 |
| 取消，`chrome.exe`，`Untitled document - Google Docs - Google Chrome` | 不略過 |
| 取消，`Chrome.EXE`（大小寫不同），Google 文件標題 | 不略過 |
| 取消，`chrome.exe`，`如何使用 Google 文件 - 某某部落格 - Google Chrome` | 略過 |
| 取消，`chrome.exe`，空標題 | 略過 |
| 取消，`notepad.exe`，任何標題 | 不略過 |

既有測試必須全部照樣通過。

## 說明文字

- 設定頁「在 Chrome 中也偵測」下方的提示：
  「若你另外裝了 Chrome 擴充，請關閉這項，否則會跳出兩個候選窗。」→ 後面加上「Google 文件仍由桌面版處理。」
  （要確認加長後不會被截斷或換行壓到下一個選項。）
- `README.md`、`desktop/README.md`「與 Chrome 擴充併用」、`docs/readme-chrome.md`「限制」裡關於 Google 文件的替代方案
  （目前寫「需保持『在 Chrome 中也偵測』開啟」，要改成不需要）。
- 新增 `docs/release-notes-v1.1.8.md`，格式比照 v1.1.7。

## 驗收

1. `desktop/test.ahk` 全部通過（含新增的 `SkipWindow` 測試）。
2. 編譯 exe，確認使用者執行中的是新版（比對 exe 雜湊）。
3. 使用者實測（取消勾選「在 Chrome 中也偵測」）：
   - Google 文件：切成英文輸入，打 `ji3u3ru/ 2l4x.6vu84xk7` → 跳出**桌面版**候選窗「我已經到樓下了」
   - 一般網頁輸入框：打同一串 → 只跳出**一個**候選窗（Chrome 版的）
4. 使用者同意後才建立 GitHub Release v1.1.8。

## 不做什麼

- 不處理 Edge 等其他瀏覽器（`BROWSER_APPS` 只有 Chrome，Chrome 擴充也只裝在 Chrome）。
- 不改 Chrome 擴充。
- 選取轉換（`CheckSelection`）也呼叫 `IsExcludedApp()`，所以會自動跟著新規則：在 Google 文件裡的表現
  與「勾選在 Chrome 中也偵測」時相同。這次不另外改選取轉換，也不把它列入驗收。
