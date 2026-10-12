// 用無頭 Chrome 開頁面、執行 JS、截圖。只用 Node 內建功能（WebSocket、fetch），
// 不需要 npm 安裝 Puppeteer。
//
// 錄影要連續開關上百次，所以這裡特別注意「不留東西」：
//   - 偵錯埠用 0，讓 Chrome 自己挑空埠、寫進 profile 的 DevToolsActivePort ——
//     寫死埠號可能連到上一次沒關乾淨、還佔著那個埠的 Chrome。
//   - 關閉時先用 CDP 的 Browser.close 正常結束（連同 renderer、GPU 子行程）；
//     沒結束才 taskkill /T /F 整棵行程樹。只 kill 主行程的話，子行程還握著
//     profile 裡的檔案，暫存資料夾就刪不掉。
//   - 從啟動到回傳之間任何一步出錯，都先清乾淨再丟出錯誤。
//   - 每個 CDP 請求有逾時；連線斷掉時，等待中的請求全部失敗，不會無限卡住。
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const SEND_TIMEOUT = 30000;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// 開一條 WebSocket，回傳 send(method, params)；逾時或連線斷掉都會讓請求失敗
async function connect(url) {
  const ws = new WebSocket(url);
  await new Promise((res, rej) => {
    ws.addEventListener('open', res, { once: true });
    ws.addEventListener('error', () => rej(new Error('連不上 Chrome 的偵錯連線：' + url)), { once: true });
  });
  let id = 0, dead = null;
  const pending = new Map(), events = [];
  const failAll = (why) => {
    dead = dead || why;
    for (const p of pending.values()) { clearTimeout(p.timer); p.rej(new Error(why)); }
    pending.clear();
  };
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    const p = m.id && pending.get(m.id);
    if (p) { clearTimeout(p.timer); pending.delete(m.id); m.error ? p.rej(new Error(`${p.method}：${m.error.message}`)) : p.res(m.result); }
    else events.push(m);
  });
  ws.addEventListener('close', () => failAll('Chrome 的偵錯連線已關閉'));
  ws.addEventListener('error', () => failAll('Chrome 的偵錯連線發生錯誤'));
  const send = (method, params = {}) => new Promise((res, rej) => {
    if (dead) return rej(new Error(`${method}：${dead}`));
    const i = ++id;
    const timer = setTimeout(() => { pending.delete(i); rej(new Error(`${method}：${SEND_TIMEOUT / 1000} 秒沒有回應`)); }, SEND_TIMEOUT);
    pending.set(i, { res, rej, timer, method });
    ws.send(JSON.stringify({ id: i, method, params }));
  });
  const close = () => { try { ws.close(); } catch {} };
  return { send, events, close };
}

export async function openPage(htmlPath, query = '') {
  const profile = mkdtempSync(join(tmpdir(), 'bgd-video-'));
  const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1080,1920', 'about:blank'],
    { stdio: 'ignore' });
  let spawnError = null;
  const exited = new Promise(r => {
    chrome.once('exit', r);
    chrome.once('error', (e) => { spawnError = e; r(); });
  });
  const running = () => !spawnError && chrome.exitCode === null && chrome.signalCode === null;
  let port = null, page = null, closed = false;

  const cleanup = async () => {
    if (closed) return;
    closed = true;
    page?.close();
    if (running() && port) {
      // 正常關閉：Browser.close 要送到「瀏覽器」那條連線，不是分頁的連線
      try {
        const ver = await (await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(3000) })).json();
        const b = await connect(ver.webSocketDebuggerUrl);
        await Promise.race([b.send('Browser.close').catch(() => {}), sleep(3000)]);
        b.close();
      } catch { /* 正常關不掉就走下面的強制結束 */ }
      await Promise.race([exited, sleep(5000)]);
    }
    if (running()) {
      spawnSync('taskkill', ['/PID', String(chrome.pid), '/T', '/F'], { stdio: 'ignore' });
      await Promise.race([exited, sleep(5000)]);
    }
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 }); }
    catch (e) { console.warn('暫存資料夾刪不掉（不影響成品）：', profile, e.message); }
  };

  try {
    // Chrome 啟動後把實際的偵錯埠寫在 profile 裡的 DevToolsActivePort 第一行
    for (let i = 0; i < 100 && !port; i++) {
      if (spawnError) throw new Error(`無法啟動 Chrome（${CHROME}）：${spawnError.message}`);
      if (!running()) throw new Error(`Chrome 啟動後立刻結束（離開碼 ${chrome.exitCode}）`);
      try {
        const n = parseInt(readFileSync(join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0], 10);
        if (n > 0) port = n;
      } catch { /* 還沒寫出來 */ }
      if (!port) await sleep(100);
    }
    if (!port) throw new Error('Chrome 10 秒內沒有開好偵錯埠（找不到 DevToolsActivePort）');

    let target;
    for (let i = 0; i < 50 && !target; i++) {
      try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page'); }
      catch { /* 還沒好 */ }
      if (!target) await sleep(100);
    }
    if (!target) throw new Error('Chrome 沒有開出分頁');

    page = await connect(target.webSocketDebuggerUrl);
    const { send, events } = page;
    await send('Page.enable');
    await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
    const nav = await send('Page.navigate', { url: pathToFileURL(htmlPath).href + query });
    if (nav.errorText) throw new Error(`開不了頁面 ${htmlPath}：${nav.errorText}`);
    for (let i = 0; i < 100 && !events.some(e => e.method === 'Page.loadEventFired'); i++) await sleep(100);
    if (!events.some(e => e.method === 'Page.loadEventFired')) throw new Error(`頁面 10 秒內沒有載入完成：${htmlPath}`);

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
    return { evaluate, screenshot, close: cleanup };
  } catch (e) {
    await cleanup();
    throw e;
  }
}
