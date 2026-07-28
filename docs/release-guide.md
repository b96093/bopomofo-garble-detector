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

1. 開啟 https://github.com/你的帳號/文字轉換器/releases
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

問題或建議請至 [GitHub Issues](https://github.com/你的帳號/文字轉換器/issues)

---

**[完整文件](https://github.com/你的帳號/文字轉換器/blob/main/README.md)**
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

見 [README](https://github.com/你的帳號/文字轉換器#安裝)
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

## 檔案大小參考

- `注音亂碼偵測-Chrome擴充.zip`：約 1,545 KB
- `注音亂碼偵測-桌面版.zip`：約 2,268 KB（含 5 MB 詞庫，壓縮後）

如果差異太大（例如變成 10 MB），代表可能誤打包了不該包的東西（詞庫、node_modules 等）—— 檢查 `build.ps1` 和 `.gitignore`。
