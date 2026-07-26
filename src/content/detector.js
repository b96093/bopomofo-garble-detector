// 偵測迴圈：監看輸入 → 抓亂碼段 → detect → 跳浮窗（3 候選 + 逐字換字）→ 選字替換。
// 另提供事後補救：選取任一段亂碼後按 Ctrl+Alt+Z，同樣跳浮窗替換
// （用於已經打完別的字、游標離開那段之後才發現打錯的情況）。
// 支援 input/textarea 與 contenteditable。被擴充內容腳本與測試頁共用（都呼叫 initDetector）。

import { extractGarbleRun } from './extract.js';
import {
  getEditableContext, caretRect, applyReplacement,
  getSelectionContext, selectionRect, applySelectionReplacement,
} from './replace.js';
import { createPopup } from './popup.js';
import { createHint } from './hint.js';

function debounce(fn, ms) {
  let t;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

export function initDetector(dict, detect, opts = {}) {
  const popup = createPopup();
  const hint = createHint();
  let apply = null; // 目前浮窗選定後要執行的替換動作

  function openPopup(res, rect, onPick) {
    hint.hide();
    apply = onPick;
    popup.show(rect, {
      candidates: res.candidates,
      // detect 已回傳每個輸出字對應的注音；標點／數字為 null（無同音字可換）
      homophonesFor: (k) => {
        const s = res.syllables[k];
        return s ? (dict.get(s) || []).map(([w]) => w) : [];
      },
      onCommit: (str) => {
        const fn = apply;
        apply = null;
        if (fn) fn(str);
      },
    });
  }

  function close() { apply = null; popup.hide(); }

  // 自動偵測：游標前那一段
  function scan() {
    const ctx = getEditableContext();
    if (!ctx) return close();
    const seg = extractGarbleRun(ctx.text, ctx.caret);
    if (!seg) return close();
    const res = detect(seg.run, dict, opts);
    if (!res) return close();
    openPopup(res, caretRect(ctx), (str) => applyReplacement(ctx, seg.start, seg.end, str));
  }
  const scanDebounced = debounce(scan, 160);

  // 手動補救：把選取的那段拿去判定（使用者已表明意圖，門檻放寬）
  // 回傳可開啟候選窗的動作，或 null（選取內容不是亂碼）
  function prepareSelection() {
    const sc = getSelectionContext();
    if (!sc || !sc.text.trim()) return null;
    const lead = sc.text.match(/^\s*/)[0];
    const trail = sc.text.match(/\s*$/)[0];
    const core = sc.text.slice(lead.length, sc.text.length - trail.length);
    const res = detect(core, dict, { ...opts, manual: true, minSyllables: 1, threshold: 0.5 });
    if (!res) return null;
    return {
      preview: res.candidates[0],
      open: () => openPopup(res, selectionRect(sc),
        (str) => applySelectionReplacement(sc, lead + str + trail)),
    };
  }

  // 選取了亂碼 → 在選取旁浮出小按鈕（免記快捷鍵）
  function offerSelection() {
    if (popup.isVisible()) return;
    const sel = prepareSelection();
    if (!sel) { hint.hide(); return; }
    const sc = getSelectionContext();
    hint.show(selectionRect(sc), sel.preview, sel.open);
  }
  const offerDebounced = debounce(offerSelection, 180);

  document.addEventListener('input', () => { hint.hide(); scanDebounced(); }, true);
  // selectionchange 在部分情境不會觸發，補上滑鼠／鍵盤放開時再判斷一次
  document.addEventListener('selectionchange', () => offerDebounced());
  document.addEventListener('mouseup', () => offerDebounced(), true);
  document.addEventListener('keyup', (e) => { if (e.shiftKey) offerDebounced(); }, true);

  document.addEventListener('keydown', (e) => {
    if (popup.isVisible()) {
      // 浮窗開著時，方向鍵/Enter 由浮窗接手；攔下以免網頁自己的選單（如搜尋建議）跟著動
      if (popup.handleKey(e.key)) {
        e.preventDefault();
        e.stopPropagation();
        if (!popup.isVisible()) apply = null;
      }
      return;
    }
    if (e.key === 'Escape' && hint.isVisible()) { hint.hide(); return; }
    // 保留快捷鍵給習慣鍵盤的人（與浮出按鈕等效）
    if (e.ctrlKey && e.altKey && !e.shiftKey && (e.key === 'z' || e.key === 'Z')) {
      const sel = prepareSelection();
      if (sel) { e.preventDefault(); e.stopPropagation(); sel.open(); }
    }
  }, true);

  document.addEventListener('mousedown', (e) => {
    if (popup.isVisible() && !popup.contains(e.target)) close();
    if (hint.isVisible() && !hint.contains(e.target)) hint.hide();
  }, true);
}
