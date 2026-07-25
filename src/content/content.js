// 內容腳本入口。內容腳本本身是傳統 script，用動態 import 載入 ES 模組引擎
// （維持零相依、免打包）。引擎模組列於 manifest 的 web_accessible_resources。
(async () => {
  const url = (p) => chrome.runtime.getURL(`src/engine/${p}`);
  const { loadDict } = await import(url('dict.js'));
  const { detect } = await import(url('detect.js'));

  const dict = loadDict();
  console.log('[文字亂碼偵測] ready，字典條目：', dict.size);

  // 階段 1 煙霧測試：確認引擎在真實網頁環境可運作
  console.log('[文字亂碼偵測] detect("ji394t au04") =', detect('ji394t au04', dict));
})();
