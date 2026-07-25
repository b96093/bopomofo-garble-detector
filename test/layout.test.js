import { test } from 'node:test';
import assert from 'node:assert/strict';
import { keysToZhuyin, keysToTokens } from '../src/engine/layout.js';

test('單一音節含三聲：ji3 → ㄨㄛˇ', () => {
  assert.deepEqual(keysToZhuyin('ji3'), ['ㄨㄛˇ']);
});

test('四聲：94 → ㄞˋ', () => {
  assert.deepEqual(keysToZhuyin('94'), ['ㄞˋ']);
});

test('一聲用空白鍵，且空白為分隔點：t → 空白 → ㄔ', () => {
  assert.deepEqual(keysToZhuyin('t '), ['ㄔ']);
});

test('大寫輸入正常還原：JI394T AU04 → 我愛吃麵的注音', () => {
  assert.deepEqual(
    keysToZhuyin('JI394T AU04'),
    ['ㄨㄛˇ', 'ㄞˋ', 'ㄔ', 'ㄇㄧㄢˋ']
  );
});

test('第二聲：6 → ˊ（ej/6 → ㄍㄨㄥˊ）', () => {
  assert.deepEqual(keysToZhuyin('ej/6'), ['ㄍㄨㄥˊ']);
});

test('輕聲：7（j7 → ㄨ˙）', () => {
  assert.deepEqual(keysToZhuyin('j7'), ['ㄨ˙']);
});

test('結尾無聲調鍵時，手上的音節視為一聲收掉', () => {
  assert.deepEqual(keysToZhuyin('ji'), ['ㄨㄛ']);
});

test('無法對應的字元會先收音節再略過', () => {
  assert.deepEqual(keysToZhuyin('ji3@94'), ['ㄨㄛˇ', 'ㄞˋ']);
});

test('空字串回傳空陣列', () => {
  assert.deepEqual(keysToZhuyin(''), []);
});

test('開頭的聲調鍵被忽略（前面沒有音節）', () => {
  assert.deepEqual(keysToZhuyin(' 3ji3'), ['ㄨㄛˇ']);
});

test('連續聲調鍵不產生空音節（ji33 → 只有一個 ㄨㄛˇ）', () => {
  assert.deepEqual(keysToZhuyin('ji33'), ['ㄨㄛˇ']);
});

// token 另含來源位置 start/end，測試只比對種類與內容
const tv = (s) => keysToTokens(s).map(({ t, v }) => ({ t, v }));

test('落單聲調數字視為字面數字（keysToTokens）', () => {
  // a93 = ㄇㄞˇ（買），第二個 3 前面已無待標調注音 → 字面數字
  assert.deepEqual(tv('a933'), [
    { t: 'syl', v: 'ㄇㄞˇ' },
    { t: 'lit', v: '3' },
  ]);
});

test('落單空白＝使用者要打的空格（一聲已用掉時）', () => {
  assert.deepEqual(tv('a93 '), [
    { t: 'syl', v: 'ㄇㄞˇ' },
    { t: 'lit', v: ' ' },
  ]);
});

test('一聲：空白有待標調注音時仍是聲調，不是空格', () => {
  // cj8 = ㄏㄨㄚ，空白＝一聲 → 花
  assert.deepEqual(tv('cj8 '), [{ t: 'syl', v: 'ㄏㄨㄚ' }]);
});
