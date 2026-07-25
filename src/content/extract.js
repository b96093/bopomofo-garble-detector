// 從欄位文字中，抓出游標前「連續的亂碼鍵字串」。
// 邊界：換行、或任何非大千鍵字元（含中文、標點）。開頭空白會修剪掉。
// 回傳 { start, end, run } 或 null（沒有可用的亂碼段）。
// 注意：本函式只負責「切出候選段」，是否真為亂碼由 detect() 三道關卡判斷。

const KEYSTROKE = /[a-z0-9 ;/.,\-]/i;

export function extractGarbleRun(text, caret) {
  let start = caret;
  while (start > 0) {
    const ch = text[start - 1];
    if (!KEYSTROKE.test(ch)) break; // 換行、中文、其他標點都會停
    start--;
  }
  const raw = text.slice(start, caret);
  const trimmed = raw.replace(/^\s+/, '');
  start += raw.length - trimmed.length;
  if (!trimmed.trim()) return null;
  return { start, end: caret, run: trimmed };
}
