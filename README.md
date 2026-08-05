# 注音亂碼偵測

打字忘了切換輸入法，把整句注音打成英文亂碼 —— `ji394t au04` 其實是「我愛吃麵」。
這個工具會**自動認出**那串亂碼，並在游標旁跳出候選中文，選一下就還原。

離線運作、不連網、不寫檔。

## 兩個版本

| | Chrome 擴充 | 桌面版 |
| --- | --- | --- |
| 適用範圍 | Chrome 裡的所有網頁（Facebook、Google…） | **Word、PowerPoint、LINE、記事本等所有 Windows 程式** |
| 判斷準確度 | 較高（能直接讀輸入框內容） | 一般（攔在輸入法之前，靠輸入法狀態判斷） |
| 安裝 | **[Chrome 線上應用程式商店](https://chromewebstore.google.com/detail/gjghbjnkbbccdhfiddmceijjkebajilm)** | [下載](https://github.com/b96093/bopomofo-garble-detector/releases)後解壓縮執行 exe |
| 說明 | [docs/readme-chrome.md](docs/readme-chrome.md) | [desktop/README.md](desktop/README.md) |

**建議兩個都裝**：Chrome 交給擴充、其他程式交給桌面版。
兩個都裝時，請在桌面版設定頁取消勾選「在 Chrome 中也偵測」，否則會跳出兩個候選窗。

## 功能

- **邊打邊偵測** —— 打成亂碼時自動跳候選窗，永不自動替換
- **三個整句候選** —— `↑↓` 選、`Enter` 插入
- **逐字換同音字** —— 例如把「面」換成「麵」，涵蓋該讀音的完整同音字
- **事後補救** —— 選取任何一段亂碼即可轉換，不限剛打的字
- **標點與數字** —— 混在句中的 `？！、，。` 與數字都會原樣保留
- **打反容錯** —— `ㄐㄣㄧ` 會依注音結構歸位成 `ㄐㄧㄣ`（同注音輸入法行為）
- **不誤判** —— 真英文、電話號碼、日期都不會觸發

## 開發

```bash
npm test                        # Chrome 版引擎測試（61 項）
node build/build-dict.js        # 由 build/data/ 原始資料重建詞庫
node build/build-english-ahk.js # 由 JS 產生桌面版的英文字表
```

```powershell
powershell -File build\build-chrome.ps1   # 打包 Chrome 擴充
powershell -File desktop\build.ps1        # 編譯桌面版 exe（需 Ahk2Exe）
```

桌面版另有兩個開發工具：

- `desktop/test.ahk` —— 引擎測試（41 項，與 Chrome 版共用黃金測資）
- `desktop/preview.ahk` + `preview.py` —— 把候選窗渲染成 PNG，調版面時不必執行程式就能看效果
- `desktop/check-globals.py` —— 檢查 AHK 的全域變數陷阱（大小寫混用、參數遮蔽）

## 發布與贊助

### 發布到 GitHub Releases

詳見 [docs/release-guide.md](docs/release-guide.md)。包含版本號規則、git 指令、Release Notes 範本和檢查清單。

### 上架 Chrome 線上應用程式商店

詳見 [docs/webstore-listing.md](docs/webstore-listing.md)。所有要填的欄位都已寫好，複製貼上即可。
上架後，使用者就不必再開「開發人員模式」手動載入。
隱私權政策見 [docs/privacy-policy.md](docs/privacy-policy.md)（需發佈到 GitHub Pages 取得公開網址）。

### 贊助連結

「支持開發」入口的網址目前留空，**留空時整個入口不會出現**，所以現在發布也不會有死連結。
申請好收款帳號（建議 [Ko-fi](https://ko-fi.com) —— 免費開通、支援台灣）後，把同一個網址填進這兩處，再各自重新打包即可：

- `desktop/app.ahk` —— `SUPPORT_URL`（會出現在系統列選單與設定頁）
- `src/support.js` —— `SUPPORT_URL`（會出現在擴充的設定頁與使用說明頁）

## 授權與資料來源

程式碼採 MIT。注音詞庫由開源資料前處理而成，詳見 [docs/NOTICE.md](docs/NOTICE.md)：
McBopomofo 小麥注音（MIT）、多字詞源自 libtabe `tsi.src`（BSD）。
