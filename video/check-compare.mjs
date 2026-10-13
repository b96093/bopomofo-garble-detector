// 核對版本比較影片各時間點的畫面狀態：node video/check-compare.mjs
// 核對的是 render(t) 之後 state() 從 DOM 讀出的內容。離開碼 = 失敗數。
import { openPage } from './cdp.mjs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
let pass = 0, fail = 0;
const eq = (name, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  ok ? pass++ : fail++;
  console.log(`  [${ok ? 'OK' : 'FAIL'}] ${name}` + (ok ? '' : `\n      期望 ${JSON.stringify(want)}\n      實際 ${JSON.stringify(got)}`));
};

const page = await openPage(join(here, 'compare.html'), '', { width: 1080, height: 1080 });
try {
  const K = await page.evaluate('COMPARE');
  const at = (t) => page.evaluate(`(render(${t}), state())`);
  const T = await page.evaluate('TIMES');
  const [S1, S2, S3, S4, S5] = T.s;

  eq('所有圖片都載入成功', await page.evaluate('[...document.images].every(i => i.naturalWidth > 0)'), true);

  let s = await at(1);
  eq('1 秒：標題', s.title, K.title);
  eq('1 秒：兩盞燈都暗', [s.lampC, s.lampD], [false, false]);
  eq('2.3 秒：Chrome 版的燈閃一下', (await at(2.3)).lampC, true);
  eq('3.1 秒：桌面版的燈閃一下', (await at(3.1)).lampD, true);
  s = await at(4.5);
  eq('4.5 秒：說明燈的意思', s.caption, K.legend);
  eq('4.5 秒：燈都暗', [s.lampC, s.lampD], [false, false]);

  s = await at(T.sum + 5);
  eq('總結：兩盞燈都亮', [s.lampC, s.lampD], [true, true]);
  eq('總結：字卡', s.caption, K.captions[5]);
  eq('總結：表格', s.summary, [K.summary.head, ...K.summary.rows]);
  eq('總結：設定提醒', s.tip, K.summary.tip);

  for (const [i, sN] of T.s.entries()) {
    s = await at(sN + 2);
    eq(`第 ${i + 1} 站：時鐘`, s.clock, K.clocks[i]);
    eq(`第 ${i + 1} 站：字卡`, s.caption, K.captions[i]);
  }

  // 字卡至少停留到讀得完：每秒 6 個字
  eq('每張字卡的停留時間都夠讀完（不夠的列在這裡）', await page.evaluate(`
    CAPS.filter(([a, b, text]) => b - a < [...text].length / 6).map(([a, b, text]) => text)`), []);

  eq('最後一格已淡出（< 0.05）', await page.evaluate(`(render(${T.end - 1 / 30}), parseFloat(getComputedStyle(document.getElementById('fade')).opacity) > 0.95)`), true);

  eq('打字聲的時間都在影片長度內（超出的列在這裡）',
     await page.evaluate(`keyHits().filter(h => !(h.t >= 0 && h.t < ${T.end})).map(h => h.t)`), []);

  // 彈出物（候選窗、小按鈕、浮窗）出現時都不能超出畫面
  const bad = await page.evaluate(`(() => {
    const out = [];
    for (let i = 0; i < ${T.end * 30}; i += 3) { render(i / 30); const o = state().overflow; if (o.length) out.push((i / 30).toFixed(1) + ':' + o.join(',')); }
    return out.slice(0, 10); })()`);
  eq('彈出物都在畫面內（超出的時間點列在這裡）', bad, []);

  // 同一個 t 永遠畫出同一格：依序畫一次、再用固定種子打亂順序畫一次，逐格比對
  const diffs = await page.evaluate(`(() => {
    const sig = () => JSON.stringify(state()) + [...document.querySelectorAll('#stage [id]')].map(el => {
      const c = getComputedStyle(el); return [el.id, c.opacity, c.transform, c.visibility, c.left, c.top].join('|'); }).join('\\n');
    const N = ${T.end * 30}, first = [];
    for (let i = 0; i < N; i++) { render(i / 30); first[i] = sig(); }
    const order = [...Array(N).keys()];
    let seed = 20261012;
    const rnd = () => (seed = (Math.imul(seed, 1103515245) + 12345) >>> 0) / 4294967296;
    for (let i = N - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
    const bad = [];
    for (const i of order) { render(i / 30); if (sig() !== first[i]) bad.push(i); }
    return bad.sort((a, b) => a - b).slice(0, 20); })()`);
  eq('全部影格依序與打亂順序畫出來完全相同（不同的格數列在這裡，最多 20 格）', diffs, []);
} finally {
  await page.close();
}
console.log(`\n結果：${pass} 通過 / ${fail} 失敗`);
process.exit(fail);
