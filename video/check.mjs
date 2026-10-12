// 在關鍵時間點核對畫面的邏輯狀態，與 content.js、popup.js 一致：node video/check.mjs
// 離開碼 = 失敗數。核對的是 render(t) 之後 state() 回傳的內容 —— 跟畫面用的是同一份資料。
import { openPage } from './cdp.mjs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

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
  } finally {
    await page.close();
  }
}
console.log(`\n結果：${pass} 通過 / ${fail} 失敗`);
process.exit(fail);
