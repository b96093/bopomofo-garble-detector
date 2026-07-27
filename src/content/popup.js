// Shadow DOM 候選浮窗（方案 C）：上半 3 整句候選、下半逐字換同音字。
// 鍵盤分三區導航：句子區 ↑↓ → 逐字區 ←→ → 同音字區 ←→，Enter 確定、Esc 退回/關閉。
// 底部提示隨所在區塊改變，讓第一次使用者知道能按什麼。

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
        padding:6px;min-width:230px;max-width:330px;color:#1e1e1e}
      .hdr{font-size:11px;color:#8a8a8a;padding:3px 8px 6px}
      .item{display:flex;justify-content:space-between;gap:14px;align-items:center;
        padding:6px 10px;border-radius:7px;cursor:pointer}
      .item:hover{background:#f0f0f0}
      .item.sel{background:#e8f1fd}
      .item.sel.dim{background:#f2f2f2}
      .z{font-size:18px;letter-spacing:1px}
      .k{font-size:11px;color:#3a76d8}
      .lbl{font-size:11px;color:#8a8a8a;padding:7px 8px 4px;border-top:1px solid #eee;margin-top:4px}
      .chars{display:flex;flex-wrap:wrap;gap:5px;padding:2px 8px 4px}
      /* 逐字：做成看得出可點的按鈕樣式（虛線框 + 小箭頭） */
      .ch{font-size:19px;padding:3px 9px 3px 8px;border-radius:7px;cursor:pointer;
        border:1px dashed #c9c9c9;background:#fff;line-height:1.25}
      .ch:hover{background:#f0f6ff;border-color:#9dc2f5}
      .ch::after{content:"▾";font-size:9px;color:#b0b0b0;margin-left:3px;vertical-align:2px}
      .ch.plain{border-color:transparent;cursor:default;color:#8a8a8a;padding-left:4px;padding-right:4px}
      .ch.plain:hover{background:none;border-color:transparent}
      .ch.plain::after{content:""}
      .ch.focus{border-style:solid;border-color:#3a76d8;background:#e8f1fd;color:#1a5fb4;
        box-shadow:0 0 0 2px rgba(58,118,216,.18)}
      .ch.open{border-style:solid;border-color:#3a76d8;background:#e8f1fd;color:#1a5fb4}
      .tray{display:flex;flex-wrap:wrap;gap:5px;padding:6px 8px;margin:2px 6px;background:#f7f7f7;
        border-radius:8px;max-height:132px;overflow-y:auto}
      .hom{font-size:17px;padding:3px 9px;border-radius:6px;cursor:pointer;border:1px solid #e2e2e2;background:#fff}
      .hom:hover{background:#e8f1fd;border-color:#bcd6f7}
      .hom.cur{border-color:#9dc2f5;background:#f0f6ff}
      .hom.focus{border-color:#3a76d8;background:#e8f1fd;color:#1a5fb4;
        box-shadow:0 0 0 2px rgba(58,118,216,.18)}
      .commit{margin:6px 6px 2px;padding:8px 10px;border-radius:8px;background:#e8f1fd;color:#1a5fb4;
        cursor:pointer;text-align:center;font-size:15px}
      .commit:hover{background:#d8e8fc}
      .ft{font-size:11px;color:#999;padding:6px 8px 2px;display:flex;justify-content:space-between;gap:10px}
    </style>
    <div class="box" id="box"></div>`;
  const box = root.getElementById('box');
  document.documentElement.appendChild(host);

  // state.zone：'sent'（整句候選）｜'chars'（逐字）｜'tray'（同音字）
  let state = null;

  function homsAt(k) { return state.homophonesFor(k) || []; }

  function currentHomIdx(k) {
    const i = homsAt(k).indexOf(state.draft[k]);
    return i >= 0 ? i : 0;
  }

  // 找下一個可換字的位置（跳過標點）；找不到就留在原地
  function seekChar(from, d) {
    for (let k = from; k >= 0 && k < state.draft.length; k += d) {
      if (homsAt(k).length) return k;
    }
    return homsAt(state.charIdx).length ? state.charIdx : -1;
  }

  function render() {
    const { candidates, selected, draft, zone, charIdx, homIdx } = state;
    const inSent = zone === 'sent';

    let h = `<div class="hdr">偵測到注音亂碼</div>`;
    h += candidates.map((c, i) =>
      `<div class="item${i === selected ? ' sel' + (inSent ? '' : ' dim') : ''}" data-cand="${i}">` +
      `<span class="z">${esc(c)}</span><span class="k">${i === selected && inSent ? 'Enter' : ''}</span></div>`
    ).join('');

    h += `<div class="lbl">逐字換同音字（點字，或按 ↓ 進入）：</div>`;
    h += `<div class="chars">` + draft.map((ch, k) => {
      if (!homsAt(k).length) return `<span class="ch plain">${esc(ch)}</span>`; // 標點：不可換
      const cls = (!inSent && k === charIdx) ? (zone === 'tray' ? ' open' : ' focus') : '';
      return `<span class="ch${cls}" data-ch="${k}">${esc(ch)}</span>`;
    }).join('') + `</div>`;

    if (zone === 'tray') {
      const homs = homsAt(charIdx);
      h += `<div class="tray">` +
        (homs.length
          ? homs.map((w, i) => {
              const cls = i === homIdx ? ' focus' : (w === draft[charIdx] ? ' cur' : '');
              return `<span class="hom${cls}" data-hom="${i}">${esc(w)}</span>`;
            }).join('')
          : `<span style="font-size:12px;color:#999">（無其他同音字）</span>`) +
        `</div>`;
    }

    h += `<div class="commit" data-commit="1">↵ 改為「${esc(draft.join(''))}」</div>`;
    const hint = inSent ? '↑↓ 選句 · ↓ 進逐字 · Enter 插入'
      : zone === 'chars' ? '←→ 選字 · ↓ 展開同音 · Enter 插入'
      : '←→↑↓ 選同音字 · Enter 換上 · Esc 返回';
    h += `<div class="ft"><span>${hint}</span><span>Esc</span></div>`;
    box.innerHTML = h;

    box.querySelectorAll('[data-cand]').forEach((el) =>
      el.addEventListener('mousedown', (e) => { e.preventDefault(); commit(state.candidates[+el.dataset.cand]); }));
    box.querySelectorAll('[data-ch]').forEach((el) =>
      el.addEventListener('mousedown', (e) => {
        e.preventDefault();
        const k = +el.dataset.ch;
        if (state.zone === 'tray' && state.charIdx === k) state.zone = 'chars';
        else { state.zone = 'tray'; state.charIdx = k; state.homIdx = currentHomIdx(k); }
        render();
      }));
    box.querySelectorAll('[data-hom]').forEach((el) =>
      el.addEventListener('mousedown', (e) => { e.preventDefault(); pickHom(+el.dataset.hom); }));
    box.querySelector('[data-commit]').addEventListener('mousedown', (e) => { e.preventDefault(); commit(state.draft.join('')); });

    // 讓鍵盤焦點所在的項目保持在可視範圍內
    const focused = box.querySelector('.focus');
    if (focused && focused.scrollIntoView) focused.scrollIntoView({ block: 'nearest' });
  }

  // 同音字是多列排版：依實際版面位置移到上／下一列中，水平位置最接近的字。
  // 回傳 false 表示已在最上／最下一列（呼叫端據此決定要不要收起）。
  function moveHomRow(dir) {
    const els = [...box.querySelectorAll('.hom')];
    const cur = els[state.homIdx];
    if (!cur) return false;
    const center = cur.offsetLeft + cur.offsetWidth / 2;
    const rows = [...new Set(els.map((e) => e.offsetTop))].sort((a, b) => a - b);
    const targetTop = rows[rows.indexOf(cur.offsetTop) + dir];
    if (targetTop === undefined) return false;
    let best = -1;
    let bestDist = Infinity;
    els.forEach((e, i) => {
      if (e.offsetTop !== targetTop) return;
      const d = Math.abs(e.offsetLeft + e.offsetWidth / 2 - center);
      if (d < bestDist) { bestDist = d; best = i; }
    });
    if (best < 0) return false;
    state.homIdx = best;
    return true;
  }

  function pickHom(i) {
    const homs = homsAt(state.charIdx);
    if (!homs.length) return;
    state.draft[state.charIdx] = homs[Math.max(0, Math.min(i, homs.length - 1))];
    state.zone = 'chars';
    render();
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
      zone: 'sent',
      charIdx: 0,
      homIdx: 0,
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

  function selectCandidate(delta) {
    const n = state.candidates.length;
    state.selected = (state.selected + delta + n) % n;
    state.draft = [...state.candidates[state.selected]]; // 換句就重置逐字修改
  }

  // 回傳 true 表示這個按鍵已被浮窗消化（呼叫端應攔下、不要傳給網頁）
  function handleKey(key) {
    if (!state) return false;
    const zone = state.zone;

    if (key === 'Escape') {
      if (zone === 'tray') { state.zone = 'chars'; render(); }
      else hide();
      return true;
    }

    if (key === 'Enter') {
      if (zone === 'tray') pickHom(state.homIdx);
      else if (zone === 'sent') commit(state.candidates[state.selected]);
      else commit(state.draft.join(''));
      return true;
    }

    if (key === 'ArrowDown') {
      if (zone === 'sent') {
        if (state.selected < state.candidates.length - 1) selectCandidate(1);
        else { // 最後一句再往下＝進逐字區
          const k = seekChar(0, 1);
          if (k >= 0) { state.zone = 'chars'; state.charIdx = k; }
        }
      } else if (zone === 'chars' && homsAt(state.charIdx).length) {
        state.zone = 'tray';
        state.homIdx = currentHomIdx(state.charIdx);
      } else if (zone === 'tray') {
        moveHomRow(1); // 同音字：下一列
      }
      render();
      return true;
    }

    if (key === 'ArrowUp') {
      if (zone === 'sent') selectCandidate(-1);
      else if (zone === 'chars') state.zone = 'sent';
      else if (!moveHomRow(-1)) state.zone = 'chars'; // 同音字：上一列；已在第一列則收起
      render();
      return true;
    }

    if (key === 'ArrowLeft' || key === 'ArrowRight') {
      const d = key === 'ArrowRight' ? 1 : -1;
      if (zone === 'sent') { // 從句子區用左右也能進逐字區
        const k = seekChar(d > 0 ? 0 : state.draft.length - 1, d > 0 ? 1 : -1);
        if (k >= 0) { state.zone = 'chars'; state.charIdx = k; }
      } else if (zone === 'chars') {
        const k = seekChar(state.charIdx + d, d); // 跳過標點
        if (k >= 0) state.charIdx = k;
      } else {
        const n = homsAt(state.charIdx).length;
        if (n) state.homIdx = (state.homIdx + d + n) % n;
      }
      render();
      return true;
    }

    return false;
  }

  return {
    show,
    hide,
    handleKey,
    isVisible: () => host.style.display === 'block',
    contains: (t) => t === host || host.contains(t),
  };
}
