// 由 src/engine/english-common.js 產生桌面版用的 desktop/english.ahk，
// 讓兩個版本共用同一份英文字表（改 JS 那份後重跑本腳本即可）。
import { writeFileSync } from 'node:fs';
import { COMMON_ENGLISH } from '../src/engine/english-common.js';

const words = [...COMMON_ENGLISH];
let s = '#Requires AutoHotkey v2.0\n';
s += '; 由 src/engine/english-common.js 自動產生 — 請勿手改\n';
s += '; 重新產生：node build/build-english-ahk.js\n\n';
s += 'global COMMON_ENGLISH := Map(\n';
s += words.map((w) => '    ' + JSON.stringify(w) + ', true').join(',\n') + ')\n\n';
s += 'IsCommonEnglish(w) {\n    return COMMON_ENGLISH.Has(w)\n}\n';

// AHK 需要 BOM 才會以 UTF-8 讀取
writeFileSync(new URL('../desktop/english.ahk', import.meta.url), '﻿' + s.replace(/\n/g, '\r\n'), 'utf8');
console.log('已產生 desktop/english.ahk，字數:', words.length);
