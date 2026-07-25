import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadDict } from '../src/engine/dict.js';
import { detect } from '../src/engine/detect.js';

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
