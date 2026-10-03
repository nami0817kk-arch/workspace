// 無地の背景（灰色など）で撮った動物の写真から、背景を消してゲーム用の透明 PNG を作る
// node tool/cutout.js <入力 jpg/png> <出力 png> [--flip]
// 背景は「外周の色からなめらかに変わる面」とみなし、そこに近くて模様の無い所を外側から塗りつぶして消す。
// 足元のうすい影も、模様が無ければ背景として消える。
var fs = require('fs'), PNG = require('pngjs').PNG, jpeg = require('jpeg-js');
var src = process.argv[2], dst = process.argv[3], flip = process.argv.indexOf('--flip') > 0;
var MAX = 480;
var buf = fs.readFileSync(src), img = /\.png$/i.test(src) ? PNG.sync.read(buf) : jpeg.decode(buf, { useTArray: true });
var W = img.width, H = img.height, D = img.data, N = W * H;

// 外周から背景の色の面（2次式）を最小二乗で求める
function fitSurface(ch) {
  var A = [], b = [];
  for (var y = 0; y < H; y += 2) for (var x = 0; x < W; x += 2) {
    if (x > 12 && x < W - 13 && y > 12 && y < H - 13) continue;
    var u = x / W - .5, v = y / H - .5; A.push([1, u, v, u * u, v * v, u * v]); b.push(D[(y * W + x) * 4 + ch]);
  }
  var M = [], r = [];
  for (var i = 0; i < 6; i++) { M.push([0, 0, 0, 0, 0, 0]); r.push(0); }
  A.forEach(function (row, k) { for (var i = 0; i < 6; i++) { r[i] += row[i] * b[k]; for (var j = 0; j < 6; j++) M[i][j] += row[i] * row[j]; } });
  for (var c = 0; c < 6; c++) { var p = c; for (var q = c + 1; q < 6; q++) if (Math.abs(M[q][c]) > Math.abs(M[p][c])) p = q;
    var t = M[c]; M[c] = M[p]; M[p] = t; var tr = r[c]; r[c] = r[p]; r[p] = tr;
    for (var q2 = 0; q2 < 6; q2++) if (q2 !== c) { var f = M[q2][c] / M[c][c]; for (var j2 = c; j2 < 6; j2++) M[q2][j2] -= f * M[c][j2]; r[q2] -= f * r[c]; } }
  return r.map(function (v, i) { return v / M[i][i]; });
}
var S = [0, 1, 2].map(fitSurface);
function model(ch, x, y) { var u = x / W - .5, v = y / H - .5, s = S[ch]; return s[0] + s[1] * u + s[2] * v + s[3] * u * u + s[4] * v * v + s[5] * u * v; }

// 明るさの細かい模様（5x5 の標準偏差）
var L = new Float64Array(N), I1 = new Float64Array((W + 1) * (H + 1)), I2 = new Float64Array((W + 1) * (H + 1));
for (var i = 0; i < N; i++) L[i] = .3 * D[i * 4] + .59 * D[i * 4 + 1] + .11 * D[i * 4 + 2];
for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) { var l = L[y * W + x], k = (y + 1) * (W + 1) + x + 1;
  I1[k] = l + I1[k - 1] + I1[k - W - 1] - I1[k - W - 2]; I2[k] = l * l + I2[k - 1] + I2[k - W - 1] - I2[k - W - 2]; }
function tex(x, y) { var r = 2, x0 = Math.max(0, x - r), x1 = Math.min(W, x + r + 1), y0 = Math.max(0, y - r), y1 = Math.min(H, y + r + 1), n = (x1 - x0) * (y1 - y0);
  function q(I) { return I[y1 * (W + 1) + x1] - I[y0 * (W + 1) + x1] - I[y1 * (W + 1) + x0] + I[y0 * (W + 1) + x0]; }
  var m = q(I1) / n; return Math.sqrt(Math.max(0, q(I2) / n - m * m)); }

