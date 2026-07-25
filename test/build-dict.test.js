import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildDict, serializeDict } from '../build/build-dict.js';

const dir = new URL('./fixtures/', import.meta.url);
const mappings = new URL('mappings.sample.txt', dir);
const base = new URL('base.sample.txt', dir);
const occ = new URL('occ.sample.txt', dir);

test('反轉：注音 key（空格分隔）→ 依詞頻降冪的候選', () => {
  const map = buildDict({ mappings, base, occ });
  assert.deepEqual(map.get('ㄨㄛˇ'), [['我', 1000]]);
  assert.deepEqual(map.get('ㄇㄧㄢˋ'), [['麵', 500], ['面', 400]]);
  assert.deepEqual(map.get('ㄞˋ ㄔ'), [['愛吃', 150]]);
});

test('serializeDict 產出可再解析的緊湊字串', () => {
  const map = buildDict({ mappings, base, occ });
  const text = serializeDict(map);
  const lines = text.split('\n').filter(Boolean);
  const mianLine = lines.find((l) => l.startsWith('ㄇㄧㄢˋ\t'));
  assert.equal(mianLine, 'ㄇㄧㄢˋ\t麵 500 面 400');
});
