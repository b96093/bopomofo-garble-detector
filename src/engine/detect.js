import { keysToTokens } from './layout.js';
import { convertCandidates } from './convert.js';
import { COMMON_ENGLISH } from './english-common.js';

const HAN = /[一-鿿㐀-䶿]/;
// 使用者自己打的標點（非大千鍵）：原樣保留不轉換。
// 含半形與全形／中文標點（中文輸入法用 Ctrl+鍵 會直接打出全形標點）。
export const PUNCT = `?!:"'()、，。？！；：「」『』（）〈〉《》【】…—～·`;
// 亂碼由：字母、聲調數字、空白、大千標點鍵，加上使用者自己打的標點組成
const KEYSTROKE_KEY = /[a-z0-9 ;/.,\-]/i;
const isRunChar = (ch) => KEYSTROKE_KEY.test(ch) || PUNCT.includes(ch);

function hanRatio(s) {
  if (!s) return 0;
  const chars = [...s];
  let n = 0;
  for (const ch of chars) if (HAN.test(ch)) n++;
  return n / chars.length;
}

// 數字鍵在注音鍵盤上多半是注音符號（1=ㄅ、2=ㄉ、5=ㄓ、8=ㄚ、9=ㄞ、0=ㄡ），
// 但使用者也可能真的要打數字。若某音節查不到（如 2天 → ㄉㄊㄧㄢ，結構上不可能），
// 就把該音節裡的數字改判為字面數字後重試。
function tokenizeResolving(input, dict) {
  const forced = new Set();
  for (let i = 0; i <= 6; i++) { // 上限：避免病態輸入無限重試
    const tokens = keysToTokens(input, forced);
    const bad = tokens.find((t) => t.t === 'syl' && !dict.has(t.v));
    if (!bad) return tokens;
    let adjusted = false;
    for (let k = bad.start; k < bad.end; k++) {
      if (input[k] >= '0' && input[k] <= '9' && !forced.has(k)) { forced.add(k); adjusted = true; break; }
    }
    if (!adjusted) return tokens; // 沒有數字可調整 → 交給 Gate 1 擋掉
  }
  return keysToTokens(input, forced);
}

// 整段判不出來時，逐個丟掉開頭的字串再試，取「最長的可辨識尾段」。
// 用途：前面夾雜了無法辨識的內容（例如隨手打的字），不該讓後面新打的句子跟著失效。
// 回傳 { res, offset }（offset 為尾段在 input 中的起點）或 null。
export function detectTail(input, dict, opts = {}, maxDrops = 8) {
  let offset = 0;
  for (let i = 0; i <= maxDrops; i++) {
    const text = input.slice(offset);
    if (!text.trim()) return null;
    const res = detect(text, dict, opts);
    if (res) return { res, offset };
    const sp = text.indexOf(' ');
    if (sp < 0) return null;
    offset += sp + 1;
    while (input[offset] === ' ') offset++;
  }
  return null;
}

// 把 token 串成「可轉換的音節段」與「原樣保留段」交替的片段清單
function toPieces(tokens) {
  const pieces = [];
  for (const tk of tokens) {
    const last = pieces[pieces.length - 1];
    if (tk.t === 'lit') pieces.push({ lit: tk.v });
    else if (last && last.syls) last.syls.push(tk.v);
    else pieces.push({ syls: [tk.v] });
  }
  return pieces;
}

// 回傳 { candidates:string[], confidence:number, syllables:(string|null)[] } 或 null（非亂碼）
// syllables 與 candidates[0] 的每個字一一對應；標點／數字位置為 null（無同音字可換）。
export function detect(input, dict, opts = {}) {
  const threshold = opts.threshold ?? 0.8; // 保守；設定頁「積極」可調低
  const minSyllables = opts.minSyllables ?? 2;

  if (!input || ![...input].every(isRunChar)) return null;

  // Gate 3：整串就是常見英文字 → 不理
  // （手動選取觸發時使用者已表明意圖，跳過這關）
  if (!opts.manual && COMMON_ENGLISH.has(input.trim().toLowerCase())) return null;

  const pieces = toPieces(tokenizeResolving(input, dict));
  const sylPieces = pieces.filter((p) => p.syls);
  if (!sylPieces.length) return null;

  // Gate 1（結構）：每個音節都要是合法音節（單音節在字典裡查得到）
  let totalSyllables = 0;
  for (const p of sylPieces) {
    if (!p.syls.every((s) => dict.has(s))) return null;
    totalSyllables += p.syls.length;
  }
  if (totalSyllables < minSyllables) return null;

  // 各音節段分別轉換，標點／數字原樣接回
  const cands = sylPieces.map((p) => convertCandidates(p.syls, dict, 3));
  const assemble = (swapAt, text) => pieces.map((p) => {
    if (p.lit !== undefined) return p.lit;
    const i = sylPieces.indexOf(p);
    return i === swapAt ? text : cands[i][0];
  }).join('');

  // Gate 2（詞庫）：轉出來的部分幾乎全是漢字（標點／數字不計入）
  const ratio = hanRatio(cands.map((c) => c[0]).join(''));
  if (ratio < threshold) return null;

  const candidates = [assemble(-1)];
  for (let i = 0; i < sylPieces.length && candidates.length < 3; i++) {
    const alt = cands[i][1];
    if (!alt) continue;
    const s = assemble(i, alt);
    if (!candidates.includes(s)) candidates.push(s);
  }

  // 每個輸出字對應的注音（標點／數字為 null）
  const syllables = [];
  for (const p of pieces) {
    if (p.lit !== undefined) for (const _ of p.lit) syllables.push(null);
    else for (const s of p.syls) syllables.push(s);
  }

  return { candidates, confidence: ratio, syllables };
}
