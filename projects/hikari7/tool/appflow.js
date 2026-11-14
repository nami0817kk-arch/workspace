// アプリとしてのつなぎ（広告・追加パック）を、ブラウザなしで確かめる（2026-10-04 品質点検）。
//   node tool/appflow.js
// ゲーム本体に「アプリの中にいる」ふりの値（window.__HIKARI_APP）を渡し、アプリへ送る頼みごとと、
// アプリからの返事（hikariAdResult など）への反応を見る。どれか外れたら exit 1。
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const code = src.slice(src.lastIndexOf('<script>') + 8, src.lastIndexOf('</script>'));

function el(attrs) {
  return {
    innerHTML: '', innerText: '', style: {}, dataset: {}, children: [],
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    setAttribute() {}, getAttribute: (k) => (attrs && k in attrs ? attrs[k] : null), removeAttribute() {},
    hasAttribute: (k) => !!(attrs && k in attrs),
    addEventListener() {}, appendChild() {}, scrollIntoView() {}, focus() {},
    getBoundingClientRect() { return { top: 0, left: 0, width: 375, height: 40 }; },
    querySelector() { return el(); }, querySelectorAll() { return []; }, closest() { return null; },
    offsetHeight: 800, offsetTop: 0,
  };
}

let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.error('NG: ' + msg); } else console.log('ok: ' + msg); };

function boot(appVals) {
  const posts = [], timers = [];
  let click = null;
  const app = el();
  const ctx = {
    console, Math, Date, JSON, Object, Array, String, Number, Boolean, RegExp, Error, Map, Set, Uint8Array, Promise,
    setTimeout: (f) => { timers.push(f); return timers.length; }, clearTimeout: (i) => { if (i) timers[i - 1] = null; },
    setInterval: () => 0, clearInterval() {}, requestAnimationFrame: () => 0, cancelAnimationFrame() {},
    atob: (s) => Buffer.from(s, 'base64').toString('binary'),
    URL: { createObjectURL: () => 'blob:x' }, Blob: function () {},
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    navigator: {}, performance: { now: () => Date.now() },
    HikariApp: { postMessage: (s) => posts.push(JSON.parse(s)) },
    __HIKARI_APP: appVals,
  };
  ctx.window = ctx;
  ctx.scrollTo = () => {};
  ctx.matchMedia = () => ({ matches: false, addEventListener() {} });
  ctx.document = {
    querySelector: (s) => (s === '#app' ? app : el()), querySelectorAll: () => [], getElementById: () => el(),
    addEventListener: (t, f) => { if (t === 'click') click = f; }, createElement: () => el(), body: el(), documentElement: el(), hidden: false,
  };
  vm.createContext(ctx);
  vm.runInContext(code, ctx);
  const run = (js) => vm.runInContext(js, ctx);
  const press = (a, v) => {
    const attrs = { 'data-a': a };
    if (v != null) attrs['data-v'] = String(v);
    const t = el(attrs);
    click({ target: { closest: () => t }, preventDefault() {} });
  };
  return { run, press, posts, timers, ctx };
}

// 1シーズン目を合否まで進める（tool/views.js と同じ進め方を短くしたもの）
const PLAY_ROUND = `applyPlan(S);applyLesson(S);S.ap=0;afterTalk(S);if(S.phase==='interview')applyInterview(S);
  while(S.phase==='event'){resolveEvent(S,0);nextEvent(S);}
  S.phase='stage';if(ROUNDS[S.rnd].crit){S.phase='critique';applyCritique(S);}
  applyFeature(S);toNight(S);if(S.phase==='night'){nightSkip(S);S.phase='judge';}
  var B=alive(S),res=S.stage.res,n=capOf(S);B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});decide(S);`;
const START = `S=newGame('m','normal',null);var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);startSeason(S);`;

