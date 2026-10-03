// 画面の通し確認：ブラウザで5つの状態を開き、タブ・シート・買い物を一通り押して、エラーが0件かを見る。
//   node tool/smoke.js            … 手元（playwright が入っていれば）
//   CI では npx playwright install chromium のあとに回す
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }
const path = require('path');
const url = 'file://' + path.join(__dirname, '..', 'prototype', 'game.html');
const STATES = {
  はじめて: null,
  中盤: { v:2, depth:93, genDepth:93, best:93, pick:31, ore:52000, w:[14,9,4,1,0,0,0], found:{ kosen:3, doki:2, kugi:1 }, frag:[4,2,0,0,0,0,0,0,0,0] },
  岩盤: { v:2, depth:120, genDepth:120, best:120, pick:20, ore:10, w:[20,10,3,0,0,0,0] },
  代替わりの前: { v:2, depth:250, genDepth:250, best:250, pick:110, ore:1e9, w:[40,30,20,10,5,2,0], gen:2, fame:8, creed:['b'] },
  深層: { v:2, depth:430, genDepth:430, best:430, pick:300, ore:1e15, w:[120,100,90,80,70,60,50], gen:9, fame:3000, creed:['a','b','a','b','a','b'], boostUntil: Date.now() + 3e5, boostLv: 6 },
};
(async () => {
  const b = await pw.chromium.launch();
  let fails = 0;
  for (const [name, st] of Object.entries(STATES)) {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 } });
    await ctx.addInitScript(o => { if (sessionStorage.getItem('s')) return; sessionStorage.setItem('s', 1); localStorage.clear(); if (o) { o.last = Date.now() - 2 * 3600e3; localStorage.setItem('tsuruhashi_v2', JSON.stringify(o)); } }, st);
    const p = await ctx.newPage();
    const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.route(/^https?:/, r => r.abort());   // 外へは読みに行かない（書体など）
    await p.goto(url);
    await p.waitForTimeout(300);
    const click = async sel => p.evaluate(s => { const el = document.querySelector(s); if (el && el.offsetParent !== null && !el.disabled) el.click(); }, sel);
    for (const sel of ['#titleGo', '#offX2', '#offOk', '[data-tab=crew]', '#pCrew [data-bn=max]', '#wB0', '#wB3', '[data-tab=tool]', '#pickBuy', '#adBoost',
      '[data-tab=book]', '[data-item=kosen]', '#itemClose', '[data-appr]', '[data-sell]', '[data-tab=co]', '#rbOpen', '.copt', '#rbCancel', '#setBtn', '#soundBtn', '#ambBtn', '#redBtn', '#setClose']) {
      await click(sel); await p.waitForTimeout(120);
    }
    await p.waitForTimeout(1500);
    const alive = await p.evaluate(() => document.getElementById('sDepth').textContent);
    if (errs.length) { fails++; console.log(`NG ${name}: ${[...new Set(errs)].join(' / ')}`); } else console.log(`ok ${name}（深さ ${alive}）`);
    await ctx.close();
  }
  await b.close();
  if (fails) process.exit(1);
  console.log('\nすべて ok');
})();
