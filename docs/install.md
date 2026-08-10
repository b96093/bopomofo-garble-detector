---
layout: default
title: 安裝 Windows 桌面版 — 注音亂碼偵測
---

# 安裝 Windows 桌面版

三步驟，不用安裝程式，解壓縮就能用。

> 只想在 Chrome 網頁裡用的話，[到 Chrome 線上應用程式商店安裝](https://chromewebstore.google.com/detail/gjghbjnkbbccdhfiddmceijjkebajilm)就好，不需要這一頁。

## 1. 下載

到 [Releases 頁面](https://github.com/b96093/bopomofo-garble-detector/releases)，
下載 **`注音亂碼偵測-桌面版.zip`**（約 2.3 MB）。

## 2. 解壓縮

在 zip 上按右鍵 →「解壓縮全部」。

> ⚠️ `注音亂碼偵測.exe` 和 `dict.txt` **必須放在同一個資料夾**。
> 詞庫是外部檔案，只把 exe 單獨搬走就跑不動了。

## 3. 執行時會跳出藍色警告 —— 這是正常的

執行 `注音亂碼偵測.exe`，Windows 會顯示：

> **Windows 已保護您的電腦**
> Microsoft Defender SmartScreen 已防止某個無法辨識的應用程式啟動。

<!-- 截圖：docs/assets/smartscreen-1.png -->

**點左下角的「其他資訊」**，畫面會展開，出現「**仍要執行**」按鈕。

<!-- 截圖：docs/assets/smartscreen-2.png -->

點「仍要執行」就會啟動。

### 為什麼會出現這個警告

展開後你會看到「發行者：**不明的發行者**」。原因是這個程式**沒有數位簽章憑證**——
那要每年付費，而這個工具免費、沒有任何收入。

SmartScreen 判斷的是「下載量」和「有沒有簽章」，**不是程式本身有沒有問題**。
任何新發布、沒簽章的程式都會跳這個警告，跟內容無關。

### 請不要因為作者說沒問題就相信

這個工具會看到你打的每一個字，你應該多疑。可以自行驗證：

- **核對檔案指紋** —— [Release 頁面](https://github.com/b96093/bopomofo-garble-detector/releases)附有 SHA256，用 PowerShell 比對：

  ```
  Get-FileHash 注音亂碼偵測.exe -Algorithm SHA256
  ```

- **上傳到 [VirusTotal](https://www.virustotal.com/)** —— 讓幾十家防毒引擎一起看
- **自己編譯** —— 安裝 [AutoHotkey v2](https://www.autohotkey.com/) 後執行 `desktop/build.ps1`
- **乾脆不用 exe** —— 直接執行原始腳本 `desktop/app.ahk`，那不會被任何警告攔下

原始碼全部公開，搜尋整個專案不會找到任何網路請求的程式碼。

## 4. 第一次啟動要等一下

首次啟動會載入詞庫，約 **5～8 秒**畫面沒有任何反應——**那是正常的**，不是當掉。

載入完成後會：

- 在系統列（右下角）出現圖示
- 跳出使用說明
- 建立桌面捷徑

之後就可以照常打字了。打成注音亂碼時，游標旁會自動跳出候選中文。

## 之後在哪裡找到它

系統列圖示按**右鍵**，可以暫停偵測、開啟設定、重看使用說明，或移除本工具。

## 移除

系統列圖示右鍵 →「移除本工具…」。會清掉桌面捷徑與開機啟動設定，再把資料夾刪掉即可。

不寫登錄檔、不留任何殘留。

## 連結

- [回首頁](./)
- [使用說明與功能](https://github.com/b96093/bopomofo-garble-detector#readme)
- [隱私權政策](privacy-policy)
- [遇到問題？](https://github.com/b96093/bopomofo-garble-detector/issues)
