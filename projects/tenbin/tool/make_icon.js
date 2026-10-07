// アプリアイコン（1024×1024、透明なし）を作る。ゲームと同じ字形（TenbinKana）と木の板で描く。
// 使い方: PLAYWRIGHT=<playwright の場所> CHROMIUM=<chromium> node tool/make_icon.js [案の番号]
//   → app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png（案の番号を付けると work/icon-<n>.png）
// App Store のアイコンは透明を受け付けない。最後に白背景で塗りつぶしてから書き出す
var path = require('path'), fs = require('fs');
var pw = require(process.env.PLAYWRIGHT || 'playwright');
var ROOT = path.join(__dirname, '..');
var variant = process.argv[2] ? +process.argv[2] : 1;
var out = process.argv[2] ? path.join(ROOT, 'work', 'icon-' + variant + '.png') : path.join(ROOT, 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png');
var html = '<!doctype html><html><head><link href="file://' + path.join(ROOT, 'prototype/fonts/kana.css') + '" rel="stylesheet"></head><body style="margin:0"><canvas id="c" width="1024" height="1024"></canvas></body></html>';
(async function () {
  var b = await pw.chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  var p = await b.newPage();
  fs.mkdirSync(path.join(ROOT, 'work'), { recursive: true });
  var tmp = path.join(ROOT, 'work', 'icon.html'); fs.writeFileSync(tmp, html);
  await p.goto('file://' + tmp);
  await p.evaluate(function () { return document.fonts.load('900 72px TenbinKana', 'もじつみ'); });
  var data = await p.evaluate(function (v) {
    var c = document.getElementById('c'), g = c.getContext('2d');
    // 夕焼けの空（ゲームの にわ の台と同じ色の流れ）
    var sky = g.createLinearGradient(0, 0, 0, 1024);
    sky.addColorStop(0, '#f4b893'); sky.addColorStop(0.55, '#f8e0c2'); sky.addColorStop(1, '#f8eedc');
    g.fillStyle = sky; g.fillRect(0, 0, 1024, 1024);
    // 遠くの山
    g.fillStyle = 'rgba(196,179,194,.55)'; g.beginPath(); g.moveTo(0, 820);
    for (var x = 0; x <= 1024; x += 16) g.lineTo(x, 760 - 40 * Math.sin(x / 140) - 22 * Math.sin(x / 53 + 1));
    g.lineTo(1024, 1024); g.lineTo(0, 1024); g.closePath(); g.fill();
    // 板
    function plank(y, w) {
      var gr = g.createLinearGradient(0, y - 22, 0, y + 22); gr.addColorStop(0, '#e3ac6c'); gr.addColorStop(1, '#bf7f43');
      g.fillStyle = 'rgba(60,35,10,.18)'; g.fillRect(512 - w / 2 + 8, y - 14, w, 44);
      g.fillStyle = gr; g.beginPath(); g.roundRect(512 - w / 2, y - 22, w, 44, 12); g.fill();
      g.strokeStyle = '#8f5a2a'; g.lineWidth = 5; g.stroke();
    }
    var INK = ['#d9472f', '#e98a1f', '#2f9a5c', '#2f6fc2'];
    function glyph(ch, x, y, a, size, col, glow) {
      g.save(); g.translate(x, y); g.rotate(a);
      g.font = '900 ' + size + 'px TenbinKana'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineJoin = 'round';
      if (glow) { g.shadowColor = 'rgba(255,214,90,.9)'; g.shadowBlur = 60; }
      g.lineWidth = size * 0.05; g.strokeStyle = 'rgba(70,45,20,.6)'; g.strokeText(ch, 0, size * 0.02);
      g.shadowBlur = 0; g.fillStyle = col; g.fillText(ch, 0, 0);
      g.globalAlpha = 0.28; g.fillStyle = '#fff'; g.beginPath(); g.rect(-size, -size, size * 2, size * 0.45); g.clip(); g.fillText(ch, 0, 0);
      g.restore();
    }
    if (v === 1) {   // 2×2 に積んだ も じ / つ み
      plank(850, 860);
      glyph('つ', 330, 670, -0.03, 330, INK[2], 1); glyph('み', 690, 670, 0.04, 330, INK[3], 1);
      glyph('も', 350, 330, 0.06, 330, INK[0], 1); glyph('じ', 700, 340, -0.05, 330, INK[1], 1);
    } else if (v === 2) {   // たてに も・じ と大きく、金の線でつなぐ
      plank(880, 760);
      g.strokeStyle = '#f2b24f'; g.lineWidth = 34; g.lineCap = 'round'; g.beginPath(); g.moveTo(512, 300); g.lineTo(512, 650); g.stroke();
      glyph('も', 512, 300, 0.05, 420, INK[0], 1); glyph('じ', 512, 660, -0.04, 420, INK[1], 1);
    } else {   // 3字を少しずつずらして高く
      plank(900, 700);
      glyph('つ', 470, 735, -0.06, 300, INK[2], 0); glyph('み', 560, 470, 0.08, 300, INK[3], 1); glyph('も', 470, 200, -0.04, 300, INK[0], 1);
    }
    return c.toDataURL('image/png');
  }, variant);
  // 透明をなくす（App Store のアイコンは透明を受け付けない）: JPEG を経ずに、白で塗った上に描き直す
  var buf = Buffer.from(data.split(',')[1], 'base64');
  var PNG = require('pngjs').PNG, png = PNG.sync.read(buf), opaque = new PNG({ width: png.width, height: png.height, colorType: 2 });
  for (var i = 0; i < png.width * png.height; i++) { var a = png.data[i * 4 + 3] / 255; for (var k = 0; k < 3; k++) opaque.data[i * 4 + k] = Math.round(png.data[i * 4 + k] * a + 255 * (1 - a)); opaque.data[i * 4 + 3] = 255; }
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, PNG.sync.write(opaque, { colorType: 2 }));
  fs.unlinkSync(tmp);
  console.log('wrote', path.relative(ROOT, out), png.width + 'x' + png.height);
  await b.close();
})();
