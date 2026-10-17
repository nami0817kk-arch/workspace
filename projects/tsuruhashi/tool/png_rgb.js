// PNG から透明度（アルファチャンネル）を外して RGB にする。App Store のアイコンはアルファ付きだと受け付けない
// （ブラウザの canvas は必ず RGBA の PNG を書くので、tool/import_art.js が書いたアイコンはここを通す）。
//   node tool/png_rgb.js <png>   … 上書き。半透明の所は白の上に重ねた色にする
const fs = require('fs'), zlib = require('zlib');
function toRgb(buf){
  if (buf.readUInt32BE(12) !== 0x49484452) throw new Error('PNG ではない');
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20), depth = buf[24], ct = buf[25], inter = buf[28];
  if (ct === 2) return { out: buf, changed: false, minA: 255 };
  if (ct !== 6 || depth !== 8 || inter !== 0) throw new Error(`この形の PNG は扱えない（色の型 ${ct}・${depth}bit・インターレース ${inter}）`);
  const idat = []; let p = 8;
  while (p < buf.length) { const len = buf.readUInt32BE(p), type = buf.toString('ascii', p + 4, p + 8); if (type === 'IDAT') idat.push(buf.subarray(p + 8, p + 8 + len)); p += 12 + len; }
  const raw = zlib.inflateSync(Buffer.concat(idat)), bpp = 4, stride = w * bpp, px = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? px[y * stride + x - bpp] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = y && x >= bpp ? px[(y - 1) * stride + x - bpp] : 0;
      let v = src[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[y * stride + x] = v & 255;
    }
  }
  let minA = 255;
  const rgb = Buffer.alloc(h * (w * 3 + 1));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = y * stride + x * 4, al = px[i + 3]; if (al < minA) minA = al;
    const o = y * (w * 3 + 1) + 1 + x * 3;
    for (let k = 0; k < 3; k++) rgb[o + k] = Math.round(px[i + k] * al / 255 + 255 * (1 - al / 255));
  }
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, 'ascii'), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32 ? zlib.crc32(td) >>> 0 : crc32(td)); return Buffer.concat([len, td, crc]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const out = Buffer.concat([buf.subarray(0, 8), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(rgb, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
  return { out, changed: true, minA };
}
function crc32(b){ let c, crc = 0xffffffff; for (let n = 0; n < b.length; n++) { c = (crc ^ b[n]) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; } return (crc ^ 0xffffffff) >>> 0; }
module.exports = { toRgb };
if (require.main === module) {
  const f = process.argv[2]; if (!f) { console.error('使い方: node tool/png_rgb.js <png>'); process.exit(1); }
  const r = toRgb(fs.readFileSync(f));
  if (r.changed) fs.writeFileSync(f, r.out);
  console.log(`${f}: ${r.changed ? `RGBA → RGB（いちばん薄い所の不透明度 ${r.minA}/255）` : 'もともと RGB'}`);
}
