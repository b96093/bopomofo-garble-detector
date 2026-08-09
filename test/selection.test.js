import { test } from 'node:test';
import assert from 'node:assert/strict';
import { selectionOpts } from '../src/content/detector.js';
import { loadDict } from '../src/engine/dict.js';
import { detect } from '../src/engine/detect.js';

const dict = loadDict();

// content.js 的兩種模式
const CONSERVATIVE = { threshold: 0.8, minSyllables: 2 };
const AGGRESSIVE = { threshold: 0.6, minSyllables: 1 };

const passive = (s, opts = CONSERVATIVE) => detect(s, dict, selectionOpts(opts, false));
const explicit = (s, opts = CONSERVATIVE) => detect(s, dict, selectionOpts(opts, true));

// 被動提示只要「選取任何文字」就會觸發 —— 那是複製東西的日常動作，不是意圖。
// 用和熱鍵一樣的寬鬆門檻，選個版本號、IP、電話號碼都會跳出來打擾人。
test('被動提示：版本號不該跳', () => {
  assert.equal(passive('1.457.72.0'), null);
  assert.equal(passive('v1.0.0'), null);
});

test('被動提示：IP 位址不該跳', () => {
  assert.equal(passive('192.168.0.1'), null);
});

test('被動提示：電話號碼不該跳', () => {
  assert.equal(passive('0966335806'), null);
  assert.equal(passive('0287654321'), null);
});

test('被動提示：純數字與時間不該跳', () => {
  assert.equal(passive('8731'), null);
  assert.equal(passive('100'), null);
  assert.equal(passive('09:41'), null);
  assert.equal(passive('2026/08/09'), null);
});

test('被動提示：真的亂碼仍要跳', () => {
  assert.equal(passive('ji394t au04').candidates[0], '我愛吃面');
  assert.equal(passive('su3gji').candidates[0], '你說');
  assert.equal(passive('su35 2l4a8').candidates[0], '你知道嗎');
});

// 按下 Ctrl+Alt+Z 是明確表明意圖，門檻該放寬 —— 選到什麼都給候選。
test('明確按熱鍵：門檻放寬，單音節也給候選', () => {
  assert.ok(explicit('su3'), '單音節在熱鍵路徑應該要有候選');
});

test('明確按熱鍵：仍比被動寬鬆（這是刻意的差別）', () => {
  assert.equal(passive('a932ek7', AGGRESSIVE) === null, false);
  assert.ok(explicit('1.457.72.0'), '熱鍵是使用者自己按的，照他的要求給結果');
});
