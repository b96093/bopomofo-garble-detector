// 用產品實際的引擎驗證影片內容：node video/verify-content.mjs
// 筆記整段丟進 DetectBlock（選取轉換的整段路徑），聊天那句丟進 DetectTail（打字偵測，
// 靈敏度 4），轉回來都必須與 content.js 一字不差。離開碼 = 失敗數。
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sandbox = { window: {} };
vm.runInNewContext(readFileSync(join(here, 'content.js'), 'utf8'), sandbox);
const C = sandbox.window.CONTENT;

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

// 欄位裡有換行，所以紀錄用 \u001e、欄位用 \u001f 分隔
const input = join(process.env.TEMP, 'video-verify-in.txt');
writeFileSync(input, '\ufeff' + rows.map(r => r.join('\u001f')).join('\u001e'), 'utf8');

const ahk = 'C:/Program Files/AutoHotkey/v2/AutoHotkey64.exe';
const r = spawnSync(ahk, [join(here, 'verify-content.ahk'), input], { encoding: 'utf8', timeout: 120000 });
process.stdout.write(r.stdout || '');
if (r.error || r.status === null) {
  console.error('AHK 沒有正常結束（可能跳出了錯誤對話框，請到桌面關掉它）');
  process.exit(99);
}
process.exit(r.status);
