import { DICT_TEXT } from './dict-data.js';

// 解析緊湊字串為 Map<注音key, [[詞, 詞頻], ...]>
export function loadDict() {
  const map = new Map();
  for (const line of DICT_TEXT.split('\n')) {
    if (!line) continue;
    const tab = line.indexOf('\t');
    if (tab < 0) continue;
    const key = line.slice(0, tab);
    const toks = line.slice(tab + 1).split(' ');
    const entries = [];
    for (let i = 0; i + 1 < toks.length; i += 2) {
      entries.push([toks[i], Number(toks[i + 1])]);
    }
    map.set(key, entries);
  }
  return map;
}
