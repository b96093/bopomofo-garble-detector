// 輸出影片：node video/render.mjs classroom|meeting|compare
// 只輸出幾張靜態畫面檢查：node video/render.mjs compare --stills 1,5,9,12.5
import { openPage } from './cdp.mjs';
import { keyTrack } from './sfx.mjs';
import { mkdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
// 每支影片：哪一頁、網址參數、尺寸、長度、成品名稱（在頁面裡求值的運算式）
const TARGETS = {
  classroom: { page: 'scene.html', query: '?v=classroom', width: 1080, height: 1920, seconds: 30, name: 'CONTENT.classroom.name' },
  meeting:   { page: 'scene.html', query: '?v=meeting',   width: 1080, height: 1920, seconds: 30, name: 'CONTENT.meeting.name' },
  compare:   { page: 'compare.html', query: '',           width: 1080, height: 1080, seconds: 90, name: "'版本比較'" },
};
const usage = () => {
  console.error('用法：node video/render.mjs classroom|meeting|compare [--stills 1,5,9]');
  process.exit(2);
};
const v = process.argv[2];
const target = TARGETS[v];
if (!target) usage();
const si = process.argv.indexOf('--stills');
let stills = null;
if (si > 0) {
  const arg = process.argv[si + 1];
  if (!arg) usage();
  stills = arg.split(',').map(s => (s.trim() === '' ? NaN : Number(s)));
  if (stills.some(t => !Number.isFinite(t))) usage();
}
// 輸出影片才需要 ffmpeg：開 Chrome、錄影格之前先找，找不到就別白錄
let ffmpeg = null;
if (!stills) {
  try { ffmpeg = execFileSync('where.exe', ['ffmpeg'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split(/\r?\n/)[0].trim(); }
  catch { /* where.exe 找不到時離開碼非 0 */ }
  if (!ffmpeg) {
    console.error('找不到 ffmpeg，請先安裝並加入 PATH');
    process.exit(1);
  }
}
const out = join(root, 'dist', 'video');
mkdirSync(out, { recursive: true });

const page = await openPage(join(here, target.page), target.query, { width: target.width, height: target.height });
try {
  const name = await page.evaluate(target.name);
  if (stills) {
    const dir = join(out, `stills-${name}`);
    mkdirSync(dir, { recursive: true });
    for (const t of stills) {
      await page.evaluate(`render(${t})`);
      writeFileSync(join(dir, `${t}.png`), await page.screenshot());
    }
    console.log('靜態畫面：', dir);
  } else {
    const FPS = 30, N = target.seconds * FPS;
    const frames = mkdtempSync(join(tmpdir(), 'bgd-frames-'));
    try {
      for (let i = 0; i < N; i++) {
        await page.evaluate(`render(${i / FPS})`);
        writeFileSync(join(frames, String(i).padStart(4, '0') + '.png'), await page.screenshot());
        if (i % 90 === 0) console.log(`  ${i}/${N}`);
      }
      const wav = join(frames, 'keys.wav');
      writeFileSync(wav, keyTrack(await page.evaluate('keyHits()'), target.seconds));
      const mp4 = join(out, `注音亂碼偵測-${name}.mp4`);
      const r = spawnSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error',
        '-framerate', String(FPS), '-i', join(frames, '%04d.png'), '-i', wav,
        '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', mp4], { stdio: 'inherit' });
      if (r.status !== 0) throw new Error('ffmpeg 失敗' + (r.error ? '：' + r.error.message : ''));
      console.log('完成：', mp4);
    } finally {
      rmSync(frames, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
    }
  }
} finally {
  await page.close();
}
