// Gemini の絵（アイコン・タイトル・層の景色）を、ゲームとアプリで使う大きさにして置く。図鑑の絵は tool/cut_sheet.js。
//   node tool/import_art.js <絵のフォルダ>
//   → app/ios/.../AppIcon.appiconset/Icon-1024.png（1024・透明なし）
//     prototype/art/title.jpg（縦長の起動画面）、prototype/art/scene0〜9.jpg（層の景色 960×536）
// どの絵が何かは tool/art_sources.json（ドライブのファイル名の一部 → 役目）。絵を描き直したらそこを書き換える。
const fs = require('fs'), path = require('path');
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }

const dir = process.argv[2];
if (!dir) { console.error('使い方: node tool/import_art.js <絵のフォルダ>'); process.exit(1); }
const ROOT = path.join(__dirname, '..');
const map = JSON.parse(fs.readFileSync(path.join(__dirname, 'art_sources.json'), 'utf8'));
const files = fs.readdirSync(dir).filter(f => /\.(jpe?g|jfif|png|webp)$/i.test(f));
const find = key => { const f = files.find(x => x.includes(key)); if (!f) throw new Error(`${key} の絵がフォルダにない`); return path.join(dir, f); };
const ART = path.join(ROOT, 'prototype', 'art');
fs.mkdirSync(ART, { recursive: true });

// [役目, 出力先, 幅, 高さ, 形式, 品質]
const jobs = [['icon', path.join(ROOT, 'app', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Icon-1024.png'), 1024, 1024, 'image/png', 1],
  ['title', path.join(ART, 'title.jpg'), 768, 1376, 'image/jpeg', 0.84]];
for (let L = 0; L < 10; L++) jobs.push(['scene' + L, path.join(ART, `scene${L}.jpg`), 960, 536, 'image/jpeg', 0.8]);

(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage();
  for (const [role, out, w, h, type, q] of jobs) {
    const src = find(map[role]);
    const url = 'data:image/jpeg;base64,' + fs.readFileSync(src).toString('base64');
    const data = await p.evaluate(async ({ url, w, h, type, q }) => {
      const img = new Image(); img.src = url; await img.decode();
      // 縦横比が違えば真ん中を切り出す（引き伸ばさない）
      const k = Math.max(w / img.naturalWidth, h / img.naturalHeight), sw = w / k, sh = h / k;
      const c = document.createElement('canvas'); c.width = w; c.height = h;
      const x = c.getContext('2d', { alpha: false }); x.imageSmoothingQuality = 'high';
      x.drawImage(img, (img.naturalWidth - sw) / 2, (img.naturalHeight - sh) / 2, sw, sh, 0, 0, w, h);
      return c.toDataURL(type, q);
    }, { url, w, h, type, q });
    fs.writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
    console.log(`${role.padEnd(7)} ${path.relative(ROOT, out)}  ${(fs.statSync(out).size / 1024).toFixed(0)}KB`);
  }
  await b.close();
})();
