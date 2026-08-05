# Google 文件支援可行性研究

2026-08-05 實測。目的：Chrome 擴充在 Google 文件無法運作，釐清是否有解。

**結論：選取轉換可行、邊打邊偵測不可行。**

---

## 背景：為什麼一般做法會失效

Google Docs 自 2021 年起把文件內容**繪製在 canvas 上**：

- 文字**不存在於 DOM**（實測：畫面看得到 `ji394t au04`，`document.body.innerText` 搜尋不到）
- 鍵盤輸入由一個藏在 iframe 裡的隱形 contenteditable 接收
  （`.docs-texteventtarget-iframe`），該元素平時是空字串
- 內容由 Google 自己的 JS 模型管理

因此所有依賴「讀 DOM 文字 / 改 DOM 文字」的擴充都會失效。

> 注意：**不需要 `all_frames: true`**。該 iframe 與主頁面同源，
> 頂層內容腳本可直接 `iframe.contentDocument` 存取。本研究全部從頂層完成。

---

## 實測結果

### ✅ 可行的能力

| 能力 | 方法 | 實測結果 |
| --- | --- | --- |
| **讀取選取內容** | `iframe.contentWindow.getSelection().toString()` | 回傳完整選取文字 |
| 讀取選取（備用） | 對 CE 派送合成 `copy` 事件，讀 `clipboardData` | Docs 會填入 `text/plain` |
| **寫入／取代選取** | 派送合成 `paste` 事件（帶 `DataTransfer`） | **成功**，整段選取被取代 |
| **候選窗定位** | `.kix-cursor-caret` 的 `getBoundingClientRect()` | 回傳實際插入點座標 |
| 觀察使用者按鍵 | 在 iframe document 掛 `keydown`（capture） | 收得到，且 `isTrusted: true` |
| 觸發 Docs UI 按鈕 | 對按鈕派送合成 `click` | **成功**（以復原按鈕驗證） |

**關鍵發現**：Docs 的 JS handler **不檢查 `isTrusted`**，所以合成事件能觸發它的處理邏輯。
失效的是那些依賴瀏覽器「預設行為」的路徑（例如在 contenteditable 插入字元）。

### ❌ 不可行的能力

| 嘗試 | 結果 | 原因 |
| --- | --- | --- |
| 合成 `keydown` 輸入文字 | 無作用 | 文字插入靠瀏覽器預設行為，合成事件不觸發 |
| 合成 `keydown` 送 Backspace | 無作用 | 同上 |
| `document.execCommand('insertText')` | 回傳 `false` | Docs 不透過 execCommand |
| **點擊復原按鈕當作刪除手段** | 可執行但**粒度不可控** | 復原的是「整個操作」而非 N 個字元。實測：打「今天」→ 打亂碼 → 一次復原，結果多還原了先前被取代的文字 |
| 合成滑鼠拖曳在 canvas 上選取 | 只選到一個空白 | canvas 選取邏輯不吃合成滑鼠事件 |

---

## 可以做什麼

### ✅ 選取轉換（事後補救）—— 完整可行

```
使用者選取亂碼
  → iframe.contentWindow.getSelection() 讀出內容
  → 引擎判斷是否為注音亂碼
  → 於 .kix-cursor-caret 位置顯示候選窗
  → 使用者確認後派送合成 paste 事件取代選取
```

四個環節全部實測通過。

### ❌ 邊打邊偵測 —— 缺最後一哩

偵測本身可行（keydown 收得到、可累積緩衝、候選窗也顯示得出來），
但**無法刪除已經打進去的亂碼**——五種刪除途徑全部失敗或不可靠。

理論上可行但不採用的方案：攔截所有按鍵並 `preventDefault`，
由擴充自行以合成 paste 重建整個輸入流。這等於重寫一個輸入法，
會破壞正常打字行為，代價遠大於收益。

---

## 風險

本方案依賴 Google Docs 的**內部實作細節**：

- `.docs-texteventtarget-iframe`（輸入目標 iframe 的 class）
- `.kix-cursor-caret`（插入點元素的 class）
- Docs 會回應合成 `paste` 與 `copy` 事件的行為

這些都**不是公開介面**，Google 改版即可能失效。若採用，說明文件必須誠實標註此風險，
並在偵測不到上述元素時安靜地不啟用，而非報錯。

---

## 最終結論：不實作

**因為桌面版已經完整覆蓋這個情境，且做得比 Chrome 版能做到的更好。**

2026-08-05 以螢幕錄影實測桌面版於 Google 文件：

| 能力 | 桌面版 | Chrome 版若實作 |
| --- | --- | --- |
| 邊打邊自動偵測 | ✅ | ❌ 無法（刪不掉已輸入的亂碼） |
| 候選窗定位 | ✅ | ✅ |
| 逐字換同音字 | ✅ | ✅ |
| **按 Enter 替換** | ✅ | ❌ **無法** |

實測畫面：輸入 `ao6hji4ru.4g45k4u;4` → 候選窗跳出「沒錯就是這樣」→ 展開同音字盤
→ 按 Enter → 文字成功替換。

桌面版在 OS 層攔鍵盤、用模擬輸入送字，不碰 DOM，因此完全不受 canvas 限制。

### 不做的理由

1. **功能更少** —— Chrome 版只能做選取轉換，桌面版連自動偵測都能用
2. **長期維護負擔** —— 依賴 `.docs-texteventtarget-iframe`、`.kix-cursor-caret`
   等內部 class，Google 改版即失效
3. **需要重新送審** —— 換來的是一個比現有解法更弱的功能

### 改為採取的做法

在說明文件中明確引導：**Google 文件請使用桌面版**。已寫入 `docs/readme-chrome.md`。

### 這份研究仍然有價值

若未來桌面版不可用（例如出了 macOS / Linux 版之前，或使用者只裝 Chrome 擴充），
上面驗證過的技術路徑可以直接拿來實作，不必重做實驗。
