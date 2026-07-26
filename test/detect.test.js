import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadDict } from '../src/engine/dict.js';
import { detect, detectTail } from '../src/engine/detect.js';

const dict = loadDict();

test('注音亂碼：回傳候選', () => {
  const r = detect('ji394t au04', dict);
  assert.ok(r);
  assert.ok(r.candidates.length >= 1);
  assert.ok(r.candidates[0].startsWith('我愛吃'));
});

test('真英文句子：不觸發（回傳 null）', () => {
  assert.equal(detect('the cat sat', dict), null);
});

test('常見英文單字：不觸發', () => {
  assert.equal(detect('hello', dict), null);
});

test('空字串：不觸發', () => {
  assert.equal(detect('', dict), null);
});

test('句中標點：前後兩段一起轉，標點原樣保留', () => {
  const r = detect('su35 2l4a8 ?ji394su3', dict);
  assert.ok(r);
  assert.equal(r.candidates[0], '你知道嗎?我愛你');
});

test('標點情境：syllables 與輸出字一一對應，標點位置為 null', () => {
  const r = detect('su35 2l4a8 ?ji394su3', dict);
  const best = r.candidates[0];
  assert.equal(r.syllables.length, [...best].length);
  assert.equal(r.syllables[[...best].indexOf('?')], null); // 標點不可換字
  assert.equal(r.syllables[0], 'ㄋㄧˇ');                    // 首字對到「你」的注音
});

test('只有標點：不觸發', () => {
  assert.equal(detect('???', dict), null);
});

test('全形中文標點（頓號、逗號）：不中斷，原樣保留', () => {
  const r = detect('ji394su3、su35 2l4a8', dict);
  assert.ok(r);
  assert.ok(r.candidates[0].includes('、'), '應保留頓號');
  assert.equal(r.candidates[0], '我愛你、你知道嗎');
});

test('全形標點位置的 syllables 為 null', () => {
  const r = detect('ji394su3、su35 2l4a8', dict);
  const best = [...r.candidates[0]];
  assert.equal(r.syllables[best.indexOf('、')], null);
  assert.equal(r.syllables.length, best.length);
});

test('落單的聲調數字＝使用者要打的數字，原樣保留', () => {
  const r = detect('bj6eji3a933ek7sk', dict);
  assert.ok(r);
  assert.equal(r.candidates[0], '如果買3個呢');
});

test('數字位置的 syllables 為 null（不可換同音字）', () => {
  const r = detect('bj6eji3a933ek7sk', dict);
  const best = [...r.candidates[0]];
  assert.equal(r.syllables[best.indexOf('3')], null);
  assert.equal(r.syllables.length, best.length);
});

test('注音符號鍵上的數字：音節查無時自動改判為數字（買N個，0-9）', () => {
  for (let n = 0; n <= 9; n++) {
    const r = detect('a93' + n + 'ek7', dict);
    assert.ok(r, `買${n}個 應被偵測`);
    assert.equal(r.candidates[0], `買${n}個`);
  }
});

test('長句混合數字與標點', () => {
  const r = detect('ji3u/ e9 3wu0 1j4vu3w.6?c96g42wu0', dict);
  assert.ok(r);
  assert.equal(r.candidates[0], '我應該3天不洗頭?還是2天');
});

test('數字修正不會讓英文誤判', () => {
  assert.equal(detect('abc123', dict), null);
  assert.equal(detect('r2d2', dict), null);
});

test('手動觸發（manual）：跳過常見英文那道關卡', () => {
  // 'up' 在常見英文清單裡（ㄧㄣ 是合法音節），自動偵測會放行不理
  assert.equal(detect('up', dict, { minSyllables: 1 }), null);
  // 但使用者主動選取要求轉換時，應該給出結果
  const r = detect('up', dict, { manual: true, minSyllables: 1, threshold: 0.5 });
  assert.ok(r, 'manual 模式應轉換');
  assert.equal(r.candidates[0], '因');
});

test('手動模式不影響自動偵測的既有行為', () => {
  assert.equal(detect('the cat sat', dict), null);
  assert.equal(detect('hello', dict), null);
  assert.equal(detect('ji394t au04', dict).candidates[0], '我愛吃面');
});

test('detectTail：前面夾雜無法辨識的內容時，仍偵測得到後面的新句子', () => {
  const input = 'IEIEI SU3W8 A8 EP JI3D9 J06VUL4A8'; // IEIEI = ㄛㄍㄛㄍㄛ，不合法
  assert.equal(detect(input, dict), null, '整段判定應失敗');
  const hit = detectTail(input, dict);
  assert.ok(hit, '應退到可辨識的尾段');
  assert.equal(hit.offset, 6, 'offset 應指向 SU3W8 的位置');
  assert.equal(hit.res.candidates[0], '你他嗎跟我開玩笑嗎');
  assert.equal(input.slice(hit.offset), 'SU3W8 A8 EP JI3D9 J06VUL4A8');
});

test('detectTail：整段本來就可辨識時，offset 為 0', () => {
  const hit = detectTail('ji394t au04', dict);
  assert.equal(hit.offset, 0);
  assert.equal(hit.res.candidates[0], '我愛吃面');
});

test('detectTail：真英文仍然不觸發', () => {
  assert.equal(detectTail('the cat sat on the mat', dict), null);
  assert.equal(detectTail('please review this document', dict), null);
});

test('注音打反順序：依結構歸位（跟注音輸入法一樣）', () => {
  // uv;3 = ㄧㄒㄤˇ（打反）→ 歸位成 ㄒㄧㄤˇ = 想
  assert.equal(detect('ji3uv;3t z04', dict).candidates[0], '我想吃飯');
  // 順序本來就對的不受影響
  assert.equal(detect('ji3vu;3t z04', dict).candidates[0], '我想吃飯');
});

test('歸位只在合理時發生，不會硬湊', () => {
  // 兩個聲母（ㄉㄊ）不可能是打反 → 仍走數字修正那條路
  assert.equal(detect('a932ek7', dict).candidates[0], '買2個');
  // 英文與無意義字串仍然不觸發
  assert.equal(detect('the cat sat', dict), null);
  assert.equal(detect('r2d2', dict), null);
  assert.equal(detect('abc123', dict), null);
  assert.equal(detect('IEIEI', dict), null);
});
