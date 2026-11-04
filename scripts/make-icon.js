// Generates App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024, RGB, no alpha).
// Near-black ground with a soft top light, and a glowing ring split Red / Amber / Green.
// Run: node scripts/make-icon.js
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");

const N = 1024, cx = 512, cy = 540;
const R = 300, T = 62;                     // ring radius and thickness
const segs = [                             // clockwise from 12 o'clock, with gaps
  { from: 8, to: 112, c: [255, 106, 92] },   // red
  { from: 128, to: 232, c: [255, 196, 97] }, // amber
  { from: 248, to: 352, c: [114, 220, 156] } // green
];
const px = Buffer.alloc(N * (N * 3 + 1));
const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
const smooth = (e0, e1, x) => { const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };

for (let y = 0; y < N; y++) {
  px[y * (N * 3 + 1)] = 0;
  for (let x = 0; x < N; x++) {
    // ground: radial top light fading to black
    const gy = (y - 0) / N, gx = (x - N / 2) / N;
    const g = Math.max(0, 1 - Math.sqrt((gx / 0.95) ** 2 + (gy / 0.8) ** 2));
    let r = 2 + 26 * g * g, gg = 2 + 26 * g * g, b = 3 + 30 * g * g;

    const dx = x - cx, dy = y - cy, d = Math.sqrt(dx * dx + dy * dy);
    let ang = Math.atan2(dx, -dy) * 180 / Math.PI; if (ang < 0) ang += 360;

    // glass disc behind the ring (slightly lifted, with a bright top rim)
    const disc = 1 - smooth(R + T / 2 + 40, R + T / 2 + 44, d);
    if (disc > 0) {
      const lift = 18 + 22 * Math.max(0, -dy / (R + 70));
      r += lift * disc; gg += lift * disc; b += (lift + 3) * disc;
      const rim = Math.exp(-(((d - (R + T / 2 + 41)) / 2.2) ** 2)) * Math.max(0, -dy / (R + 70));
      r += 150 * rim; gg += 150 * rim; b += 155 * rim;
    }

    // ring segments, track and glow
    for (const s of segs) {
      const inSeg = smooth(s.from - 1.2, s.from + 1.2, ang) * (1 - smooth(s.to - 1.2, s.to + 1.2, ang));
      const ringMask = (1 - smooth(T / 2 - 2, T / 2 + 2, Math.abs(d - R)));
      const soft = smooth(s.from - 18, s.from + 10, ang) * (1 - smooth(s.to - 10, s.to + 18, ang));
      const glow = Math.exp(-(((d - R) / 70) ** 2)) * 0.28 * soft;
      // round caps
      const capA = [s.from, s.to].map(a => {
        const rad = a * Math.PI / 180, ex = cx + R * Math.sin(rad), ey = cy - R * Math.cos(rad);
        return 1 - smooth(T / 2 - 2, T / 2 + 2, Math.hypot(x - ex, y - ey));
      });
      const m = Math.max(inSeg * ringMask, capA[0], capA[1]);
      const k = m + (1 - m) * glow;
      // inner highlight on the ring (top-lit glass)
      const hl = m * Math.max(0, 1 - Math.abs(d - (R - T / 4)) / (T / 3)) * 0.35;
      r = r * (1 - Math.min(1, k)) + s.c[0] * k + 255 * hl;
      gg = gg * (1 - Math.min(1, k)) + s.c[1] * k + 255 * hl;
      b = b * (1 - Math.min(1, k)) + s.c[2] * k + 255 * hl;
    }
    const o = y * (N * 3 + 1) + 1 + x * 3;
    px[o] = clamp(r); px[o + 1] = clamp(gg); px[o + 2] = clamp(b);
  }
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(px, { level: 9 })), chunk("IEND", Buffer.alloc(0))
]);
const out = path.join(__dirname, "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png");
fs.writeFileSync(out, png);
console.log("wrote", out, png.length, "bytes");
