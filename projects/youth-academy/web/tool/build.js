// 画面と試合の中身を1枚の HTML にまとめて、アプリ（Flutter）の assets に置く。
'use strict';
const fs = require('fs');
const path = require('path');
const src = (f) => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8');
let html = src('shell.html');
const parts = { CSS: 'style.css', DATA: 'data.js', ENGINE: 'engine.js', LIVE: 'live.js', LIVEMATCH: 'livematch.js', WORLD: 'world.js', LEAGUE: 'league.js', CLUB: 'club.js', SCOUT: 'scout.js', RENDER: 'render.js', UI: 'ui.js', VIEWS: 'views.js', VIEWS2: 'views2.js', EXTRA: 'extra.js', MORE: 'more.js', CORE: 'core.js', VIEWS3: 'views3.js', LINEAGE: 'lineage.js', RIVALS: 'rivals.js', STORY: 'story.js', MEMORY: 'memory.js', CHAINS: 'chains.js', CHAINS2: 'chains2.js', EVENTS2: 'events2.js', STAFF: 'staff.js', SCOUT2: 'scout2.js', CLUB5: 'club5.js', LIFE: 'life.js', FUNC: 'func.js', PRONEWS: 'pronews.js', STARACTS: 'staracts.js', SHOP: 'shop.js', GUIDE: 'guide.js', BODY: 'body.js', POS2: 'pos2.js', TRAITS2: 'traits2.js', PERSONA: 'persona.js', COND2: 'cond2.js', STARS2: 'stars2.js', KADAI: 'kadai.js', KIZUKI: 'kizuki.js', TEAM2: 'team2.js', RECORDS: 'records.js', PAPER: 'paper.js', FINISH: 'finish.js', IMGDATA: 'imgdata.js', ART: 'art.js' };
for (const [k, f] of Object.entries(parts)) html = html.replace(`/*__${k}__*/`, () => src(f).replace(/<\/script>/g, '<\/script>'));
const outs = [path.join(__dirname, '../../app/assets/web/index.html')];
if (process.argv[2]) outs.push(path.resolve(process.argv[2]));
for (const o of outs) {
  fs.mkdirSync(path.dirname(o), { recursive: true });
  fs.writeFileSync(o, html);
  console.log('書き出し', o, (html.length / 1024).toFixed(0) + 'KB');
}