// ===== 全画面広告（エンドロールの前に1シーズン1回だけ。2026-10-04 ユーザー決定） =====
{
  const FIN = `var B=alive(S),res=S.stage.res;B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,Math.min(6,S.caps.finMax,B.length)).forEach(function(t){S.pass[t.id]=true;});decide(S);`;
  const g = boot({ adFree: false, store: {}, owned: {} });
  g.run(START);
  for (let r = 1; r <= 4; r++) { g.run(PLAY_ROUND); g.press('nextround'); }
  ok(g.run('S.rnd') === 5 && !g.posts.some((p) => p.type === 'between' || p.type === 'prepInter'), '審査の間には全画面広告を出さず、読み込みも頼まない');
  g.run(PLAY_ROUND.replace(/var B=alive[\s\S]*$/, '') + FIN);
  g.press('toprep');
  g.run("S.prep.color=2;S.prep.song=1;S.prep.leader=S.tr.filter(function(t){return t.status==='debut';})[0].id;startMonth(S);");
  ok(g.posts.some((p) => p.type === 'prepInter'), 'デビュー後1か月に入ったら、そのときだけ読み込みを頼む');
  g.press('monthdone');
  ok(g.posts.filter((p) => p.type === 'between').length === 1 && g.run('S.phase') === 'month', 'エンドロールへ進むとき1回出し、閉じるまでは進まない');
  g.run('hikariBetweenDone()');
  ok(g.run('S.phase') === 'result' && g.run('S.ending') === true, '広告を閉じたらエンドロールへ進む');

  const k = boot({ adFree: false, store: {}, owned: {} });
  k.run(START + "S.tr.slice(0,6).forEach(function(t){t.status='debut';});startPrep(S);S.prep.leader=S.tr[0].id;S.phase='month';S.month={w:4,busy:0,fan:0,song:0,coh:0,log:[]};");
  k.press('monthdone');
  k.timers.filter(Boolean).forEach((f) => f());
  ok(k.run('S.phase') === 'result', 'アプリから返事が来なくても、少し待てばエンドロールへ進む（固まらない）');

  const n = boot({ adFree: true, store: {}, owned: {} });
  n.run(START + "S.tr.slice(0,6).forEach(function(t){t.status='debut';});startPrep(S);S.prep.leader=S.tr[0].id;S.phase='month';S.month={w:4,busy:0,fan:0,song:0,coh:0,log:[]};");
  n.press('monthdone');
  ok(!n.posts.some((p) => p.type === 'between') && n.run('S.phase') === 'result', '広告を消した人には出さず、すぐ進む');
}

// ===== 動画の特典 =====
{
  const g = boot({ adFree: false, store: {}, owned: {} });
  g.run(START);
  g.run(`withAd(function(){S.__got=(S.__got||0)+1;})`);
  const req = g.posts.filter((p) => p.type === 'reward').pop();
  ok(req && req.id === 1, '動画の頼みに番号が付く');
  g.press('adcancel');
  ok(g.posts.some((p) => p.type === 'rewardCancel' && p.id === 1), '「やめる」はアプリにも伝える');
  g.run(`withAd(function(){S.__got=(S.__got||0)+1;})`);
  g.run('hikariAdResult(true,null,1)');
  ok(!g.run('S.__got'), 'やめた動画の結果は、次の特典に入らない');
  const id2 = g.posts.filter((p) => p.type === 'reward').pop().id;
  g.run(`hikariAdShowing(${id2})`);
  g.timers.filter(Boolean).forEach((f) => f());
  ok(g.run('!!pendingAd'), '動画の表示が始まったら、90秒の打ち切りで取り消さない');
  g.run(`hikariAdResult(true,null,${id2})`);
  ok(g.run('S.__got') === 1, '見終えた返事で特典が入る');
}

// ===== 追加パック =====
{
  const g = boot({ adFree: false, store: {}, owned: { story: false, audition: false } });
  g.run(START);
  ok(g.run('packArcKeys().length') === 0 && g.run("fmtKeys().indexOf('acap')") < 0, '買っていないパックの中身は出ない');
  g.run("hikariSetApp({owned:{story:true,audition:true},storeOk:true,prices:{story:'¥320',audition:'¥320'}})");
  ok(g.run('packArcKeys().length') === 6 && g.run("fmtKeys().indexOf('acap')") >= 0, '買ったらその場で中身が入る');
  g.run('hikariSetApp({owned:{story:false,audition:false}})');
  ok(g.run('packArcKeys().length') === 0 && g.run("fmtKeys().indexOf('acap')") < 0, '返金されたら、新しく始める中身から外す');
  ok(!/data-a="buypack"/.test(g.run('vTitleShop()')) && /広告を消す/.test(g.run('vTitleShop()')), '売り出すまでは、追加パックを売り場に出さない');
  g.run('PACK_SALE=true');
  g.press('tsub', 'shop');
  ok(g.posts.some((p) => p.type === 'refresh'), '追加パックの画面を開いたら、最新の値段を取りに行く');
  g.run('hikariSetApp({storeOk:true,prices:{story:null,audition:"¥320"}})');
  const shop = g.run('vTitleShop()');
  ok(/data-v="story" disabled/.test(shop) && !/data-v="audition" disabled/.test(shop), '値段が読めていないパックは押せず、読めたパックは押せる');

  const b = boot({ adFree: false, store: {}, owned: { story: true, audition: false } });
  ok(b.run('packArcKeys().length') === 6, '起動の時点で、買ったパックが入っている（ストアの返事を待たない）');
  ok(/data-v="story"/.test(b.run('vTitleShop()')) === false || /入っています/.test(b.run('vTitleShop()')), '持っているパックは「入っています」');
}

