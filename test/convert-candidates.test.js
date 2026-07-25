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

test('多個模糊段落：依詞頻差距升冪排序、並依 n 截斷', () => {
  const d = new Map([
    ['ㄚ', [['啊', 900], ['阿', 100]]], // gap 800
    ['ㄛ', [['喔', 800], ['噢', 750]]], // gap 50（最小，替代最先出現）
    ['ㄜ', [['額', 700], ['惡', 300]]], // gap 400
  ]);
  const input = '8 i k '; // → 注音音節 ㄚ ㄛ ㄜ
  // best = 啊喔額；替代依 gap 升冪：噢(50) → 惡(400) → 阿(800，n=3 時被截斷)
  assert.deepEqual(convertCandidates(input, d, 3), ['啊喔額', '啊噢額', '啊喔惡']);
  assert.deepEqual(convertCandidates(input, d, 2), ['啊喔額', '啊噢額']);
});
