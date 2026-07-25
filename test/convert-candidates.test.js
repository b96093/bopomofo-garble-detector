import { test } from 'node:test';
import assert from 'node:assert/strict';
import { convertCandidates } from '../src/engine/convert.js';

const dict = new Map([
  ['ㄨㄛˇ', [['我', 1000]]],
  ['ㄞˋ', [['愛', 500], ['礙', 30]]],
  ['ㄔ', [['吃', 300], ['尺', 80]]],
  ['ㄇㄧㄢˋ', [['麵', 500], ['面', 400]]],
  ['ㄞˋ ㄔ', [['愛吃', 150]]],
]);

test('第一候選為貪婪最佳解', () => {
  const c = convertCandidates('ji394t au04', dict, 3);
  assert.equal(c[0], '我愛吃麵');
});

test('回傳至多 n 個、且彼此不同', () => {
  const c = convertCandidates('ji394t au04', dict, 3);
  assert.ok(c.length >= 2 && c.length <= 3);
  assert.equal(new Set(c).size, c.length);
  assert.ok(c.includes('我愛吃面'));
});
