import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeTyped } from '../src/content/replace.js';
import { extractGarbleRun } from '../src/content/extract.js';
import { loadDict } from '../src/engine/dict.js';
import { detect } from '../src/engine/detect.js';

const dict = loadDict();
const NBSP = ' ';

test('不斷行空白還原成空白鍵', () => {
  assert.equal(normalizeTyped(`su3gji${NBSP}`), 'su3gji ');
});

test('還原不改變長度（替換後的索引仍對得上原文字節點）', () => {
  const s = `su3gji${NBSP}su3gji${NBSP}`;
  assert.equal(normalizeTyped(s).length, s.length);
});

test('其他字元原樣不動', () => {
  assert.equal(normalizeTyped('你說什麼 ji394t'), '你說什麼 ji394t');
});

// 迴歸：contenteditable 打完一個字按空白鍵，瀏覽器存的是 U+00A0 而非 U+0020。
// 未還原時 extractGarbleRun 會把它當邊界，整段抓不出來、浮窗跟著消失。
test('迴歸：contenteditable 的尾端空白不該把亂碼段切斷', () => {
  const text = `su3gji${NBSP}`;
  assert.equal(extractGarbleRun(text, text.length), null, '未還原時確實會被切斷');

  const fixed = normalizeTyped(text);
  assert.deepEqual(extractGarbleRun(fixed, fixed.length),
    { start: 0, end: 7, run: 'su3gji ' });
  assert.equal(detect('su3gji ', dict, {}).candidates[0], '你說');
});

test('迴歸：連續多段之間的不斷行空白也要還原（否則只認得出最後一段）', () => {
  const text = `su3gji${NBSP}su3gji${NBSP}su3gji`;
  const fixed = normalizeTyped(text);
  const seg = extractGarbleRun(fixed, fixed.length);
  assert.equal(seg.run, 'su3gji su3gji su3gji');
  assert.equal(detect(seg.run, dict, {}).candidates[0], '你說你說你說');
});
