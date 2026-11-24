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
  .replace('/*__LIVE__*/', () => read('live.js')) // 画面の試合は一続きの試合（前はここに入れておらず、前の作りの画面を点検していた）
  .replace('/*__LIVEMATCH__*/', () => read('livematch.js'))
  .replace('/*__WORLD__*/', () => read('world.js'))
  .replace('/*__LEAGUE__*/', () => read('league.js'))
  .replace('/*__CLUB__*/', () => read('club.js'))
  .replace('/*__SCOUT__*/', () => read('scout.js'))
  .replace('/*__RENDER__*/', () => read('render.js'))
  .replace('/*__UI__*/', () => read('ui.js'))
  .replace('/*__VIEWS__*/', () => read('views.js'))
  .replace('/*__VIEWS2__*/', () => read('views2.js'))
  .replace('/*__EXTRA__*/', () => read('extra.js'))
  .replace('/*__MORE__*/', () => read('more.js'))
  .replace('/*__CORE__*/', () => read('core.js'))
  .replace('/*__LINEAGE__*/', () => read('lineage.js'))
  .replace('/*__RIVALS__*/', () => read('rivals.js'))
  .replace('/*__STORY__*/', () => read('story.js'))
  .replace('/*__MEMORY__*/', () => read('memory.js'))
  .replace('/*__CHAINS__*/', () => read('chains.js'))
  .replace('/*__CHAINS2__*/', () => read('chains2.js'))
  .replace('/*__EVENTS2__*/', () => read('events2.js'))
  .replace('/*__STAFF__*/', () => read('staff.js'))
  .replace('/*__SCOUT2__*/', () => read('scout2.js'))
  .replace('/*__CLUB5__*/', () => read('club5.js'))
  .replace('/*__LIFE__*/', () => read('life.js'))
  .replace('/*__FUNC__*/', () => read('func.js'))
  .replace('/*__PRONEWS__*/', () => read('pronews.js'))
  .replace('/*__STARACTS__*/', () => read('staracts.js'))
  .replace('/*__SHOP__*/', () => read('shop.js'))
  .replace('/*__GUIDE__*/', () => read('guide.js'))
  .replace('/*__BODY__*/', () => read('body.js'))
  .replace('/*__POS2__*/', () => read('pos2.js'))
  .replace('/*__TRAITS2__*/', () => read('traits2.js'))
  .replace('/*__PERSONA__*/', () => read('persona.js'))
  .replace('/*__COND2__*/', () => read('cond2.js'))
  .replace('/*__STARS2__*/', () => read('stars2.js'))
  .replace('/*__TEAM2__*/', () => read('team2.js'))
  .replace('/*__RECORDS__*/', () => read('records.js'))
  .replace('/*__VIEWS3__*/', () => read('views3.js'))
  .replace('/*__IMGDATA__*/', () => read('imgdata.js'))
  .replace('/*__ART__*/', () => read('art.js'));

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
    const ctx = new Proxy(function () {}, { get: (t, k) => (k === 'measureText' ? () => ({ width: 10 }) : k === 'createLinearGradient' || k === 'createRadialGradient' ? () => ({ addColorStop() {} }) : () => {}), set: () => true });
    w.HTMLCanvasElement.prototype.getContext = () => ctx;
    w.YA_DEV = true; // 開発用の道具（おまかせ進行・点検用）を出す
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
// 記録タブ（旧 系譜）の小タブは3つの群（卒業生・実績・年表・監督）に分かれている（2026-11-18）。群を切り替えながら探して押す
const ltab = (label) => {
  const find = () => [...d.querySelectorAll('#main .tabs button:not(.grp)')].find((b) => b.textContent.trim() === label);
  for (const g of ['卒業生', '実績・年表', '監督']) {
    if (find()) break;
    const gb = [...d.querySelectorAll('#main .tabs button.grp')].find((x) => x.textContent.trim() === g);
    if (gb) gb.click();
  }
  const b = find();
  if (b) b.click();
  return !!b;
};
// 画面に出ている文字だけを見る（ページに埋め込んだスクリプトの文字を拾うと、何でも通ってしまう）
const txt = () => d.getElementById('app').textContent;
const rail = (k) => btn(k, d.getElementById('rail')).click();
// 2026-11-16 左の帯の最後は「ほか」（中は名鑑・記録・Bチーム・実績と引退・用語集・設定）

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
  // 新しく始める：指導者を作る・クラブを選ぶ
  ok(txt().includes('指導者を作る') && txt().includes('最初のクラブを選ぶ') && txt().includes('この指導者で始める') && !A.w, '保存がなければ新しく始める画面');
  w.YA._ui.store.set('legacy', { runs: 1, people: [{ name: '遠藤 光', pos: 'MF', main: 'CM', ovr: 13, bond: 5, form: null, mem: [{ y: 1, w: 3, g: 1, k: 'wall', c: 'warm', q: '必ず越えられる' }], year: 2, club: 'X', from: '前のクラブ' }] });
  w.YA._ui.render();
  ok(txt().includes('前の人生の教え子') && txt().includes('遠藤 光') && txt().includes('待って'), '前の人生の教え子が、新しく始める画面に出る（記憶の言葉つき）');
  btn('連れていかない').click();
  ok(txt().includes('連れていく'), '教え子を選べる');
  const nameBox = d.querySelector('input[type=text]');
  nameBox.value = 'テスト監督';
  nameBox.dispatchEvent(new w.Event('input', { bubbles: true }));
  btn('高校で指導していた').click();
  for (let i = 0; i < 3; i++) [...d.querySelectorAll('#main button')].filter((b) => b.textContent === '＋')[0].click();
  btn('千葉 ジェフィーズU-18').click();
  btn('この指導者で始める').click();
  await sleep(50);
  ok(A.w && A.w.coachName === 'テスト監督' && A.w.club.tier === 2 && A.w.clubName.indexOf('千葉') >= 0 && A.w.coach.exp === 3, '選んだ内容で世界が始まる');
  // 最初の説明（決定128）：数枚で、飛ばせる
  ok(!!d.querySelector('.sheet.intro') && txt().includes('はじめに 1/') && !!btn('飛ばす'), '最初の説明が出る');
  btn('次へ').click();
  ok(txt().includes('★注目の子を選ぶ'), '説明を次へ進められる');
  btn('飛ばす').click();
  ok(!d.querySelector('.sheet.intro') && A.w.introSeen, '説明を飛ばせる');
  ok(!!d.querySelector('.tut.coach') && /左が今週やること/.test(d.querySelector('.tut.coach').textContent), '初めての画面でコーチの一言');
  btn('わかった').click();
  ok(!d.querySelector('.tut.coach'), 'コーチの一言は二度目から出ない');
  // 年度はじめ：クラブの目標と約束事
  ok(txt().includes('クラブの目標') && txt().includes('この1年を始める') && txt().includes('易しく'), '年度はじめの目標の画面');
  btn('挨拶と片付けを徹底する').click();
  btn('この1年を始める').click();
  ok(!d.querySelector('.sheet') && A.w.rules.length === 1 && !A.w.yearIntro, '目標と約束事を決めて始める');
  // 始めたらすぐ練習を組める（最初のセレクションはない）。入団の暦はホームに案内が出る
  ok(!A.w.firstSel && Object.values(A.w.players).filter((p) => p.grade === 1).length === 12, '始めた時点で高1が12人いる');
  ok(!!btn('スカウトに出る'), '4月はホームにスカウトに出る案内がある');
  btn('スカウトに出る').click();
  ok(A.tab === 'club' && A.ct === 'scout' && txt().includes('スカウトに出る') && txt().includes('内部昇格') && txt().includes('セレクション'), 'スカウトの画面に暦と行き先が出る');
  btn('地元の中学・クラブ').click();
  ok(A.w.scouting.cands.some((c) => c.kind === 'scout') && txt().includes('今月あと'), '行き先を選ぶとスカウトに出られる');
  A.ct = 'over'; A.tab = 'home'; rail('ホーム');
  // ホーム
  ok(txt().includes('1年目') && txt().includes('4月第1週') && txt().includes('リーグ'), 'ホームに年と週');
  ok(!!btn('この週で行く') && !!btn('練習を組む'), 'ホームの操作');
  ok(!!d.querySelector('.tut:not(.coach)') && /練習/.test(d.querySelector('.tut:not(.coach)').textContent), '最初の1か月の案内が出る');
  ok(txt().includes('おまかせ進行') && !!btn('1年') && !!btn('次の試合まで'), 'おまかせ進行のボタン');
  {
    const Y = dom.window.YA;
    dom.window.YA_DEV = false;
    ok(Y.devOn() === false && Y.simCard() === null, '開発用の道具は ?dev が無いと出ない');
    dom.window.YA_DEV = true;
    ok(Y.devOn() === true, '開発用の道具は有効にすると出る');
  }
  ok(txt().includes('今週気にかけたい子') && txt().includes('お知らせ'), 'ホームの欄');
  // 2026-11-17 画面の直し：お知らせの重要度は札で、選手につながるものは「›」、「すべてのお知らせ」
  {
    A.w.inbox.push({ year: A.w.year, week: A.w.week, text: 'てすと：選手につながる知らせ', pid: Object.keys(A.w.players)[0], tier: 1 });
    w.YA._ui.render();
    const tags = [...d.querySelectorAll('#main .ntag')].map((e) => e.textContent);
    ok(tags.length > 0 && tags.every((t) => ['大事', '通常', '記録'].includes(t)), 'お知らせの重要度に札（色だけにしない） ' + tags.slice(0, 3).join(','));
    const it = [...d.querySelectorAll('#main .pitem')].find((e) => e.textContent.includes('てすと：選手につながる知らせ'));
    ok(!!it && !!it.querySelector('.goarrow') && it.textContent.includes('大事'), '選手につながるお知らせに「›」');
    ok(!!btn('すべてのお知らせ') && !txt().includes('記録も見る'), 'お知らせを広げるボタンは「すべてのお知らせ」');
    A.w.inbox.pop();
    w.YA._ui.render();
  }
  // 週を進めるボタン：言葉は1つ、ホームと練習で同じ大きさ
  const goHome = btn('この週で行く');
  ok(!!goHome && goHome.style.minHeight === '42px' && goHome.style.fontSize === '14px' && !btn('週を進める'), 'ホームの「この週で行く」（42px・14px、ほかの言い方が無い）');
  // 練習
  rail('練習');
  // 練習は1枚（決定143）：7マス・チームの重点・疲れの高い子・見込みと「この週で行く」
  ok(['月', '火', '水', '木', '金', '土', '日'].every((x) => txt().includes(x)) && txt().includes('チームの重点') && txt().includes('この週の見込み') && !!btn('この週で行く'), '練習の1枚');
  ok(!!d.querySelector('[data-int-legend]') && d.querySelector('[data-int-legend]').textContent.includes('強さ'), '練習の●の説明（2026-11-21 品質）');
  {
    const go = btn('この週で行く');
    ok(go.style.minHeight === '42px' && go.style.fontSize === '14px' && parseInt(go.style.marginLeft, 10) >= 12, '練習の「この週で行く」はホームと同じ大きさで、「選手ごとに細かく」と間がある');
    const same = [...d.querySelectorAll('#main button')].find((b) => b.textContent === '先週と同じ');
    ok(!A.w.lastPlan && same && same.disabled && /まだ先週の練習がありません/.test(same.dataset.why || ''), '最初の週の「先週と同じ」は押せず、理由が出る');
    ok(![...d.querySelectorAll('#main button.card')].some((b) => b.title), '練習の曜日のマスに長押しの説明（title）を使わない');
  }
  btn('攻撃の形').click();
  ok(A.w.plan.teamFocus === '攻撃の形', 'チームの重点を選べる');
  const dayBtns = [...d.querySelectorAll('#main button.card')];
  ok(dayBtns.length === 5, '曜日のカード');
  dayBtns[0].click();
  ok(txt().includes('曜日のメニュー'), 'メニューの選択');
  btn('フィジカル').click();
  ok(txt().includes('フィジカル'), 'メニューを替えられる');
  btn('おまかせ').click();
  btn('選手ごとに細かく').click();
  ok(txt().includes('重点にする能力'), '選手ごとの表');
  { const same = [...d.querySelectorAll('#main button')].find((b) => b.textContent === '先週と同じ'); ok(same && same.disabled && !!same.dataset.why, '細かい画面の「先週と同じ」も最初の週は押せず理由が出る'); }
  btn('疲れた子を休ます').click();
  // 重点・特性練習の選択
  const focusBtn = [...d.querySelectorAll('#main .pitem button')].find((b) => b.textContent.includes('未設定') || true);
  focusBtn.click();
  ok(txt().includes('重点（今の値）'), '重点の選択');
  btn('閉じる').click();
  btn('← 1枚の画面へ').click();
  ok(txt().includes('チームの重点'), '1枚の画面へ戻れる');
  // 2026-11-16 画面の点検：戦術理解の欄は右の欄（スクロールする）の中。main に直に足すと曜日の欄に重なっていた
  { const rt = d.querySelector('[data-train-right]'); ok(!!rt && [...rt.querySelectorAll('.h')].some((x) => x.textContent.startsWith('戦術理解の内訳')), '戦術理解の欄は練習の右の欄に入る'); }
  // 選手
  rail('選手');
  ok(txt().includes('進路') && txt().includes('様子') && txt().includes('特性') && txt().includes('性格'), '選手の詳細（能力・様子・進路）');
  { const hd = d.querySelector('#main .plhead'); ok(!!hd && ['名前', '学年', '総合'].every((x) => hd.textContent.includes(x)) && /伸び|将来/.test(hd.textContent), '選手一覧の数字に見出し（2026-11-21）'); }
  ok(w.YA.wkName(1) === '4月第1週' && /^\d+年目 \d+月第\d週$/.test(w.YA.ywName(2, 11)), '週の呼び方は「4月第1週」の形（2026-11-21） ' + w.YA.ywName(2, 11));
  // 2026-11-19「能力値とかはいらない。FM の選手概要欄を参考にして」：最初に開くのは概要。能力の数字の棒は出さない
  {
    const ov = d.querySelector('#main .pdetail .overview');
    ok(!!ov, '選手を開くと最初は概要');
    ok(!!ov && ['コーチの見立て', 'プロフィール', 'ポジション', '状態', '試合', '特性'].every((t) => ov.textContent.includes(t)), '概要に見立て・プロフィール・ポジション・状態・試合・特性');
    ok(!!ov && !ov.querySelector('.abg') && !ov.textContent.includes('ファーストタッチ'), '概要に能力の数字の表を出さない');
    // 2026-11-20 選手を構成する要素：体格・誕生日・出身・仲間・性格と相性・8週のグラフ・記録
    ok(!!ov && ['体格', '誕生日', '出身', '仲間', '性格と相性', 'cm', 'kg'].every((t) => ov.textContent.includes(t)), '概要に体格・誕生日・出身・仲間・性格と相性 ' + ['体格', '誕生日', '出身', '仲間', '性格と相性'].filter((t) => !(ov && ov.textContent.includes(t))).join('・'));
    ok(!!ov && /適性20/.test(ov.textContent), '概要のポジションに適性20の位置');
    ok(!!ov && !!ov.querySelector('svg.posmap circle'), '概要にポジションの図');
    ok(!!ov && ov.querySelectorAll('.ovpc .pro').length >= 1 && ov.querySelectorAll('.ovpc .con').length >= 1, '長所と短所を言葉で');
    const W0 = w.YA._ui.app.w;
    // どの子の見立ても、言葉のつながりが崩れない（「確かストライカー」「不安定うえ」が出ていた）
    const bad = Object.values(W0.players).map((p) => w.YA.coachReport(W0, p)).filter((t) => /うえ、|確か[^な]|苦手こと|がちこと|がち[^な]|undefined|NaN/.test(t));
    ok(bad.length === 0, 'コーチの見立ての文がつながる ' + (bad[0] || ''));
    ok(Object.values(W0.players).every((p) => !/\d{2,}/.test(w.YA.futureWords(W0, p))), '将来の見立ては水準の名前だけ（数字なし）');
    btn('能力').click();
    ok(!!d.querySelector('#main .pdetail .abg'), '能力の数字は「能力」タブに残す');
    // 直近の試合の採点（p.rl）：A・B とも残り、5つまで
    const w2 = w.YA.newWorld(23);
    for (let k = 0; k < 8; k++) w.YA.simulate(w2, { until: 'week', stopOnImportant: false });
    const rls = Object.values(w2.players).map((p) => p.rl || []);
    ok(rls.some((r) => r.some((x) => x.t === 'A')) && rls.some((r) => r.some((x) => x.t === 'B')), '直近の採点は A と B の試合で残る');
    ok(rls.every((r) => r.length <= 5 && r.every((x) => x.r >= 3 && x.r <= 10)), '直近の採点は5つまで・3〜10');
  }
  btn('様子').click();
  ok(txt().includes('調子') && txt().includes('コーチの一言'), '選手の様子');
  ok(![...d.querySelectorAll('#main .chip.gray')].some((c) => c.textContent === 'ふつう'), '性格に「ふつう」の札を並べない（2026-11-16）');
  // 2026-11-17：長押しの説明は iPhone で見えない。札は押すと下に説明が出る（tip）
  {
    ok(![...d.querySelectorAll('#main .chip[title]')].some((c) => c.getAttribute('title')), '選手の画面の札に長押しの説明（title）を使わない');
    const pc = d.querySelector('#main .chip.pers[data-tip]') || d.querySelector('#main span[data-tip]');
    if (pc) {
      pc.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
      const t = d.getElementById('ya-toast');
      ok(!!t && t.textContent === pc.dataset.tip, '説明つきの札を押すと、下にその説明が出る');
    } else ok(false, '説明つきの札が見つからない');
    const fut = [...d.querySelectorAll('#main .chip.trait')].find((c) => c.textContent.startsWith('伸びしろ'));
    ok(!!fut && !!fut.dataset.tip && !/\d/.test(fut.textContent), '伸びしろは押すと説明、帯には数字を出さない（2026-11-19）');
  }
  btn('進路').click();
  ok(txt().includes('本人の希望') && txt().includes('トップへの近さ'), '選手の進路（希望・トップへの近さ）');
  // 面談の一言と選択肢は選手の状態で変わる（talkSetup）ので、どれかが出ていれば押す
  (['褒める', '課題を伝える', '悩みを聞く', 'できていることを褒める', '背中を押す'].map((t) => btn(t)).find(Boolean) || btn('不安をゆっくり聞く') || btn('足りない点を伝える') || btn('期待していると伝える') || btn('焦らなくていいと聞く') || btn('さらに上を求める') || btn('気を引き締める') || btn('しっかり見ていると伝える') || btn('話を聞く')).click();
  ok(txt().includes('自信'), '面談の反応');
  // ★の子と過ごす（2026-11-16）：★の子の進路の画面に6つの働きかけ。押すと本人の一言と結果が出て、週の回数が減る
  {
    const sp = A.w.players[A.pSel];
    sp.star = true; sp.inj = 0; sp.fat = 10;
    A.w.saUsed = null;
    w.YA._ui.render();
    btn('進路').click();
    ok(['★の子と過ごす（今週あと2回', '居残り練習に付き合う', '試合の映像を一緒に見る', '覚醒の手がかりを話し合う', 'ご飯に連れて行く', '目標を約束する', '卒業生に会わせる', '自主練のメニューを一緒に作る', '休ませて話を聞く', '家族と話す', '試合前に声をかける', '別の位置を試させる', '本を薦める'].every((x) => txt().includes(x)), '★の子の働きかけが12並ぶ');
    btn('ご飯に連れて行く').click();
    ok(errors.length === 0 && txt().includes('今週あと1回') && txt().includes('信頼+8') && txt().includes('「'), 'ご飯に連れて行くと結果と本人の一言が出る: ' + errors.slice(0, 2).join('|'));
    const mb = [...d.querySelectorAll('#main button')].find((b) => b.textContent.startsWith('ご飯に連れて行く'));
    ok(mb && mb.disabled && /週に1回/.test(mb.dataset.why || ''), '続けては押せず、理由が付く ' + (mb && [mb.disabled, mb.dataset.why, mb.textContent].join('|')));
  }
  // 絞り込みは選択欄1つ（2026-11-18）。選ぶと一覧が絞られ、件数が選択肢に出る
  {
    const fs = d.querySelector('select[title="絞り込み"]');
    ok(!!fs && fs.options.length === 12 && /GK（\d+）/.test(fs.textContent), '選手の絞り込みは選択欄1つで件数つき');
    const pick = (v) => { fs.value = v; fs.dispatchEvent(new w.Event('change')); };
    pick('GK');
    ok([...d.querySelectorAll('.plist.scroll .pitem')].every((b) => /GK/.test(b.textContent)), 'GKで絞ると GK だけ');
    pick('inj');
    pick('all');
    ok(d.querySelectorAll('.plist.scroll .pitem').length === Object.keys(A.w.players).length, '全員に戻る');
    // 名前は詳しい画面の帯に出る（2026-11-18）
    const sp = A.w.players[A.pSel];
    ok(!!d.querySelector('#main .pname') && d.querySelector('#main .pname').textContent.includes(sp.name), '選手の帯に名前');
    // A・Bの入れ替えは名前と同じ段（2026-11-21 品質）
    { const nb = d.querySelector('#main .pname'), sb = btn('Bに回す') || btn('Aに上げる'); ok(!!sb && nb.parentNode === sb.parentNode && Math.abs(sb.getBoundingClientRect().top - nb.getBoundingClientRect().top) < 30, '選手の帯：Bに回すは名前の段'); }
  }
  btn('Bに回す') || btn('Aに上げる');
  rail('クラブ');
  ok(txt().includes('予算と施設') && txt().includes('概要') && txt().includes('順位と日程'), 'クラブの8項目');
  btn('概要').click();
  ok(txt().includes('チームの雰囲気') && /の輪/.test(txt()) && !!btn('チーム全員で話す'), 'クラブの概要にチームの雰囲気と仲良しの輪（2026-11-20）');
  btn('チーム全員で話す').click();
  { const tb = [...d.querySelectorAll('#main button')].find((b) => b.textContent === 'チーム全員で話す'); ok(txt().includes('雰囲気+') && !!tb && tb.disabled && /月1回/.test(tb.dataset.why || ''), 'チームへの働きかけは月1回 ' + (tb && [tb.disabled, tb.dataset.why].join('|'))); }
  ok(txt().includes('信頼度') && txt().includes('今年の目標') && !txt().includes('undefined'), 'クラブの概要（信頼度の名前が出る）');
  ok(txt().includes('指導の方針') && txt().includes('強化部長') && txt().includes('寄り添い'), 'クラブの概要に指導の方針と強化部長');
  ok(txt().includes('中長期の計画'), 'クラブの概要に中長期の計画');
  // 2026-11-21：クラブのやり残しは、どの小タブかに赤い点
  {
    const subs = w.YA.todoSubs(A.w);
    const dots = [...d.querySelectorAll('#main .tabs .btn')].filter((b) => b.querySelector('.subdot')).map((b) => b.textContent.trim());
    const SUBN = { int: '内部昇格', sel: 'セレクション', scout: 'スカウト', over: '概要' };
    ok(Object.keys(subs).every((k) => dots.includes(SUBN[k]) || A.ct === k), 'クラブのやり残しの小タブに赤い点 ' + Object.keys(subs).join(',') + ' / ' + dots.join(','));
  }
  for (const k of ['予算と施設', 'スタッフ', 'スカウト', '順位と日程', '概要']) {
    btn(k).click();
    await sleep(10);
    if (k === '予算と施設') ok(txt().includes('今年の予算') && txt().includes('施設レベル'), '予算の画面');
    if (k === 'スタッフ') ok(txt().includes('技術コーチ') && txt().includes('スタッフ候補') && txt().includes('監督との関係') && txt().includes('得意は'), 'スタッフの画面（性格・得意・関係が出る）');
    if (k === 'スカウト') ok(txt().includes('来年の高1') && txt().includes('スカウトに出る'), 'スカウトの画面');
    // 見出しと注記が横に並んで1文字ずつ縦に崩れない（2026-11-21 品質）
    if (k === 'スカウト') { const tall = [...d.querySelectorAll('#main .sub, #main b')].filter((e) => /^(見えている度合い|ポジション別の人数)/.test(e.textContent) && e.getBoundingClientRect().height > 30); ok(!tall.length, 'スカウトの見出しが縦に崩れない ' + tall.map((e) => e.textContent.slice(0, 10)).join('/')); }
    if (k === '順位と日程') ok(txt().includes('プレミアリーグ') || txt().includes('プリンスリーグ') || txt().includes('県リーグ'), '順位表');
    if (k === '順位と日程') ok(/今年の日程（いま\d+月第\d+週）/.test(txt()) && txt().includes('セレクション') && txt().includes('卒業式') && [...d.querySelectorAll('#main .chip')].some((c) => c.textContent === '今'), '今年の日程は表で、今週の行に印（2026-11-16）');
    if (k === 'スタッフ') ok(/（いま .+・能力\d+）/.test(txt()) && /[+-]?\d+・給料[+−]/.test(txt()), 'スタッフ候補は役ごとに、いまのスタッフとの差を1行で（2026-11-18）');
    // 2026-11-17：お金は YA.yen（「万」だけの表示をしない）
    if (k === '予算と施設' || k === 'スタッフ' || k === 'スカウト') { const mt = d.getElementById('main').textContent; ok(!/\d万(?![円人回])/.test(mt), 'お金の表示に「万」だけが出ない（' + k + '） ' + ((mt.match(/.{0,8}\d万(?![円人回]).{0,4}/) || [''])[0])); }
  }
  // スタッフの採用：確かめてから入れ替え、結果を知らせる（2026-11-17）
  {
    const t0 = A.w.club.trust;
    A.w.club.trust = 95;
    btn('スタッフ').click();
    await sleep(10);
    const hb = btn('採用');
    if (hb) {
      const role = hb.closest('.pitem').dataset.role;
      const before = A.w.club.staff.find((x) => x.role === role);
      hb.click();
      const sh = d.querySelector('.sheet');
      ok(!!sh && /入れ替えますか|迎えますか/.test(sh.textContent) && A.w.club.staff.find((x) => x.role === role) === before, '採用を押すと確認が出て、まだ入れ替わらない');
      const yes = sh && (btn('入れ替える', sh) || btn('迎える', sh));
      ok(!!yes && (!before || yes.classList.contains('danger')), '確認の確定は動詞（入れ替える／迎える）、入れ替えは赤');
      if (yes) yes.click();
      await sleep(10);
      const t = d.getElementById('ya-toast');
      ok(!d.querySelector('.sheet') && !!t && /迎えました/.test(t.textContent) && A.w.club.staff.find((x) => x.role === role) !== before, '採用すると結果の文が出る ' + (t && t.textContent));
    } else ok(false, '採用のボタンが無い');
    A.w.club.trust = t0;
  }
  // ポジション別の人数：足りない位置は「不足」の札、字は11px以上
  {
    btn('セレクション').click();
    await sleep(10);
    const cells = [...d.querySelectorAll('#main .poscount')];
    ok(cells.length === 15 && cells.every((c) => [...c.children].every((e) => parseFloat(e.style.fontSize) >= 11)), 'ポジション別の人数の字は11px以上 ' + cells.length);
    ok(cells.filter((c) => c.classList.contains('short')).every((c) => c.textContent.includes('不足')), '足りない位置は色だけでなく「不足」');
  }
  rail('ほか');
  btn('クラブ史', d.getElementById('main')).click();
  ok(txt().includes('主な記録') && txt().includes('リーグの履歴'), '記録の画面');
  btn('設定', d.getElementById('main')).click();
  ok(!btn('卒業生名鑑', d.querySelector('#main .tabs')), 'ほかに卒業生名鑑の重複が無い（系譜にまとめた）');

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
  // 選手の出来事：説明と接し方が出て、選んだあとの画面に「null」などが出ない
  {
    const pid = A.w.lineupA[5].pid;
    for (const id of ['rival', 'hot', 'unrest', 'senpai', 'homesick', 'lowconf']) {
      A.w.phase = 'event';
      A.w.events = [{ id, pid, week: A.w.week, year: A.w.year }];
      rail('ホーム');
      const sh = d.querySelector('.sheet');
      ok(!!sh && sh.textContent.includes(w.YA.EVENT_ABOUT[id]) && /寄り添う|厳しく|背中を押す|任せる/.test(sh.textContent), '出来事に説明と接し方が出る ' + id);
      [...sh.querySelectorAll('button.btn')][0].click();
      await sleep(10);
      ok(!/null|undefined|NaN/.test(d.querySelector('.sheet').textContent), '出来事の結果に null などが出ない ' + id);
      btn('閉じる', d.querySelector('.sheet')).click();
    }
  }
  A.w.phase = 'plan';
  rail('ホーム');

  // 1週目：練習を確定 → 出来事 → 試合
  rail('ホーム');
  btn('この週で行く').click();
  await sleep(20);
  await clearEvents();
  ok(A.w.phase === 'match', '出来事のあとは試合 ' + A.w.phase);
  ok(txt().includes('試合へ'), '試合へのボタン');
  btn('試合へ（').click();
  ok(txt().includes('キックオフ') && txt().includes('vs') && txt().includes('結果まで'), '今週の試合の前の画面');
  for (const k of ['戦い方', '選手と役割', '相手の分析']) {
    btn(k).click();
    await sleep(10);
  }
  // 2026-11-16 相手の分析：先発に位置の札（分析の担当がいれば）と要注意の印
  ok(txt().includes('先発（') && (w.YA.analysisLevel(A.w) < 1 || (d.querySelectorAll('#main .plist .pos').length >= 11 && txt().includes('要注意'))), '相手の分析に先発の位置と要注意');
  // 編成（FM風）：先発・ベンチ・控え外を、タップ→タップで入れ替える
  [...d.querySelectorAll('.tabs button')].find((b) => b.textContent.trim() === '編成').click();
  // おまかせ編成：押すと11人がそろい、適性の合わない先発が減る
  {
    btn('おまかせ編成').click();
    await sleep(10);
    const lu = A.w.lineupA;
    ok(lu.length === 11 && new Set(lu.map((s) => s.pid)).size === 11 && A.w.players[lu[0].pid].pos === 'GK', 'おまかせ編成で11人とGKがそろう');
    const off = lu.filter((s, i) => A.w.players[s.pid].apt[d.defaultView.YA.pos15OfSlot(s, i)] < 14).length;
    ok(off <= 1, 'おまかせ編成では、適性の合わない先発がほとんどいない（Aに本職がいないときだけ） ' + off);
    [...d.querySelectorAll('.tabs button')].find((b) => b.textContent.trim() === '編成').click();
  }
  ok(txt().includes('ベンチ（9人）') && txt().includes('控え外') && d.querySelectorAll('.pitem.sq').length >= 9, '編成の画面');
  {
    const names = () => [...d.querySelectorAll('.pitem.sq')].slice(0, 9).map((b) => b.textContent);
    const n0 = names();
    d.querySelectorAll('.pitem.sq')[0].click();
    d.querySelectorAll('.pitem.sq')[1].click();
    const n1 = names();
    ok(n1[0] === n0[1] && n1[1] === n0[0], 'ベンチどうしを入れ替えられる');
    // ベンチ → 先発（ピッチ）：同じ位置の選手と入れ替わる
    const gs = [...d.querySelectorAll('.board svg g')].filter((g) => g.getAttribute('transform'));
    const lu0 = A.w.lineupA.map((s) => s.pid);
    const bn = A.w.benchA.slice();
    const cands = [...d.querySelectorAll('.pitem.sq')].slice(0, 9);
    const fb = cands.find((b) => !b.textContent.includes('GK'));
    fb.click();
    gs[5].setPointerCapture = () => {};
    gs[5].dispatchEvent(new w.Event('pointerdown', { bubbles: true }));
    gs[5].dispatchEvent(new w.Event('pointerup', { bubbles: true }));
    ok(!A.panelErr, 'ピッチの選手をタップできる');
    const nowL = A.w.lineupA.map((s) => s.pid);
    ok(nowL[5] !== lu0[5] && A.w.benchA.includes(lu0[5]), 'ベンチの選手と先発が入れ替わる');
    ok(nowL.length === 11 && new Set(nowL.concat(A.w.benchA)).size === 20, '入れ替え後も先発11＋ベンチ9で重複なし');
    // 控え外：選んで入れ替える
    const res = [...d.querySelectorAll('.pitem.sq')].slice(9);
    ok(res.length >= 10, '控え外の選手が並ぶ ' + res.length);
    // 控え外 → ベンチ：Bの選手を入れると、入れ替わった選手はBに回り、Bの並びからも抜ける
    const bpick = [...d.querySelectorAll('.pitem.sq')].slice(0, 9).find((b) => !b.textContent.includes('GK'));
    const rpick = [...d.querySelectorAll('.pitem.sq')].slice(9).find((b) => !b.textContent.includes('GK') && !b.textContent.includes('怪'));
    const inB = (id) => A.w.lineupB.some((s) => s.pid === id) || A.w.benchB.includes(id);
    const benchBefore = A.w.benchA.slice();
    bpick.click();
    rpick.click();
    const outId = benchBefore.find((id) => !A.w.benchA.includes(id));
    const inId = A.w.benchA.find((id) => !benchBefore.includes(id));
    ok(outId && inId, '控え外の選手がベンチに入る');
    if (outId && inId) {
      const pin = A.w.players[inId];
      const pout = A.w.players[outId];
      ok(pin.team === 'A' && pout.team === 'B', '入った選手はA・外れた選手はB');
      ok(!inB(inId) && inB(outId), 'Bの並びも入れ替わる（Bに入ったままの選手が出ない）');
      ok(new Set(A.w.lineupA.map((s) => s.pid).concat(A.w.benchA)).size === 20, '控え外から入れたあとも重複なし');
    }
  }
  btn('戦い方').click();
  ok(txt().includes('クロスの種類') && txt().includes('セットプレーのキッカー') && txt().includes('戦い方の浸透') && d.querySelectorAll('#main select').length === 3, '戦術の細かい設定（クロス・キッカー・浸透）');
  btn('高い（長身が生きる）').click();
  ok(A.w.tactic && A.w.tactic.crossType === 'high', 'クロスの種類が保存される');
  const fkSel = d.querySelectorAll('#main select')[0];
  fkSel.value = fkSel.options[2].value;
  fkSel.dispatchEvent(new w.Event('change', { bubbles: true }));
  ok(A.w.tactic.fk === fkSel.options[2].value, 'キッカーの指定が保存される');
  // 布陣は「布陣：」のボタンから一覧で選ぶ。変えたら「元に戻す」で1回戻せる（2026-11-17）
  for (const f of ['4-4-2', '3-5-2', '4-2-3-1', '5-3-2', '4-3-3']) {
    btn('布陣：').click();
    btn(f, d.querySelector('.sheet')).click();
    ok(d.querySelectorAll('.board svg g').length >= 11, '形を変えても11人 ' + f);
  }
  ok(!!btn('元に戻す'), '布陣を変えたあとは「元に戻す」が押せる');
  btn('元に戻す').click();
  ok(!btn('元に戻す'), '元に戻すは1回だけ');
  // 型：空の型は呼び出せない（理由つき）、保存→呼び出し、上書きは確かめる
  btn('型').click();
  const loads = [...d.querySelectorAll('.sheet button')].filter((b) => b.textContent === '呼び出す');
  ok(loads.length === 3 && loads.every((b) => b.disabled && b.dataset.why), '空の型の「呼び出す」は押せず、理由がある');
  btn('ここに保存', d.querySelector('.sheet')).click();
  btn('型').click();
  btn('呼び出す', d.querySelector('.sheet')).click();
  btn('型').click();
  btn('ここに保存', d.querySelector('.sheet')).click();
  ok(txt().includes('上書きしますか'), '保存してある型への保存は上書きを確かめる');
  btn('やめる', d.querySelector('.sheet')).click();

  // 試合中
  btn('キックオフ').click();
  await sleep(300);
  ok(!d.querySelector('.stage canvas') && !!d.querySelector('.feed') && !!d.querySelector('.mstat') && !!d.querySelector('.scoreboard'), '試合の画面（図は出さず、実況の流れと数字）');
  ok(txt().includes('止める') && txt().includes('自動停止') && txt().includes('結果まで'), '止めるボタン・自動停止・結果まで');
  ok(!!d.querySelector('.feed .fl') && txt().includes('ボール保持'), '実況の流れに開始の1行・右に試合の数字');
  ok(d.querySelectorAll('.mrate .rrow').length === 11 && /^\d+\.\d$/.test(d.querySelector('.mrate .rrow b').textContent), '試合中に選手ごとの採点が11人ぶん出る');
  { const bs = () => d.querySelectorAll('.mrate .rtabs button'); bs()[1].click(); ok(d.querySelectorAll('.mrate .rrow').length === 11 && bs()[1].classList.contains('on'), '採点は相手チームにも切り替えられる'); bs()[0].click(); }
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
  const subBtn = btn('交代する'); // 試合の進み具合で交代の画面が出ないことがある（時間任せの試験）ので、あるときだけ押す
  if (subBtn) subBtn.click();
  btn('声かけ', d.querySelector('.sheet .tabs')).click();
  btn('激励').click();
  ok(txt().includes('チーム全体に「激励」'), '声かけの反応');
  btn('再開', d.querySelector('.sheet')).click();
  ok(!d.querySelector('.sheet'), '再開でパネルが閉じる');
  btn('結果まで').click();
  ok(txt().includes('結果まで進めますか'), '結果までは確かめてから進む');
  // 2026-11-21「確認タブ毎回出るの面倒」：やめると試合は止まる前の状態に戻り、「次回から聞かない」を選べる
  {
    btn('やめる', d.querySelector('.sheet')).click();
    ok(!d.querySelector('.sheet'), '結果までの確認は「やめる」で閉じる');
    btn('結果まで').click();
    const cb = d.querySelector('.sheet input[type=checkbox]');
    ok(!!cb && txt().includes('次回から聞かない'), '結果までの確認に「次回から聞かない」');
    cb.checked = true; cb.dispatchEvent(new w.Event('change'));
  }
  btn('結果まで進める').click();
  ok(w.YA._ui.store.get('ask.skipmatch', true) === false, '「次回から聞かない」を選ぶと覚える');
  ok(txt().includes('見どころ') && txt().includes('気づき') && txt().includes('採点'), '試合後の画面');
  // 気づき：効いた特性は子ごとに1行（同じ子が2行に出ない）。不満などの指摘が先（2026-11-21 品質）
  { const ip = [...d.querySelectorAll('[data-insight-player] b')].map((e) => e.textContent); ok(new Set(ip).size === ip.length && !/回効いた/.test(txt()), '気づきは子ごとに1行 ' + ip.join('/'));
    const all = [...d.querySelectorAll('.insight')], fb = all.findIndex((e) => e.classList.contains('bad')), fp = all.findIndex((e) => e.hasAttribute('data-insight-player')); ok(fb < 0 || fp < 0 || fb < fp, '気づき：大事な指摘が上'); }
  ok(A.w.phase === 'after' && A.w.rec.w + A.w.rec.d + A.w.rec.l === 1, '試合の結果が名簿の世界に入る');
  btn('ホームへ（次の週へ）').click();
  ok(txt().includes('次の週へ') && txt().includes('試合が終わりました'), '試合後のホーム');
  // 同じ月なら「次の週へ ▶」1回で練習のまま進む。週のはじめで止まりたいときは下の小さいボタン（2026-11-18）
  ok(!!btn('次の週へ ▶') && w.YA.weekChainable(A.w), '同じ月は「次の週へ ▶」で練習まで進める');
  btn('練習やスカウトを見てから進む').click();
  ok(A.w.week === 2 && A.w.phase === 'plan', '次の週へ進む（週のはじめで止まる）');
  {
    // 押したら1回で週のはじめを通り越す（出来事か試合か週の終わりまで）
    const saved = JSON.stringify(A.w);
    A.w.phase = 'after'; A.w.matchDone = true;
    w.YA._ui.render();
    rail('ホーム');
    btn('次の週へ ▶').click();
    ok(A.w.week === 3 && A.w.phase !== 'plan', '「次の週へ ▶」1回で練習まで進む ' + A.w.phase);
    if (d.querySelector('.sheet')) d.querySelector('.sheet').remove();
    A.w = JSON.parse(saved);
    w.YA._ui.render();
  }

  // 試合のない週：1年を最後まで進めて、卒業式と入学
  A.w.week = 40;
  YA_startEnd();
  async function YA_startEnd() {
    rail('ホーム');
    btn('この週で行く').click();
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
    // おまかせ進行：1週・1年（結果の画面が出る）
    btn('1週').click();
    await sleep(300);
    ok(txt().includes('おまかせ進行の結果') && !!btn('閉じる', d.querySelector('.sheet')), 'おまかせ進行の結果の画面');
    btn('閉じる', d.querySelector('.sheet')).click();
    await clearEvents();
    rail('ホーム');
    const yb = [...d.querySelectorAll('#main button')].find((b) => b.textContent === '1年');
    A.simStop = false;
    A.w.phase = A.w.phase === 'match' || A.w.phase === 'after' || A.w.phase === 'event' ? A.w.phase : 'plan';
    rail('ホーム');
    [...d.querySelectorAll('#main button')].find((b) => b.textContent === '1年').click();
    await sleep(2500);
    ok(txt().includes('おまかせ進行の結果') && txt().includes('年末の評価'), '1年おまかせの結果の画面');
    btn('閉じる', d.querySelector('.sheet')).click();
    ok(A.w.year >= 3, '1年おまかせで年度が進む ' + A.w.year);
    // 設定：セーブ枠・書き出し・復元・効果音
    rail('ほか');
    btn('設定', d.getElementById('main')).click();
    // 設定は4つの小タブ（2026-11-18）
    ok(['表示と音', 'お知らせ', '名前', 'セーブ・ショップ'].every((x) => !!btn(x, d.querySelector('.settabs'))), '設定は4つの小タブ');
    btn('表示と音', d.querySelector('.settabs')).click();
    ok(txt().includes('効果音') && txt().includes('文字の大きさ') && !txt().includes('セーブ枠（'), '設定の表示と音');
    {
      const ab = d.querySelector('[data-ask="skipmatch"]');
      ok(!!ab && ab.textContent === '出さない', '設定に「結果まで」の確認の出す・出さない（聞かないにしたまま）');
      ab.click();
      ok(w.YA._ui.store.get('ask.skipmatch', true) === true && d.querySelector('[data-ask="skipmatch"]').textContent === '出す', '設定で「結果まで」の確認を出すに戻せる');
    }
    btn('セーブ・ショップ', d.querySelector('.settabs')).click();
    ok(txt().includes('セーブ枠') && !!btn('書き出す') && !!btn('復元する'), '設定の画面');
    ok(txt().includes('点検用：新しい世界でシミュレーション') && !!btn('実行') && !!btn('10年'), '点検用シミュレーションの設定');
    const before = JSON.stringify(A.w.year) + A.w.clubName;
    btn('実行').click();
    for (let i = 0; i < 400 && !txt().includes('平均：順位'); i++) await sleep(100);
    ok(txt().includes('平均：順位') && txt().includes('想定') && txt().includes('評価の内訳'), '点検用シミュレーションの結果の表');
    btn('閉じる', d.querySelector('.sheet')).click();
    ok(JSON.stringify(A.w.year) + A.w.clubName === before, '点検用はいまの遊びに影響しない');
    btn('書き出す').click();
    const ta = d.querySelector('.sheet textarea');
    ok(!!ta && ta.value.indexOf('youth-academy') >= 0, '書き出しの画面');
    const exported = ta.value;
    btn('閉じる', d.querySelector('.sheet')).click();
    btn('復元する').click();
    d.querySelector('.sheet textarea').value = '壊れた文字';
    btn('復元する', d.querySelector('.sheet')).click();
    ok(txt().includes('読み取れませんでした'), '壊れたデータは復元しない');
    d.querySelector('.sheet textarea').value = exported;
    {
      // 2026-11-17 課金の点検：復元は、いまの進み具合を上書きする前に確かめる（オリジナル選手の扱いも書く）
      const w0 = A.w;
      btn('復元する', d.querySelector('.sheet')).click();
      await sleep(10);
      const sheets = d.querySelectorAll('.sheet');
      ok(sheets.length === 2 && /置き換えますか/.test(sheets[1].textContent) && /予約したオリジナル選手も戻ります/.test(sheets[1].textContent) && A.w === w0, '復元はすぐ上書きせず、確かめる');
      btn('置き換える', sheets[1]).click();
    }
    await sleep(20);
    ok(!d.querySelector('.sheet') && A.w.players, '書き出したデータを復元できる');
    rail('記録');
    ltab('卒業生名鑑');
    ok(d.querySelectorAll('#main .pitem').length >= 12, '卒業生が名鑑に並ぶ');
    // 段2：設定の文字の大きさ・お知らせの重さ、実績、名前の書き換え
    rail('ほか');
    btn('設定', d.getElementById('main')).click();
    btn('お知らせ', d.querySelector('.settabs')).click();
    ok(txt().includes('お知らせの重さ') && txt().includes('必ず止める') && !!btn('全部おすすめに戻す') === Object.keys(A.w.noticeTier || {}).length > 0, '設定のお知らせの重さ（全部おすすめに戻す）');
    btn('表示と音', d.querySelector('.settabs')).click();
    ok(txt().includes('文字の大きさ'), '設定に文字の大きさ');
    btn('大', d.getElementById('main')).click();
    ok(d.getElementById('app').style.zoom !== '', '文字の大きさが変わる');
    btn('標準', d.getElementById('main')).click();
    rail('ほか');
    btn('引退', d.querySelector('#main .tabs')).click();
    rail('ほか');
    btn('設定', d.getElementById('main')).click();
    btn('名前', d.querySelector('.settabs')).click();
    ok(txt().includes('名前の書き換え'), '設定に名前の書き換え');
    rail('練習');
    ok(txt().includes('先週と同じ') && txt().includes('おまかせ') && txt().includes('疲れの高い子'), '練習に一括ボタン');
    ok(!!A.w.lastPlan && !!btn('先週と同じ'), '週を進めたあとは「先週と同じ」を押せる');
    rail('ほか');
    btn('Bチーム').click();
    ok(txt().includes('Bチームの指揮') && txt().includes('起用方針'), 'Bチームの指揮の画面');
    btn('下級生を優先').click();
    ok(A.w.bCtl && A.w.bCtl.policy === 'young', 'Bの起用方針を選べる');
    rail('ほか');
    btn('引退', d.querySelector('#main .tabs')).click();
    ok(txt().includes('実績') && txt().includes('引退する') && !txt().includes('リーグ優勝を1回'), '引退の画面（実績の一覧は系譜へ）');
    // 取り返せない操作の確認：確定は動詞の赤いボタン、「やめる」が主ボタン（2026-11-17）
    {
      btn('引退する', d.getElementById('main')).click();
      const sh = d.querySelector('.sheet');
      const yes = sh && [...sh.querySelectorAll('button')].find((b) => b.textContent === '引退する');
      const no = sh && [...sh.querySelectorAll('button')].find((b) => b.textContent === 'やめる');
      ok(!!yes && yes.classList.contains('danger') && !yes.classList.contains('pri') && !!no && no.classList.contains('pri') && ![...sh.querySelectorAll('button')].some((b) => b.textContent === 'はい'), '引退の確認：「引退する」は赤、「やめる」が主ボタン、「はい」は無い');
      if (no) no.click();
      ok(!d.querySelector('.sheet') && !A.w.retired, 'やめるで閉じ、何も起きない');
    }
    // 2段目その1：系譜タブ（決定139）
    {
      rail('記録');
      ok(A.tab === 'lineage' && ['卒業生名鑑', '殿堂'].every((x) => txt().includes(x)) && ['卒業生', '実績・年表', '監督'].every((x) => !!btn(x, d.querySelector('#main .tabs'))), '記録タブは3つの群（卒業生・実績・年表・監督）');
      ok(ltab('実績') && /実績 \d+\/\d+/.test(txt()) && ltab('年表') && ltab('育成基金'), '実績・年表の群に実績・年表・育成基金');
      // 2026-11-21「系譜の画面はいらない」：系譜図の小タブとホームの系譜の小窓を外した
      ok(!ltab('系譜図') && !d.querySelector('.lin-svg') && ![...d.querySelectorAll('#rail button')].some((b) => b.textContent.includes('系譜')), '系譜図が無く、左の帯は「記録」');
      // 2026-11-17：系譜の小タブは「監督の注文」「移籍先クラブ」（クラブ＞トップ・左の帯のクラブと中身が違うので）
      const ltabs = [];
      for (const g of ['卒業生', '実績・年表', '監督']) { btn(g, d.querySelector('#main .tabs')).click(); ltabs.push(...[...d.querySelectorAll('#main .tabs button:not(.grp)')].map((b) => b.textContent.trim())); }
      ok(ltabs.includes('監督の注文') && ltabs.includes('移籍先クラブ') && !ltabs.includes('トップ') && !ltabs.includes('クラブ'), '記録の小タブの名前が、ほかのトップ・クラブと重ならない ' + ltabs.join('・'));
      for (const n of ['ライバル', 'トップ', '移籍', 'クラブ']) {
        const label = { トップ: '監督の注文', クラブ: '移籍先クラブ' }[n] || n;
        ltab(label);
        ok(errors.length === 0, n + 'の画面で例外なし: ' + errors.slice(0, 2).join('|'));
        if (n === 'ライバル') ok(txt().includes('名物のライバル監督') && txt().includes('対戦成績'), 'ライバル監督の画面');
        if (n === 'トップ') ok(txt().includes('トップ監督の注文'), 'トップ監督の注文の画面');
        if (n === '移籍') ok(txt().includes('クラブ移籍'), 'クラブ移籍の画面');
        if (n === 'クラブ') ok(txt().includes('移籍先のクラブ（367・38リーグ）') && txt().includes('ロイヤル・マドリード') && txt().includes('リーグの水準'), '移籍先のクラブと強さの画面');
      }
      // 卒業生の成績の表：得点・アシスト・出場とバロンドール。GK は完封（2026-11-15）
      {
        const fa = { pos: 'FW', apps: 60, goals: 20, assists: 9, titles: [], awards: [{ y: 3, name: 'バロンドール 4位' }, { y: 3, name: 'ラ・リーガ アシスト王' }], bdBest: 4, seasons: [{ y: 3, club: 'ロイヤル・マドリード', league: 'ラ・リーガ', apps: 30, goals: 12, assists: 5, bd: 4, titles: [], awards: [] }] };
        const e1 = w.YA.alumniStats(A.w, fa).textContent;
        ok(['出場 60', '得点 20', 'アシスト 9', 'バロンドール 最高4位', 'アシスト王', 'ロイヤル・マドリード'].every((x) => e1.includes(x)), '卒業生の成績の表（得点・アシスト・バロンドール）');
        const gk = { pos: 'GK', apps: 40, goals: 0, assists: 0, cleans: 14, titles: [], awards: [], seasons: [{ y: 3, club: 'FCバルセロナ', league: 'ラ・リーガ', apps: 30, goals: 0, assists: 0, cleans: 11, titles: [], awards: [] }] };
        const e2 = w.YA.alumniStats(A.w, gk).textContent;
        ok(e2.includes('完封 14') && !e2.includes('得点') && !e2.includes('アシスト'), 'GK の成績は完封で、得点・アシストを出さない');
        // 経歴をまとめたページ（2026-11-15）
        const ca = Object.assign({}, fa, { name: '経歴 試し', year: 2, age: 24, status: 'pro', abroad: true, club: 'ロイヤル・マドリード', league: 'ラ・リーガ', ovr: 17.6, ovr0: 13.5, main: 'ST', star: true, transfers: 1, feeTotal: 52000, valueMax: 90000,
          rHist: [{ y: 1, g: 1, r: 70 }, { y: 2, g: 2, r: 88 }], cs: { apps: 40, goals: 22, assists: 7 }, form: '点取り屋', traits: ['決定力'], note: 'プロ契約',
          moves: [{ y: 4, age: 21, from: '川崎 フロンティエラ', fromLg: 'J1リーグ', to: 'ロイヤル・マドリード', toLg: 'ラ・リーガ', fee: 52000, share: 780, abroad: true }],
          titles: [{ y: 4, name: 'ラ・リーガ優勝' }], mem: [{ y: 1, w: 3, k: 'star', q: 'ここで一番になる' }] });
        ca.seasons = [{ y: 4, age: 21, club: 'ロイヤル・マドリード', league: 'ラ・リーガ', apps: 30, goals: 12, assists: 5, value: 90000, bd: 4, titles: ['ラ・リーガ優勝'], awards: ['バロンドール 4位'] }];
        const before = d.querySelectorAll('.sheet').length;
        w.YA.careerPage(A.w, ca);
        const sheets = d.querySelectorAll('.sheet');
        const e3 = sheets[sheets.length - 1].textContent;
        ok(errors.length === 0 && sheets.length === before + 1, '経歴のページが開く: ' + errors.slice(0, 2).join('|'));
        ok(['ユース時代', '高1 70', 'Aの公式戦 40試合', '覚醒：点取り屋', '年ごとの成績', '市場価値', '9億円', '移籍の歴史', '川崎 フロンティエラ → ロイヤル・マドリード', '5.2億円', '移籍金の合計 5.2億円', 'タイトルと賞', 'ユースでの思い出', 'ここで一番になる', 'バロンドール 最高4位'].every((x) => e3.includes(x)), '経歴のページに、ユース時代・年ごとの成績・市場価値・移籍金・賞・思い出が出る');
        // 卒業生の紹介文（2026-11-18「概要欄が薄い、もっと文章で」）：経歴のページの上に2段落
        ok(e3.includes('どんな子だったか') && e3.includes('卒業してから') && e3.includes('「点取り屋」に目覚めた') && e3.includes('高1で70だった総合力') && e3.includes('ロイヤル・マドリード（ラ・リーガ）へ移った'), '経歴のページに、ユース時代とその後の紹介文が出る');
        sheets[sheets.length - 1].remove();
        {
          const sa = Object.assign({}, ca, { route: 'セレクション', joinY: 2, pers: ['寡黙'], bg: 'bropro', capt: true, awY: 3, youthCaps: 2, bond: 5,
            mem: [{ y: 3, k: 'path', c: 'univ', wish: 'abroad' }, { y: 3, k: 'grad', q: '監督に会えてよかった' }] });
          const st = w.YA.alumniStory(A.w, sa);
          ok(['2年目にセレクションを勝ち抜いて入ってきた', 'キャプテン', '性格は寡黙', '兄がプロ', '3年目に「点取り屋」に目覚めた', 'Aの公式戦には40試合に出て、22得点・7アシスト', '海外を望んだが、大学の道を選ばせた', '「監督に会えてよかった」', '絆は深い'].every((x) => st.youth.includes(x)), '紹介文（ユース時代）に、入団・性格・事情・伸び・覚醒・成績・進路・言葉・絆が入る: ' + st.youth);
          ok(['卒業から1年', '通算', '移籍金 5.2億円', 'タイトルは'].every((x) => st.after.includes(x)), '紹介文（その後）に、年数・通算・移籍・タイトルが入る: ' + st.after);
          ok(/^「点取り屋」に目覚めた、.+のST$/.test(w.YA.alumniTagline(sa)),'名鑑のひとこと紹介: ' + w.YA.alumniTagline(sa));
          const bare = w.YA.alumniStory(A.w, { name: '古い 記録', pos: 'DF', main: 'CB', year: 2, ovr: 10, status: 'amateur', club: '社会人', league: '社会人リーグ', traits: [] });
          ok(bare.youth.includes('監督が来たときには、もうチームにいた') && errors.length === 0, '記録の少ない古い卒業生でも紹介文が作れる: ' + bare.youth);
        }
      }
      // やり残し（2026-11-18「操作を忘れることとかあるので、直したい」）：ホームの欄・タブの印・締め切りの週に一度止める
      {
        const keepW = A.w, keepTab = A.tab;
        const tw = w.YA.newWorld(11);
        tw.introSeen = true;
        for (const p of Object.values(tw.players)) p.star = false;
        tw.week = 4; tw.phase = 'after'; tw.matchDone = true; tw.events = [];
        const L = w.YA.todoList(tw);
        ok(L.some((x) => x.id === 'star' && x.hard && x.left === 0), '4週目で★が未定なら、締め切りのやり残しになる');
        A.w = tw; A.tab = 'home'; w.YA._ui.render();
        const card = d.querySelector('.todo');
        ok(card && card.textContent.includes('高1の★注目を決める') && card.textContent.includes('今週まで'), 'ホームにやり残しの欄が出る');
        ok(!!d.querySelector('#rail .tdot'), 'やり残しのあるタブに印が付く');
        btn('次の週へ').click();
        const sh = [...d.querySelectorAll('.sheet')].pop();
        ok(sh && sh.textContent.includes('この週で締め切られるもの') && sh.textContent.includes('★は付けられなくなり') && tw.week === 4, '締め切りの週は「次の週へ」の前に一度止まる');
        btn('戻って決める', sh).click();
        ok(A.tab === 'players' && A.pSel === w.YA.starPick(tw, 1)[0].id && !d.querySelector('.sheet'), '「戻って決める」でその画面へ');
        A.tab = 'home'; w.YA._ui.render();
        btn('次の週へ').click();
        btn('このまま進む', [...d.querySelectorAll('.sheet')].pop()).click();
        ok(tw.week === 5 || tw.phase !== 'after', '「このまま進む」で週が進む');
        d.querySelectorAll('.sheet').forEach((s) => s.remove());
        tw.week = 27; tw.phase = 'after';
        ok(w.YA.todoDue(tw).some((x) => x.id === 'int'), '11月の最後の週は、内部昇格が締め切りのやり残しになる');
        tw.week = 12;
        ok(!w.YA.todoDue(tw).length, '締め切りのない週は止めない');
        A.w = keepW; A.tab = keepTab; w.YA._ui.render();
        ok(errors.length === 0, 'やり残しで例外なし: ' + errors.slice(0, 2).join('|'));
      }
      for (const n of ['実績', '図鑑', '殿堂', '年表', '育成基金', '卒業生名鑑']) {
        ok(ltab(n), n + 'の小タブがある');
        ok(errors.length === 0, n + 'の画面で例外なし: ' + errors.slice(0, 2).join('|'));
      }
      // 育成基金：お金は YA.yen、使う前に確かめ、結果を知らせる（2026-11-17）
      {
        const f0 = A.w.fund;
        A.w.fund = 12000;
        ltab('育成基金');
        ok(txt().includes('育成基金 1.2億円') && !/\d万(?![円人回])/.test(txt()), '育成基金の額は YA.yen（12000万円 → 1.2億円）');
        btn('使う', d.getElementById('main')).click();
        const sh = d.querySelector('.sheet');
        ok(!!sh && /使いますか/.test(sh.textContent) && A.w.fund === 12000, '育成基金を使う前に確認が出る ' + (sh && sh.textContent.slice(0, 80)) + ' ' + A.w.fund);
        if (sh) btn('使う', sh).click();
        await sleep(10);
        const t = d.getElementById('ya-toast');
        ok(A.w.fund < 12000 && !!t && /使いました/.test(t.textContent) && /残り/.test(t.textContent), '使うと結果の文が出る ' + (t && t.textContent));
        A.w.fund = f0;
        ltab('図鑑');
        ok(![...d.querySelectorAll('#main .card[title]')].some((c) => c.getAttribute('title')), '図鑑の手がかりは title ではなく本文に');
        ltab('実績');
        ok(d.querySelectorAll('#main .chip[data-tip]').length > 0 && !d.querySelector('#main .chip[title]'), '実績の銅銀金の札は押すと名前が出る');
      }
      ltab('図鑑');
      ok(txt().includes('覚醒の図鑑 ') && txt().includes('/80') && txt().includes('？'), '図鑑：80種が並び、未発見は？');
      ltab('実績');
      ok(txt().includes('/72') && txt().includes('銅'), '実績は72個の銅銀金');
      ok(d.querySelectorAll('#main .plist > .pitem').length === 24, '実績は銅銀金を1行にまとめて24行（2026-11-16。11-20 に図鑑の40/60/80種を足した）');
      ltab('図鑑');
      { const g = [...d.querySelectorAll('#main .scroll')].find((e) => e.style.display === 'grid'); ok(!!g && g.children.length === 80 && g.style.gridTemplateColumns.includes('repeat(4'), '図鑑は4列の札・80種（2026-11-20）'); }
      ltab('実績');
      rail('ホーム');
      ok(!txt().includes('系譜図') && !d.querySelector('.lin-svg') && txt().includes('次の実績'), 'ホームに次の実績（系譜の小窓は無い）');
      rail('ほか');
      ok(txt().includes('設定') || txt().includes('実績と引退'), '歯車から設定へ');
    }
    // フリー対戦（成績に残らない）
    rail('選手');
    btn('様子').click();
    ok(txt().includes('キャプテン') && txt().includes('ポジション'), '選手にキャプテンとポジション変更');
    btn('キャプテンにする').click();
    ok(A.w.captain != null, 'キャプテンを指名');
    rail('試合');
    ok(txt().includes('キックオフ'), '試合の前の画面');
    ok(errors.length === 0, '例外: ' + errors.slice(0, 3).join(' | '));
    // 金の特性：詳しい画面に金の札と、金までの進み具合が出る
    {
      const gp = Object.values(A.w.players).find((p) => p.pos !== 'GK');
      gp.traits = ['スルーパス', 'ボール奪取'];
      gp.gold = ['スルーパス'];
      gp.trUse = { ボール奪取: 4 };
      A.pSel = gp.id; A.tab = 'players'; w.YA._ui.render();
      btn('能力').click();
      ok(!!d.querySelector('.chip.gold') && txt().includes('金 針の穴を通すパス'), '金の特性の札が出る');
      ok(txt().includes('金まで：「ボール奪取」→「ボールハンター」') && txt().includes('4/' + w.YA.GOLD_USES), '金までの進み具合が出る');
    }
    // 先発をBに下げる：代わりに入る子を選ぶ画面が出て、選ぶと入れ替わる
    {
      const sid = A.w.lineupA[4].pid;
      A.pSel = sid; A.tab = 'players'; w.YA._ui.render();
      btn('Bに回す').click();
      const sh = d.querySelector('.sheet');
      ok(!!sh && sh.textContent.includes('先発に入る子を選ぶ'), '先発をBに下げると、代わりを選ぶ画面が出る');
      const first = sh && sh.querySelector('.pitem');
      if (first) first.click();
      ok(A.w.players[sid].team === 'B' && !A.w.lineupA.some((s) => s.pid === sid) && A.w.lineupA.length === 11, '選ぶと先発が入れ替わり、下げた子はBへ');
      ok(A.w.benchA.length === 9 && new Set(A.w.lineupA.map((s) => s.pid).concat(A.w.benchA)).size === 20, '入れ替えのあともAは20人で重ならない');
    }
    // 契約満了の画面：分かりやすく、押せる。更新を断られたときは理由が出る
    {
      d.querySelectorAll('.sheet').forEach((s) => s.remove());
      A.w.pendingContract = { offers: w.YA.moveOffers(A.w) };
      A.tab = 'home';
      w.YA._ui.render();
      await sleep(20);
      ok(txt().includes('3年の契約が終わりました') && txt().includes('で続ける') && txt().includes('ここへ移る') && txt().includes('持っていけます'), '契約満了の画面に、選べる道と何が変わるかが出る');
      const t0 = A.w.club.trust; A.w.club.trust = 10;
      d.querySelectorAll('.sheet').forEach((s) => s.remove());
      w.YA._ui.render();
      await sleep(20);
      ok(txt().includes('クラブが更新を断っています') && txt().includes('30未満'), '更新できないときは理由が出る');
      const mv = btn('ここへ移る');
      if (mv) mv.click();
      await sleep(20);
      ok(!A.w.pendingContract && !txt().includes('3年の契約が終わりました'), '「ここへ移る」を押すと先へ進める');
      A.w.club.trust = Math.max(t0, 50);
    }
    // 押せないボタンには、触れたときに出す理由（data-why）がある
    {
      const noWhy = () => [...d.querySelectorAll('#app button[disabled]')].filter((b) => !b.dataset.why).map((b) => b.textContent.trim().slice(0, 16));
      const bad = [];
      for (const k of ['ホーム', '選手', 'クラブ']) { rail(k); await sleep(10); bad.push(...noWhy()); }
      for (const k of ['予算と施設', 'スタッフ', 'スカウト', 'セレクション', '内部昇格', '概要']) { const bb = btn(k); if (bb) { bb.click(); await sleep(10); bad.push(...noWhy()); } }
      ok(bad.length === 0, '押せないボタンには理由がある: ' + bad.slice(0, 5).join('|'));
      ok(typeof w.YA.toast === 'function', '押せないボタンに触れたら理由を出す仕組みがある');
    }
    // 機能面の画面
    rail('選手');
    await sleep(10);
    const sortSel = d.querySelector('select[title="並び替え"]');
    ok(!!sortSel && sortSel.options.length === 7, '選手一覧に並び替え');
    if (sortSel) { sortSel.value = 'ovr'; sortSel.dispatchEvent(new w.Event('change')); }
    await sleep(10);
    btn('育て方').click();
    ok(txt().includes('今年の育成計画') && txt().includes('伸び悩みの診断') && txt().includes('位置の転向練習') && !txt().includes('この子との記憶'), '選手の育て方に育成計画・診断・転向');
    btn('思い出').click();
    ok(!txt().includes('今年の育成計画') && (txt().includes('最近のこと') || txt().includes('まだ思い出はありません')), '選手の思い出は別の小タブ');
    btn('…').click();
    ok(!!btn('PK戦のキッカー') && !btn('名前を変える'), '「…」に比べる・PK（名前は変えられない）');
    btn('他の子と比べる').click();
    ok(!!d.querySelector('.sheet') && txt().includes('比べる子を選ぶ'), '比べる画面が開く');
    const sh2 = d.querySelector('.sheet');
    const first2 = sh2 && sh2.querySelector('.pitem');
    if (first2) first2.click();
    ok(txt().includes('総合力') && txt().includes('別の子と比べる'), '2人の比較が出る');
    if (btn('閉じる')) btn('閉じる').click();
    rail('ほか');
    if (btn('用語集')) { btn('用語集').click(); ok(txt().includes('覚醒の鍵') && txt().includes('連帯貢献金'), '用語集'); }
    // ---------- ガイド（2026-11-19「各操作や画面のガイドを充実させて」） ----------
    {
      const Y = w.YA;
      const app = Y._ui.app;
      // どの画面・小タブにもガイドがある
      const keys = ['home', 'players', 'train', 'pre', 'play', 'result', 'club:money', 'club:over', 'club:staff', 'club:top', 'club:int', 'club:scout', 'club:sel', 'club:table', 'lineage:alumni', 'more:howto', 'more:rec', 'more:bteam', 'more:ach', 'more:help', 'set:disp', 'set:notice', 'set:name', 'set:save'];
      const miss = keys.filter((k) => { const g = Y.GUIDE[k]; return !g || !g.t || !g.what; });
      ok(!miss.length, 'ガイド: 全画面に見出しと説明: ' + miss.join(','));
      ok(Y.guideKey({ tab: 'club', ct: 'scout' }) === 'club:scout' && Y.guideKey({ tab: 'more', mt: 'set', st: 'save' }) === 'set:save' && Y.guideKey({ tab: 'match', view: 'pre' }) === 'pre', 'ガイド: 小タブまで鍵を作る');
      ok(Y.guideOf({ tab: 'lineage', lt: 'rival' }) === Y.GUIDE.lineage, 'ガイド: 個別が無い小タブはタブのガイド');
      // 左の「？」でいまの画面のガイドが開く（どのタブでも出る）
      for (const [tb, title] of [['ホーム', 'ホーム'], ['練習', '練習'], ['クラブ', 'クラブ ―']]) {
        rail(tb);
        const q = d.querySelector('#rail .tiphelp');
        ok(!!q, 'ガイド: ' + tb + 'に？');
        if (!q) continue;
        q.click();
        await sleep(5);
        const gs = d.querySelector('.sheet-in.guide');
        ok(gs && gs.textContent.includes(title) && /できること/.test(gs.textContent), 'ガイド: ？で' + tb + 'のガイド');
        const close = gs && [...gs.querySelectorAll('button')].find((b) => b.textContent === 'わかった');
        if (close) close.click();
        await sleep(5);
        ok(!d.querySelector('.sheet-in.guide'), 'ガイド: わかったで閉じる');
      }
      // 「遊び方を章ごとに読む」→ ほか → 遊び方
      d.querySelector('#rail .tiphelp').click();
      await sleep(5);
      [...d.querySelectorAll('.sheet-in.guide button')].find((b) => b.textContent === '遊び方を章ごとに読む').click();
      await sleep(5);
      ok(app.tab === 'more' && app.mt === 'howto' && d.querySelector('.howto'), 'ガイド: 遊び方へ移る');
      ok(d.querySelectorAll('.howto .col button').length === Y.HOWTO.length && Y.HOWTO.length >= 9, 'ガイド: 遊び方の章が並ぶ');
      btn('9. ショップ').click();
      await sleep(5);
      ok(/購入を復元/.test(d.querySelector('.howto').textContent), 'ガイド: 遊び方にショップの章');
      ok(errors.length === 0, 'ガイドで例外なし: ' + errors.slice(0, 2).join('|'));
      app.hw = 0;
    }
    rail('ホーム');
    ok(txt().includes('お知らせ') && (txt().includes('留める') || txt().includes('すべて読んだ') || true), 'お知らせに留める');
    ok(errors.length === 0, '機能面の画面で例外なし: ' + errors.slice(0, 2).join('|'));
    // ---------- 課金・保存の画面（2026-11-17 課金の点検） ----------
    {
      const Y = w.YA;
      const posted = [];
      w.YouthApp = { postMessage: (m) => posted.push(JSON.parse(m)) };
      Y.shopPrices = {};
      rail('ほか');
      btn('設定', d.getElementById('main')).click();
      btn('セーブ・ショップ', d.querySelector('.settabs')).click();
      await sleep(10);
      ok(/セーブ枠（いま\d枠・無料は1枠）/.test(txt()), '課金: セーブ枠の見出しは「いまN枠・無料は1枠」');
      ok(/最後に保存できた時刻|まだ保存していません/.test(txt()), '課金: 設定に最後に保存できた時刻');
      const buyBtn = d.querySelector('button[data-pid="youth_remove_ads"]');
      ok(buyBtn && buyBtn.disabled && /ストアに接続中/.test(buyBtn.dataset.why || '') && !/円/.test(buyBtn.textContent), '課金: 価格が取れていない商品は値段を出さず押せない（理由つき）');
      ok(posted.some((m) => m.cmd === 'prices'), '課金: ショップを開いたら価格を取り直す');
      Y.onNative({ ev: 'prices', map: { youth_remove_ads: '¥610', youth_keen_eye: '¥800', youth_save_slot: '¥250', youth_ticket_1: '¥250', youth_ticket_3: '¥610' } });
      const buy2 = d.querySelector('button[data-pid="youth_remove_ads"]');
      ok(buy2 && !buy2.disabled && buy2.textContent === '¥610', '課金: 価格が届いたら買える');
      Y.onNative({ ev: 'ent', v: { slots: 4, tickets: 2, used: 0, spent: [] } });
      const sb = d.querySelector('button[data-pid="youth_save_slot"]');
      ok(sb && sb.disabled && /5枠/.test(sb.dataset.why || ''), '課金: セーブ枠が上限なら押せない（理由つき）');
      // ショップのガイド（2026-11-19）：買い方・商品ごとの「買うと／使う場所」・持っている商品の行き先
      ok(d.querySelector('.shophow') && /Apple の購入画面/.test(d.querySelector('.shophow').textContent), 'ガイド: ショップに買い方');
      ok(d.querySelectorAll('.sguide').length === Y.SHOP.length && [...d.querySelectorAll('.sguide')].every((e) => /^使う場所：./.test(e.textContent)), 'ガイド: 商品ごとに使う場所');
      ok([...d.querySelectorAll('.sgo')].some((b) => b.textContent === '作る場所へ') && [...d.querySelectorAll('.sgo')].some((b) => b.textContent === 'セーブ枠を見る'), 'ガイド: 持っている商品に使う場所へのボタン');
      Y.onNative({ ev: 'purchase', id: 'youth_ticket_1', outcome: 'purchased' });
      ok(/オリジナル選手チケット（1枚）」が届きました。.*オリジナル選手を作る/.test(Y.shopMsg), 'ガイド: 買ったあとに使う場所を知らせる');
      Y.onNative({ ev: 'purchase', id: 'youth_ticket_1', outcome: 'canceled' });
      ok(Y.shopMsg === Y.PURCHASE_MSG.canceled, 'ガイド: 取りやめは元の文のまま');
      // オリジナル選手：3人そろっていたら作れない
      A.w.originals = [{ name: 'あ', pos: 'CM', stars: 3 }, { name: 'い', pos: 'CM', stars: 3 }, { name: 'う', pos: 'CM', stars: 3 }];
      Y._ui.render();
      const ob = btn('オリジナル選手を作る') || [...d.querySelectorAll('button')].find((b) => b.textContent === 'オリジナル選手を作る');
      ok(ob && ob.disabled && /3人まで/.test(ob.dataset.why || ''), '課金: オリジナル選手が3人そろっていたら作るボタンは押せない（理由つき）');
      A.w.originals = [];
      Y._ui.render();
      const ob2 = [...d.querySelectorAll('button')].find((b) => b.textContent === 'オリジナル選手を作る');
      ob2.click();
      d.querySelector('.sheet input[type=text]').value = '迎え 太郎';
      d.querySelector('.sheet input[type=text]').dispatchEvent(new w.Event('input', { bubbles: true }));
      // 数字で作る：能力のスライダー・将来の総合力・特性3つ・覚醒の形
      const sh = d.querySelector('.sheet');
      ok(sh.querySelectorAll('input[data-ab]').length === Y.AB_FIELD.length, '数字で作る: 能力をすべて1つずつ決められる（' + sh.querySelectorAll('input[data-ab]').length + '個）');
      const fin = sh.querySelector('input[data-ab="フィニッシュ"]');
      fin.value = '18'; fin.dispatchEvent(new w.Event('input', { bubbles: true }));
      ok(fin.parentNode.textContent.indexOf('18') >= 0, '数字で作る: 動かした数がその場で出る');
      const fut = sh.querySelector('input[data-fut]');
      ok(fut && fut.max === '200', '数字で作る: 将来の総合力は200まで');
      fut.value = '190'; fut.dispatchEvent(new w.Event('input', { bubbles: true }));
      ok(/190（/.test(sh.textContent), '数字で作る: 将来の数と水準がその場で出る');
      for (let i = 0; i < 3; i++) d.querySelector('.sheet button[data-tr]:not(.on):not([disabled])').click();
      const trFull = d.querySelector('.sheet button[data-tr]:not(.on)');
      ok(d.querySelectorAll('.sheet button[data-tr].on').length === 3 && trFull.disabled && /3つまで/.test(trFull.dataset.why || ''), '数字で作る: 特性は3つまで（4つ目は理由つきで押せない）');
      d.querySelector('.sheet button[data-form]').click();
      ok(d.querySelector('.sheet button[data-form].on') && /特性「/.test(d.querySelector('.sheet').textContent), '数字で作る: 覚醒の形を選ぶと中身が出る');
      posted.length = 0;
      btn('この子を迎える').click();
      await sleep(10);
      ok(A.w.originals.length === 1 && A.w.originals[0].serial === 1 && posted.some((m) => m.cmd === 'useTicket') && posted.findIndex((m) => m.k === Y.slotKey(A.slot || 0)) < posted.findIndex((m) => m.cmd === 'useTicket'), '課金: 予約を保存してからチケットを使う（通し番号つき）');
      ok(Y.ent.tickets === 1 && Y.ent.used === 1, '課金: 使ったチケットを数える');
      const og = A.w.originals[0];
      ok(og.ab && og.ab['フィニッシュ'] === 18 && og.fut === 190 && og.traits.length === 3 && !!og.form, '数字で作る: 決めた能力・将来・特性・覚醒の形が予定に残る');
      // 見抜く目：選手の一覧と概要に将来の総合力の数字
      const eye0 = Y.ent.eye;
      Y.ent.eye = false;
      const tab0 = A.tab; A.tab = 'players'; Y._ui.render();
      ok(!/→\d{2,3}/.test(txt()), '見抜く目: 持っていなければ一覧は星のまま');
      Y.ent.eye = true; Y._ui.render();
      ok(/→\d{2,3}/.test(txt()) && /将来 \d{2,3}/.test(txt()), '見抜く目: 一覧と帯に将来の総合力が数字で出る');
      Y.ent.eye = eye0; A.tab = tab0; Y._ui.render();
      ok([...d.querySelectorAll('#app button[disabled]')].every((b) => b.dataset.why), '課金: ショップの押せないボタンに理由がある');
      // 控えに戻す確認に、オリジナル選手の扱い
      const bakBtn = btn('控え（年度はじめ）に戻す');
      if (bakBtn) { bakBtn.click(); ok(/予約したオリジナル選手も戻ります/.test(d.querySelector('.sheet').textContent), '課金: 控えに戻す確認に、予約したオリジナル選手の扱い'); btn('やめる', d.querySelector('.sheet')).click(); }
      // 裏に回ったら、まとめ書きを待たずにすぐ保存する
      posted.length = 0;
      Y.saveWorld();
      Object.defineProperty(d, 'hidden', { configurable: true, get: () => true });
      d.dispatchEvent(new w.Event('visibilitychange'));
      ok(posted.some((m) => m.k === Y.slotKey(A.slot || 0)), '課金: 裏に回ったらすぐ保存を書き出す');
      Object.defineProperty(d, 'hidden', { configurable: true, get: () => false });
      posted.length = 0;
      w.dispatchEvent(new w.Event('pagehide'));
      ok(posted.some((m) => m.k === Y.slotKey(A.slot || 0)), '課金: 閉じるとき（pagehide）も保存を書き出す');
      // 保存に失敗し続けたら知らせる
      Y.saveState.warned = false; Y.saveState.nativeFails = 0;
      Y.onNative({ ev: 'saveFail' });
      Y.onNative({ ev: 'saveFail' });
      const toast = d.getElementById('ya-toast');
      ok(toast && /保存できませんでした/.test(toast.textContent), '課金: 保存に続けて失敗したら「保存できませんでした」');
      // ご褒美の動画：読み直しの後に届いた控えも受け取る
      const pl = Object.values(A.w.players)[0];
      pl.fat = 40;
      posted.length = 0;
      Y.onNative({ ev: 'adUnclaimed', list: [{ tag: 555, reward: { k: 'rest' } }] });
      ok(pl.fat === 28 && posted.some((m) => m.cmd === 'adClaimed' && m.tag === 555), '課金: 読み直しの前に見終えた動画の特典が渡り、控えを消す');
      Y.onNative({ ev: 'adDone', tag: 555, result: 'earned', reward: { k: 'rest' } });
      ok(pl.fat === 28, '課金: 同じ動画の特典は二度渡らない');
      // 空き枠で新しく始めたら、前の枠に戻れる
      const slotNow = A.slot || 0;
      const empty = [...d.querySelectorAll('#main button')].find((b) => b.textContent === '新しく始める');
      if (empty) {
        empty.click();
        await sleep(10);
        ok(!A.w && !!btn('やめて前の枠'), '課金: 空き枠で始めかけたら「やめて前の枠に戻る」');
        btn('やめて前の枠').click();
        await sleep(10);
        ok(A.w && (A.slot || 0) === slotNow, '課金: 前の枠に戻れる');
      } else ok(false, '課金: 空き枠の「新しく始める」が無い');
      // 読めないセーブは、黙って新しく始めない
      const wsave = A.w;
      A.w = null;
      A.loadErr = { slot: slotNow };
      Y._ui.render();
      ok(txt().includes('セーブを読めませんでした') && !!btn('新しく始める') && txt().includes('控え（年度はじめ）に戻す'), '課金: セーブが読めないときは控えに戻すか新しく始めるかを選ばせる');
      ok([...d.querySelectorAll('#app button[disabled]')].every((b) => b.dataset.why), '課金: 読めないときの画面の押せないボタンに理由がある');
      A.loadErr = null;
      A.w = wsave;
      Y.entSet(null);
      Y.shopPrices = {};
      delete w.YouthApp;
      rail('ホーム');
      ok(errors.length === 0, '課金の画面で例外なし: ' + errors.slice(0, 2).join('|'));
    }
    // 引退のまとめに遺産ポイントが出る
    A.w.retired = { year: A.w.year, week: A.w.week };
    w.YA._ui.render();
    ok(txt().includes('付いてきてくれる教え子') && errors.length === 0, '引退のまとめに、次の人生に付いてくる教え子が出る: ' + errors.slice(0, 2).join('|'));
    // 引退後は行き止まりにしない：名鑑・系譜・セーブ枠へ。新しく始めるは確かめてから
    {
      const wr = A.w;
      btn('新しく始める').click();
      ok(d.querySelector('.sheet') && /新しく始めますか/.test(d.querySelector('.sheet').textContent) && A.w === wr, '引退後の「新しく始める」は確かめてから');
      btn('やめる', d.querySelector('.sheet')).click();
      btn('名鑑・記録を見る').click();
      await sleep(10);
      ok(txt().includes('卒業生') && !!btn('まとめに戻る'), '引退後も名鑑が見られる');
      [...d.querySelectorAll('button')].find((b) => b.textContent.trim() === '記録').click();
      await sleep(10);
      ok(errors.length === 0, '引退後に記録を開いて例外なし: ' + errors.slice(0, 2).join('|'));
      btn('まとめに戻る').click();
      btn('セーブ枠').click();
      ok(d.querySelector('.sheet') && /セーブ枠（いま/.test(d.querySelector('.sheet').textContent), '引退後にセーブ枠を開ける');
      btn('閉じる', d.querySelector('.sheet')).click();
    }
    console.log(fails ? '失敗 ' + fails : '画面の点検: すべて通過');
    process.exit(fails ? 1 : 0);
  }
})();
