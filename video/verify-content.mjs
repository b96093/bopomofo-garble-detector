// 用產品實際的引擎驗證影片內容：node video/verify-content.mjs
// 筆記整段丟進 DetectBlock（選取轉換的整段路徑），聊天那句丟進 DetectTail（打字偵測，
// 靈敏度 4），轉回來都必須與 content.js 一字不差。離開碼 = 失敗數。
// 也驗證版本比較影片的 compare-content.js：桌面版負責的句子丟 AHK（DetectTail），
// Chrome 版負責的句子丟擴充本身的 JS 引擎（src/engine 的 detect／detectTail）。
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import vm from 'node:vm';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sandbox = { window: {} };
vm.runInNewContext(readFileSync(join(here, 'content.js'), 'utf8'), sandbox);
const C = sandbox.window.CONTENT;
vm.runInNewContext(readFileSync(join(here, 'compare-content.js'), 'utf8'), sandbox);
const K = sandbox.window.COMPARE;

const rows = [];
for (const key of ['classroom', 'meeting']) {
  const v = C[key];
  const src = [v.header, ...v.lines.map(l => l.keep ?? l.garble)].join('\r\n');
  const want = [v.header, ...v.lines.map(l => l.keep ?? l.zh)].join('\r\n');
  const preview = v.lines.find(l => l.zh).zh;
  const hits = v.lines.filter(l => l.zh).length;
  rows.push(['BLOCK', v.name, src, want, preview, String(hits)]);
}
rows.push(['CHAT', '聊天', C.chat.garble, C.chat.zh, '', '']);
rows.push(['CHAT', '版本比較：Google 文件（桌面版）', K.docs.garble, K.docs.zh, '', '']);

// 欄位裡有換行，所以紀錄用 \u001e、欄位用 \u001f 分隔
const input = join(process.env.TEMP, 'video-verify-in.txt');
writeFileSync(input, '\ufeff' + rows.map(r => r.join('\u001f')).join('\u001e'), 'utf8');

// Chrome 版的句子用擴充本身的引擎驗證：門檻同 src/content/content.js 的預設「積極」
const src = (p) => pathToFileURL(join(here, '..', 'src', p)).href;
const { loadDict } = await import(src('engine/dict.js'));
const { detect, detectTail } = await import(src('engine/detect.js'));
const dict = loadDict();
const OPTS = { threshold: 0.6, minSyllables: 1 };
let jsPass = 0, jsFail = 0;
const jsCheck = (name, got, want) => {
  if (got === want) { jsPass++; console.log(`  [OK] ${name}`); }
  else { jsFail++; console.log(`  [FAIL] ${name}\n    期望：${want}\n    實際：${got ?? '（偵測不到）'}`); }
};
jsCheck('版本比較：回信（Chrome 打字偵測）', detectTail(K.mail.garble, dict, OPTS)?.res.candidates[0], K.mail.zh);
jsCheck('版本比較：留言（Chrome 選取浮出按鈕）', detect(K.post.garble, dict, OPTS)?.candidates[0], K.post.zh);

const ahk = 'C:/Program Files/AutoHotkey/v2/AutoHotkey64.exe';
const r = spawnSync(ahk, [join(here, 'verify-content.ahk'), input], { encoding: 'utf8', timeout: 120000 });
const ahkOut = r.stdout || '';
const m = ahkOut.match(/結果：(\d+) 通過 \/ (\d+) 失敗/);
process.stdout.write(ahkOut.replace(/結果：.*\r?\n?/, ''));
if (r.error || r.status === null || !m) {
  console.error('AHK 沒有正常結束（可能跳出了錯誤對話框，請到桌面關掉它）');
  process.exit(99);
}
console.log(`結果：${+m[1] + jsPass} 通過 / ${+m[2] + jsFail} 失敗`);
process.exit(r.status + jsFail);
