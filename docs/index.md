---
layout: default
title: 注音亂碼偵測
---

# 注音亂碼偵測

打字忘了切換輸入法，把整句注音打成英文亂碼 —— `ji394t au04` 其實是「我愛吃麵」。

這個工具會**自動認出**那串亂碼，並在游標旁跳出候選中文，選一下就還原。

**離線運作、不連網、不寫檔。** 開源，MIT 授權。

## 兩個版本

| | Chrome 擴充 | 桌面版 |
| --- | --- | --- |
| 適用範圍 | Chrome 裡的所有網頁 | Word、PowerPoint、LINE、記事本等所有 Windows 程式 |
| 判斷準確度 | 較高（能直接讀輸入框內容） | 一般（攔在輸入法之前） |

## 安裝

- **Chrome 擴充** —— [Chrome 線上應用程式商店](https://chromewebstore.google.com/detail/gjghbjnkbbccdhfiddmceijjkebajilm)
- **Windows 桌面版** —— [下載與安裝說明](install)（執行時會跳出 Windows 警告，那一頁有說明怎麼過）

## 連結

- [原始碼與說明文件](https://github.com/b96093/bopomofo-garble-detector)
- [隱私權政策](privacy-policy)
- [問題回報](https://github.com/b96093/bopomofo-garble-detector/issues)
- [聯絡與合作](support)

## 隱私

程式碼中沒有任何網路請求；你打的內容只存在記憶體，用完即丟。
詳見[隱私權政策](privacy-policy)。

不要因為這裡這樣寫就相信 —— 原始碼全部公開，可以自行檢查每一行。
