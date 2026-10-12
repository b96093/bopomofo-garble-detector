// 在關鍵時間點核對畫面的邏輯狀態，與 content.js、popup.js 一致：node video/check.mjs
// 離開碼 = 失敗數。核對的是 render(t) 之後 state() 回傳的內容 —— 跟畫面用的是同一份資料。
import { openPage } from './cdp.mjs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { inflateSync } from 'node:zlib';

// 解開 Chrome 截圖的 PNG（8 位元、RGB/RGBA、不交錯），回傳 { w, h, at(x, y) → [r, g, b] }
function decodePng(buf) {
  let p = 8, w, h, ch;
  const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p), type = buf.toString('ascii', p + 4, p + 8), d = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') {
      w = d.readUInt32BE(0); h = d.readUInt32BE(4);
      if (d[8] !== 8 || d[12] !== 0 || ![2, 6].includes(d[9])) throw new Error('不支援的 PNG 格式');
      ch = d[9] === 6 ? 4 : 3;
    } else if (type === 'IDAT') idat.push(d);
    p += 12 + len;
  }
  const raw = inflateSync(Buffer.concat(idat)), stride = w * ch, px = new Uint8Array(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], src = y * (stride + 1) + 1, o = y * stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= ch ? px[o + i - ch] : 0, b = y ? px[o + i - stride] : 0, c = (y && i >= ch) ? px[o + i - stride - ch] : 0;
      const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c);
      px[o + i] = (raw[src + i] + [0, a, b, (a + b) >> 1, (pa <= pb && pa <= pc) ? a : pb <= pc ? b : c][f]) & 255;
    }
  }
  return { w, h, at: (x, y) => [...px.subarray((y * w + x) * ch, (y * w + x) * ch + 3)] };
}

const scene = join(dirname(fileURLToPath(import.meta.url)), 'scene.html');
let pass = 0, fail = 0;
const eq = (name, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  ok ? pass++ : fail++;
  console.log(`  [${ok ? 'OK' : 'FAIL'}] ${name}` + (ok ? '' : `\n      期望 ${JSON.stringify(want)}\n      實際 ${JSON.stringify(got)}`));
};

