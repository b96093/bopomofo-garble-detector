// 版本比較影片的文字內容。亂碼都已用「該站負責的那一版」的引擎驗證過（node video/verify-content.mjs），
// 不可自行替換句子 —— 隨手寫的句子常被轉成同音別字（例如「好的明天見」→「好的明天間」）。
// 聊天那句與整頁會議紀錄沿用 content.js 的 CONTENT.chat、CONTENT.meeting（宣傳片已驗證）。
window.COMPARE = {
  title: 'Chrome 版和桌面版，差在哪？',
  legend: '亮燈＝現在是這一版在幫你',
  clocks: ['09:00', '10:30', '14:00', '16:00', '21:00'],
  captions: [
    '網頁上的輸入框 → Chrome 版',
    'LINE、Word 這些 Windows 程式 → 桌面版',
    '整段一次還原：只有桌面版',
    'Google 文件：Chrome 版讀不到，桌面版接手',
    '選起來就浮出按鈕：網頁上 Chrome 版比較順手',
    '最好兩個都裝',
  ],
  tags: { none: '沒有這個功能', cant: '讀不到' },
  // 09:00 回信：Chrome 版打字偵測（detectTail，積極模式）
  mail: { tab: '信件', subject: '回覆：週五的會議', greet: '王經理您好，', zh: '我晚點再回你', garble: 'ji3j032u03y94cjo6su3' },
  // 10:30 聊天：桌面版（CONTENT.chat）
  chatApp: '聊天',
  // 14:00 整段還原：桌面版（CONTENT.meeting）
  docApp: '會議紀錄 — 文書軟體',
  // 16:00 Google 文件：桌面版打字偵測（DetectTail，靈敏度 4）
  docs: { tab: '線上文件', title: '第三章 草稿', zh: '第三章還沒寫完', garble: '2u4n0 5; c96ao6vu,3j06' },
  // 21:00 留言：Chrome 版被動選取（detect，與打字同一組門檻）
  post: { tab: '社群', author: '阿哲', text: '週末去吃了這家拉麵，超好吃！', zh: '下次一起去', garble: 'vu84h4u fu3fm4' },
  summary: {
    head: ['', 'Chrome 版', '桌面版'],
    rows: [
      ['在哪裡用', 'Chrome 裡的網頁', 'Word、LINE 等 Windows 程式，以及 Google 文件'],
      ['事後補救', '選起來自動浮出按鈕', '選起來按 Ctrl+Alt+Z'],
      ['整段一次還原', '—', '✓'],
      ['安裝', '商店點一下，自動更新', '下載解壓縮，第一次執行會跳 Windows 警告'],
    ],
    tip: '兩個都裝時：桌面版設定取消勾選「在 Chrome 中也偵測」，Google 文件仍由桌面版處理',
  },
};
