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

// 緩衝區最後 0.01 秒的按鍵：聲音比剩下的長度還長，不能丟錯或寫出界
const tail = keyTrack([{ t: 2 - 0.01, gain: 1 }], 2, 8000);
assert.equal(tail.length, 44 + 2 * 8000 * 2, '結尾的按鍵不改變檔案長度');
let tailPeak = 0;
for (let i = Math.round((2 - 0.01) * 8000); i < 2 * 8000; i++) tailPeak = Math.max(tailPeak, Math.abs(tail.readInt16LE(44 + 2 * i)));
assert.ok(tailPeak > 1000, '結尾的按鍵也要有聲音');

// 兩下 gain 1 疊在同一時間：每個樣本都要在 16-bit 範圍內（writeInt16LE 超出範圍會丟錯）。
// 目前兩下相加的峰值約 13000，還碰不到 keyTrack 的削峰。
const both = keyTrack([{ t: 1.0, gain: 1 }, { t: 1.0, gain: 1 }], 2, 8000);
for (let i = 0; i < 2 * 8000; i++) {
  const v = both.readInt16LE(44 + 2 * i);
  assert.ok(v >= -32768 && v <= 32767, `第 ${i} 個樣本超出 16-bit 範圍`);
}
console.log('sfx：全部通過');
