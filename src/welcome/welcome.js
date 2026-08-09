// 說明頁的即時示範。
// 內容腳本跑不到 chrome-extension:// 這種擴充自己的頁面，所以這裡直接引用引擎，
// 用一個簡化的結果列示範偵測 —— 讓人先看到它真的會動，再去真正的網頁用。
import { loadDict } from '../engine/dict.js';
import { detectTail } from '../engine/detect.js';
import { SUPPORT_URL } from '../support.js';

const box = document.getElementById('demo');
const out = document.getElementById('result');

function nothing(msg) {
  out.innerHTML = '';
  const s = document.createElement('span');
  s.className = 'none';
  s.textContent = msg;
  out.appendChild(s);
}

const dict = loadDict();

function run() {
  const text = box.value;
  if (!text.trim()) {
    nothing('打字後，這裡會顯示偵測到的中文。');
    return;
  }
  const hit = detectTail(text, dict, { threshold: 0.8, minSyllables: 2 });
  if (!hit) {
    nothing('這段看起來不是注音亂碼 —— 真正的英文不會被誤判。');
    return;
  }
  out.innerHTML = '';
  hit.res.candidates.slice(0, 3).forEach((cand, i) => {
    const row = document.createElement('div');
    row.className = i === 0 ? 'cand top' : 'cand';
    const n = document.createElement('span');
    n.className = 'n';
    n.textContent = i === 0 ? '→' : '';
    const v = document.createElement('span');
    v.className = 'v';
    // 亂碼前面若有正常文字（例如「你好 ji394t」），原樣保留
    v.textContent = text.slice(0, hit.offset) + cand;
    row.append(n, v);
    out.appendChild(row);
  });
}

box.addEventListener('input', run);

// 聯絡入口在 HTML 裡預設就顯示（見 welcome.html 的 #support 註解）。
// 這裡只負責兩件事：把網址對回單一來源，以及 SUPPORT_URL 留空時整塊藏起來。
if (SUPPORT_URL) {
  document.getElementById('support-link').href = SUPPORT_URL;
} else {
  document.getElementById('support').style.display = 'none';
}

// 擴充頁面之間不能用相對路徑直接開啟選項頁
document.getElementById('opt-link').addEventListener('click', (e) => {
  e.preventDefault();
  chrome.runtime.openOptionsPage();
});
