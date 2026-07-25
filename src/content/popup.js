// Shadow DOM 候選浮窗。階段 2 為極簡版（列出候選、點擊/鍵盤選字）。
// 階段 3 會擴充為「3 整句候選 + 逐字換字」。

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

export function createPopup() {
  const host = document.createElement('div');
  host.style.cssText = 'position:absolute;z-index:2147483647;top:0;left:0;display:none;';
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
    <style>
      .box{background:#fff;border:1px solid #d0d0d0;border-radius:10px;
        box-shadow:0 6px 22px rgba(0,0,0,.16);font:14px system-ui,-apple-system,sans-serif;
        padding:6px;min-width:190px;color:#1e1e1e}
      .hdr{font-size:11px;color:#8a8a8a;padding:3px 8px 7px;display:flex;gap:5px;align-items:center}
      .item{display:flex;justify-content:space-between;gap:14px;align-items:center;
        padding:7px 10px;border-radius:7px;cursor:pointer}
      .item:hover,.item.sel{background:#e8f1fd}
      .z{font-size:18px;letter-spacing:1px}
      .k{font-size:11px;color:#3a76d8}
      .ft{font-size:11px;color:#aaa;padding:6px 8px 2px;border-top:1px solid #eee;
        margin-top:4px;display:flex;justify-content:space-between}
    </style>
    <div class="box" id="box"></div>`;
  const box = root.getElementById('box');
  document.documentElement.appendChild(host);

  let onPick = null;
  let candidates = [];

  function show(cands, rect, pick) {
    candidates = cands;
    onPick = pick;
    box.innerHTML =
      `<div class="hdr">偵測到注音亂碼 · 選一個</div>` +
      cands.map((c, i) =>
        `<div class="item${i === 0 ? ' sel' : ''}" data-i="${i}">` +
        `<span class="z">${esc(c)}</span>` +
        `<span class="k">${i === 0 ? 'Enter' : i + 1}</span></div>`
      ).join('') +
      `<div class="ft"><span>點擊 / 數字鍵</span><span>Esc 忽略</span></div>`;
    box.querySelectorAll('.item').forEach((el) => {
      el.addEventListener('mousedown', (ev) => {
        ev.preventDefault();
        pickIndex(Number(el.dataset.i));
      });
    });
    host.style.left = (window.scrollX + rect.left) + 'px';
    host.style.top = (window.scrollY + rect.bottom + 4) + 'px';
    host.style.display = 'block';
  }

  function hide() {
    host.style.display = 'none';
    onPick = null;
    candidates = [];
  }

  function pickIndex(i) {
    const c = candidates[i];
    const cb = onPick;
    hide();
    if (c != null && cb) cb(c);
  }

  return {
    show,
    hide,
    pickIndex,
    isVisible: () => host.style.display === 'block',
    contains: (t) => t === host || host.contains(t),
    count: () => candidates.length,
  };
}
