// Gemini で描いてもらった図鑑の絵（1枚に5種、白い背景）を、1種ずつの PNG に切り分ける。
//   node tool/cut_sheet.js <絵のファイル> <層の番号 0〜9>
//   → prototype/art/items/<id>.webp（192×192、背景は透明。アプリに埋め込むので軽くする）と、確認用の prototype/art/check/_sheet<層>.png（git に入れない）
// 並びは注文書と同じ「上の段 左から3つ → 下の段 左から2つ」＝ ITEMS の順。
// 背景の色は縁から取り、背景とちがう色のかたまりを大きい順に5つ拾う（小さな透かし・ごみは捨てる）。
// 図鑑以外（家宝・売店・仲間）は名前を並び順に渡す:
//   node tool/cut_sheet.js <絵> --names a,b,c --dir heirs [--size 256]  → prototype/art/<dir>/<名前>.webp
//   並びは「上の段から、段の中は左から」。物の大きさがばらばらで段がずれる絵は、確認用の一覧を見て名前の順を合わせる
const fs = require('fs');
const path = require('path');
const vm = require('vm');
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }

const args = process.argv.slice(2), file = args[0];
const opt = k => { const i = args.indexOf('--' + k); return i > 0 ? args[i + 1] : null; };
const SIZE = +(opt('size') || 192), RAD = +(opt('r') || 2), HOLES = args.includes('--holes');   // HOLES: 囲まれた背景（腕と体のすき間など）も抜く。白い物がある絵（真珠・雪花石）には使わない
// RAD: かたまりをつなぐ太らせ方。物どうしが近い絵は 1 か 0
let ids, OUT, L;
if (opt('names')) {
  ids = opt('names').split(','); L = opt('dir') || 'misc';
  OUT = path.join(__dirname, '..', 'prototype', 'art', L);
} else {
  L = Number(args[1]);
  if (!file || !(L >= 0 && L <= 9)) { console.error('使い方: node tool/cut_sheet.js <絵> <層 0〜9>  ／  <絵> --names a,b --dir 置き場 [--size 256]'); process.exit(1); }
  const html = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
  const engine = html.split('/*ENGINE-START*/')[1].split('/*ENGINE-END*/')[0];
  const ctx = {}; vm.createContext(ctx); vm.runInContext(engine + ';this.ITEMS=ITEMS;', ctx);
  ids = ctx.ITEMS.filter(it => it.L === L).map(it => it.id);
  OUT = path.join(__dirname, '..', 'prototype', 'art', 'items');
}
fs.mkdirSync(OUT, { recursive: true });

const mime = /\.jpe?g$/i.test(file) ? 'image/jpeg' : /\.webp$/i.test(file) ? 'image/webp' : 'image/png';
const src = 'data:' + mime + ';base64,' + fs.readFileSync(file).toString('base64');

