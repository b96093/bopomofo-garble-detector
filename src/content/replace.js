// 統一處理 input / textarea 與 contenteditable：取得可編輯脈絡、游標矩形、執行替換。

export function isTextField(el) {
  if (!el || !el.tagName) return false;
  if (el.tagName === 'TEXTAREA') return true;
  if (el.tagName === 'INPUT') {
    const t = (el.type || 'text').toLowerCase();
    return ['text', 'search', 'url', 'email', 'tel', ''].includes(t);
  }
  return false;
}

function closestEditableHost(node) {
  const el = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
  return el ? el.closest('[contenteditable=""],[contenteditable="true"]') : null;
}

// 取得目前游標所在的可編輯脈絡；沒有則回 null
// input/textarea → { kind:'input', el, text, caret }
// contenteditable → { kind:'ce', node(文字節點), caret, host }
export function getEditableContext() {
  const ae = document.activeElement;
  if (isTextField(ae)) {
    return { kind: 'input', el: ae, text: ae.value, caret: ae.selectionStart ?? ae.value.length };
  }
  const sel = window.getSelection();
  if (sel && sel.rangeCount && sel.isCollapsed) {
    const node = sel.anchorNode;
    if (node && node.nodeType === Node.TEXT_NODE && closestEditableHost(node)) {
      return { kind: 'ce', node, text: node.textContent, caret: sel.anchorOffset, host: closestEditableHost(node) };
    }
  }
  return null;
}

// 浮窗定位用的矩形：contenteditable 用游標精準位置；input/textarea 用欄位框
export function caretRect(ctx) {
  if (ctx.kind === 'input') return ctx.el.getBoundingClientRect();
  const r = document.createRange();
  const pos = Math.min(ctx.caret, ctx.node.textContent.length);
  r.setStart(ctx.node, pos);
  r.collapse(true);
  const rect = r.getBoundingClientRect();
  if (rect.width || rect.height || rect.top || rect.left) return rect;
  return (ctx.node.parentElement || ctx.host).getBoundingClientRect();
}

// 以 chosen 取代 [start, end)
export function applyReplacement(ctx, start, end, chosen) {
  if (ctx.kind === 'input') {
    const v = ctx.el.value;
    ctx.el.value = v.slice(0, start) + chosen + v.slice(end);
    const pos = start + chosen.length;
    try { ctx.el.setSelectionRange(pos, pos); } catch (_) { /* 某些 input 不支援 */ }
    ctx.el.dispatchEvent(new Event('input', { bubbles: true }));
    ctx.el.focus();
    return;
  }
  // contenteditable：選取該區段，用 execCommand 插入（讓 React/Lexical 等框架能接收）
  const sel = window.getSelection();
  const range = document.createRange();
  const len = ctx.node.textContent.length;
  range.setStart(ctx.node, Math.min(start, len));
  range.setEnd(ctx.node, Math.min(end, len));
  sel.removeAllRanges();
  sel.addRange(range);
  document.execCommand('insertText', false, chosen);
}