// ===== 保存と審査の型 =====
{
  const g = boot({ adFree: false, store: {}, owned: { story: false, audition: false } });
  g.run('parseSave(JSON.stringify({rnd:2,ev:{xid:"blackout"}}))');
  ok(g.run('!!packDone.story'), 'パックの出来事の途中の保存は、持っていなくても中身を足して読む（落ちない）');
  const w = g.run("JSON.stringify(teamW(PACK_AUDITION.acap,TEAM_CONCEPTS[0]))");
  ok(JSON.parse(w).v >= 0.36, 'アカペラ審査は、曲の方向を選んでも歌の重みが主になる（' + w + '）');
}

// ===== 制作費の動画の回数は、審査の順番を入れ替えても戻らない（2026-10-05 点検） =====
{
  const g = boot({ adFree: false, store: {}, owned: {} });
  g.run(START + 'S.budgetN=3;changeFmt(S);');
  ok(g.run('budgetAdLeft()') === 0, '審査の順番を入れ替えても、制作費の動画の残りは戻らない');
}

// ===== 動画を「やめる」と押したあとに届いた返事は受け取らない（2026-11-01：叱るような知らせが出ていた） =====
{
  const g = boot({ adFree: false, store: {}, owned: {} });
  g.run(START + 'ui.toasts=[];window.__t=[];toast=function(m){__t.push(m);};S.__got=0;withAd(function(){S.__got=1;});');
  const id = g.posts.filter((p) => p.type === 'reward').pop().id;
  g.press('adcancel');
  g.run(`hikariAdResult(false,'動画を最後まで見ると使えます',${id})`);
  ok(g.run('__t.length') === 0 && !g.run('S.__got'), 'やめた動画の「途中で閉じた」の知らせは出さない');
}

// ===== 評価のお願い（2026-10-28：評価0件だったので、1シーズン目から頼む） =====
{
  const g = boot({ adFree: false, store: {}, owned: {} });
  ok(g.run("reviewDue({seasons:1},'B')") && !g.run("reviewDue({seasons:1},'C')"), '1シーズン目でもB以上なら評価を頼み、C以下では頼まない');
  ok(!g.run("reviewDue({seasons:3,reviewAsked:1,reviewAt:4},'S')") && g.run("reviewDue({seasons:4,reviewAsked:1,reviewAt:4},'A')"), '頼んだあとは3シーズンあける');
  ok(!g.run("reviewDue({seasons:20,reviewAsked:3,reviewAt:4},'S')"), '頼むのは3回まで');
}

