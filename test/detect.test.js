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
