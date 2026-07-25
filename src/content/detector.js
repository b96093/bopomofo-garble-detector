// 偵測迴圈：監看輸入 → 抓亂碼段 → detect → 跳浮窗（3 候選 + 逐字換字）→ 選字替換。
// 支援 input/textarea 與 contenteditable。被擴充內容腳本與測試頁共用（都呼叫 initDetector）。

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
    popup.show(caretRect(ctx), {
      candidates: res.candidates,
      // detect 已回傳每個輸出字對應的注音；標點為 null（無同音字可換）
      homophonesFor: (k) => {
        const s = res.syllables[k];
        return s ? (dict.get(s) || []).map(([w]) => w) : [];
      },
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
    // 浮窗開著時，方向鍵/Enter 由浮窗接手；攔下以免網頁自己的選單（如搜尋建議）跟著動
    if (popup.handleKey(e.key)) {
      e.preventDefault();
      e.stopPropagation();
      if (!popup.isVisible()) active = null;
    }
  }, true);

  document.addEventListener('mousedown', (e) => {
    if (popup.isVisible() && !popup.contains(e.target)) { popup.hide(); active = null; }
  }, true);
}
