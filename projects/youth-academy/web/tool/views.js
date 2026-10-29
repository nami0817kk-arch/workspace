// 画面の点検：ブラウザの代わりに jsdom で全画面を作り、例外が出ないか・必要な文字が出るか・操作が効くかを確かめる。
// 見た目（色・配置・絵）は確かめない。そこはブラウザで見る。
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
  .replace('/*__WORLD__*/', () => read('world.js'))
  .replace('/*__LEAGUE__*/', () => read('league.js'))
  .replace('/*__CLUB__*/', () => read('club.js'))
  .replace('/*__SCOUT__*/', () => read('scout.js'))
  .replace('/*__RENDER__*/', () => read('render.js'))
  .replace('/*__UI__*/', () => read('ui.js'))
  .replace('/*__VIEWS__*/', () => read('views.js'))
  .replace('/*__VIEWS2__*/', () => read('views2.js'));

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
const btn = (t, scope) => [...(scope || d).querySelectorAll('button')].find((b) => b.textContent.includes(t) && !b.disabled);
const txt = () => d.body.textContent;
const rail = (k) => btn(k, d.getElementById('rail')).click();

// 出来事が出ていたら、最初の選択肢で全部片付ける
async function clearEvents() {
  let n = 0;
  while (d.querySelector('.sheet') && n++ < 10) {
    const s = d.querySelector('.sheet');
    const opts = [...s.querySelectorAll('button.btn')].filter((b) => !/次へ|閉じる|卒業|新しい年度/.test(b.textContent));
    const next = btn('次へ', s) || btn('閉じる', s) || btn('新しい年度へ', s);
    if (next) next.click();
    else if (opts.length) opts[0].click();
    await sleep(10);
  }
}