// ===== プロデューサー歴の節目（2026-11-14：2シーズン目以降に遊ぶ理由） =====
{
  const CAR = (o) => ({ hikari7_career: JSON.stringify(Object.assign({ seasons: 0, points: 0, hall: [] }, o)) });
  const FINISH = "S.tr.slice(0,6).forEach(function(t){t.status='debut';});startPrep(S);S.prep.leader=S.tr[0].id;S.phase='month';S.month={w:4,busy:0,fan:0,song:0,coh:0,log:[]};";
  // 追加パックは売らずに、節目のごほうびとして入る（PACK_SALE=false のまま）
  const a = boot({ adFree: false, store: CAR({ seasons: 10, points: 40 }), owned: { story: false, audition: false } });
  ok(a.run("fmtKeys().indexOf('acap')") >= 0 && a.run('packArcKeys().length') === 0, '10シーズンを終えた人には審査パックが入り、物語パックはまだ');
  ok(!a.run('PACK_SALE') && !/data-a="buypack"/.test(a.run('vTitleShop()')), 'ごほうびで入っても、売り場は出さない');
  a.run('hikariSetApp({owned:{story:false,audition:false}})');
  ok(a.run("fmtKeys().indexOf('acap')") >= 0, 'ストアの返事（買っていない）が来ても、ごほうびの中身は外さない');
  const b = boot({ adFree: false, store: CAR({ seasons: 20, points: 90 }), owned: {} });
  ok(b.run('packArcKeys().length') === 6 && b.run("fmtKeys().indexOf('acap')") >= 0, '20シーズンを終えた人には物語パックも入る');
  const c = boot({ adFree: false, store: CAR({ seasons: 9, points: 40 }), owned: {} });
  ok(c.run("fmtKeys().indexOf('acap')") < 0, '9シーズンではまだ入らない');
  c.run(START + FINISH); c.press('monthdone'); c.run('hikariBetweenDone()');
  ok(c.run("fmtKeys().indexOf('acap')") >= 0 && /ごほうび/.test(c.run('S.careerNews.news.join("|")')), '10シーズン目を終えたその場で入り、知らせが出る');
  ok(c.run('saveUsesPack(JSON.stringify({fmt:["acap"]}))'), '審査パックを使った保存は見分けられる（読むときに中身を足す）');

  // 審査の解放は経験で。前のポイントで解放済みの人からは取り上げない
  const d = boot({ adFree: false, store: CAR({ seasons: 3, points: 5 }), owned: {} });
  ok(d.run('JSON.stringify(Object.keys(lockedFormats(loadCareer())))') === '["live"]', '前に5ポイントだった人は、体力合宿とペア対決を持ったまま');
  d.run(START + FINISH); d.press('monthdone'); d.run('hikariBetweenDone()');
  const du = JSON.parse(d.run('JSON.stringify(loadCareer().unl)'));
  ok(du.camp && du.duo, '次のシーズンを終えて保存しても、解放済みの審査は消えない');
  const e = boot({ adFree: false, store: CAR({}), owned: {} });
  ok(e.run('Object.keys(lockedFormats(loadCareer())).length') === 3, 'はじめての人は3つとも閉じている');
  e.run(START);
  ok(e.run("Object.keys(S.locked).length") === 3 && /覚醒/.test(e.run('S.locked.camp')), '閉じた審査には、開く条件（経験）が出る');
  e.run("S.tr[0].awoke=true;" + FINISH); e.press('monthdone'); e.run('hikariBetweenDone()');
  ok(e.run('!!loadCareer().unl.camp') && /体力合宿/.test(e.run('S.careerNews.news.join("|")')), '誰かを覚醒させたシーズンを終えると体力合宿が開く');
  ok(e.run('loadCareer().seasons') === 1 && !e.run('loadCareer().unl.duo'), 'コンビを結成していなければペア対決は閉じたまま');

  // 肩書きの先は、難しさの実績も要る
  ok(e.run("rankOf(300,{achv:{}})[1]") === '番組の顔' && e.run("rankOf(300,{achv:{hardA5:1,legendA3:1,legendS:1}})[1]") === 'ひかりの名プロデューサー', '番組の顔より先の肩書きは、難しさの実績が無いと上がらない');
  // 結末の手がかり：まだ見ていない結末に近づく条件を、いつもの3つに足す
  const ms = JSON.parse(e.run("JSON.stringify(pickMissions({endings:{}}))"));
  ok(ms.length === 4 && e.run(`!!missionOf(${JSON.stringify(ms[3])}).end`) && ms.slice(0, 3).every((k) => !e.run(`missionOf(${JSON.stringify(k)}).end`)), '依頼はいつもの3つ＋結末の手がかり1つ');
  const allSeen = '{' + e.run("ENDS.map(function(x){return JSON.stringify(x.k)+':1';}).join(',')") + '}';
  ok(e.run(`pickMissions({endings:${allSeen}}).length`) === 3, '結末をすべて見た人には、手がかりを出さない');
  ok(e.run("(function(){for(var i=0;i<200;i++){var m=pickMissions({endings:{}}).map(missionOf),bad=m.some(function(a){return m.some(function(b){return a!==b&&missionClash(a,b);});});if(bad)return false;}return true;})()"), '手がかりと重なる・食い違う依頼は一緒に出さない');
  // はじめてのシーズンの C は休止からの再出発
  e.run(START + "S.first=1;" + FINISH);
  ok(e.run("(function(){var D=S.tr.filter(function(t){return t.status==='debut';});for(var i=0;i<30;i++){if(endShape(S,{q:.3},{tier:3,D:D,coh:30,combos:[],L:null}).k!=='restart')return false;}return true;})()"), 'はじめてのシーズンの C は、解散ではなく休止からの再出発になる');
  e.run('S.first=0');
  ok(e.run("(function(){var D=S.tr.filter(function(t){return t.status==='debut';});for(var i=0;i<30;i++){if(endShape(S,{q:.3},{tier:3,D:D,coh:30,combos:[],L:null}).k!=='restart')return true;}return false;})()"), '2シーズン目からの C は、これまでどおり解散の筋もある');

  // 心得の上の段（2026-11-15）：1段目を極めると開く。前の保存（上の段の印が無い）でも壊れず、取ったものは消えない
  const pk = boot({ adFree: false, store: CAR({ seasons: 9, points: 70, spent: 58, perk: { bud: 3, watch: 2, seat: 2, trust: 2, coach: 1, bond: 1, ap: 1 }, achv: { perkAll: 1 } }), owned: {} });
  ok(pk.run("perkPoints(loadCareer())") === 12 && /上の段/.test(pk.run('perkBox()')), '前の保存のまま開ける。上の段が出る');
  ok(pk.run("buyPerk('bud2')") === false && pk.run("(loadCareer().perk.bud2||0)") === 0, 'ポイントが足りなければ上の段は買えない');
  pk.run("var c=loadCareer();c.points=200;saveCareer(c);");
  ok(pk.run("buyPerk('bud2')") === true && pk.run('loadCareer().perk.bud2') === 1 && pk.run('loadCareer().spent') === 74, '1段目を極めていれば、上の段を買える（使ったポイントに入る）');
  ok(pk.run("buyPerk('rare')") === true, '1段目をすべて極めると「掘り出し上手」が開く');
  ok(pk.run("loadCareer().perk.bud") === 3 && pk.run("!!loadCareer().achv.perkAll"), '上の段を買っても、1段目と実績「心得を極める」は消えない');
  const pl = boot({ adFree: false, store: CAR({ seasons: 2, points: 40, spent: 4, perk: { bud: 2 } }), owned: {} });
  ok(pl.run("buyPerk('bud2')") === false && /を極めると開く/.test(pl.run('perkBox()')), '1段目を極めていない心得の上の段は、買えず「極めると開く」と出る');
  ok(pl.run("perkBase().length") === 7 && pl.run("ACHV.filter(function(a){return a.k==='perkAll';})[0].chk(null,null,{perk:{bud:3,watch:2,seat:2,trust:2,coach:1,bond:1,ap:1}})"), '実績「心得を極める」は1段目だけで数える（上の段で遠くならない）');
  ok(pl.run("PERKS.filter(function(p){return p.req;}).every(function(p){return p.x;})"), '上の段の心得には、どれも代償が書いてある');
  // 上の段の効き目と代償
  const pe = boot({ adFree: false, store: CAR({ seasons: 9, points: 300, spent: 240, perk: { bud: 3, watch: 2, seat: 2, trust: 2, coach: 1, bond: 1, ap: 1, bud2: 2, watch2: 1, coach2: 1, trust2: 1, bond2: 1, ap2: 1, rare: 1 } }), owned: {} });
  pe.run("S=newGame('m','normal',null);");
  ok(pe.run("S.tr.filter(function(t){return t.rare;}).length") >= 1, '掘り出し上手：めずらしい応募者が必ず来る');
  ok(pe.run("slotsOf(S)") === pe.run("SP_SLOTS+2"), '専属トレーナー：特訓できる人数がさらに+1');
  const daily = boot({ adFree: false, store: CAR({ seasons: 9, perk: { rare: 1 } }), owned: {} });
  ok(daily.run("(function(){var a=[];for(var i=0;i<3;i++){S=newGame('m','normal',null,'2026-11-15');a.push(S.tr.map(function(t){return t.rare||'';}).join(','));}return a[0]===a[1]&&a[1]===a[2];})()"), '今日のオーディションの応募者は、心得があっても同じ');
  // 会議の最初の画面：前回のあらすじは1〜2行にたたみ、押すと全部（物語の文は消さない）
  const pv = boot({ adFree: false, store: CAR({}), owned: {} });
  pv.run(START + "S.story={r:1,lines:['一行目のあらすじ。','二行目のあらすじ。']};S.rnd=2;");
  const vp = pv.run('vPlan()');
  ok(/<details class="prevst pvf"/.test(vp) && /一行目のあらすじ/.test(vp) && /二行目のあらすじ/.test(vp) && /data-a="fold" data-v="story"/.test(vp), '前回のあらすじは畳んだ札で、文はすべて残っている');
  // 本番の出来の文：型・担当ごとの束と、その子だけの行
  ok(pv.run("(function(){var n=0;['v','d','r','e'].forEach(function(k){['g','o','b'].forEach(function(g){['solo','team','duo','live','final'].forEach(function(ty){n+=BEAT_TY[ty][k][g].length;});});});return n;})()") >= 150, '出来の文に、審査の型ごとの束がある');
  ok(pv.run("(function(){S.rnd=2;S.critRes=[{id:S.tr[0].id,c:1,say:'x'}];var t=S.tr[0];t.traits=['clutch'];var a=beatPers(S,t,90),b=beatPers(S,t,60);return !!a&&b===null;})()"), 'その子だけの行は、出来がはっきりしたときだけ出る');
}

