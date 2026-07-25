// 內容腳本入口。傳統 script，用動態 import 載入 ES 模組（維持零相依、免打包）。
(async () => {
  const settings = await new Promise((r) =>
    chrome.storage.sync.get({ enabled: true, mode: 'conservative' }, r));
  if (!settings.enabled) { console.log('[文字亂碼偵測] 已停用'); return; }

  const eng = (p) => chrome.runtime.getURL(`src/engine/${p}`);
  const con = (p) => chrome.runtime.getURL(`src/content/${p}`);

  const { loadDict } = await import(eng('dict.js'));
  const { detect } = await import(eng('detect.js'));
  const { initDetector } = await import(con('detector.js'));

  const dict = loadDict();
  const opts = settings.mode === 'aggressive'
    ? { threshold: 0.6, minSyllables: 1 }
    : { threshold: 0.8, minSyllables: 2 };

  initDetector(dict, detect, opts);
  console.log('[文字亂碼偵測] 已啟用（' + settings.mode + '），字典條目：', dict.size);
})();
