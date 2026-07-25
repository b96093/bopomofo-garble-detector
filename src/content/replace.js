// input / textarea 的欄位讀取、游標、替換。（contenteditable 於階段 4 補上）

export function isTextField(el) {
  if (!el || !el.tagName) return false;
  if (el.tagName === 'TEXTAREA') return true;
  if (el.tagName === 'INPUT') {
    const t = (el.type || 'text').toLowerCase();
    return ['text', 'search', 'url', 'email', 'tel', ''].includes(t);
  }
  return false;
}

export function getFieldText(el) {
  return el.value ?? '';
}

export function getCaret(el) {
  const p = el.selectionStart;
  return typeof p === 'number' ? p : getFieldText(el).length;
}

// 以 chosen 取代 [start, end) 區段，並觸發 input 事件（讓網站的框架知道內容變了）
export function replaceInField(el, start, end, chosen) {
  const v = getFieldText(el);
  el.value = v.slice(0, start) + chosen + v.slice(end);
  const pos = start + chosen.length;
  try { el.setSelectionRange(pos, pos); } catch (_) { /* 某些 input 不支援 */ }
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.focus();
}
