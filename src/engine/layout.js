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
export function keysToTokens(input) {
  const tokens = [];
  let current = '';
  const flush = (mark = '') => {
    if (current) { tokens.push({ t: 'syl', v: current + mark }); current = ''; }
  };
  for (const ch of input.toLowerCase()) {
    if (Object.hasOwn(TONE_KEYS, ch)) {
      if (current) flush(TONE_MARKS[TONE_KEYS[ch]]);
      else tokens.push({ t: 'lit', v: ch }); // 落單的聲調鍵＝字面數字／空格
      continue;
    }
    if (Object.hasOwn(LAYOUT, ch)) {
      current += LAYOUT[ch];
      continue;
    }
    // 無法對應的字元（標點等）：先收掉手上的音節（視為一聲），該字元原樣保留
    flush();
    tokens.push({ t: 'lit', v: ch });
  }
  flush();
  return tokens;
}

// 把英文鍵位字串還原成注音音節陣列（每個音節含聲調符號）
export function keysToZhuyin(input) {
  return keysToTokens(input).filter((t) => t.t === 'syl').map((t) => t.v);
}