(async () => {
  await sleep(100);
  const A = w.YA._ui.app;
  // 年度はじめ：クラブの目標と約束事
  ok(txt().includes('クラブの目標') && txt().includes('この1年を始める') && txt().includes('易しく'), '年度はじめの目標の画面');
  btn('遅刻をしない').click();
  btn('この1年を始める').click();
  ok(!d.querySelector('.sheet') && A.w.rules.length === 1 && !A.w.yearIntro, '目標と約束事を決めて始める');
  // ホーム
  ok(txt().includes('1年目') && txt().includes('4月第1週') && txt().includes('リーグ'), 'ホームに年と週');
  ok(!!btn('練習を確定して週を進める') && !!btn('練習を組む'), 'ホームの操作');
  ok(txt().includes('今週気にかけたい子') && txt().includes('お知らせ'), 'ホームの欄');
  // 練習
  rail('練習');
  ok(['月', '火', '水', '木', '金'].every((x) => txt().includes(x)) && txt().includes('重点にする能力'), '練習の曜日と表');
  btn('月').click?.();
  const dayBtns = [...d.querySelectorAll('#main button.card')];
  ok(dayBtns.length === 5, '曜日のカード');
  dayBtns[0].click();
  ok(txt().includes('曜日のメニュー'), 'メニューの選択');
  btn('フィジカル').click();
  ok(txt().includes('フィジカル'), 'メニューを替えられる');
  btn('おまかせ').click();
  btn('疲れている子を休ませる').click();
  // 重点・特性練習の選択
  const focusBtn = [...d.querySelectorAll('#main .pitem button')].find((b) => b.textContent.includes('未設定') || true);
  focusBtn.click();
  ok(txt().includes('重点（今の値）'), '重点の選択');
  btn('閉じる').click();
  // 選手
  rail('選手');
  ok(txt().includes('面談') && txt().includes('特性') && txt().includes('性格'), '選手の詳細');
  btn('褒める').click();
  ok(txt().includes('自信'), '面談の反応');
  btn('GK', d.querySelector('.fm-row')).click();
  btn('怪我', d.querySelector('.fm-row')).click();
  btn('全員', d.querySelector('.fm-row')).click();
  btn('Bに回す') || btn('Aに上げる');
  rail('クラブ');
  ok(txt().includes('信頼度') && txt().includes('今年の目標'), 'クラブの概要');
  for (const k of ['予算と施設', 'スタッフ', 'スカウト', '順位と日程', '概要']) {
    btn(k).click();
    await sleep(10);
    if (k === '予算と施設') ok(txt().includes('今年の予算') && txt().includes('施設レベル'), '予算の画面');
    if (k === 'スタッフ') ok(txt().includes('技術コーチ') && txt().includes('スタッフ候補'), 'スタッフの画面');
    if (k === 'スカウト') ok(txt().includes('来年の入団予定'), 'スカウトの画面');
    if (k === '順位と日程') ok(txt().includes('全国リーグ') || txt().includes('地域リーグ') || txt().includes('県リーグ'), '順位表');
  }
  rail('ほか');
  btn('記録').click();
  ok(txt().includes('主な記録') && txt().includes('リーグの履歴'), '記録の画面');
  btn('設定').click();
  btn('卒業生名鑑').click();

  // 選手のいない出来事（クラブの要望・スタッフの引き抜き）でも、画面が開いて選べる
  for (const [id, x] of [['club', 0], ['club', 1], ['club', 2], ['poach', 0]]) {
    A.w.phase = 'event';
    A.w.events = [{ id, pid: null, x, week: A.w.week, year: A.w.year }];
    rail('ホーム');
    ok(!!d.querySelector('.sheet') && txt().includes('出来事'), '選手のいない出来事の画面が開く ' + id + x);
    const o1 = [...d.querySelectorAll('.sheet button.btn')][0];
    o1.click();
    await sleep(10);
    ok(!!btn('閉じる', d.querySelector('.sheet')), '選んだあとの画面 ' + id + x);
    btn('閉じる', d.querySelector('.sheet')).click();
    ok(A.w.phase === 'match' || A.w.phase === 'after', '片付けたら先へ進める ' + id + x);
  }
  A.w.phase = 'plan';
  rail('ホーム');

  // 1週目：練習を確定 → 出来事 → 試合
  rail('ホーム');
  btn('練習を確定して週を進める').click();
  await sleep(20);
  await clearEvents();
  ok(A.w.phase === 'match', '出来事のあとは試合 ' + A.w.phase);
  ok(txt().includes('試合へ'), '試合へのボタン');
  btn('試合へ（').click();
  ok(txt().includes('キックオフ') && txt().includes('vs') && txt().includes('全シミュレーション'), '今週の試合の前の画面');
  for (const k of ['戦い方', '選手と役割', '相手の分析']) {
    btn(k).click();
    await sleep(10);
  }
  for (const f of ['4-4-2', '3-5-2', '4-2-3-1', '5-3-2', '4-3-3']) {
    btn(f).click();
    ok(d.querySelectorAll('.board svg g').length >= 11, '形を変えても11人 ' + f);
  }
  btn('保存', d.querySelector('.fm-row:last-child')).click();
  btn('呼出').click();

  // 試合中
  btn('キックオフ').click();
  await sleep(300);
  ok(!!d.querySelector('canvas') && !!d.querySelector('.scoreboard'), '試合の画面');
  ok(txt().includes('止める') && txt().includes('自動停止') && txt().includes('結果まで'), '止めるボタン・自動停止・結果まで');
  btn('見どころ').click();
  btn('止める').click();
  let n = 0;
  while (!d.querySelector('.sheet') && n++ < 100) await sleep(50);
  ok(!!d.querySelector('.sheet'), '止めたら操作パネルが開く');
  for (const k of ['交代', '布陣・役割', '戦い方', '指示', '声かけ']) {
    btn(k, d.querySelector('.sheet')).click();
    await sleep(10);
  }
  btn('交代', d.querySelector('.sheet .tabs')).click();
  const items = [...d.querySelectorAll('.sheet .pitem')];
  items[10].click();
  items.filter((b) => b.querySelector('.pos.FW'))[3].click();
  btn('交代する').click();
  btn('声かけ', d.querySelector('.sheet .tabs')).click();
  btn('激励').click();
  ok(txt().includes('チーム全体に「激励」'), '声かけの反応');
  btn('再開', d.querySelector('.sheet')).click();
  ok(!d.querySelector('.sheet'), '再開でパネルが閉じる');
  btn('結果まで').click();
  ok(txt().includes('見どころ') && txt().includes('気づき') && txt().includes('採点'), '試合後の画面');
  ok(A.w.phase === 'after' && A.w.rec.w + A.w.rec.d + A.w.rec.l === 1, '試合の結果が名簿の世界に入る');
  btn('ホームへ（次の週へ）').click();
  ok(txt().includes('次の週へ') && txt().includes('試合が終わりました'), '試合後のホーム');
  btn('次の週へ').click();
  ok(A.w.week === 2 && A.w.phase === 'plan', '次の週へ進む');

  // 試合のない週：1年を最後まで進めて、卒業式と入学
  A.w.week = 40;
  YA_startEnd();
  async function YA_startEnd() {
    rail('ホーム');
    btn('練習を確定して週を進める').click();
    await sleep(20);
    await clearEvents();
    ok(A.w.phase === 'after', '試合のない週 ' + A.w.phase);
    btn('卒業式へ').click();
    await sleep(20);
    ok(txt().includes('卒業式') && A.w.year === 2 && A.w.week === 1, '卒業式で次の年へ');
    ok(txt().includes('今年の評価'), '卒業式に年末の評価が出る');
    btn('新しい年度へ').click();
    ok(txt().includes('伸ばす力を1つ選んでください'), '指導者の成長の選択');
    btn('教える力').click();
    ok(txt().includes('2年目の始まり'), '次の年の目標の画面');
    btn('この1年を始める').click();
    ok(txt().includes('2年目'), '2年目のホーム');
    rail('ほか');
    btn('卒業生名鑑').click();
    ok(d.querySelectorAll('#main .pitem').length >= 12, '卒業生が名鑑に並ぶ');
    // フリー対戦（成績に残らない）
    rail('選手');
    ok(txt().includes('キャプテン') && txt().includes('ポジション'), '選手にキャプテンとポジション変更');
    btn('キャプテンにする').click();
    ok(A.w.captain != null, 'キャプテンを指名');
    rail('試合');
    ok(txt().includes('キックオフ'), '試合の前の画面');
    ok(errors.length === 0, '例外: ' + errors.slice(0, 3).join(' | '));
    console.log(fails ? '失敗 ' + fails : '画面の点検: すべて通過');
    process.exit(fails ? 1 : 0);
  }
})();
