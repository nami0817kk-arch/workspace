// 切り抜き写真（背景が透明な PNG）から、当たり判定の輪郭を取り出す
// node tool/trace.js <種類> <PNG> <名前> <ゲーム内の幅px>   … prototype/photos.js に追記・上書き
//   例: node tool/trace.js elephant photos/elephant.png ぞう 118
// 写真は右向きにそろえる。輪郭は不透明度50%の境目、いちばん大きい塊だけを使う
var fs = require('fs'), path = require('path'), PNG = require('pngjs').PNG;
var kind = process.argv[2], file = process.argv[3], name = process.argv[4], width = +process.argv[5];
if (!kind || !file || !name || !width) { console.error('使い方: node tool/trace.js <種類> <PNG> <名前> <幅>'); process.exit(1); }
var png = PNG.sync.read(fs.readFileSync(file)), Wd = png.width, Ht = png.height;
function solid(x, y) { return x >= 0 && y >= 0 && x < Wd && y < Ht && png.data[(y * Wd + x) * 4 + 3] >= 128; }

// いちばん大きい塊を選ぶ（4近傍の塗りつぶし）
var label = new Int32Array(Wd * Ht), best = 0, bestN = 0, id = 0;
for (var y0 = 0; y0 < Ht; y0++) for (var x0 = 0; x0 < Wd; x0++) {
  if (!solid(x0, y0) || label[y0 * Wd + x0]) continue;
  id++; var st = [y0 * Wd + x0], n = 0; label[y0 * Wd + x0] = id;
  while (st.length) { var q = st.pop(), qx = q % Wd, qy = (q / Wd) | 0; n++;
    [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(function (d) { var nx = qx + d[0], ny = qy + d[1];
      if (solid(nx, ny) && !label[ny * Wd + nx]) { label[ny * Wd + nx] = id; st.push(ny * Wd + nx); } }); }
  if (n > bestN) { bestN = n; best = id; }
}
function inside(x, y) { return x >= 0 && y >= 0 && x < Wd && y < Ht && label[y * Wd + x] === best; }

// 輪郭をたどる（ムーア近傍）
var sx = -1, sy = -1;
for (var yy = 0; yy < Ht && sx < 0; yy++) for (var xx = 0; xx < Wd; xx++) if (inside(xx, yy)) { sx = xx; sy = yy; break; }
var DIRS = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];
var pts = [], cx = sx, cy = sy, dir = 6, guard = 0;
do {
  pts.push([cx + 0.5, cy + 0.5]);
  var found = false;
  for (var k = 0; k < 8; k++) { var d = (dir + 6 + k) % 8, nx = cx + DIRS[d][0], ny = cy + DIRS[d][1];
    if (inside(nx, ny)) { cx = nx; cy = ny; dir = d; found = true; break; } }
  if (!found) break;
} while ((cx !== sx || cy !== sy) && ++guard < 1e6);

// ゲーム内の大きさへ。原点は外枠の中心
var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
pts.forEach(function (p) { minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]); minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]); });
var sc = width / (maxX - minX), ox = (minX + maxX) / 2, oy = (minY + maxY) / 2;
var poly = simplify(pts.map(function (p) { return [(p[0] - ox) * sc, (p[1] - oy) * sc]; }), 0.8);
function simplify(P, tol) {
  var keep = P.map(function () { return false; }); keep[0] = keep[P.length - 1] = true;
  (function rdp(a, b) { var A = P[a], B = P[b], dx = B[0] - A[0], dy = B[1] - A[1], L = Math.hypot(dx, dy) || 1, md = 0, mi = -1;
    for (var i = a + 1; i < b; i++) { var dd = Math.abs((P[i][0] - A[0]) * dy - (P[i][1] - A[1]) * dx) / L; if (dd > md) { md = dd; mi = i; } }
    if (md > tol) { keep[mi] = true; rdp(a, mi); rdp(mi, b); } })(0, P.length - 1);
  return P.filter(function (_, i) { return keep[i]; }).map(function (p) { return [+p[0].toFixed(1), +p[1].toFixed(1)]; });
}
var entry = { name: name, img: 'photos/' + path.basename(file), imgRect: [+(-ox * sc).toFixed(1), +(-oy * sc).toFixed(1), +(Wd * sc).toFixed(1), +(Ht * sc).toFixed(1)], poly: poly };

var dir = path.join(__dirname, '../prototype'), json = path.join(dir, 'photos.json'), cur = {};
if (fs.existsSync(json)) cur = JSON.parse(fs.readFileSync(json, 'utf8'));
cur[kind] = entry;
fs.writeFileSync(json, JSON.stringify(cur, null, 1) + '\n');
fs.writeFileSync(path.join(dir, 'photos.js'), '// tool/trace.js が photos.json から生成（手で直さない）。写真の動物は animals.js のシルエットを上書きする\n' +
  'var TenbinPhotos = ' + JSON.stringify(cur) + ';\nif (typeof module !== \'undefined\') module.exports = TenbinPhotos;\n');
console.log(kind, name, poly.length + '点', '高さ', ((maxY - minY) * sc).toFixed(0));
