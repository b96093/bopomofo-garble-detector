import { test } from 'node:test';
import assert from 'node:assert/strict';
import { convert } from '../src/engine/convert.js';

// fixture 詞庫：value 依詞頻降冪；含單字與詞
const dict = new Map([
  ['ㄨㄛˇ', [['我', 1000]]],
  ['ㄞˋ', [['愛', 500], ['礙', 30]]],
  ['ㄔ', [['吃', 300], ['尺', 80], ['池', 60]]],
  ['ㄇㄧㄢˋ', [['麵', 500], ['面', 400]]],
  ['ㄞˋ ㄔ', [['愛吃', 150]]],
  ['ㄒㄧㄢˋ', [['現', 500], ['線', 300]]],
  ['ㄕㄤˋ', [['上', 900]]],
  ['ㄍㄨㄥ', [['工', 400], ['公', 300]]],
  ['ㄐㄩˋ', [['具', 200], ['句', 150]]],
  ['ㄨㄤˇ', [['網', 250], ['往', 200]]],
  ['ㄒㄧㄢˋ ㄕㄤˋ', [['線上', 180]]],
  ['ㄍㄨㄥ ㄐㄩˋ', [['工具', 160]]],
]);

test('單字：ji3 → 我', () => {
  assert.equal(convert('ji3', dict), '我');
});

test('最長詞優先：愛吃 而非 礙尺（94t → 愛吃）', () => {
  assert.equal(convert('94t ', dict), '愛吃');
});

test('無對應音節時保留注音當 fallback', () => {
  assert.equal(convert('1 ', dict), 'ㄅ');
});

test('golden：ji394t au04 → 我愛吃麵', () => {
  assert.equal(convert('ji394t au04', dict), '我愛吃麵');
});

test('golden：vu04g;4ej/ rm4j;3 → 線上工具網', () => {
  assert.equal(convert('vu04g;4ej/ rm4j;3', dict), '線上工具網');
});
