import { readFileSync, writeFileSync } from 'node:fs';

const MAX_WORD_CANDIDATES = 10;  // 多音節詞（含空格）：整句候選夠用即可
const MAX_CHAR_CANDIDATES = 50;  // 單音節：供「逐字換同音字」，需較完整的同音字表

function readLines(url) {
  return readFileSync(url, 'utf8').split('\n').map((l) => l.trim()).filter(Boolean);
}

// 回傳 Map<注音key（空格分隔）, [[詞, 詞頻], ...]（詞頻降冪）>
export function buildDict({ mappings, base, occ }) {
  const freq = new Map();
  for (const line of readLines(occ)) {
    const sp = line.lastIndexOf(' ');
    const word = line.slice(0, sp);
    const count = Number(line.slice(sp + 1));
    if (word && Number.isFinite(count)) freq.set(word, count);
  }

  const acc = new Map();
  const add = (key, word) => {
    if (!key || !word) return;
    if (!acc.has(key)) acc.set(key, new Map());
    const inner = acc.get(key);
    const f = freq.get(word) ?? 0;
    if (!inner.has(word) || inner.get(word) < f) inner.set(word, f);
  };

  for (const line of readLines(mappings)) {
    const parts = line.split(/\s+/);
    const word = parts[0];
    const key = parts.slice(1).join(' ');
    add(key, word);
  }

  for (const line of readLines(base)) {
    const parts = line.split(/\s+/);
    add(parts[1], parts[0]);
  }

  const out = new Map();
  for (const [key, inner] of acc) {
    const cap = key.includes(' ') ? MAX_WORD_CANDIDATES : MAX_CHAR_CANDIDATES;
    const entries = [...inner.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, cap);
    out.set(key, entries);
  }
  return out;
}

// Map -> 緊湊字串：每行 `key\t詞1 頻1 詞2 頻2 ...`
export function serializeDict(map) {
  const lines = [];
  for (const [key, entries] of map) {
    const flat = entries.map(([w, f]) => `${w} ${f}`).join(' ');
    lines.push(`${key}\t${flat}`);
  }
  return lines.join('\n');
}

function main() {
  const dataDir = new URL('./data/', import.meta.url);
  const map = buildDict({
    mappings: new URL('BPMFMappings.txt', dataDir),
    base: new URL('BPMFBase.txt', dataDir),
    occ: new URL('phrase.occ', dataDir),
  });
  const text = serializeDict(map);
  const outUrl = new URL('../src/engine/dict-data.js', import.meta.url);
  writeFileSync(outUrl, `export const DICT_TEXT = ${JSON.stringify(text)};\n`, 'utf8');
  console.log(`dict entries: ${map.size}, bytes: ${text.length}`);
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('build-dict.js')) {
  main();
}
