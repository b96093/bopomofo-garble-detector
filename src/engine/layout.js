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

// 把英文鍵位字串還原成注音音節陣列（每個音節含聲調符號）
export function keysToZhuyin(input) {
  const syllables = [];
  let current = '';
  for (const ch of input.toLowerCase()) {
    if (Object.hasOwn(TONE_KEYS, ch)) {
      if (current) {
        syllables.push(current + TONE_MARKS[TONE_KEYS[ch]]);
        current = '';
      }
      continue;
    }
    if (Object.hasOwn(LAYOUT, ch)) {
      current += LAYOUT[ch];
      continue;
    }
    // 無法對應的字元：先收掉手上的音節（視為一聲），再略過此字元
    if (current) {
      syllables.push(current);
      current = '';
    }
  }
  if (current) syllables.push(current);
  return syllables;
}
