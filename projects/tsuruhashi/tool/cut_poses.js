// 「同じ人の2ポーズ」の絵（振り上げ・振り下ろし）を、足もとをそろえた2枚に切る。
//   node tool/cut_poses.js <絵> <名前> <上げのx,y> <下ろしのx,y> [--flip-down] [--flip-up]
//   → prototype/art/crew/<名前>_up.webp・_down.webp（256×256・背景透明）
// x,y は元の絵での「両足のまん中・足の裏」の座標（目盛りを重ねた絵で測る）。2枚とも同じ大きさの正方形を、
// 足もとを下のふちに合わせて切るので、ゲームで差し替えても人がずれない。向きが逆に描かれた方は --flip-* で左右を返す。
// どちらの人のものかは、足もとの近くのかたまりで決める（隣のポーズのはみ出しは消す）。
const fs = require('fs'), path = require('path');
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }

const [file, name, upArg, dnArg] = process.argv.slice(2);
if (!file || !name || !upArg || !dnArg) { console.error('使い方: node tool/cut_poses.js <絵> <名前> <上げx,y> <下ろしx,y> [--flip-down] [--flip-up]'); process.exit(1); }
const flip = { up: process.argv.includes('--flip-up'), down: process.argv.includes('--flip-down') };
const SIDE = 900, SIZE = 256;   // 元の絵での切り出しの一辺（足もとの上に振り上げたつるはしまで入る大きさ）
const OUT = path.join(__dirname, '..', 'prototype', 'art', 'crew');
fs.mkdirSync(OUT, { recursive: true });
const src = 'data:image/jpeg;base64,' + fs.readFileSync(file).toString('base64');

(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage();
  for (const [k, arg] of [['up', upArg], ['down', dnArg]]) {
    const [ax, ay] = arg.split(',').map(Number);
    const url = await p.evaluate(async ({ src, ax, ay, SIDE, SIZE, flip }) => {
      const img = new Image(); img.src = src; await img.decode();
      const W = img.naturalWidth, H = img.naturalHeight;
      const c0 = document.createElement('canvas'); c0.width = W; c0.height = H;
      const x0 = c0.getContext('2d'); x0.drawImage(img, 0, 0);
      const D = x0.getImageData(0, 0, W, H).data;
      const dif = i => (255 - D[i]) + (255 - D[i + 1]) + (255 - D[i + 2]);   // 白い背景からの離れ具合
      // かたまり分け（4px の升目・2升ぶん太らせる）
      const S = 4, gw = Math.ceil(W / S), gh = Math.ceil(H / S), m = new Uint8Array(gw * gh), md = new Uint8Array(gw * gh);
      for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) {
        let hit = 0; for (let y = gy * S; y < Math.min(H, gy * S + S); y++) for (let x = gx * S; x < Math.min(W, gx * S + S); x++) if (dif((y * W + x) * 4) > 60) hit++;
        if (hit * 4 >= S * S) m[gy * gw + gx] = 1;
      }
      for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) if (m[gy * gw + gx])
        for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) { const x = gx + dx, y = gy + dy; if (x >= 0 && y >= 0 && x < gw && y < gh) md[y * gw + x] = 1; }
      const lab = new Int32Array(gw * gh); let id = 0;
      for (let s0 = 0; s0 < gw * gh; s0++) if (md[s0] && !lab[s0]) { id++; const st = [s0]; lab[s0] = id;
        while (st.length) { const q = st.pop(), x = q % gw; for (const n of [x > 0 ? q - 1 : -1, x < gw - 1 ? q + 1 : -1, q - gw, q + gw]) if (n >= 0 && n < gw * gh && md[n] && !lab[n]) { lab[n] = id; st.push(n); } } }
      // 足もとの少し上にいちばん近いかたまりを、この人とする
      let mine = 0, best = 1e9;
      for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) { const l = lab[gy * gw + gx]; if (!l || !m[gy * gw + gx]) continue;
        const d = Math.hypot(gx * S - ax, gy * S - (ay - 120)); if (d < best) { best = d; mine = l; } }
      // 足もとを下のふちに合わせた正方形に切り、この人以外と背景を透明にする
      const left = Math.round(ax - SIDE / 2), top = Math.round(ay + 20 - SIDE);
      const c = document.createElement('canvas'); c.width = c.height = SIDE;
      const cx = c.getContext('2d'); cx.drawImage(c0, left, top, SIDE, SIDE, 0, 0, SIDE, SIDE);
      const id2 = cx.getImageData(0, 0, SIDE, SIDE), d = id2.data;
      for (let y = 0; y < SIDE; y++) for (let x = 0; x < SIDE; x++) {
        const sx = x + left, sy = y + top, i = (y * SIDE + x) * 4;
        if (sx < 0 || sy < 0 || sx >= W || sy >= H) { d[i + 3] = 0; continue; }
        const l = lab[Math.floor(sy / S) * gw + Math.floor(sx / S)];
        const v = (255 - d[i]) + (255 - d[i + 1]) + (255 - d[i + 2]);
        if (l !== mine) { d[i + 3] = 0; continue; }
        if (v < 24) d[i + 3] = 0; else if (v < 70) d[i + 3] = Math.round(255 * (v - 24) / 46);
      }
      cx.putImageData(id2, 0, 0);
      const o = document.createElement('canvas'); o.width = o.height = SIZE;
      const ox = o.getContext('2d'); ox.imageSmoothingQuality = 'high';
      if (flip) { ox.translate(SIZE, 0); ox.scale(-1, 1); }
      ox.drawImage(c, 0, 0, SIZE, SIZE);
      return o.toDataURL('image/webp', 0.9);
    }, { src, ax, ay, SIDE, SIZE, flip: flip[k] });
    const out = path.join(OUT, `${name}_${k}.webp`);
    fs.writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
    console.log(path.relative(path.join(__dirname, '..'), out), (fs.statSync(out).size / 1024).toFixed(0) + 'KB');
  }
  await b.close();
})();
