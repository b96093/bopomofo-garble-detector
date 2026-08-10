# GitHub Release 發布指南

## 版本號規則

採用 **Semantic Versioning**：`v主版號.次版號.修正號`

例：`v1.0.0`、`v1.1.0`、`v1.0.1`

| 情況 | 例子 |
| --- | --- |
| 新功能或重大改動 | `v1.0.0` → `v1.1.0` |
| 修復 bug | `v1.0.0` → `v1.0.1` |
| 首次發布 | `v1.0.0` |

## 發布流程

### 1. 確認程式碼已提交

```bash
cd "D:\Claude code session庫\文字轉換器"
git status
```

確保沒有未提交的改動。

### 2. 打標籤

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 3. 打包（若還沒有）

確保 `dist/` 下有最新的兩個檔案：
- `dist/注音亂碼偵測-Chrome擴充.zip` —— Chrome 擴充
- `dist/注音亂碼偵測-桌面版.zip` —— 桌面版（內含 exe、詞庫、說明）

```powershell
cd "D:\Claude code session庫\文字轉換器"
powershell -File build\build-chrome.ps1
powershell -File desktop\build.ps1
```

### 4. 在 GitHub 上創建 Release

#### 用 GitHub 網頁介面（簡單）

1. 開啟 https://github.com/b96093/bopomofo-garble-detector/releases
2. 點 **Draft a new release**
3. **Choose a tag** —— 選你剛剛推上去的 `v1.0.0`
4. 填 Release title（例：`v1.0.0 — 首次發布`）
5. 貼下方的 Release Notes（見下文）
6. **Attach binaries** —— 拖或點選這兩個檔案上傳：
   - `dist/注音亂碼偵測-Chrome擴充.zip`
   - `dist/注音亂碼偵測-桌面版.zip`
7. 勾 **Set as a pre-release**（如果是測試版），或 **Set as the latest release**（正式版）
8. 點 **Publish release**

#### 用 GitHub CLI（快速）

如果電腦裝了 `gh`：

```bash
gh release create v1.0.0 `
  dist/注音亂碼偵測-Chrome擴充.zip `
  dist/注音亂碼偵測-桌面版.zip `
  -t "v1.0.0 — 首次發布" `
  -F release-notes.txt
```

## Release Notes 範本

以下是標準範本。每次發布時複製並改成你這一版的內容：

### 版本 1.0.0（首次發布）

```markdown
## 功能

- **邊打邊偵測** —— 打成亂碼時自動跳候選窗
- **三個整句候選** —— `↑↓` 選、`Enter` 插入
- **逐字換同音字** —— 例如把「面」換成「麵」
- **事後補救** —— 選取任何一段亂碼即可轉換
- **標點與數字** —— `？！、，。` 與混入的數字都保留
- **打反容錯** —— `ㄐㄣㄧ` 會自動歸位成 `ㄐㄧㄣ`
- **不誤判** —— 真英文、電話號碼、日期不觸發

## 安裝

### Chrome 擴充
1. 下載 `注音亂碼偵測-Chrome擴充.zip` 並解壓
2. 開啟 Chrome 網址列輸入 `chrome://extensions/`
3. 開啟右上角「開發者模式」
4. 點「載入未封裝擴充功能」，選剛剛解壓的資料夾

### 桌面版（Word、PowerPoint、LINE 等）
1. 下載 `注音亂碼偵測-桌面版.zip` 並解壓
2. 執行 `注音亂碼偵測.exe`（無需安裝）
3. 系統列會出現圖示，第一次啟動會載入詞庫（約 5–8 秒）

> exe 與 `dict.txt` 必須放在同一個資料夾，不要只把 exe 單獨搬出來 —— 詞庫是外部檔案。

## 隱私

- 離線運作，不連網
- 輸入只存在記憶體，不寫檔案
- 無廣告、無追蹤

## 意見回饋

