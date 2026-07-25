import { keysToZhuyin } from './layout.js';

const MAX_WORD_LEN = 4;

// input 可以是英文鍵位字串，或已算好的注音音節陣列（避免重複斷詞）
const toSyllables = (input) => (Array.isArray(input) ? input : keysToZhuyin(input));

// input：英文鍵位亂碼字串
// dict：Map，key = 注音音節串接，value = [[詞, 詞頻], ...]（依詞頻降冪）
// 回傳：最可能的漢字串
export function convert(input, dict) {
  const syllables = toSyllables(input);
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

// 貪婪斷詞，回傳每段的候選清單
function segment(input, dict) {
  const syllables = toSyllables(input);
  const segments = [];
  let i = 0;
  while (i < syllables.length) {
    let matched = false;
    const maxLen = Math.min(MAX_WORD_LEN, syllables.length - i);
    for (let len = maxLen; len >= 1; len--) {
      const key = syllables.slice(i, i + len).join(' ');
      const entry = dict.get(key);
      if (entry && entry.length) {
        segments.push(entry);
        i += len;
        matched = true;
        break;
      }
    }
    if (!matched) {
      segments.push([[syllables[i], 0]]);
      i += 1;
    }
  }
  return segments;
}

// 回傳至多 n 個完整候選字串，最佳在前。
// 替代解：對每個「有次佳詞」的段落做單點替換，依詞頻差距（小者優先）排序。
export function convertCandidates(input, dict, n = 3) {
  const segments = segment(input, dict);
  const best = segments.map((s) => s[0][0]).join('');

  const swaps = [];
  for (let idx = 0; idx < segments.length; idx++) {
    if (segments[idx].length >= 2) {
      const gap = segments[idx][0][1] - segments[idx][1][1];
      const variant = segments
        .map((s, j) => (j === idx ? s[1][0] : s[0][0]))
        .join('');
      swaps.push([gap, variant]);
    }
  }
  swaps.sort((a, b) => a[0] - b[0]);

  const result = [best];
  for (const [, variant] of swaps) {
    if (result.length >= n) break;
    if (!result.includes(variant)) result.push(variant);
  }
  return result;
}
