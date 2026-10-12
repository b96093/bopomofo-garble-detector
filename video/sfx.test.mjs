// node video/sfx.test.mjs
import assert from 'node:assert/strict';
import { keyTrack } from './sfx.mjs';

const wav = keyTrack([{ t: 1.0, gain: 1 }], 2, 8000);
assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
assert.equal(wav.toString('ascii', 8, 12), 'WAVE');
assert.equal(wav.length, 44 + 2 * 8000 * 2, '2 秒、8kHz、16-bit 單聲道');

const sample = (sec) => Math.abs(wav.readInt16LE(44 + 2 * Math.round(sec * 8000)));
let peak = 0;
for (let i = 0; i < 200; i++) peak = Math.max(peak, sample(1.0 + i / 8000));
assert.ok(peak > 1000, '按鍵的時間點要有聲音');
assert.equal(sample(0.5), 0, '沒有按鍵的地方要安靜');

assert.ok(wav.equals(keyTrack([{ t: 1.0, gain: 1 }], 2, 8000)), '同樣的輸入要產生一模一樣的檔案');
console.log('sfx：全部通過');