問題或建議請至 [GitHub Issues](https://github.com/b96093/bopomofo-garble-detector/issues)

---

**[完整文件](https://github.com/b96093/bopomofo-garble-detector/blob/main/README.md)**
```

### 版本 X.Y.Z（後續更新）

```markdown
## 新增

- 功能 A
- 功能 B

## 修復

- 修復了在某某情況下會崩潰的問題
- 改善了同音字盤的反應速度

## 改動

- 調整偵測靈敏度預設值

## 已知問題

- （如果有）

## 安裝

見 [README](https://github.com/b96093/bopomofo-garble-detector#安裝)
```

## 檢查清單

發布前逐項確認：

- [ ] 程式碼 commit 完成，沒有未提交的改動
- [ ] `git push origin master`（或 main） —— 推到遠端
- [ ] Chrome 測試 61/61 pass
- [ ] 桌面版測試 41/41 pass
- [ ] `python desktop/check-globals.py` 無警告
- [ ] 兩個 zip 都已打包（存在於 `dist/`）
- [ ] 測試了 Chrome 擴充的實際使用
- [ ] 測試了桌面版在 Word、PowerPoint、記事本的實際使用
- [ ] **用全新環境驗過第一次開啟的流程**：Chrome 移除後重新載入應自動開啟說明頁；
      桌面版刪掉 `settings.ini` 後重開應自動跳出使用說明
- [ ] 若有新功能，確認說明文件已更新（README.md、docs/）
- [ ] 【贊助連結】`SUPPORT_URL` 已填入（或保持為空、留待後續填入）
- [ ] 打上版本標籤 `git tag v1.0.0`
- [ ] 推送標籤 `git push origin v1.0.0`
- [ ] 在 GitHub Release 頁上傳二進制檔案
- [ ] Release Notes 描述清楚

## 防毒誤判：每次發布都要處理

AHK 編譯的 exe 幾乎一定會被 Windows Defender 以
`Program:Win32/Contebrew.A!ml` 之類的名稱誤判（`!ml`＝機器學習啟發式猜測）。
**發布前務必先回報**，否則使用者下載後會被擋、甚至檔案直接消失。

### 回報步驟（免費，通常 1～3 天回覆）

1. 前往 <https://www.microsoft.com/en-us/wdsi/filesubmission>
2. 選 **Software developer**（軟體開發者），需用 Microsoft 帳號登入
3. 上傳 `dist/注音亂碼偵測-桌面版/注音亂碼偵測.exe`
4. **Detection name** 填 Defender 顯示的名稱（例：`Program:Win32/Contebrew.A!ml`）
5. 提交理由選 **I believe this file is incorrectly detected**（誤判）
6. 說明欄可寫：開源的注音輸入法輔助工具，MIT 授權，需全域鍵盤 hook 才能在
   各程式中運作，原始碼位於 GitHub（附上你的 repo 網址）

> ⚠️ **每次重新編譯 exe 的 SHA256 都會變**，白名單是綁 hash 的。
> 所以流程要固定成：**先編譯 → 立刻回報 → 等通過 → 才發布**。
> 不要編譯完馬上上傳 Release。

### 已提交的誤判回報紀錄

| 項目 | 內容 |
| --- | --- |
| Submission ID | `b587a8a7-edf1-4e2b-a138-4e4e2c7f5ee6` |
| 提交時間 | 2026-07-30 10:48（台北時間） |
| 提交者 | b96093@gmail.com |
| User Opinion | PuaFalsePositive |
| 判定名稱 | `Program:Win32/Contebrew.A!ml` |
| 定義版本 | 1.455.417.0 |
| 對應 exe SHA256 | `1185F41AA9E3645BF408EB07D5206E98ADCC8F4512DB03D153A13EBB19C1B2F3` |
| **結果** | ✅ **2026-08-05 Completed —— 誤判成立，不會加入偵測** |

分析師回覆原文：

> The submitted files do not meet our criteria for malware or potentially unwanted
> applications. **No detection will be added for these files.**

**同一天（2026-07-30）就回覆了**，速度比預期快很多。

⚠️ **Microsoft 會寄通知信，但很容易被誤認成別的信而略過。**
本次就是收到了卻沒發現，白等了好幾天才去查提交紀錄頁。
下次送出後，除了留意信箱，**直接到提交紀錄頁看 Status 最保險**。

### 第二次提交（浮窗修正後重編）

| 項目 | 內容 |
| --- | --- |
| 提交日期 | 2026-08-06 |
| 對應 exe SHA256 | `2266B23D0035F4F1FCE6A7B2C973F0809F3355F84751B93806FBE54EB040CBDE` |
| 定義版本 | 1.457.30.0 |
| 狀態 | ⚠️ **已作廢** —— 送出後 `desktop/app.ahk` 又改了 8 次，這個 hash 對不上要發布的 exe |

### 第三次提交（v1.0.0 發布用）

| 項目 | 內容 |
| --- | --- |
| Submission ID | `88b4dfac-5ad1-4a73-8634-5bb29aaa5882` |
| 提交時間 | 2026-08-09 23:34（台北時間） |
| 提交者 | b96093@gmail.com |
| User Opinion | PuaFalsePositive |
| 判定名稱 | `Program:Win32/Contebrew.A!ml` |
| 定義版本 | 1.457.80.0 |
| 對應 exe SHA256 | `1DD108F880C0721284D947968C085C94045D01F67AD5D461B48FA4608751150C` |
| **結果** | ✅ **2026-08-10 Completed —— 不符合惡意程式／PUA 判定標準** |

分析師回覆原文：

> The submitted files do not meet our criteria for malware or potentially unwanted
> applications. **No detection will be removed for these files.**
>
> If we need to remove the detection for submitted files, Requesting you share below
> information with us for further investigation.

⚠️ **這次的措辭要看仔細**：第一次寫的是 "No detection will be **added**"，這次是
"will be **removed**"。乍看像被拒絕，其實是「**目前沒有偵測可以移除**」——因為這顆
exe 根本沒被判定。送件前後各掃過一次都是 found no threats（定義版本 1.457.80.0），
與此一致。他們套用的是「要求移除既有偵測」情境的樣板，而這個案子沒有偵測存在。

**這份結果保證什麼、不保證什麼**：

- ✅ 不會被歸類為惡意程式或 PUA
- ❌ **不保證使用者不會看到警告**。SmartScreen 是另一套機制 —— 它看的是下載聲譽與
  數位簽章，不是惡意程式判定。沒有簽章、下載量又少的新 exe，幾乎一定會跳
  「Windows 已保護您的電腦」。那不是這份回覆能解決的，要靠程式碼簽章憑證或累積下載量。

🔓 **`desktop/` 解凍**（2026-08-10）。

### ⚠️ 但這次送錯了偵測名稱 —— 最重要的一課

複驗通過後做真實情境測試（上傳到雲端硬碟再用瀏覽器下載），結果**下載直接失敗**，
Chrome 顯示「系統偵測到病毒」。查 Defender 紀錄才發現：

| | 我們送審的 | 實際擋下載的 |
| --- | --- | --- |
| 名稱 | `Program:Win32/Contebrew.A!ml` | **`Trojan:Win32/Wacatac.C!ml`** |
| 類別 | PUA | **Trojan（惡意程式）** |
| 嚴重度 | 4 | **5（Severe）** |
| ThreatID | 251873 | 2147749372 |

`Contebrew` 是 2026-07-28 那版舊 exe 的判定名稱，我們一路沿用到第三次提交。
**但每次重編出的 exe 可能觸發完全不同的分類器** —— 這顆觸發的是 Wacatac。

這也解釋了「No detection will be **removed**」的措辭：沒有 Contebrew 偵測可以移除，
因為真正存在的是 Wacatac。分析師的回覆從頭到尾都是正確的，是我們報錯了。

**兩個關鍵教訓**：

1. **本機掃描乾淨 ≠ 使用者不會被擋。** `MpCmdRun -Scan` 對本機檔案回報 no threats，
   但瀏覽器下載的檔案帶有 mark-of-the-web，會走雲端分類器 —— 那是完全不同的判定路徑。
   **送件前一定要先做真實下載測試**，否則會像這次一樣，報了一個根本不存在的偵測名稱。

2. **偵測名稱要從實機查，不要沿用舊記錄。** 查法：

   ```powershell
   Get-MpThreatDetection | Sort-Object InitialDetectionTime -Descending |
       Select-Object -First 3 InitialDetectionTime, ThreatID, Resources
   Get-MpThreat | Select-Object ThreatID, ThreatName, SeverityID, IsActive
   ```

   用 ThreatID 對照出 ThreatName，那才是要填進表單的名稱。

### 第四次提交（正確的偵測名稱）

| 項目 | 內容 |
| --- | --- |
| Submission ID | `2eff2859-5c35-4de3-a1e5-8c47b57917f8` |
| 提交時間 | 2026-08-10 14:56（台北時間） |
| User Opinion | Incorrect detection |
| 判定名稱 | `Trojan:Win32/Wacatac.C!ml` |
| 提交類別 | **Incorrectly detected as malware/malicious**（不是 PUA） |
| 定義版本 | 1.457.80.0 |
| 對應 exe SHA256 | `1DD108F880C0721284D947968C085C94045D01F67AD5D461B48FA4608751150C`（與第三次相同，未重編） |
| **結果** | ✅ **2026-08-10 Completed —— 偵測已移除** |

分析師回覆原文：

> At this time, the submitted files do not meet our criteria for malware or potentially
> unwanted applications. **The detection has been removed.**

**這才是要的措辭**。三次「No detection will be added／removed」都不是通過的意思，
只有 "The detection **has been** removed" 才是真的移除了偵測。收到回覆時務必看清楚
是哪一種。

**回覆裡附的本機快取清除步驟**（分析師要求照做，否則本機仍會擋）：

```
以系統管理員開啟命令提示字元，切到 C:\Program Files\Windows Defender
MpCmdRun.exe -removedefinitions -dynamicsignatures
MpCmdRun.exe -SignatureUpdate
```

清完之後**務必重做一次真實下載測試**（上傳雲端硬碟 → 用瀏覽器下載）才算數。
本機掃描乾淨不代表下載不會被擋 —— 這是這輪學到最貴的一課。

**為什麼會有第三次**：第二次送出（2026-08-06）後沒有凍結 `desktop/`，
接連提交了剪貼簿修正、系統列選單、暫停圖示、全螢幕修正、使用說明重做、設定頁版本號
等 8 個 commit，每一次都會讓重新編譯出的 exe 換一個 hash。

**教訓**：送出前先確認 `desktop/` 已定稿。等待期間想改東西就先累積在分支或暫緩，
不要直接提交到 `desktop/` —— 否則等到的結果是白等的。

**為什麼要重報**：白名單綁 SHA256。修正「同音字太多時浮窗會跳位置」後重新編譯，
hash 就變了，第一次的判定不再涵蓋這個檔案。

**這次的說明文字有加一段關鍵內容**：把前一次的 Submission ID 與判定原文放在最前面，
讓分析師一看就知道是同一個程式改版後的複驗，可直接調出上次結論。
發新版重報時建議照做。

查看進度：<https://www.microsoft.com/en-us/wdsi/submissionhistory>

> ⚠️ 在收到結果之前**不要改動 `desktop/` 下的任何檔案**。重新編譯會改變 exe 的
> SHA256，這次提交就對不上了，得整個重來。改 `docs/`、`src/`、README 都安全。

### 記錄本次發布的雜湊

```powershell
Get-FileHash "dist\注音亂碼偵測-桌面版\注音亂碼偵測.exe" -Algorithm SHA256
```

把結果寫進 Release Notes，讓使用者能自行核對下載到的檔案。

## 檔案大小參考

- `注音亂碼偵測-Chrome擴充.zip`：約 1,545 KB
- `注音亂碼偵測-桌面版.zip`：約 2,268 KB（含 5 MB 詞庫，壓縮後）

如果差異太大（例如變成 10 MB），代表可能誤打包了不該包的東西（詞庫、node_modules 等）—— 檢查 `build.ps1` 和 `.gitignore`。