(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage();
  const res = await p.evaluate(async ({ src, n, SIZE, RAD, HOLES }) => {
    const img = new Image(); img.src = src; await img.decode();
    const W = img.naturalWidth, H = img.naturalHeight;
    const full = document.createElement('canvas'); full.width = W; full.height = H;
    const fx = full.getContext('2d'); fx.drawImage(img, 0, 0);
    const D = fx.getImageData(0, 0, W, H).data;
    // 背景の色：縁の画素の中央値
    const edge = [[], [], []];
    for (let x = 0; x < W; x += 2) for (const y of [1, H - 2]) { const i = (y * W + x) * 4; for (let c = 0; c < 3; c++) edge[c].push(D[i + c]); }
    for (let y = 0; y < H; y += 2) for (const x of [1, W - 2]) { const i = (y * W + x) * 4; for (let c = 0; c < 3; c++) edge[c].push(D[i + c]); }
    const bg = edge.map(a => a.sort((p, q) => p - q)[a.length >> 1]);
    const diff = i => Math.abs(D[i] - bg[0]) + Math.abs(D[i + 1] - bg[1]) + Math.abs(D[i + 2] - bg[2]);
    // 粗い升目で「物がある」所を出し、少し太らせてから、つながったかたまりに分ける
    const S = Math.max(1, Math.round(Math.max(W, H) / 256)), gw = Math.ceil(W / S), gh = Math.ceil(H / S);
    const m = new Uint8Array(gw * gh);
    for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) {
      let hit = 0;
      for (let y = gy * S; y < Math.min(H, gy * S + S); y++) for (let x = gx * S; x < Math.min(W, gx * S + S); x++) if (diff((y * W + x) * 4) > 60) hit++;
      if (hit * 4 >= S * S) m[gy * gw + gx] = 1;
    }
    const R = RAD, md = new Uint8Array(gw * gh);
    for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) if (m[gy * gw + gx])
      for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) { const x = gx + dx, y = gy + dy; if (x >= 0 && y >= 0 && x < gw && y < gh) md[y * gw + x] = 1; }
    const lab = new Int32Array(gw * gh), blobs = [];
    for (let s = 0; s < gw * gh; s++) if (md[s] && !lab[s]) {
      const id = blobs.length + 1, st = [s]; lab[s] = id;
      const bb = { x0: gw, y0: gh, x1: 0, y1: 0, area: 0, id };
      while (st.length) {
        const k = st.pop(), x = k % gw, y = (k / gw) | 0;
        if (m[k]) bb.area++;
        bb.x0 = Math.min(bb.x0, x); bb.y0 = Math.min(bb.y0, y); bb.x1 = Math.max(bb.x1, x); bb.y1 = Math.max(bb.y1, y);
        for (const q of [k - 1, k + 1, k - gw, k + gw]) {
          if (q < 0 || q >= gw * gh || lab[q] || !md[q]) continue;
          if ((q === k - 1 && x === 0) || (q === k + 1 && x === gw - 1)) continue;
          lab[q] = id; st.push(q);
        }
      }
      blobs.push(bb);
    }
    blobs.sort((a, c) => c.area - a.area);
    const found = blobs.length;
    const pick = blobs.slice(0, n).map(bb => ({
      x0: Math.max(0, (bb.x0 - R + 1) * S), y0: Math.max(0, (bb.y0 - R + 1) * S),
      x1: Math.min(W, (bb.x1 + R) * S), y1: Math.min(H, (bb.y1 + R) * S), area: bb.area, id: bb.id,
    }));
    // 並べ替え：上から段に分け、段の中は左から
    pick.forEach(r => { r.cx = (r.x0 + r.x1) / 2; r.cy = (r.y0 + r.y1) / 2; r.h = r.y1 - r.y0; });
    pick.sort((a, c) => a.cy - c.cy);
    const rows = [];
    for (const r of pick) { const row = rows[rows.length - 1]; if (row && r.cy - row[0].cy < row[0].h * 0.6) row.push(r); else rows.push([r]); }
    const ordered = rows.flatMap(row => row.sort((a, c) => a.cx - c.cx));
    // 1種ずつ：正方形に切り、縁からつながった背景だけを透明にして 256 に縮める
    const outs = ordered.map(r => {
      const w = r.x1 - r.x0, h = r.y1 - r.y0, side = Math.round(Math.max(w, h) * 1.08);
      const c = document.createElement('canvas'); c.width = c.height = side;
      const cx = c.getContext('2d');
      cx.fillStyle = 'rgb(' + bg.join(',') + ')'; cx.fillRect(0, 0, side, side);
      cx.drawImage(full, r.x0, r.y0, w, h, Math.round((side - w) / 2), Math.round((side - h) / 2), w, h);
      const id = cx.getImageData(0, 0, side, side), d = id.data;
      const dif = i => Math.abs(d[i] - bg[0]) + Math.abs(d[i + 1] - bg[1]) + Math.abs(d[i + 2] - bg[2]);
      const seen = new Uint8Array(side * side), st = [];
      for (let i = 0; i < side; i++) st.push(i, (side - 1) * side + i, i * side, i * side + side - 1);
      while (st.length) {
        const k = st.pop(); if (seen[k]) continue; seen[k] = 1;
        const v = dif(k * 4); if (v > 90) continue;
        d[k * 4 + 3] = v < 30 ? 0 : Math.round(255 * (v - 30) / 60);
        const x = k % side;
        if (x > 0) st.push(k - 1); if (x < side - 1) st.push(k + 1);
        if (k >= side) st.push(k - side); if (k < side * (side - 1)) st.push(k + side);
      }
      // 囲まれた背景のすき間：背景とほぼ同じ色のひとまとまりが大きければ抜く（小さい白目・光は残す）
      if (HOLES) {
        const lim = side * side * 0.002;
        for (let s0 = 0; s0 < side * side; s0++) {
          if (seen[s0] || dif(s0 * 4) > 24) continue;
          const reg = [s0], q = [s0]; seen[s0] = 1;
          while (q.length) { const k = q.pop(), x = k % side;
            for (const nb of [x > 0 ? k - 1 : -1, x < side - 1 ? k + 1 : -1, k - side, k + side]) {
              if (nb < 0 || nb >= side * side || seen[nb] || dif(nb * 4) > 24) continue;
              seen[nb] = 1; reg.push(nb); q.push(nb);
            } }
          if (reg.length >= lim) for (const k of reg) d[k * 4 + 3] = 0;
        }
      }
      // 隣の物のはみ出し（別のかたまりに属する画素）は消す
      const offX = Math.round((side - w) / 2), offY = Math.round((side - h) / 2);
      for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
        const sx0 = x - offX + r.x0, sy0 = y - offY + r.y0;
        if (sx0 < 0 || sy0 < 0 || sx0 >= W || sy0 >= H) continue;
        const l = lab[Math.floor(sy0 / S) * gw + Math.floor(sx0 / S)];
        if (l && l !== r.id) d[(y * side + x) * 4 + 3] = 0;
      }
      cx.putImageData(id, 0, 0);
      const o = document.createElement('canvas'); o.width = o.height = SIZE;
      const ox = o.getContext('2d'); ox.imageSmoothingQuality = 'high'; ox.drawImage(c, 0, 0, SIZE, SIZE);
      return o;
    });
    // 確認用の一覧（並び順に横一列、市松模様の上）
    const sh = document.createElement('canvas'); sh.width = 192 * Math.max(1, outs.length); sh.height = 192;
    const sx = sh.getContext('2d');
    for (let y = 0; y < 192; y += 16) for (let x = 0; x < sh.width; x += 16) { sx.fillStyle = ((x + y) / 16) % 2 ? '#ddd' : '#fff'; sx.fillRect(x, y, 16, 16); }
    outs.forEach((o, i) => sx.drawImage(o, i * 192, 0));
    return { found, bg, size: [W, H], pngs: outs.map(o => o.toDataURL('image/webp', 0.88)), sheet: sh.toDataURL('image/png') };
  }, { src, n: ids.length, SIZE, RAD, HOLES });
  await b.close();

  const put = (name, url) => fs.writeFileSync(path.join(OUT, name), Buffer.from(url.split(',')[1], 'base64'));
  if (res.pngs.length < ids.length) {
    console.error(`物が ${res.pngs.length} つしか見つからない（要るのは ${ids.length}）。物どうしが重なっていないか確かめる`);
    process.exit(1);
  }
  res.pngs.forEach((u, i) => put(ids[i] + '.webp', u));
  const CHECK = path.join(__dirname, '..', 'prototype', 'art', 'check'); fs.mkdirSync(CHECK, { recursive: true });
  fs.writeFileSync(path.join(CHECK, '_sheet' + L + '.png'), Buffer.from(res.sheet.split(',')[1], 'base64'));
  console.log(`${res.size.join('×')} 背景 rgb(${res.bg}) かたまり ${res.found} → ${ids.join(', ')}`);
  console.log('並びを確かめる: ' + path.join('prototype', 'art', 'check', '_sheet' + L + '.png'));
})();