const versions = ['classroom', 'meeting'];
for (const v of versions) {
  const page = await openPage(scene, `?v=${v}`);
  try {
    const C = await page.evaluate(`CONTENT.${v}`);
    const chat = await page.evaluate('CONTENT.chat');
    const at = (t) => page.evaluate(`(render(${t}), state())`);
    console.log(`── ${C.name} ──`);
    const typedRows = [C.header, ...C.lines.map(l => l.keep ?? l.garble)];
    const zhRows = [C.header, ...C.lines.map(l => l.keep ?? l.zh)];
    const empty = typedRows.map(() => '');
    const hits = C.lines.filter(l => l.zh).length;

    let s = await at(0);
    eq('0 秒：筆記是空的', s.notes, empty);
    eq('0 秒：時鐘', s.clock, '10:02');
    eq('0 秒：投影片頁碼', s.page, '7');
    s = await at(8.6);
    eq('8.6 秒：亂碼全部打完', s.notes, typedRows);
    eq('8.6 秒：時鐘', s.clock, '10:48');
    eq('8.6 秒：結束頁', s.slideTitle, C.endPage);
    s = await at(12.5);
    eq('12.5 秒：浮窗文字', s.icon, `→ ${C.lines.find(l => l.zh).zh}　還原 ${hits} 行`);
    s = await at(16);
    eq('16 秒：整段還原', s.notes, zhRows);
    eq('16 秒：標出沒被動到的行', s.marked, C.lines.filter(l => l.keep).map(l => l.keep));
    s = await at(22);
    eq('22 秒：輸入框是亂碼', s.chatInput, chat.garble);
    eq('22 秒：候選窗開著', s.popup, true);
    s = await at(24.5);
    eq('24.5 秒：已送出中文', s.sent, [chat.zh]);
    eq('24.5 秒：輸入框清空', s.chatInput, '');
    s = await at(29.95);
    eq('29.95 秒：接回開頭（筆記是空的）', s.notes, empty);
    eq('29.95 秒：接回開頭（時鐘）', s.clock, '10:02');
    eq('候選窗第一個候選＝聊天要還原的句子',
       await page.evaluate("POPUP.ops.find(o => o.t === 'text' && o.pt === 13).s"), chat.zh);

    // 圖檔路徑錯了，cdp.mjs 的等待會被 onerror 放行，所以在這裡另外確認每張圖都真的有載入
    eq('所有圖片都載入成功', await page.evaluate('[...document.images].every(i => i.naturalWidth > 0)'), true);

    // 段落交界：該消失的東西要真的消失
    const look = (t, expr) => page.evaluate(`(render(${t}), ${expr})`);
    const opacity = (id) => `parseFloat(getComputedStyle(document.getElementById('${id}')).opacity)`;
    eq('12.5 秒：浮窗看得到', await look(12.5, `${opacity('icon')} > 0.5`), true);
    eq('12.95 秒：按 Enter 後浮窗消失', await look(12.95, `${opacity('icon')} > 0.5`), false);
    eq('23.05 秒：按 Enter 後候選窗消失', (await at(23.05)).popup, false);
    eq('29.95 秒：聊天藏起來', await look(29.95, "getComputedStyle(document.getElementById('chat')).visibility"), 'hidden');
    eq('29.95 秒：候選窗、浮窗透明度 0', await look(29.95, `[${opacity('popup')}, ${opacity('icon')}]`), [0, 0]);
    eq('29.95 秒：片尾已淡出（< 0.05）', await look(29.95, `${opacity('endCard')} < 0.05`), true);

    eq('26.0 秒：大字卡是「不亂動」', await look(26.0, "document.getElementById('bigWord').textContent"), '不亂動');
    eq('27.0 秒：大字卡已清空', await look(27.0, "document.getElementById('bigWord').textContent"), '');

    eq('候選窗每一段文字都有畫出來（缺少的列在這裡）', await page.evaluate(`
      POPUP.ops.filter(o => o.t === 'text')
        .filter(o => ![...document.querySelectorAll('#popup div')].some(d => d.textContent === o.s))
        .map(o => o.s)`), []);

    // Logo 拆成三塊飛入：拼好時要跟原圖逐像素相同（三塊合起來蓋滿、沒有重疊加深），
    // 而且每條裁切邊（不在圖框上的邊）兩側 2px 內都只能是空白 —— 邊切過筆畫的話，
    // 飛行中那一塊會缺角，或帶著別塊的殘片。
    // 只留片尾那一層比對：移到畫面外的筆記卡會讓 Chrome 改用另一種合成路徑，
    // multiply 的結果在鉛筆網點上差幾個色階（肉眼看不出），跟裁切是否正確無關
    await page.evaluate(`[...document.getElementById('stage').children].forEach(el => { if (el.id !== 'endCard') el.style.display = 'none'; })`);
    await page.evaluate('render(28.9)');
    const assembled = decodePng(await page.screenshot());
    const geo = await page.evaluate(`(() => {
      const parts = ['logoJ', 'logoPen', 'logoA'].map(id => document.getElementById(id));
      const r = parts[0].getBoundingClientRect();
      const polys = parts.map(el => getComputedStyle(el).clipPath.replace(/^polygon\\(|\\)$/g, '').split(',')
        .map(pt => pt.trim().split(/\\s+/).map((v, i) => v.endsWith('%') ? parseFloat(v) / 100 * (i ? r.height : r.width) : parseFloat(v))));
      const ref = parts[0].cloneNode();
      ref.id = 'logoRef';
      ref.style.clipPath = 'none';
      parts.forEach(el => { el.style.visibility = 'hidden'; });
      parts[0].after(ref);
      return { x: r.left, y: r.top, w: r.width, h: r.height, polys };
    })()`);
    const original = decodePng(await page.screenshot());
    await page.evaluate(`document.getElementById('logoRef').remove();
      ['logoJ', 'logoPen', 'logoA'].forEach(id => { document.getElementById(id).style.visibility = ''; });
      [...document.getElementById('stage').children].forEach(el => { el.style.display = ''; })`);
    let diffPx = 0;
    for (let y = 0; y < original.h; y++) for (let x = 0; x < original.w; x++) {
      const a = assembled.at(x, y), b = original.at(x, y);
      if (a[0] !== b[0] || a[1] !== b[1] || a[2] !== b[2]) diffPx++;
    }
    eq('28.9 秒：三塊 Logo 拼起來與未裁切的原圖逐像素相同（不同的像素數）', diffPx, 0);
    const bg = original.at(Math.round(geo.x) + 2, Math.round(geo.y) + 2);   // Logo 底下的顏色（白卡）
    const onBorder = (a, b) => [0, 1].some(i => Math.abs(a[i] - b[i]) < 0.5 && (Math.abs(a[i]) < 0.5 || Math.abs(a[i] - (i ? geo.h : geo.w)) < 0.5));
    const cuts = [];
    geo.polys.forEach((poly, k) => poly.forEach((a, i) => {
      const b = poly[(i + 1) % poly.length];
      if (onBorder(a, b)) return;
      const len = Math.hypot(b[0] - a[0], b[1] - a[1]), nx = -(b[1] - a[1]) / len, ny = (b[0] - a[0]) / len;
      let bad = 0;
      for (let s = 0; s <= len; s++) for (let o = -2; o <= 2; o++) {
        const x = Math.round(geo.x + a[0] + (b[0] - a[0]) * s / len + nx * o), y = Math.round(geo.y + a[1] + (b[1] - a[1]) * s / len + ny * o);
        if (original.at(x, y).some((c, j) => Math.abs(c - bg[j]) > 2)) bad++;
      }
      if (bad) cuts.push(`${['ㄐ', '鉛筆', 'A'][k]} 第 ${i + 1} 條邊：${bad} 點有筆畫`);
    }));
    eq('Logo 每條裁切邊都只經過空白（切到筆畫的邊列在這裡）', cuts, []);

    eq('打字聲的時間都在 [0, 30) 之內（超出的列在這裡）',
       await page.evaluate('keyHits().filter(h => !(h.t >= 0 && h.t < 30)).map(h => h.t)'), []);

    // 同一個 t 永遠畫出同一格：900 格依序畫一次、再用固定種子打亂順序畫一次，逐格比對
    const diffs = await page.evaluate(`(() => {
      const els = () => [...document.querySelectorAll('#stage [id], #lines span, #keys .key')];
      const sig = () => els().map(el => {
        const c = getComputedStyle(el);
        return [el.id, c.opacity, c.transform, c.visibility, c.top, c.backgroundColor, el.textContent].join('|');
      }).join('\\n');
      const N = 900, first = [];
      for (let i = 0; i < N; i++) { render(i / 30); first[i] = sig(); }
      const order = [...Array(N).keys()];
      let seed = 20261012;
      const rnd = () => (seed = (Math.imul(seed, 1103515245) + 12345) >>> 0) / 4294967296;
      for (let i = N - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
      const bad = [];
      for (const i of order) { render(i / 30); if (sig() !== first[i]) bad.push(i); }
      return bad.sort((a, b) => a - b).slice(0, 20);
    })()`);
    eq('900 格依序與打亂順序畫出來完全相同（不同的格數列在這裡，最多 20 格）', diffs, []);
  } finally {
    await page.close();
  }
}
console.log(`\n結果：${pass} 通過 / ${fail} 失敗`);
process.exit(fail);
