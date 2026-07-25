// 偵測迴圈：監看輸入 → 抓亂碼段 → detect → 跳浮窗（3 候選 + 逐字換字）→ 選字替換。
// 支援 input/textarea 與 contenteditable。被擴充內容腳本與測試頁共用（都呼叫 initDetector）。

import { keysToZhuyin } from '../engine/layout.js';
import { extractGarbleRun } from './extract.js';
import { getEditableContext, caretRect, applyReplacement } from './replace.js';
import { createPopup } from './popup.js';

function debounce(fn, ms) {
  let t;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

export function initDetector(dict, detect, opts = {}) {
  const popup = createPopup();
  let active = null; // { ctx, start, end }

  function scan() {
    const ctx = getEditableContext();
    if (!ctx) { active = null; popup.hide(); return; }
    const seg = extractGarbleRun(ctx.text, ctx.caret);
    if (!seg) { active = null; popup.hide(); return; }
    const res = detect(seg.run, dict, opts);
    if (!res) { active = null; popup.hide(); return; }

    active = { ctx, start: seg.start, end: seg.end };
    const syllables = keysToZhuyin(seg.run);
    popup.show(caretRect(ctx), {
      candidates: res.candidates,
      // 每個輸出字對應一個音節（字典的詞皆為一字一音節），位置一一對應
      homophonesFor: (k) => (dict.get(syllables[k]) || []).map(([w]) => w),
      onCommit: (str) => {
        if (!active) return;
        applyReplacement(active.ctx, active.start, active.end, str);
        active = null;
      },
    });
  }
  const scanDebounced = debounce(scan, 160);

  document.addEventListener('input', () => scanDebounced(), true);

  document.addEventListener('keydown', (e) => {
    if (!popup.isVisible()) return;
    if (e.key === 'Escape') { popup.hide(); active = null; }
    else if (e.key === 'Enter') { e.preventDefault(); popup.commitDraft(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); popup.move(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); popup.move(-1); }
  }, true);

  document.addEventListener('mousedown', (e) => {
    if (popup.isVisible() && !popup.contains(e.target)) { popup.hide(); active = null; }
  }, true);
}
