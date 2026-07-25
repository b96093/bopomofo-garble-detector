import { keysToZhuyin } from './layout.js';
import { convertCandidates } from './convert.js';
import { COMMON_ENGLISH } from './english-common.js';

const HAN = /[一-鿿㐀-䶿]/;
// 亂碼由：字母、聲調數字、空白、大千標點鍵，加上使用者自己打的標點組成
const KEYSTROKE = /^[a-z0-9 ;/.,\-?!:"'()]+$/i;
// 使用者自己打的標點（非大千鍵）：切段用，原樣保留不轉換
const PUNCT = `?!:"'()`;

function hanRatio(s) {
  if (!s) return 0;
  const chars = [...s];
  let n = 0;
  for (const ch of chars) if (HAN.test(ch)) n++;
  return n / chars.length;
}

// 以標點為界切成交替的「按鍵段 / 標點段」
function splitParts(input) {
  const parts = [];
  let cur = '';
  let curIsPunct = null;
  for (const ch of input) {
    const isPunct = PUNCT.includes(ch);
    if (curIsPunct === null || isPunct === curIsPunct) { cur += ch; curIsPunct = isPunct; }
    else { parts.push({ punct: curIsPunct, text: cur }); cur = ch; curIsPunct = isPunct; }
  }
  if (cur) parts.push({ punct: curIsPunct, text: cur });
  return parts;
}

// 回傳 { candidates:string[], confidence:number, syllables:(string|null)[] } 或 null（非亂碼）
// syllables 與 candidates[0] 的每個字一一對應；標點位置為 null（無同音字可換）。
export function detect(input, dict, opts = {}) {
  const threshold = opts.threshold ?? 0.8; // 保守；設定頁「積極」可調低
  const minSyllables = opts.minSyllables ?? 2;

  if (!input || !KEYSTROKE.test(input)) return null;

  // Gate 3：整串就是常見英文字 → 不理
  if (COMMON_ENGLISH.has(input.trim().toLowerCase())) return null;

  const parts = splitParts(input);
  const keyParts = parts.filter((p) => !p.punct && p.text.trim());
  if (!keyParts.length) return null;

  // Gate 1（結構）：每段的每個音節都要是合法音節（單音節在字典裡查得到）
  const sylOf = new Map();
  let totalSyllables = 0;
  for (const p of keyParts) {
    const syl = keysToZhuyin(p.text);
    if (!syl.length || !syl.every((s) => dict.has(s))) return null;
    sylOf.set(p, syl);
    totalSyllables += syl.length;
  }
  if (totalSyllables < minSyllables) return null;

  // 各段分別轉換，標點原樣接回
  const partCands = keyParts.map((p) => convertCandidates(p.text, dict, 3));
  const assemble = (swapAt, text) => parts.map((p) => {
    const i = keyParts.indexOf(p);
    if (i < 0) return p.punct ? p.text : ''; // 標點原樣；純空白段（已被當聲調鍵吃掉）不輸出
    return i === swapAt ? text : partCands[i][0];
  }).join('');

  // Gate 2（詞庫）：轉出來的部分幾乎全是漢字（標點不計入）
  const ratio = hanRatio(partCands.map((c) => c[0]).join(''));
  if (ratio < threshold) return null;

  const candidates = [assemble(-1)];
  for (let i = 0; i < keyParts.length && candidates.length < 3; i++) {
    const alt = partCands[i][1];
    if (!alt) continue;
    const s = assemble(i, alt);
    if (!candidates.includes(s)) candidates.push(s);
  }

  // 每個輸出字對應的注音（標點為 null）
  const syllables = [];
  for (const p of parts) {
    const i = keyParts.indexOf(p);
    if (i < 0) { if (p.punct) for (const _ of p.text) syllables.push(null); }
    else for (const s of sylOf.get(p)) syllables.push(s);
  }

  return { candidates, confidence: ratio, syllables };
}
