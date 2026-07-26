// 選取亂碼時，在選取範圍旁浮出的小按鈕（顯示轉換結果預覽，點一下打開候選窗）。
// 只在選取內容確實判定為亂碼時出現，平常選字複製不受打擾。

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

export function createHint() {
  const host = document.createElement('div');
  host.style.cssText = 'position:absolute;z-index:2147483646;top:0;left:0;display:none;';
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
    <style>
      .btn{display:inline-flex;align-items:center;gap:7px;background:#fff;border:1px solid #bcd6f7;
        border-radius:9px;box-shadow:0 3px 12px rgba(0,0,0,.15);cursor:pointer;
        font:13px system-ui,-apple-system,sans-serif;padding:5px 11px;white-space:nowrap;
        max-width:320px;overflow:hidden}
      .btn:hover{background:#e8f1fd;border-color:#3a76d8}
      .ar{color:#3a76d8;font-size:13px}
      .zh{font-size:16px;color:#1e1e1e;text-overflow:ellipsis;overflow:hidden}
      .k{font-size:11px;color:#8a8a8a}
    </style>
    <div class="btn" id="btn"></div>`;
  const btn = root.getElementById('btn');
  document.documentElement.appendChild(host);

  let onPick = null;
  btn.addEventListener('mousedown', (e) => {
    e.preventDefault(); // 不要奪走輸入框的焦點與選取
    e.stopPropagation();
    const fn = onPick;
    hide();
    if (fn) fn();
  });

  function show(rect, preview, cb) {
    onPick = cb;
    btn.innerHTML =
      `<span class="ar">→</span><span class="zh">${esc(preview)}</span><span class="k">點我轉換</span>`;
    host.style.left = (window.scrollX + rect.left) + 'px';
    host.style.top = (window.scrollY + rect.bottom + 6) + 'px';
    host.style.display = 'block';
  }

  function hide() { host.style.display = 'none'; onPick = null; }

  return {
    show,
    hide,
    isVisible: () => host.style.display === 'block',
    contains: (t) => t === host || host.contains(t),
  };
}
