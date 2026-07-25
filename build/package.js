// 打包：把「執行時需要的檔案」複製到 dist/文字亂碼偵測/（乾淨的未封裝擴充），
// 可直接於 chrome://extensions 載入，或再壓成 zip 上架。不含 build/、test/、docs 規格等開發檔。
import { cpSync, mkdirSync, rmSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const distRoot = new URL('../dist/', import.meta.url);
const out = new URL('../dist/文字亂碼偵測/', import.meta.url);

rmSync(distRoot, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// 目錄遞迴複製；單檔直接複製
cpSync(new URL('manifest.json', root), new URL('manifest.json', out));
cpSync(new URL('src', root), new URL('src', out), { recursive: true });
cpSync(new URL('README.md', root), new URL('README.md', out));
cpSync(new URL('docs/NOTICE.md', root), new URL('NOTICE.md', out));

console.log('已輸出未封裝擴充到 dist/文字亂碼偵測/');
console.log('→ 可於 chrome://extensions 開啟開發人員模式後「載入未封裝項目」選此資料夾；');
console.log('→ 或將此資料夾壓成 zip 上架 Chrome 線上應用程式商店。');
