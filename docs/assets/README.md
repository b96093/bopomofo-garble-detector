# 說明文件用的圖片

`install.md` 需要兩張 SmartScreen 的截圖：

| 檔名 | 內容 |
| --- | --- |
| `smartscreen-1.png` | 藍色警告的初始畫面（只有「不要執行」與「其他資訊」） |
| `smartscreen-2.png` | 點「其他資訊」展開後（顯示發行者「不明的發行者」與「仍要執行」） |

放進來之後，把 install.md 裡對應的 `<!-- 截圖：... -->` 註解換成：

```markdown
![Windows 已保護您的電腦](assets/smartscreen-1.png)
```

註：圖片一旦 commit 就會留在 git 歷史裡，換掉舊的仍查得到。
