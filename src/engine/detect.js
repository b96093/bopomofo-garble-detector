import { keysToZhuyin } from './layout.js';
import { convertCandidates } from './convert.js';
import { COMMON_ENGLISH } from './english-common.js';

const HAN = /[一-鿿㐀-䶿]/;
// 亂碼只由：字母、聲調數字 3/4/6/7、空白、及大千標點鍵組成
const KEYSTROKE = /^[a-z0-9 ;/.,-]+$/i;

function hanRatio(s) {
  if (!s) return 0;
  const chars = [...s];
  let n = 0;
  for (const ch of chars) if (HAN.test(ch)) n++;
  return n / chars.length;
}

// 回傳 { candidates:string[], confidence:number } 或 null（非亂碼）
export function detect(input, dict, opts = {}) {
  const threshold = opts.threshold ?? 0.8; // 保守；設定頁「積極」可調低
  const minSyllables = opts.minSyllables ?? 2;

  if (!input || !KEYSTROKE.test(input)) return null;

  // Gate 3：整串就是常見英文字 → 不理
  if (COMMON_ENGLISH.has(input.trim().toLowerCase())) return null;

  // Gate 1（結構）：每個音節都是合法（單音節在字典裡查得到）
  const syllables = keysToZhuyin(input);
  if (syllables.length < minSyllables) return null;
  if (!syllables.every((s) => dict.has(s))) return null;

  // Gate 2（詞庫）：轉出的最佳解幾乎全是漢字
  const candidates = convertCandidates(input, dict, 3);
  const ratio = hanRatio(candidates[0]);
  if (ratio < threshold) return null;

  return { candidates, confidence: ratio };
}
