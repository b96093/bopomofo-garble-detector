import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadDict } from '../src/engine/dict.js';
import { convert } from '../src/engine/convert.js';

const dict = loadDict();

test('真實字典非空', () => {
  assert.ok(dict.size > 1000);
});

// 註：只看單字詞頻、無上下文的 MVP 限制 —— ㄇㄧㄢˋ 的最高頻字是「面」(33473) 而非「麵」(1616)，
// 故 top-1 為「我愛吃面」；「麵」會出現在多候選中（見 convertCandidates）供使用者改選。
test('golden 斷詞與轉換：ji394t au04 → 我愛吃面（面/麵 同音，麵為候選）', () => {
  assert.equal(convert('ji394t au04', dict), '我愛吃面');
});

test('ㄇㄧㄢˋ 的候選同時包含 面 與 麵', () => {
  const words = dict.get('ㄇㄧㄢˋ').map(([w]) => w);
  assert.ok(words.includes('面'));
  assert.ok(words.includes('麵'));
});

test('golden：vu04g;4ej/ rm4j;3 → 線上工具網', () => {
  assert.equal(convert('vu04g;4ej/ rm4j;3', dict), '線上工具網');
});
