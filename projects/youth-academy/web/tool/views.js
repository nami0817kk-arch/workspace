// 画面の点検：ブラウザの代わりに jsdom で全画面を作り、例外が出ないか・必要な文字が出るか・操作が効くかを確かめる。
// 見た目（色・配置・絵）は確かめない。そこはブラウザで見る（docs/screens/ に撮った画面を置いてある）。
//   npm install --no-save jsdom && node tool/views.js
'use strict';
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(root, 'src', f), 'utf8');
const html = read('shell.html')
  .replace('/*__CSS__*/', () => read('style.css'))
  .replace('/*__BOOT__*/', '')
  .replace('/*__DATA__*/', () => read('data.js'))
  .replace('/*__ENGINE__*/', () => read('engine.js'))
  .replace('/*__RENDER__*/', () => read('render.js'))
  .replace('/*__UI__*/', () => read('ui.js'));

let fails = 0;
const ok = (c, m) => {
  if (!c) {
    fails++;
    console.log('FAIL:', m);
  }
};
const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'http://localhost/',
  beforeParse(w) {
    // canvas は描かない（描画の呼び出しが落ちないことだけ確かめる）
    const ctx = new Proxy(function () {}, { get: (t, k) => (k === 'measureText' ? () => ({ width: 10 }) : k === 'createLinearGradient' ? () => ({ addColorStop() {} }) : () => {}), set: () => true });
    w.HTMLCanvasElement.prototype.getContext = () => ctx;
    w.addEventListener('error', (e) => errors.push(String(e.error || e.message)));
    const ce = w.console.error;
    w.console.error = (...a) => {
      errors.push(a.join(' '));
      ce(...a);
    };
    w.SVGElement.prototype.getScreenCTM = () => ({ inverse: () => ({}) });
    w.SVGSVGElement.prototype.createSVGPoint = () => ({ x: 0, y: 0, matrixTransform: () => ({ x: 34, y: 60 }) });
  },
});
const w = dom.window;
const d = w.document;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const btn = (t, scope) => [...(scope || d).querySelectorAll('button')].find((b) => b.textContent.includes(t));
const txt = () => d.body.textContent;

(async () => {
  await sleep(100);
  // 試合前
  ok(!!btn('キックオフ'), 'キックオフのボタン');
  ok(txt().includes('港北学院高校') && txt().includes('ブルーウィング東京ユース') && txt().includes('北陵高校'), '相手が3つ');
  ok(d.querySelectorAll('.board svg g').length > 0, '布陣ボードに選手');
  for (const k of ['戦い方', '選手と役割', '相手の分析']) {
    btn(k).click();
    await sleep(20);
  }
  ok(txt().includes('港北学院') && txt().includes('型：'), '相手の分析');
  btn('選手と役割').click();
  ok(txt().includes('特性') && txt().includes('役割'), '選手と役割の表示');
  // 定番の形・型の保存と呼出
  for (const f of ['4-4-2', '3-5-2', '4-2-3-1', '5-3-2', '4-3-3']) {
    btn(f).click();
    ok(d.querySelectorAll('.board svg g').length >= 11, '形を変えても11人 ' + f);
  }
  btn('保存', d.querySelector('.fm-row:last-child')).click();
  btn('呼出').click();
  // 左の縦タブ
  for (const k of ['選手', '練習', 'クラブ', 'ほか', 'ホーム', '試合']) {
    btn(k, d.getElementById('rail')).click();
    await sleep(10);
  }
  btn('選手', d.getElementById('rail')).click();
  ok(txt().includes('裏への抜け出し') && txt().includes('負けず嫌い'), '選手の詳細に特性と性格');
  btn('試合', d.getElementById('rail')).click();

  // 試合中
  btn('キックオフ').click();
  await sleep(300);
  ok(!!d.querySelector('canvas') && !!d.querySelector('.scoreboard'), '試合の画面');
  ok(txt().includes('止める') && txt().includes('自動停止'), '止めるボタンと自動停止');
  btn('見どころ').click();
  btn('止める').click();
  let n = 0;
  while (!d.querySelector('.sheet') && n++ < 100) await sleep(50);
  ok(!!d.querySelector('.sheet'), '止めたら操作パネルが開く');
  for (const k of ['交代', '布陣・役割', '戦い方', '指示', '声かけ']) {
    btn(k, d.querySelector('.sheet')).click();
    await sleep(10);
  }
  // 交代
  btn('交代', d.querySelector('.sheet .tabs')).click();
  [...d.querySelectorAll('.sheet .pitem')].find((b) => b.textContent.includes('鷹村')).click();
  [...d.querySelectorAll('.sheet .pitem')].find((b) => b.textContent.includes('速水')).click();
  btn('交代する').click();
  ok(txt().includes('交代しました'), '交代できる');
  btn('声かけ', d.querySelector('.sheet .tabs')).click();
  btn('激励').click();
  ok(txt().includes('チーム全体に「激励」'), '声かけの反応');
  btn('指示', d.querySelector('.sheet .tabs')).click();
  btn('仕掛けろ').click();
  ok(txt().includes('仕掛けろ'), '指示');
  btn('再開', d.querySelector('.sheet')).click();
  ok(!d.querySelector('.sheet'), '再開でパネルが閉じる');

  // 試合後の画面（エンジンを最後まで回して直接出す）
  const YA = w.YA;
  const m = new YA.Match({ seed: 5, home: YA.makeOurs(1), away: YA.makeOpponent(YA.OPPONENTS[0], 3), settings: { autoStop: false } });
  let e;
  while (!m.finished) e = m.step();
  YA._ui.app.last = { m, summary: e.summary };
  YA._ui.app.view = 'result';
  YA._ui.render();
  ok(txt().includes('見どころ') && txt().includes('気づき') && txt().includes('採点'), '試合後の画面');
  ok(!!btn('同じ設定でもう一度') && !!btn('戦術を直す'), '試合後のボタン');
  ok(txt().includes('特性') || txt().includes('性格'), '特性や性格が効いたことが出る');
  btn('戦術を直す').click();
  ok(!!btn('キックオフ'), '試合前に戻る');

  ok(errors.length === 0, '例外: ' + errors.slice(0, 3).join(' | '));
  console.log(fails ? '失敗 ' + fails : '画面の点検: すべて通過');
  process.exit(fails ? 1 : 0);
})();
