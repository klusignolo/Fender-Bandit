// Placeholder loop for the week-1 audio check (#20): 120 BPM, 16 beats = exactly 8 s.
// A sustained pad whose partials complete whole cycles in 8 s, so the PCM loops with no
// discontinuity; any click or gap heard at the seam comes from MP3 encoding/decoding.
import { Mp3Encoder } from "@breezystack/lamejs";
import { writeFileSync } from "node:fs";
const SR = 44100, BPM = 120, BEATS = 16, N = SR * BEATS * 60 / BPM;
const beat = SR * 60 / BPM;
const pcm = new Int16Array(N);
const pad = [110, 137.5, 165, 220];
const melody = [440, 550, 660, 550, 495, 440, 412.5, 330]; // eighth notes, repeats every 4 beats
for (let i = 0; i < N; i++) {
  const t = i / SR;
  let s = 0;
  for (const f of pad) s += 0.07 * Math.sin(2 * Math.PI * f * t);
  const bp = i % beat, bt = bp / SR;
  s += 0.45 * Math.sin(2 * Math.PI * (50 + 60 * Math.exp(-bt * 30)) * bt) * Math.exp(-bt * 9); // kick
  const eighth = beat / 2, k = Math.floor(i / eighth), et = (i % eighth) / SR, dur = eighth / SR;
  const env = Math.min(1, et / 0.005) * Math.exp(-et * 6) * Math.min(1, (dur - et) / 0.01);
  s += 0.12 * env * Math.sin(2 * Math.PI * melody[k % 8] * t);
  pcm[i] = Math.max(-32767, Math.min(32767, Math.round(s * 32767)));
}
const enc = new Mp3Encoder(1, SR, 160), out = [];
for (let i = 0; i < N; i += 1152) { const b = enc.encodeBuffer(pcm.subarray(i, i + 1152)); if (b.length) out.push(Buffer.from(b)); }
out.push(Buffer.from(enc.flush()));
writeFileSync(process.argv[2], Buffer.concat(out));
console.log("wrote", process.argv[2]);
