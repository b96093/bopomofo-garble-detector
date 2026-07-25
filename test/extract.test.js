import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractGarbleRun } from '../src/content/extract.js';

test('整段亂碼：抓出全部', () => {
  assert.deepEqual(extractGarbleRun('ji394t au04', 11), { start: 0, end: 11, run: 'ji394t au04' });
});

test('游標在中間：只抓游標前', () => {
  // 'ji394t au04' 游標在 6（ji394t 之後）
  assert.deepEqual(extractGarbleRun('ji394t au04', 6), { start: 0, end: 6, run: 'ji394t' });
});

test('前面有中文：中文是邊界，只抓後面的亂碼', () => {
  // '面 ji394t'：面(0) 空白(1) j(2)...t(7)，caret=8
  assert.deepEqual(extractGarbleRun('面 ji394t', 8), { start: 2, end: 8, run: 'ji394t' });
});

test('換行是邊界', () => {
  assert.deepEqual(extractGarbleRun('abc\nji394t', 10), { start: 4, end: 10, run: 'ji394t' });
});

test('純英文也會被抓出（是否亂碼交給 detect 判斷）', () => {
  assert.deepEqual(extractGarbleRun('hello', 5), { start: 0, end: 5, run: 'hello' });
});

test('空字串回 null', () => {
  assert.equal(extractGarbleRun('', 0), null);
});

test('只有空白回 null', () => {
  assert.equal(extractGarbleRun('   ', 3), null);
});

test('游標前是中文（無亂碼）回 null', () => {
  assert.equal(extractGarbleRun('我愛', 2), null);
});
