// 大千（標準）注音鍵盤佈局：英文鍵 → 注音符號
export const LAYOUT = {
  '1': 'ㄅ', 'q': 'ㄆ', 'a': 'ㄇ', 'z': 'ㄈ',
  '2': 'ㄉ', 'w': 'ㄊ', 's': 'ㄋ', 'x': 'ㄌ',
  'e': 'ㄍ', 'd': 'ㄎ', 'c': 'ㄏ',
  'r': 'ㄐ', 'f': 'ㄑ', 'v': 'ㄒ',
  '5': 'ㄓ', 't': 'ㄔ', 'g': 'ㄕ', 'b': 'ㄖ',
  'y': 'ㄗ', 'h': 'ㄘ', 'n': 'ㄙ',
  'u': 'ㄧ', 'j': 'ㄨ', 'm': 'ㄩ',
  '8': 'ㄚ', 'i': 'ㄛ', 'k': 'ㄜ', ',': 'ㄝ',
  '9': 'ㄞ', 'o': 'ㄟ', 'l': 'ㄠ', '.': 'ㄡ',
  '0': 'ㄢ', 'p': 'ㄣ', ';': 'ㄤ', '/': 'ㄥ',
  '-': 'ㄦ',
};

// 聲調鍵 → 聲調號（1=一聲 … 5=輕聲）；一聲用空白鍵
export const TONE_KEYS = { ' ': 1, '6': 2, '3': 3, '4': 4, '7': 5 };

// 聲調號 → 注音聲調符號（一聲無符號）
export const TONE_MARKS = { 1: '', 2: 'ˊ', 3: 'ˇ', 4: 'ˋ', 5: '˙' };

// 把英文鍵位字串拆成 token 陣列：
//   { t:'syl', v:'ㄋㄧˇ' }  可轉成漢字的注音音節
//   { t:'lit', v:'3' }      原樣保留的字元（標點、或使用者真的要打的數字）
// 聲調鍵（空白＝一聲，3/4/6/7）若前面沒有待標調的注音，就不可能是聲調
// → 視為使用者真的要打的字元（數字或空格）。
// forcedLiteral：一組字元索引，強制當成字面字元而非注音鍵
// （給 detect 用來修正「1/2/5/8/9/0 其實是數字」的情況）
// 每個 token 附上來源字元範圍 [start, end)，方便回頭修正。
export function keysToTokens(input, forcedLiteral = null) {
  const tokens = [];
  const lower = input.toLowerCase();
  let current = '';
  let start = 0;
  const flush = (mark, end) => {
    if (current) { tokens.push({ t: 'syl', v: current + mark, start, end }); current = ''; }
  };
  for (let i = 0; i < lower.length; i++) {
    const ch = lower[i];
    const forced = forcedLiteral && forcedLiteral.has(i);
    if (!forced && Object.hasOwn(TONE_KEYS, ch)) {
      if (current) flush(TONE_MARKS[TONE_KEYS[ch]], i + 1);
      else tokens.push({ t: 'lit', v: input[i], start: i, end: i + 1 }); // 落單聲調鍵＝數字／空格
      continue;
    }
    if (!forced && Object.hasOwn(LAYOUT, ch)) {
      if (!current) start = i;
      current += LAYOUT[ch];
      continue;
    }
    // 標點、或被強制視為字面的字元：先收掉手上的音節（視為一聲），該字元原樣保留
    flush('', i);
    tokens.push({ t: 'lit', v: input[i], start: i, end: i + 1 });
  }
  flush('', lower.length);
  return tokens;
}

// 把英文鍵位字串還原成注音音節陣列（每個音節含聲調符號）
export function keysToZhuyin(input) {
  return keysToTokens(input).filter((t) => t.t === 'syl').map((t) => t.v);
}