// ===== 画面の弱い所（2026-11-15）：最後の合格者の間・別れの言葉の決め手・次のシーズンの引き・「新」の札 =====
{
  const e = boot({ adFree: false, store: {}, owned: {} });
  const fire = () => { for (let i = e.timers.length - 1; i >= 0; i--) if (e.timers[i]) { const f = e.timers[i]; e.timers[i] = null; f(); return true; } return false; };
  const html = () => e.run("document.querySelector('#app').innerHTML");
  e.run(START + PLAY_ROUND);
  e.run('S.call.n=S.call.order.length-1;S.call.done=false;');
  e.press('calllast');
  ok(e.run('!!ui.lastRoll&&!S.call.done&&S.call.n===S.call.order.length-1') && /lastseat rolling/.test(html()), '最後の合格者：「名前を呼ぶ」ですぐ一覧に戻らず、候補の顔の点滅が始まる');
  e.run('ROLL_MS=0'); fire();
  ok(e.run('!ui.lastRoll&&!S.call.done&&S.call.n===S.call.order.length') && /crev last/.test(html()) && /crok/.test(html()), '点滅のあと、選ばれた子を大きく照らして合格のひと言を出す（まだ一覧へは行かない）');
  fire();
  ok(e.run('S.call.done'), '少し置くと一覧へ進む');
  e.run('S.call.n=S.call.order.length-1;S.call.done=false;ROLL_MS=1500;'); e.press('calllast'); e.press('lastskip');
  ok(e.run('!ui.lastRoll&&!S.call.done&&S.call.n===S.call.order.length'), '点滅中に押すと、すぐ発表に飛ぶ');
  e.press('lastskip');
  ok(e.run('S.call.done'), '発表中に押すと、すぐ一覧へ');
  e.run('S.call.n=S.call.order.length-1;S.call.done=false;ui.endStatic=true;'); e.press('calllast');
  ok(e.run('!ui.lastRoll&&S.call.n===S.call.order.length'), '動きを減らす設定なら点滅を飛ばす');
  e.run('ui.endStatic=false;'); fire();
  // 別れの言葉：決め手と効き目、下の帯
  e.run('S.farewell={};render();');
  const nf = e.run('S.call.failed.length');
  ok(nf > 0 && html().includes('data-a="fwjump"') && html().includes('残り' + nf + '人') && html().includes('このまま進む'), '選んでいない子がいる間は、下の帯が「ひと言を選ぶ（残りn人）」になり、進む道も残る');
  ok(/人気 ★\d+/.test(html()) && /番組で[＋−]\d+伸びた/.test(html()) && e.run('FW_SHORT.every(function(x){return document.querySelector("#app").innerHTML.indexOf(x)>=0;})'), '行に人気と伸びの札、3つの言葉の効き目が出る');
  ok(e.run("(function(){var t=S.tr[S.call.failed[0]],p=t.pop,sh=t.sh;t.pop=50;var a=fwBest(t);t.pop=10;t.sh=[[1,0,0,0,0]];var b=fwBest(t);t.sh=[[1,t.st.v,t.st.d,t.st.r,t.st.e]];var c=fwBest(t);t.pop=p;t.sh=sh;return a===2&&b===0&&c===-1;})()"), '合う言葉：人気35以上は「また必ず会おう」、大きく伸びた子は「誇って」');
  e.press('fwall', 1);
  ok(!html().includes('data-a="fwjump"'), '全員に選ぶと、下の帯は「次の審査へ」に戻る');
}
{
  const CAR = (o) => ({ hikari7_career: JSON.stringify(Object.assign({ seasons: 0, points: 0, hall: [] }, o)) });
  const e = boot({ adFree: false, store: CAR({ seasons: 10, points: 12 }), owned: {} });
  const html = () => e.run("document.querySelector('#app').innerHTML");
  const pk = e.run('Object.keys(PACK_AUDITION)[0]');
  e.run("S=newGame('f','hard','poor');var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);S.fmt=[null,null,null,null];render();");
  ok(e.run('S.phase') === 'format' && e.run(`fmtKeys().indexOf(${JSON.stringify(pk)})>=0`) && html().includes('class="ftag"'), 'ごほうびで入った審査の型に「新」の札が付く');
  e.press('fadd', pk);
  ok(!e.run(`fmtNew(${JSON.stringify(pk)})`) && e.run(`Object.keys(PACK_AUDITION).slice(1).every(fmtNew)`), '一度選んだ型だけ「新」が消える');
  e.run("S.fmt=DEFAULT_FMT.slice();startSeason(S);S.tr.slice(0,6).forEach(function(t){t.status='debut';});S.tr[7].fwd='again';S.tr[7].status='out';startPrep(S);S.prep.leader=S.tr[0].id;S.phase='month';S.month={w:4,busy:0,fan:0,song:0,coh:0,log:[]};");
  e.press('monthdone'); e.run('hikariBetweenDone()');
  ok(e.run('S.phase') === 'result' && e.posts.filter((p) => p.type === 'between').length === 1, '全画面広告はエンドロールの前に1回のまま');
  e.run('S.ending=false;render();');
  ok(html().includes('次のシーズンでできること') && /次の肩書き/.test(html()) && /ごほうびの「物語パック」まで あと<b>\d+<\/b>シーズン/.test(html()) && /約束した子 <b>\d+人<\/b>/.test(html()) && html().includes('data-a="again"'), '結果の一番下に「次のシーズンでできること」と「同じ設定で次のシーズン」');
  e.press('again');
  ok(e.run("S.phase==='select'&&S.g==='f'&&S.diff==='hard'&&S.chal==='poor'&&!S.recorded"), '「同じ設定で次のシーズン」で、同じ性別・難しさ・チャレンジの新しいシーズンが始まる');
}

