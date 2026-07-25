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
