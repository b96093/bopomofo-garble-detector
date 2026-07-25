import { keysToZhuyin } from './layout.js';

const MAX_WORD_LEN = 4;

// input：英文鍵位亂碼字串
// dict：Map，key = 注音音節串接，value = [[詞, 詞頻], ...]（依詞頻降冪）
// 回傳：最可能的漢字串
export function convert(input, dict) {
  const syllables = keysToZhuyin(input);
  let out = '';
  let i = 0;
  while (i < syllables.length) {
    let matched = false;
    const maxLen = Math.min(MAX_WORD_LEN, syllables.length - i);
    for (let len = maxLen; len >= 1; len--) {
      const key = syllables.slice(i, i + len).join(' ');
      const entry = dict.get(key);
      if (entry && entry.length) {
        out += entry[0][0];
        i += len;
        matched = true;
        break;
      }
    }
    if (!matched) {
      out += syllables[i];
      i += 1;
    }
  }
  return out;
}
