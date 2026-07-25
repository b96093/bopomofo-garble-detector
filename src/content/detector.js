// 偵測迴圈：監看輸入 → 抓亂碼段 → detect → 跳浮窗 → 選字替換。
// 被擴充內容腳本與測試頁共用（都呼叫 initDetector）。

import { extractGarbleRun } from './extract.js';
import { isTextField, getFieldText, getCaret, replaceInField } from './replace.js';
import { createPopup } from './popup.js';

function debounce(fn, ms) {
  let t;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

export function initDetector(dict, detect, opts = {}) {
  const popup = createPopup();
  let active = null; // { field, start, end, candidates }

  function apply(chosen) {
    if (!active) return;
    replaceInField(active.field, active.start, active.end, chosen);
    active = null;
  }

  function scan(field) {
    if (!isTextField(field)) { active = null; popup.hide(); return; }
    const seg = extractGarbleRun(getFieldText(field), getCaret(field));
    if (!seg) { active = null; popup.hide(); return; }
    const res = detect(seg.run, dict, opts);
    if (!res) { active = null; popup.hide(); return; }
    active = { field, start: seg.start, end: seg.end, candidates: res.candidates };
    popup.show(res.candidates, field.getBoundingClientRect(), apply);
  }
  const scanDebounced = debounce(scan, 160);

  document.addEventListener('input', (e) => scanDebounced(e.target), true);

  document.addEventListener('keydown', (e) => {
    if (!popup.isVisible()) return;
    if (e.key === 'Escape') { popup.hide(); active = null; }
    else if (e.key === 'Enter') { e.preventDefault(); popup.pickIndex(0); }
    else if (e.key >= '2' && e.key <= '9') {
      const i = Number(e.key) - 1;
      if (i < popup.count()) { e.preventDefault(); popup.pickIndex(i); }
    }
  }, true);

  document.addEventListener('mousedown', (e) => {
    if (popup.isVisible() && !popup.contains(e.target)) { popup.hide(); active = null; }
  }, true);
}
