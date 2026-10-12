// 輸出影片：node video/render.mjs classroom|meeting
// 只輸出幾張靜態畫面檢查：node video/render.mjs classroom --stills 1,5,9,12.5
import { openPage } from './cdp.mjs';
import { keyTrack } from './sfx.mjs';
import { mkdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const v = process.argv[2];
if (!['classroom', 'meeting'].includes(v)) {
  console.error('用法：node video/render.mjs classroom|meeting [--stills 1,5,9]');
  process.exit(2);
}
const si = process.argv.indexOf('--stills');
const stills = si > 0 ? process.argv[si + 1].split(',').map(Number) : null;
const out = join(root, 'dist', 'video');
mkdirSync(out, { recursive: true });

const page = await openPage(join(here, 'scene.html'), `?v=${v}`);
try {
  const name = await page.evaluate(`CONTENT.${v}.name`);
  if (stills) {
    const dir = join(out, `stills-${name}`);
    mkdirSync(dir, { recursive: true });
    for (const t of stills) {
      await page.evaluate(`render(${t})`);
      writeFileSync(join(dir, `${t}.png`), await page.screenshot());
    }
    console.log('靜態畫面：', dir);
  } else {
    const FPS = 30, N = 30 * FPS;
    const frames = mkdtempSync(join(tmpdir(), 'bgd-frames-'));
    for (let i = 0; i < N; i++) {
      await page.evaluate(`render(${i / FPS})`);
      writeFileSync(join(frames, String(i).padStart(4, '0') + '.png'), await page.screenshot());
      if (i % 90 === 0) console.log(`  ${i}/${N}`);
    }
    const wav = join(frames, 'keys.wav');
    writeFileSync(wav, keyTrack(await page.evaluate('keyHits()')));
    const ffmpeg = execFileSync('where.exe', ['ffmpeg'], { encoding: 'utf8' }).split(/\r?\n/)[0].trim();
    const mp4 = join(out, `注音亂碼偵測-${name}.mp4`);
    const r = spawnSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error',
      '-framerate', String(FPS), '-i', join(frames, '%04d.png'), '-i', wav,
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', mp4], { stdio: 'inherit' });
    rmSync(frames, { recursive: true, force: true });
    if (r.status !== 0) throw new Error('ffmpeg 失敗');
    console.log('完成：', mp4);
  }
} finally {
  await page.close();
}
