// 画面と試合の中身を1枚の HTML にまとめて、アプリ（Flutter）の assets に置く。
'use strict';
const fs = require('fs');
const path = require('path');
const src = (f) => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8');
let html = src('shell.html');
const parts = { CSS: 'style.css', DATA: 'data.js', ENGINE: 'engine.js', WORLD: 'world.js', LEAGUE: 'league.js', CLUB: 'club.js', SCOUT: 'scout.js', RENDER: 'render.js', UI: 'ui.js', VIEWS: 'views.js', VIEWS2: 'views2.js' };
for (const [k, f] of Object.entries(parts)) html = html.replace(`/*__${k}__*/`, () => src(f).replace(/<\/script>/g, '<\/script>'));
const outs = [path.join(__dirname, '../../app/assets/web/index.html')];
if (process.argv[2]) outs.push(path.resolve(process.argv[2]));
for (const o of outs) {
  fs.mkdirSync(path.dirname(o), { recursive: true });
  fs.writeFileSync(o, html);
  console.log('書き出し', o, (html.length / 1024).toFixed(0) + 'KB');
}
