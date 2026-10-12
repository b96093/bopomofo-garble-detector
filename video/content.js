// 兩個版本的影片內容。純資料，scene.html 與 verify-content.mjs 共用。
//
// 筆記裡每一行亂碼都必須通過 node video/verify-content.mjs —— 用產品實際的引擎
// 轉回來要與 zh 一字不差。隨手寫的句子約一半會被轉成同音別字（2026-10-11：
// 37 句候選只有 12 句通過，例如「鐘」→「中」、「客服」→「克服」、「寄」→「繼」），
// 所以任何一句都不可以不經驗證就改。
window.CONTENT = {
  classroom: {
    name: '課堂版',
    docName: '上課筆記',
    slideTitle: '期中報告說明',
    slidePages: ['評分方式', '報告格式', '繳交期限', '期末考範圍'],
    endPage: '下課',
    caption1: '整節課的筆記。',
    header: '期中報告重點',
    lines: [
      { garble: '1l4el4fu6vu04g4vu845. j3', zh: '報告期限是下週五' },
      { garble: 'ru42k6zj4g;4h0 dl3y xul4', zh: '記得附上參考資料' },
      { keep: '10/24' },
      { garble: 'zp yj3au/620 au/6wu0 ej/ 1j4', zh: '分組名單明天公布' },
      { garble: 'fu6ai4dl3dl3fu06xu.45;', zh: '期末考考前六章' },
      { keep: '10:30' },
      { garble: 'dl3g4ul4294vm,6g/ 5/4', zh: '考試要帶學生證' },
    ],
  },
  meeting: {
    name: '會議版',
    docName: '會議紀錄',
    slideTitle: '第四季計畫',
    slidePages: ['產品進度', '預算規劃', '人力安排', '下次會議'],
    endPage: '散會',
    caption1: '整場會的紀錄。',
    header: '週會紀錄',
    lines: [
      { garble: 'vup 1031p3vu845. z8 1j4', zh: '新版本下週發布' },
      { garble: 'm4nj04m,42u3fu06nj/4tj', zh: '預算月底前送出' },
      { keep: '10/24' },
      { garble: 'ao3ek7bp65jp31o4rup42j41l4el4', zh: '每個人準備進度報告' },
      { garble: 'vu84h4d9 cjo4e932l45. n4', zh: '下次開會改到週四' },
      { keep: '10:30' },
      { garble: 'vup bp6vu84ek4m,41l42l4', zh: '新人下個月報到' },
    ],
  },
  chat: { name: '小雨', incoming: '你到了嗎？', garble: 'ji3u3ru/ 2l4x.6vu84xk7', zh: '我已經到樓下了' },
};
