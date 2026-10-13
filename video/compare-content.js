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
  // 各站視窗只仿照程式的配色與版面、寫出程式名稱，不畫任何 Logo 圖示（名稱見 summary.tm 的商標聲明）
  // 09:00 回信（Gmail）：Chrome 版打字偵測（detectTail，積極模式）
  mail: { tab: 'mail.google.com', app: 'Gmail', subject: '回覆：週五的會議', to: '王經理', send: '傳送',
    greet: '王經理您好，', zh: '我晚點再回你', garble: 'ji3j032u03y94cjo6su3' },
  // 10:30 聊天（LINE）：桌面版（CONTENT.chat）
  chatApp: 'LINE',
  // 14:00 整段還原（Word）：桌面版（CONTENT.meeting）
  docApp: 'Word',
  docFile: '會議紀錄.docx',
  docRibbon: ['檔案', '常用', '插入', '設計', '版面配置'],
  // 16:00 Google 文件：桌面版打字偵測（DetectTail，靈敏度 4）
  docs: { tab: 'docs.google.com', menu: ['檔案', '編輯', '查看', '插入', '格式', '工具'], share: '共用',
    title: '第三章 草稿', zh: '第三章還沒寫完', garble: '2u4n0 5; c96ao6vu,3j06' },
  // 21:00 留言（Facebook）：Chrome 版被動選取（detect，與打字同一組門檻）
  post: { tab: 'facebook.com', app: 'Facebook', actions: ['讚', '留言', '分享'],
    author: '阿哲', text: '週末去吃了這家拉麵，超好吃！', zh: '下次一起去', garble: 'vu84h4u fu3fm4' },
  endTitle: '注音亂碼偵測',
  summary: {
    head: ['', 'Chrome 版', '桌面版'],
    rows: [
      ['在哪裡用', 'Chrome 裡的網頁', 'Word、LINE 等 Windows 程式，以及 Google 文件'],
      ['事後補救', '選起來自動浮出按鈕', '選起來按 Ctrl+Alt+Z'],
      ['整段一次還原', '—', '✓'],
      ['安裝', '商店點一下，自動更新', '下載解壓縮，第一次執行會跳 Windows 警告'],
    ],
    tip: '兩個都裝時：桌面版設定取消勾選「在 Chrome 中也偵測」，Google 文件仍由桌面版處理',
    tm: 'LINE、Word、Gmail、Google 文件、Facebook 為各公司的商標，本工具與其無關',
  },
};
