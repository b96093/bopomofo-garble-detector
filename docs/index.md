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
| 適用範圍 | Chrome 裡的所有網頁 | Word、PowerPoint、LINE、記事本等所有 Windows 程式，以及 Google 文件 |

<div>
<video src="assets/version-compare.mp4" poster="assets/version-compare.jpg"
       controls muted autoplay loop playsinline preload="metadata"
       style="width:100%;max-width:540px;display:block;margin:1em 0">
  你的瀏覽器無法播放影片，可以<a href="assets/version-compare.mp4">直接下載</a>（2.7 MB）。
</video>
</div>

**建議兩個都裝**：網頁交給 Chrome 擴充，其他程式與 Google 文件交給桌面版。
兩個都裝時，請在桌面版設定取消勾選「在 Chrome 中也偵測」，否則網頁上會跳出兩個候選窗。

## 安裝

> **兩個版本都要裝在電腦上。** 手機版的 Chrome 不支援擴充功能，桌面版只能在 Windows 執行。
> 如果你是用手機看到這一頁，請改用電腦開啟。

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
