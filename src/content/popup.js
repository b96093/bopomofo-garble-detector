// Shadow DOM 候選浮窗（方案 C）：上半 3 整句候選、下半逐字換字。
// 選字：方向鍵 ↑↓ 移動高亮、Enter 插入；逐字換字用滑鼠點。（不用數字鍵，避免長句誤按）

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
        padding:6px;min-width:210px;max-width:320px;color:#1e1e1e}
      .hdr{font-size:11px;color:#8a8a8a;padding:3px 8px 6px}
      .item{display:flex;justify-content:space-between;gap:14px;align-items:center;
        padding:6px 10px;border-radius:7px;cursor:pointer}
      .item:hover{background:#f0f0f0}
      .item.sel{background:#e8f1fd}
      .z{font-size:18px;letter-spacing:1px}
      .k{font-size:11px;color:#3a76d8}
      .lbl{font-size:11px;color:#8a8a8a;padding:7px 8px 4px;border-top:1px solid #eee;margin-top:4px}
      .chars{display:flex;flex-wrap:wrap;gap:4px;padding:2px 8px 4px}
      .ch{font-size:19px;padding:2px 7px;border-radius:6px;cursor:pointer;border:1px solid transparent}
      .ch:hover{background:#f0f0f0}
      .ch.open{background:#e8f1fd;border-color:#bcd6f7;color:#1a5fb4}
      .tray{display:flex;flex-wrap:wrap;gap:5px;padding:6px 8px;margin:2px 6px;background:#f7f7f7;
        border-radius:8px;max-height:132px;overflow-y:auto}
      .hom{font-size:17px;padding:3px 9px;border-radius:6px;cursor:pointer;border:1px solid #e2e2e2;background:#fff}
      .hom:hover{background:#e8f1fd;border-color:#bcd6f7}
      .hom.cur{background:#e8f1fd;border-color:#3a76d8;color:#1a5fb4}
      .commit{margin:6px 6px 2px;padding:8px 10px;border-radius:8px;background:#e8f1fd;color:#1a5fb4;
        cursor:pointer;text-align:center;font-size:15px}
      .commit:hover{background:#d8e8fc}
      .ft{font-size:11px;color:#aaa;padding:6px 8px 2px;display:flex;justify-content:space-between}
    </style>
    <div class="box" id="box"></div>`;
  const box = root.getElementById('box');
  document.documentElement.appendChild(host);

  let state = null; // { candidates, selected, draft[], homophonesFor, onCommit, openChar }

  function render() {
    const { candidates, selected, draft, homophonesFor, openChar } = state;
    let h = `<div class="hdr">偵測到注音亂碼 · ↑↓ 選句、Enter 插入，或點字換同音</div>`;
    h += candidates.map((c, i) =>
      `<div class="item${i === selected ? ' sel' : ''}" data-cand="${i}">` +
      `<span class="z">${esc(c)}</span><span class="k">${i === selected ? 'Enter' : ''}</span></div>`
    ).join('');
    h += `<div class="lbl">逐字換同音字（點字）：</div>`;
    h += `<div class="chars">` +
      draft.map((ch, k) => `<span class="ch${k === openChar ? ' open' : ''}" data-ch="${k}">${esc(ch)}</span>`).join('') +
      `</div>`;
    if (openChar >= 0) {
      const homs = homophonesFor(openChar);
      h += `<div class="tray">` +
        (homs.length
          ? homs.map((w) => `<span class="hom${w === draft[openChar] ? ' cur' : ''}" data-hom="${esc(w)}">${esc(w)}</span>`).join('')
          : `<span style="font-size:12px;color:#999">（無其他同音字）</span>`) +
        `</div>`;
    }
    h += `<div class="commit" data-commit="1">插入「${esc(draft.join(''))}」</div>`;
    h += `<div class="ft"><span>↑↓ 選句 · 點字換同音</span><span>Esc 忽略</span></div>`;
    box.innerHTML = h;

    box.querySelectorAll('[data-cand]').forEach((el) =>
      el.addEventListener('mousedown', (e) => { e.preventDefault(); commit(state.candidates[+el.dataset.cand]); }));
    box.querySelectorAll('[data-ch]').forEach((el) =>
      el.addEventListener('mousedown', (e) => {
        e.preventDefault();
        state.openChar = state.openChar === +el.dataset.ch ? -1 : +el.dataset.ch;
        render();
      }));
    box.querySelectorAll('[data-hom]').forEach((el) =>
      el.addEventListener('mousedown', (e) => {
        e.preventDefault();
        state.draft[state.openChar] = el.dataset.hom;
        state.openChar = -1;
        render();
      }));
    box.querySelector('[data-commit]').addEventListener('mousedown', (e) => { e.preventDefault(); commit(state.draft.join('')); });
  }

  function position(rect) {
    host.style.left = (window.scrollX + rect.left) + 'px';
    host.style.top = (window.scrollY + rect.bottom + 4) + 'px';
  }

  function show(rect, opts) {
    state = {
      candidates: opts.candidates,
      selected: 0,
      draft: [...opts.candidates[0]],
      homophonesFor: opts.homophonesFor,
      onCommit: opts.onCommit,
      openChar: -1,
    };
    render();
    position(rect);
    host.style.display = 'block';
  }

  function hide() { host.style.display = 'none'; state = null; }

  function commit(str) {
    const cb = state && state.onCommit;
    hide();
    if (str != null && cb) cb(str);
  }

  // 方向鍵移動高亮：切換選中的整句候選，並把草稿重設為該候選（清掉逐字暫改）
  function move(delta) {
    if (!state) return;
    const n = state.candidates.length;
    state.selected = (state.selected + delta + n) % n;
    state.draft = [...state.candidates[state.selected]];
    state.openChar = -1;
    render();
  }

  return {
    show,
    hide,
    move,
    isVisible: () => host.style.display === 'block',
    contains: (t) => t === host || host.contains(t),
    commitDraft: () => { if (state) commit(state.draft.join('')); },
  };
}
