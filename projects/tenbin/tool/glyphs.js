// ひらがなの字形から当たり判定の輪郭を取り、prototype/glyphs.js に書く
// node tool/glyphs.js   （playwright が要る。字形は prototype/fonts の M PLUS Rounded 1c Black）
var path = require('path'), fs = require('fs');
var { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
var KANA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん';
var SIZE = 72;   // ゲーム内の字の大きさ（px）
var R = 300;     // 輪郭を取るときの字の大きさ
(async function () {
  var b = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  var p = await b.newPage();
  var dir = path.join(__dirname, '../prototype');
  fs.writeFileSync(path.join(dir, '_glyph_tmp.html'), '<link rel=stylesheet href="fonts/kana.css"><body>' + '<span style="font:900 20px TenbinKana">' + KANA + '</span>');
  await p.goto('file://' + path.join(dir, '_glyph_tmp.html'));
  // 分割されたフォントは字ごとに読み込まれる。全部の字を読み込んでから輪郭を取る
  await p.evaluate(function (K) { return Promise.all(K.split('').map(function (ch) { return document.fonts.load('900 300px TenbinKana', ch); })); }, KANA);
  var out = await p.evaluate(function (a) {
    var KANA = a[0], SIZE = a[1], R = a[2], N = R * 2, res = {};
    var cv = document.createElement('canvas'); cv.width = cv.height = N; var g = cv.getContext('2d');
    for (var ci = 0; ci < KANA.length; ci++) {
      var ch = KANA[ci];
      g.clearRect(0, 0, N, N); g.fillStyle = '#000'; g.font = '900 ' + R + 'px TenbinKana'; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(ch, N / 2, N / 2);
      var d = g.getImageData(0, 0, N, N).data, lab = new Int32Array(N * N), comps = [], id = 0;
      var solid = function (x, y) { return x >= 0 && y >= 0 && x < N && y < N && d[(y * N + x) * 4 + 3] >= 128; };
      for (var y0 = 0; y0 < N; y0++) for (var x0 = 0; x0 < N; x0++) {
        if (!solid(x0, y0) || lab[y0 * N + x0]) continue;
        id++; var st = [y0 * N + x0], n = 0; lab[y0 * N + x0] = id;
        while (st.length) { var q = st.pop(), qx = q % N, qy = (q / N) | 0; n++;
          [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(function (dd) { var nx = qx + dd[0], ny = qy + dd[1];
            if (solid(nx, ny) && !lab[ny * N + nx]) { lab[ny * N + nx] = id; st.push(ny * N + nx); } }); }
        comps.push({ id: id, n: n, sx: x0, sy: y0 });
      }
      var total = comps.reduce(function (s, c) { return s + c.n; }, 0), polys = [];
      comps.forEach(function (c) {
        if (c.n < total * 0.01) return;
        var inside = function (x, y) { return x >= 0 && y >= 0 && x < N && y < N && lab[y * N + x] === c.id; };
        var DIRS = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];
        var pts = [], cx = c.sx, cy = c.sy, dir = 6, guard = 0;
        do { pts.push([cx + .5, cy + .5]); var f = false;
          for (var k = 0; k < 8; k++) { var dd = (dir + 6 + k) % 8, nx = cx + DIRS[dd][0], ny = cy + DIRS[dd][1];
            if (inside(nx, ny)) { cx = nx; cy = ny; dir = dd; f = true; break; } }
          if (!f) break; } while ((cx !== c.sx || cy !== c.sy) && ++guard < 1e6);
        var keep = pts.map(function () { return false; }); keep[0] = keep[pts.length - 1] = true;
        (function rdp(a, b) { var A = pts[a], B = pts[b], dx = B[0] - A[0], dy = B[1] - A[1], L = Math.hypot(dx, dy) || 1, md = 0, mi = -1;
          for (var i = a + 1; i < b; i++) { var e = Math.abs((pts[i][0] - A[0]) * dy - (pts[i][1] - A[1]) * dx) / L; if (e > md) { md = e; mi = i; } }
          if (md > 2.5) { keep[mi] = true; rdp(a, mi); rdp(mi, b); } })(0, pts.length - 1);
        var s = SIZE / R;
        polys.push(pts.filter(function (_, i) { return keep[i]; }).map(function (q) { return [+((q[0] - N / 2) * s).toFixed(1), +((q[1] - N / 2) * s).toFixed(1)]; }));
      });
      res[ch] = polys;
    }
    return res;
  }, [KANA, SIZE, R]);
  fs.unlinkSync(path.join(dir, '_glyph_tmp.html'));
  fs.writeFileSync(path.join(dir, 'glyphs.js'), '// tool/glyphs.js が生成（手で直さない）。ひらがなの当たり判定の輪郭。字の中心が原点、大きさ ' + SIZE + 'px\n' +
    'var TenbinGlyphs = ' + JSON.stringify({ size: SIZE, font: 'TenbinKana', chars: out }) + ';\nif (typeof module !== \'undefined\') module.exports = TenbinGlyphs;\n');
  Object.keys(out).forEach(function (ch) { process.stdout.write(ch + out[ch].length + ' '); }); console.log();
  await b.close();
})();