// ===== 約束の子の再挑戦（2026-11-15）：前は名前がぶつかると何もせず、出る率が2%だった =====
{
  const b = boot({ adFree: false, store: { hikari7_career: JSON.stringify({ seasons: 0, points: 0, hall: [] }) }, owned: {} });
  const r = JSON.parse(b.run(`(function(){var o={n:0,ap:0,bad:[],keep:0,dly:0,face:0},N=300;
    function grp(g,i){return (typeof FACE_GRP!=='undefined'&&FACE_GRP[g])?FACE_GRP[g][i]:i;}
    for(var i=0;i<N;i++){var g=i%2?'f':'m';saveCareer({seasons:0,points:0,hall:[]});var P=newGame(g,'normal',null),t=P.tr[i%P.tr.length];
      var rec={g:g,img:t.img,fam:t.fam,giv:t.giv,spec:t.spec,temper:t.temper,pot:t.pot,age:t.age,home:t.home,st:t.st,
        bg:{start:'き',past:'が',family:'テストの家族',skill:'と',habit:'「テストの口癖」'},dream:'テストの夢',like:'テストの好物',arc:'lyric',vo:g+'3'};
      saveCareer({seasons:3,points:10,hall:[],back:[rec]});var S=newGame(g,'normal',null),B=S.tr.filter(function(x){return x.back;});o.n++;
      if(B.length){o.ap++;var x=B[0],F={},G={},I={};S.tr.forEach(function(y){F[y.fam]=(F[y.fam]||0)+1;G[y.giv]=(G[y.giv]||0)+1;I[grp(g,y.img)]=(I[grp(g,y.img)]||0)+1;});
        if(x.fam!==rec.fam||x.giv!==rec.giv||F[x.fam]>1||G[x.giv]>1||S.tr.some(function(y){return y.name!==y.fam+' '+y.giv;}))o.bad.push('名前 '+x.name);
        if(x.img!==rec.img||Object.keys(I).some(function(k){return I[k]>1;}))o.bad.push('顔 '+x.img);
        if(B.length!==1||x.rare)o.bad.push('札');
        if(S.rels.some(function(r){return (r.a===x.id||r.b===x.id)&&r.k!=='town';})||S.tr.some(function(y){return y.arc&&y.arc.p===x.id;}))o.bad.push('つながり');
        if(x.bg.family==='テストの家族'&&x.bg.habit==='「テストの口癖」'&&x.dream==='テストの夢'&&x.like==='テストの好物'&&x.arc.k==='lyric'&&x.arc.step===0&&x.vo===g+'3'&&x.temperRev&&!x.backKeep)o.keep++;
        if(loadCareer().back.length)o.bad.push('記録が残った');}
      saveCareer({seasons:3,points:10,hall:[],back:[rec]});var D=newGame(g,'normal',null,'2026-11-15');if(D.tr.some(function(y){return y.back;})||!loadCareer().back.length)o.dly++;}
    return JSON.stringify(o);})()`));
  console.log('  再挑戦の子が出た率', (r.ap / r.n * 100).toFixed(1) + '%（' + r.ap + '/' + r.n + '）');
  ok(r.ap / r.n >= 0.1, '前のシーズンに「また会おう」と送り出した子が、1割以上のシーズンで戻ってくる');
  ok(!r.bad.length, '戻ってきた子と名前・顔がぶつかる子がいない／注目の札・前の枠のつながりを引き継がない' + (r.bad.length ? '（' + r.bad.slice(0, 3).join('・') + '）' : ''));
  ok(r.keep === r.ap, '戻ってきた子の物語・家族・口癖・夢・声は前のシーズンの記録のまま');
  ok(r.dly === 0, '今日のオーディションでは戻ってこない（乱数をずらさない・記録も消さない）');
  // 書類審査の一番上の札
  b.run(`saveCareer({seasons:3,points:10,hall:[],back:[]});S=newGame('f','normal',null);var bt=S.tr[7];bt.back=1;S.phase='select';`);
  ok(/約束の子が戻ってきた<\/b>（No\.08 /.test(b.run('vSelect()')) && /data-a="backjump" data-id="7"/.test(b.run('vSelect()')), '書類審査の一番上に「約束の子が戻ってきた（No.n 名前）」の札が出て、押すとその子へ飛ぶ');
  b.run('S.tr[7].back=0');
  ok(!/約束の子が戻ってきた/.test(b.run('vSelect()')), '戻ってきた子がいなければ札は出ない');
}