var cand = new Uint8Array(N);
for (var y2 = 0; y2 < H; y2++) for (var x2 = 0; x2 < W; x2++) {
  var p = (y2 * W + x2) * 4, d = 0, dl = 0;
  for (var c2 = 0; c2 < 3; c2++) { var e = D[p + c2] - model(c2, x2, y2); d = Math.max(d, Math.abs(e)); dl += e / 3; }
  var chroma = Math.max(D[p], D[p + 1], D[p + 2]) - Math.min(D[p], D[p + 1], D[p + 2]), t = tex(x2, y2);
  // 背景そのもの、または模様の無い暗い影
  if ((d < 14 && t < 3.2) || (dl < 0 && dl > -60 && chroma < 18 && t < 3.0)) cand[y2 * W + x2] = 1;
}
// 外周から塗りつぶし
var bg = new Uint8Array(N), st = [];
for (var x3 = 0; x3 < W; x3++) { st.push(x3, (H - 1) * W + x3); }
for (var y3 = 0; y3 < H; y3++) { st.push(y3 * W, y3 * W + W - 1); }
while (st.length) { var q = st.pop(); if (bg[q] || !cand[q]) continue; bg[q] = 1; var qx = q % W, qy = (q / W) | 0;
  if (qx > 0) st.push(q - 1); if (qx < W - 1) st.push(q + 1); if (qy > 0) st.push(q - W); if (qy < H - 1) st.push(q + W); }
// いちばん大きい前景の塊だけ残す
var lab = new Int32Array(N), best = 0, bestN = 0, id = 0;
for (var s0 = 0; s0 < N; s0++) { if (bg[s0] || lab[s0]) continue; id++; var n2 = 0, s2 = [s0]; lab[s0] = id;
  while (s2.length) { var a = s2.pop(), ax = a % W, ay = (a / W) | 0; n2++;
    [ax > 0 ? a - 1 : -1, ax < W - 1 ? a + 1 : -1, ay > 0 ? a - W : -1, ay < H - 1 ? a + W : -1].forEach(function (b2) { if (b2 >= 0 && !bg[b2] && !lab[b2]) { lab[b2] = id; s2.push(b2); } }); }
  if (n2 > bestN) { bestN = n2; best = id; } }
// 縁をなじませる: 1px 削ってから 3x3 でぼかす
var fg = new Float32Array(N);
for (var i2 = 0; i2 < N; i2++) fg[i2] = lab[i2] === best ? 1 : 0;
var er = new Float32Array(N);
for (var y4 = 1; y4 < H - 1; y4++) for (var x4 = 1; x4 < W - 1; x4++) { var k4 = y4 * W + x4;
  er[k4] = fg[k4] && fg[k4 - 1] && fg[k4 + 1] && fg[k4 - W] && fg[k4 + W] ? 1 : 0; }
var al = new Float32Array(N);
for (var y5 = 1; y5 < H - 1; y5++) for (var x5 = 1; x5 < W - 1; x5++) { var s5 = 0;
  for (var dy = -1; dy <= 1; dy++) for (var dx = -1; dx <= 1; dx++) s5 += er[(y5 + dy) * W + x5 + dx]; al[y5 * W + x5] = s5 / 9; }

// 切り出し・縮小・左右反転
var minX = W, maxX = 0, minY = H, maxY = 0;
for (var k5 = 0; k5 < N; k5++) if (al[k5] > 0) { var xx = k5 % W, yy = (k5 / W) | 0; minX = Math.min(minX, xx); maxX = Math.max(maxX, xx); minY = Math.min(minY, yy); maxY = Math.max(maxY, yy); }
var cw = maxX - minX + 1, chh = maxY - minY + 1, sc = Math.min(1, MAX / Math.max(cw, chh));
var ow = Math.round(cw * sc), oh = Math.round(chh * sc), out = new PNG({ width: ow, height: oh });
for (var oy = 0; oy < oh; oy++) for (var ox = 0; ox < ow; ox++) {
  var sx0 = minX + ox / sc, sy0 = minY + oy / sc, sx1 = minX + (ox + 1) / sc, sy1 = minY + (oy + 1) / sc, acc = [0, 0, 0, 0], wsum = 0;
  for (var sy = Math.floor(sy0); sy < Math.ceil(sy1); sy++) for (var sx = Math.floor(sx0); sx < Math.ceil(sx1); sx++) {
    var kk = sy * W + sx, a2 = al[kk]; wsum++; acc[3] += a2; acc[0] += D[kk * 4] * a2; acc[1] += D[kk * 4 + 1] * a2; acc[2] += D[kk * 4 + 2] * a2; }
  var tx = flip ? ow - 1 - ox : ox, o = (oy * ow + tx) * 4;
  if (acc[3] > 0) { out.data[o] = acc[0] / acc[3]; out.data[o + 1] = acc[1] / acc[3]; out.data[o + 2] = acc[2] / acc[3]; }
  out.data[o + 3] = Math.round(255 * acc[3] / wsum);
}
fs.writeFileSync(dst, PNG.sync.write(out));
console.log(dst, ow + 'x' + oh, '前景', (bestN / N * 100).toFixed(1) + '%');
