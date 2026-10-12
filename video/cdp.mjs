// 用無頭 Chrome 開頁面、執行 JS、截圖。只用 Node 內建功能（WebSocket、fetch），
// 不需要 npm 安裝 Puppeteer。
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

export async function openPage(htmlPath, query = '', port = 9333) {
  const profile = mkdtempSync(join(tmpdir(), 'bgd-video-'));
  const chrome = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1080,1920', 'about:blank'],
    { stdio: 'ignore' });
  const exited = new Promise(r => chrome.once('exit', r));
  let target;
  for (let i = 0; i < 75 && !target; i++) {
    try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page'); }
    catch { /* Chrome 還沒起來 */ }
    if (!target) await sleep(200);
  }
  if (!target) { chrome.kill(); throw new Error('Chrome 沒有啟動'); }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.addEventListener('open', res, { once: true }); ws.addEventListener('error', rej, { once: true }); });
  let id = 0;
  const pending = new Map(), events = [];
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } else events.push(m);
  });
  const send = (method, params = {}) => new Promise((res, rej) => {
    const i = ++id;
    pending.set(i, (m) => m.error ? rej(new Error(`${method}：${m.error.message}`)) : res(m.result));
    ws.send(JSON.stringify({ id: i, method, params }));
  });

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: pathToFileURL(htmlPath).href + query });
  for (let i = 0; i < 100 && !events.some(e => e.method === 'Page.loadEventFired'); i++) await sleep(100);

  const evaluate = async (expr) => {
    const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error('頁面執行錯誤：' + (r.exceptionDetails.exception?.description ?? r.exceptionDetails.text));
    return r.result.value;
  };
  await evaluate('document.fonts.ready.then(() => true)');
  // 等圖片（Logo、圖示）載入完，否則前幾格會缺圖
  await evaluate('Promise.all([...document.images].map(i => i.complete ? 1 : new Promise(r => { i.onload = i.onerror = r; }))).then(() => true)');

  const screenshot = async () => Buffer.from((await send('Page.captureScreenshot',
    { format: 'png', clip: { x: 0, y: 0, width: 1080, height: 1920, scale: 1 } })).data, 'base64');
  // 先等 Chrome 真的結束、放開檔案，再刪暫存的 profile 資料夾。
  // 直接 kill 之後馬上刪會失敗（Chrome 還握著檔案），每開一次頁面就在 %TEMP% 留下一個資料夾。
  const close = async () => {
    try { ws.close(); } catch {}
    chrome.kill();
    await Promise.race([exited, sleep(5000)]);
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); }
    catch (e) { console.warn('暫存資料夾刪不掉（不影響成品）：', profile, e.message); }
  };
  return { evaluate, screenshot, close };
}
