// 依按鍵時間點合成打字聲（44.1kHz、16-bit、單聲道 WAV）。
// 每一下是一段很短、快速衰減的低通雜訊，再疊一點低頻，聽起來像鍵盤而不是電子音。
// 亂數用固定種子：同樣的輸入每次產生一模一樣的檔案，重錄結果可預期。
export function keyTrack(hits, seconds = 30, rate = 44100) {
  const n = Math.round(seconds * rate);
  const buf = new Float32Array(n);
  let seed = 12345;
  const rnd = () => ((seed = (Math.imul(seed, 1103515245) + 12345) >>> 0) / 4294967296) * 2 - 1;
  for (const { t, gain } of hits) {
    const start = Math.round(t * rate);
    const len = Math.round(0.035 * rate);
    let lp = 0;
    for (let i = 0; i < len && start + i < n; i++) {
      const env = Math.exp(-i / (0.004 * rate));
      lp += 0.35 * (rnd() - lp);
      const thump = Math.sin(2 * Math.PI * 160 * i / rate) * Math.exp(-i / (0.010 * rate)) * 0.4;
      buf[start + i] += gain * (lp * env + thump);
    }
  }
  const out = Buffer.alloc(44 + n * 2);
  out.write('RIFF', 0); out.writeUInt32LE(36 + n * 2, 4); out.write('WAVE', 8);
  out.write('fmt ', 12); out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(1, 22);
  out.writeUInt32LE(rate, 24); out.writeUInt32LE(rate * 2, 28); out.writeUInt16LE(2, 32); out.writeUInt16LE(16, 34);
  out.write('data', 36); out.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) out.writeInt16LE((Math.max(-1, Math.min(1, buf[i] * 0.5)) * 32767) | 0, 44 + i * 2);
  return out;
}