// ===== 物語の3択の外れ（2026-11-15） =====
{
  const a = boot({ adFree: false, store: {}, owned: {} });
  const r = JSON.parse(a.run(`(function(){S=newGame('f','normal',null);var o={miss:0,ok:0,bad:[],half:0,lab:0};
    for(var i=0;i<S.tr.length*3;i++){var t=S.tr[i%S.tr.length];if(!t.arc||t.arc.step>=3)continue;var sc=arcScene(S,t),ch=arcChoices(S,t);
      if(ch.some(function(c){return !c.hint.parts.some(function(p){return /信頼・自信−|気質に合わない/.test(p[0]);});}))o.lab++;
      var j=i%3,oi=arcPerm(t)[j],c4=arcText(S,t,sc.ch[oi][4]),rev=t.temperRev,res=arcChoose(S,t,j),hit=t.arc.hits[t.arc.hits.length-1];
      if(hit){o.ok++;if(res.indexOf(c4)!==0)o.bad.push('当たりなのに返事が違う');}
      else{o.miss++;if(res.indexOf(c4)>=0)o.bad.push('外れなのに成功の返事: '+res);if(!rev&&t.ngT)o.half++;}}
    return JSON.stringify(o);})()`));
  ok(r.miss > 0 && r.ok > 0 && !r.bad.length, '物語の3択：外れたら成功前提の返事を出さず、外れ用の返事にする' + (r.bad.length ? '（' + r.bad[0] + '）' : ''));
  ok(r.lab === 0, '物語の3択の札に「気質しだいで 信頼・自信−」（気質が分かれば「外すと…」か「気質に合わない」）が付く');
  ok(a.run(`(function(){var t={temper:'sensai',temperRev:false};temperHalf(t,'h');var x=temperTxt(t);temperHalf(t,'a');return x+'|'+temperTxt(t)+'|'+t.temperRev;})()`) === '繊細かマイペースかお調子者？|繊細かマイペース？|false'
    && a.run(`(function(){var t={temper:'makezu',temperRev:false};temperHalf(t,'s');return t.temperRev;})()`) === true, '気質に合わない語りかけで外れると、気質の候補が絞られる（1つになれば明かす）');
}

if (fails) { console.error(fails + '件 外れ'); process.exitCode = 1; } else console.log('すべて通った');
