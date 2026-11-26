// 2段目「続ける理由」その1（決定133〜135・139・140・147）：系譜タブ（系譜図・名鑑・殿堂・実績・年表）、
// 殿堂の2段、実績66個（5分野・銅銀金）、育成基金。見せ方は下の views の部分（画面を持たない点検では使わない）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 実績：22の物差し × 銅銀金 = 66個（決定134）----------
  const sum = (al, f) => al.reduce((s, a) => s + f(a), 0);
  const cnt = (al, f) => al.filter(f).length;
  const wcN = (a) => (a.awards || []).filter((x) => /W杯/.test(x.name)).length;
  YA.ACH_FIELDS = ['育成', '試合と大会', '卒業生', 'クラブ', '系譜'];
  YA.ACH_TIERS = ['銅', '銀', '金'];
  // [key, 分野, 名前（{n}に目標の数が入る）, 目標3つ, 数え方]
  const METRICS = [
    ['pro', 0, 'プロ入りした卒業生が{n}人', [5, 15, 40], (w) => cnt(w.alumni, (a) => a.status === 'pro')],
    ['r125', 0, 'J1級（総合力125）に届いた卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => YA.rate(a.ovr) >= 125)],
    ['r155', 0, '日本代表級（総合力155）に届いた卒業生が{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => YA.rate(a.ovr) >= 155)],
    ['grads', 0, '送り出した卒業生が{n}人', [36, 108, 360], (w) => w.alumni.length],
    ['dex', 0, '覚醒の図鑑を{n}種そろえる', [5, 10, 20], (w) => YA.dexCount(w)],
    ['dexb', 0, '覚醒の図鑑を{n}種そろえる', [40, 60, 80], (w) => YA.dexCount(w)], // 2026-11-20 覚醒の形を80種に
    ['trophy', 1, '大会で優勝を{n}回', [1, 5, 15], (w) => (w.trophies || []).length],
    ['lwin', 1, 'リーグ優勝を{n}回', [1, 3, 8], (w) => (w.leagueHist || []).filter((x) => x.rank === 1).length],
    ['wins', 1, 'Aチームで通算{n}勝', [20, 100, 300], (w) => (w.rec && w.rec.w) || 0],
    ['top1', 1, '1部で戦った年が{n}年', [1, 5, 10], (w) => (w.leagueHist || []).filter((x) => x.level === 1).length],
    ['nat', 2, '代表経験者が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => a.nat > 0)],
    ['abroad', 2, '海外のクラブへ行った卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => a.abroad)],
    ['u21', 2, 'U-21代表を出す（{n}人）', [1, 3, 10], (w) => cnt(w.alumni, (a) => a.u21 > 0)],
    ['apps', 2, '卒業生のプロでの通算出場が{n}試合', [100, 1000, 5000], (w) => sum(w.alumni, (a) => (a.status === 'pro' ? a.apps : 0))],
    ['titles', 2, '卒業生が獲ったタイトルが{n}個', [1, 10, 40], (w) => sum(w.alumni, (a) => (a.titles || []).length)],
    ['wc', 2, 'W杯に出た卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => wcN(a) > 0)],
    ['hof', 2, '殿堂入りが{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => a.hof === 'full')],
    ['years', 3, '{n}年指導する', [3, 10, 20], (w) => Math.max(0, w.year - 1)],
    ['fund', 3, '育成基金に累計{n}万円', [500, 2000, 7500], (w) => w.fundIn || 0],
    ['fac', 3, '施設レベル{n}', [1, 3, 6], (w) => YA.facilityLevel(w)],
    ['clubs', 3, '{n}つのクラブを指導する', [2, 3, 5], (w) => ((w.club && w.club.careerClubs) || []).length + 1],
    ['long', 4, '10年以上プレーした卒業生が{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => (a.seasons || []).length >= 10)],
    ['ret', 4, '現役を引退した卒業生が{n}人', [1, 10, 30], (w) => cnt(w.alumni, (a) => a.retired && !a.quit)],
    ['cand', 4, '殿堂候補になった卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => !!a.hof)],
  ];
  YA.ACH_COUNT = METRICS.length * 3;
  YA.achievements = function (w) {
    const out = [];
    for (const [k, f, name, goals, fn] of METRICS) {
      const cur = fn(w);
      goals.forEach((g, i) => out.push({ k: k + i, name: name.replace('{n}', g.toLocaleString('en-US')), field: YA.ACH_FIELDS[f], tier: YA.ACH_TIERS[i], cur, goal: g, done: cur >= g }));
    }
    return out;
  };
  // 次に届きそうな実績を1つ（決定134）。進み具合がいちばん大きく、まだ届いていないもの
  YA.nextAchievement = function (w) {
    let best = null;
    for (const a of YA.achievements(w)) {
      if (a.done) continue;
      const r = a.cur / a.goal;
      if (!best || r > best.r) best = { a, r };
    }
    return best ? best.a : null;
  };
  // 新しく届いた実績を知らせる（毎週の進行のあとに呼ぶ）
  YA.achieveCheck = function (w) {
    const seen = (w.achSeen = w.achSeen || {});
    const firstRun = !w.achInit;
    w.achInit = true;
    const got = [];
    for (const a of YA.achievements(w)) {
      if (!a.done || seen[a.k]) continue;
      seen[a.k] = w.year;
      got.push(a);
    }
    if (!firstRun) for (const a of got) YA.noteTier(w, a.tier === '金' ? 1 : 2, `実績「${a.name}」（${a.tier}）に届きました`);
    return got;
  };

  // ---------- 殿堂の2段（決定133）----------
  // 条件に届いた瞬間に「殿堂候補」（銀）。引退のときに生涯の成績で正式に殿堂入り（金）
  // 2026-11-17 点検：候補51%・殿堂入り17%とかんたんすぎた。候補は「日本代表・5大リーグ・主要タイトル・個人の大きな賞」のどれか。
  // 殿堂入りは点が YA.HOF_FULL（9）以上。大学・社会人のタイトルと出場は数えない。代表は試合数（a.caps）で数える
  const BIG5 = /^(プレミアリーグ|ラ・リーガ|ブンデスリーガ|セリエA|リーグ・アン)$/;
  const proSeasons = (a) => (a.seasons || []).filter((s) => !/大学|社会人/.test(s.league || ''));
  const big5Seasons = (a) => proSeasons(a).filter((s) => BIG5.test(s.league || '') && s.apps >= 10).length;
  const capsOf = (a) => (a.caps != null ? a.caps : (a.nat || 0) * 5);
  const MAJOR_T = /^(J1リーグ|プレミアリーグ|ラ・リーガ|ブンデスリーガ|セリエA|リーグ・アン)優勝$|^チャンピオンズリーグ優勝$|^ACL優勝$/;
  const BIG_AW = /^バロンドール|ゴールデンシュー|コパ・トロフィー|ヤシン|アジア年間最優秀|^W杯出場|^(J1リーグ|プレミアリーグ|ラ・リーガ|ブンデスリーガ|セリエA|リーグ・アン) (年間MVP|得点王)$/;
  YA.HOF_FULL = 9;
  const hofScore = YA.hofScore = function (a) {
    const caps = capsOf(a);
    let v = (caps > 0 ? 2 : 0) + Math.min(6, Math.floor(caps / 15));
    for (const t of a.titles || []) v += /^チャンピオンズリーグ/.test(t.name) ? 3 : /^(プレミアリーグ|ラ・リーガ|ブンデスリーガ|セリエA|リーグ・アン)優勝$/.test(t.name) ? 2 : /^(J1リーグ|ACL)優勝$/.test(t.name) ? 1 : 0;
    for (const x of a.awards || []) v += x.name === 'バロンドール' ? 5 : /^バロンドール ([1-9]|10)位$/.test(x.name) ? 3 : /^バロンドール/.test(x.name) ? 1 : /ゴールデンシュー|コパ・トロフィー|ヤシン|アジア年間最優秀|^W杯出場/.test(x.name) ? 2 : /^(J1リーグ|プレミアリーグ|ラ・リーガ|ブンデスリーガ|セリエA|リーグ・アン) (年間MVP|得点王)$/.test(x.name) ? 1 : 0;
    v += Math.min(3, Math.floor(proSeasons(a).reduce((t, s) => t + (s.apps || 0), 0) / 150));
    v += Math.floor(big5Seasons(a) / 3);
    return v;
  };
  // 5大リーグは主力（10試合以上）で3季。主要タイトルは5大リーグと CL の優勝（J1・ACL の優勝は点にだけ数える。
  // 強いJクラブに卒業生が集まるので、J1優勝だけで候補にすると2割を超えた）
  YA.hofCondition = (a) => proSeasons(a).length > 0 && (capsOf(a) > 0 || big5Seasons(a) >= 3 || (a.titles || []).some((t) => MAJOR_T.test(t.name) && !/^(J1リーグ|ACL)優勝$/.test(t.name)) || (a.awards || []).some((x) => BIG_AW.test(x.name)));
  YA.hofFull = (a) => hofScore(a) >= YA.HOF_FULL;
  const HOF_WORDS = ['あの頃から、ひたむきな子でした。', 'いちばん最初に練習に来て、最後まで残る子でした。', '背中を押しただけです。歩いたのは本人です。', '卒業の日の顔を、いまも覚えています。', 'ここから世界へ行ったのだと思うと、誇らしい。'];
  YA.hofWord = (w, a) => HOF_WORDS[(a.name.length + a.year) % HOF_WORDS.length];
  const tickBase = YA.alumniTick;
  YA.alumniTick = function (w) {
    const was = new Set(w.alumni.filter((a) => a.retired).map((a) => a));
    const contrib = tickBase(w);
    for (const a of w.alumni) {
      if (!a.hof && YA.hofCondition(a)) {
        a.hof = 'cand';
        a.hofY = w.year;
        YA.noteTier(w, 2, `卒業生の${a.name}が殿堂候補になりました（${a.club}）`);
      }
      if (a.hof === 'cand' && ((a.retired && !was.has(a) && YA.hofFull(a)) || (!a.retired && a.age >= 31 && hofScore(a) >= YA.HOF_FULL + 3))) {
        a.hof = 'full';
        a.hofY = w.year;
        YA.noteTier(w, 1, `卒業生の${a.name}が殿堂入りしました。「${YA.hofWord(w, a)}」`);
      }
    }
    YA.achieveCheck(w);
    return contrib;
  };
  // ---------- 遺産（決定152を作り直し）：絆の深い★の卒業生が、次の人生にコーチとして付いてくる ----------
  // 端末の store 'legacy' = { runs, people: [{ name, pos, main, ovr, bond, form, mem, year, club, from }] }
  YA.legacyCands = (w) => (w.alumni || []).filter((a) => a.mem && a.star && (a.bond == null ? 3 : a.bond) >= 3).sort((a, b) => (b.bond || 0) - (a.bond || 0) || b.ovr - a.ovr).slice(0, 3);
  // 引退したとき1回だけ。付いてきてくれる教え子（最大3人）を残す
  YA.legacyBank = function (store, w) {
    if (w.legacyBanked) return w.legacyBanked;
    const st = store.get('legacy', null) || { runs: 0, people: [] };
    const add = YA.legacyCands(w).map((a) => ({ name: a.name, pos: a.pos, main: a.main, ovr: a.ovr, bond: a.bond, form: a.form || null, mem: (a.mem || []).slice(-6), year: a.year, club: a.club, from: w.clubName }));
    store.set('legacy', { runs: (st.runs || 0) + 1, people: (st.people || []).concat(add).slice(-6) });
    w.legacyBanked = add.map((x) => x.name);
    return w.legacyBanked;
  };
  YA.legacyPeople = (store) => ((store.get('legacy', null) || {}).people || []);
  // 新しい人生に連れていく（store から外す）
  YA.legacyTake = function (store, name) {
    const st = store.get('legacy', null) || { runs: 0, people: [] };
    const p = (st.people || []).find((x) => x.name === name);
    if (!p) return null;
    store.set('legacy', Object.assign({}, st, { people: st.people.filter((x) => x !== p) }));
    return p;
  };
  YA.legacyApply = function (w, person) {
    if (!person || !YA.obJoin) return;
    const s = YA.obJoin(w, Object.assign({}, person), `前の人生の教え子。${person.from || '前のクラブ'}から付いてきてくれた`);
    w.legacyUsed = person.name;
    return s;
  };
  const newWorldBase = YA.newWorld;
  YA.newWorld = function (...a) {
    const w = newWorldBase.apply(this, a);
    w.achInit = true; // 新しい世界は最初から知らせる。古いセーブは最初の1回だけ黙って記録する
    if (a[1] && a[1].legacy) YA.legacyApply(w, a[1].legacy);
    return w;
  };

  // ---------- 育成基金（決定135）：連帯貢献金はクラブ予算と別に貯まる。使い道は自分で決める ----------
  YA.FUND_USES = [
    { k: 'facility', name: '施設の建て増し', cost: 800, note: '施設の積み立てが600万円（施設1段ぶん）進みます' },
    { k: 'trip', name: '海外遠征', cost: 600, note: '全員の自信が上がり、課題中の子との信頼が深まります' },
    { k: 'scout', name: '腕の良いスカウトを雇う', cost: 700, note: '今年は、月ごとに見に行ける回数が1回増えます' },
    // 毎年くり返し使える使い道（2026-11-17 直し：前は使い道が少なく、10年目に予算の2.5倍たまっていた）。どれも1年に1回
    { k: 'staff', name: 'スタッフの給料に回す', cost: 500, yearly: true, note: '今年の予算が500万円増えます（スタッフの入れ替えや遠征に使えます）' },
    { k: 'medical', name: '医療とトレーナーの体制', cost: 400, yearly: true, note: '今年は怪我が2割減り、疲れが少し抜けやすくなります' },
    { k: 'dorm', name: '寮の食事と設備', cost: 300, yearly: true, note: '今年は寮生の疲れが抜けやすく、全員の自信が少し上がります' },
  ];
  // 押せない理由（押せるなら null）
  YA.fundWhy = function (w, k) {
    const u = YA.FUND_USES.find((x) => x.k === k);
    if (!u) return '使い道がありません';
    if ((w.fund || 0) < u.cost) return `育成基金が足りません（${u.cost}万円）`;
    if (u.yearly && (w.fundYr || {})[k] === w.year) return '今年はもう使いました（1年に1回）';
    if (k === 'scout' && w.scoutPlus) return '今年はもう雇っています';
    return null;
  };
  YA.fundUse = function (w, k) {
    const u = YA.FUND_USES.find((x) => x.k === k);
    const why = YA.fundWhy(w, k);
    if (why) return { ok: false, msg: why };
    w.fund -= u.cost;
    if (u.yearly) (w.fundYr = w.fundYr || {})[k] = w.year;
    if (k === 'staff') w.club.total += u.cost;
    else if (k === 'dorm') for (const p of Object.values(w.players)) p.conf = clamp((p.conf || 50) + 2, 0, 100);
    if (k === 'facility') w.club.facPts = (w.club.facPts || 0) + 600;
    else if (k === 'trip') {
      for (const p of Object.values(w.players)) p.conf = clamp((p.conf || 50) + 5, 0, 100);
      for (const p of Object.values(w.players)) if (p.star && YA.addTr) YA.addTr(w, p, 1);
    } else if (k === 'scout') w.scoutPlus = 1;
    (w.fundLog = w.fundLog || []).push({ y: w.year, k, cost: u.cost });
    return { ok: true, msg: `${u.name}に${u.cost}万円を使いました` };
  };
  // 今年使った、くり返しの使い道か
  YA.fundOn = (w, k) => (w.fundYr || {})[k] === w.year;
  // おまかせ（年度はじめ）：基金がたまっていたら、施設→医療→寮→給料→スカウト→遠征の順に、手元に300万円ほど残して使う
  YA.fundAuto = function (w, notes) {
    const order = ['medical', 'dorm', 'facility', 'staff', 'scout', 'trip'];
    for (let g = 0; g < 8; g++) {
      const k = order.find((x) => !YA.fundWhy(w, x) && (w.fund || 0) - YA.FUND_USES.find((u) => u.k === x).cost >= 300 && !(x === 'facility' && YA.facilityLevel(w) >= 5));
      if (!k) break;
      const r = YA.fundUse(w, k);
      if (notes && r.ok) notes.push(r.msg);
      if (!r.ok) break;
    }
  };
  // 年度はじめ：前の年の連帯貢献金を育成基金へ（予算には入れない）
  const yearStartBase = YA.yearStart;
  YA.yearStart = function (w) {
    const got = (w.club && w.club.solidarity) || 0;
    const add = Math.round(got * 0.5); // 決定：連帯貢献金の5割が基金、残りはクラブ本体へ（予算には入れない）。知らせも「半分を育成基金へ」と書く
    if (w.club) w.club.solidarity = 0;
    yearStartBase(w);
    w.fund = (w.fund || 0) + add;
    w.fundIn = (w.fundIn || 0) + add;
    w.club.solidarityLast = add;
    w.scoutPlus = 0;
  };

  // ---------- 系譜図（決定147）：アカデミー長を根にした、横に伸びる木 ----------
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  YA.lineageData = function (w) {
    const years = {};
    for (const a of w.alumni) (years[a.year] = years[a.year] || []).push(a);
    const ys = Object.keys(years).map(Number).sort((a, b) => a - b);
    return { ys, years };
  };
  // mini=true なら名前なしの小窓。戻りは SVG の文字列
  YA.lineageSvg = function (w, opt) {
    const mini = !!(opt && opt.mini);
    const { ys, years } = YA.lineageData(w);
    const colW = mini ? 26 : 150, rowH = mini ? 7 : 19, x0 = mini ? 14 : 70;
    const rows = Math.max(1, ...ys.map((y) => years[y].length));
    const H = rows * rowH + (mini ? 14 : 34);
    const W = x0 + Math.max(1, ys.length) * colW + (mini ? 6 : 30);
    const my = H / 2;
    let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="sans-serif">`;
    s += `<circle cx="${x0 - (mini ? 8 : 40)}" cy="${my}" r="${mini ? 4 : 11}" fill="#1f6feb"/>`;
    if (!mini) s += `<text x="${x0 - 40}" y="${my + 3}" font-size="9" text-anchor="middle" fill="#fff">長</text>`;
    ys.forEach((y, i) => {
      const x = x0 + i * colW;
      const list = years[y].slice().sort((a, b) => b.ovr - a.ovr);
      s += `<line x1="${i ? x - colW : x0 - (mini ? 8 : 40)}" y1="${my}" x2="${x}" y2="${my}" stroke="#9db4d6" stroke-width="2"/>`;
      list.forEach((a, j) => {
        const yy = my + (j - (list.length - 1) / 2) * rowH;
        const pro = a.status === 'pro';
        const hof = a.hof === 'full', cand = a.hof === 'cand';
        const col = hof ? '#d9a400' : cand ? '#9aa6b8' : pro ? '#1f6feb' : '#c3cedf';
        s += `<line x1="${x}" y1="${my}" x2="${x + (mini ? 8 : 16)}" y2="${yy}" stroke="${col}" stroke-width="${pro ? 2.4 : 1}"/>`;
        const cx = x + (mini ? 10 : 20);
        s += `<circle cx="${cx}" cy="${yy}" r="${mini ? 2 : 4.5}" fill="${col}"${hof || cand ? ` stroke="${hof ? '#a37b00' : '#6b7587'}" stroke-width="1.5"` : ''}/>`;
        if (a.nat > 0) s += `<circle cx="${cx}" cy="${yy}" r="${mini ? 1 : 2}" fill="#ffd34d"/>`;
        if (!mini) s += `<text x="${cx + 8}" y="${yy + 3}" font-size="9" fill="#2b3a55">${esc(a.name.split(' ')[0])}</text>`;
      });
      if (!mini) s += `<text x="${x}" y="${H - 4}" font-size="9" fill="#6b7a93">${y}年目</text>`;
    });
    return s + '</svg>';
  };

  // ---------- 年表（卒業・大会・リーグ・殿堂）----------
  YA.chronicle = function (w) {
    const rows = [];
    for (const x of w.leagueHist || []) rows.push({ y: x.year, t: `${YA.levelNames(w)[x.level - 1]} ${x.rank}位`, k: x.rank === 1 ? 'gold' : '' });
    for (const t of w.trophies || []) rows.push({ y: t.year, t: `${t.name} ${t.rank || ''}`.trim(), k: 'gold' });
    const { ys, years } = YA.lineageData(w);
    // 在学中のプロ契約（トップ昇格）は卒業と分けて数える（2026-11-16「3年目2週に1人が卒業」と出ていた）
    const early = (a) => /高.でトップ昇格/.test(a.note0 || a.note || ''); // 引退で a.note は書き換わる。卒業のときの言葉は a.note0
    for (const y of ys) {
      const al = years[y].filter((a) => !early(a));
      const ea = years[y].filter(early);
      if (al.length) rows.push({ y, t: `${al.length}人が卒業（プロ入り${al.filter((a) => a.status === 'pro').length}人）`, k: '' });
      if (ea.length) rows.push({ y, t: `在学中にプロ契約 ${ea.length}人（${ea.map((a) => a.name).join('・')}）`, k: 'gold' });
    }
    for (const a of w.alumni) if (a.hof) rows.push({ y: a.hofY || a.year, t: `${a.name}が殿堂${a.hof === 'full' ? '入り' : '候補に'}`, k: a.hof === 'full' ? 'gold' : '' });
    // 年末の評価・覚醒・卒業生の大きな出来事（2026-11-16 年表が1年に2〜3行だった）
    for (const e of (w.club && w.club.eval) || []) rows.push({ y: e.year, t: `年末の評価 ${e.letter}`, k: e.letter === 'S' || e.letter === 'A' ? 'gold' : '' });
    for (const [k, d] of Object.entries(w.dex || {})) { const f = (YA.AWAKE_FORMS || []).find((x) => x.k === k); if (d && d.y) rows.push({ y: d.y, t: `${d.name}が覚醒（${f ? f.name : '新しい形'}）`, k: 'gold' }); }
    const BIG = /バロンドール$|バロンドール [1-9]位$|W杯|ゴールデンシュー|コパ・トロフィー|ヤシン|年間MVP|得点王/;
    for (const a of w.alumni) {
      for (const m of a.moves || []) {
        if (m.abroad && /^J/.test(m.fromLg || 'J')) rows.push({ y: m.y, t: `卒業生の${a.name}が海外へ（${m.to}）`, k: '' });
        if (m.join) rows.push({ y: m.y, t: `卒業生の${a.name}が大学からプロへ（${m.to}）`, k: '' });
      }
      if (a.natY1 != null) rows.push({ y: a.natY1, t: `卒業生の${a.name}が日本代表に初選出`, k: 'gold' });
      for (const x of a.awards || []) if (BIG.test(x.name)) rows.push({ y: x.y, t: `卒業生の${a.name}：${x.name}`, k: 'gold' });
      for (const x of a.titles || []) if (/チャンピオンズリーグ/.test(x.name)) rows.push({ y: x.y, t: `卒業生の${a.name}：${x.name}`, k: 'gold' });
    }
    return rows.sort((a, b) => a.y - b.y);
  };

  // ---------- 見せ方 ----------
  const U = () => YA._ui;
  const V = () => YA._v;
  const h = (...a) => U().h(...a);
  const rerender = () => U().render();
  // ホームの右列の小窓。系譜図は 2026-11-21「系譜の画面はいらない」で外し、次に届きそうな実績だけ出す
  YA.lineageMiniCard = function (w) {
    const na = YA.nextAchievement(w);
    if (!na) return h('span', {});
    return h('div', { class: 'card', style: 'padding:6px 8px;margin-top:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, '次の実績'), h('button', { class: 'btn sm', onclick: () => { U().app.tab = 'lineage'; U().app.lt = 'ach'; rerender(); } }, '開く')),
      h('div', { class: 'note', style: 'margin-top:2px' }, `${na.name}（${Math.min(na.cur, na.goal)}/${na.goal}）`));
  };
  function achTab(body, w) {
    const ui = U().app;
    ui.af2 = ui.af2 || 0;
    const all = YA.achievements(w);
    body.append(h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap' }, h('div', { class: 'h grow' }, `実績 ${all.filter((a) => a.done).length}/${all.length}`), ...['すべて'].concat(YA.ACH_FIELDS).map((n, i) => h('button', { class: 'btn sm' + (ui.af2 === i ? ' on' : ''), onclick: () => { ui.af2 = i; rerender(); } }, n))));
    const list = all.filter((a) => !ui.af2 || a.field === YA.ACH_FIELDS[ui.af2 - 1]);
    const tcol = { 銅: '#b5733b', 銀: '#8d99ab', 金: '#d9a400' };
    // 銅・銀・金を1行にまとめる（2026-11-16 69行の縦の一覧だった）。次の段までの進み具合をバーで
    const groups = [];
    for (const a of list) { const g = groups[groups.length - 1]; if (g && g.k === a.k.slice(0, -1)) g.items.push(a); else groups.push({ k: a.k.slice(0, -1), items: [a] }); }
    body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, groups.map((g) => {
      const next = g.items.find((a) => !a.done);
      const top = next || g.items[g.items.length - 1];
      const prev = next ? g.items[g.items.indexOf(next) - 1] : null;
      const lo = prev ? prev.goal : 0;
      const pct = next ? Math.max(0, Math.min(100, ((Math.min(top.cur, top.goal) - lo) / Math.max(1, top.goal - lo)) * 100)) : 100;
      return h('div', { class: 'pitem', style: 'cursor:default;gap:6px;flex-wrap:wrap' },
        h('span', { class: 'grow', style: 'font-size:12px;min-width:180px' + (next ? '' : ';font-weight:800') }, top.name),
        h('div', { class: 'bar', style: 'width:90px;flex:none' }, h('i', { style: `width:${pct}%;background:${next ? '#2f7ed8' : '#d9a400'}` })),
        h('span', { class: 'note', style: 'width:64px;flex:none;text-align:right' }, next ? `${Math.min(top.cur, top.goal).toLocaleString('en-US')}/${top.goal.toLocaleString('en-US')}` : 'すべて達成'),
        ...g.items.map((a) => h('span', { class: 'chip', tip: a.name + (a.done ? '（達成）' : ''), style: `flex:none;padding:0 6px;${a.done ? `background:${tcol[a.tier]};color:#fff` : 'background:#eef2f8;color:#9aa6b8'}` }, a.tier)));
    })));
  }
  function hallTab(body, w) {
    const hof = w.alumni.filter((a) => a.hof).sort((a, b) => (b.hof === 'full') - (a.hof === 'full') || b.ovr - a.ovr);
    body.append(h('div', { class: 'h' }, `殿堂（正式 ${hof.filter((a) => a.hof === 'full').length}人・候補 ${hof.filter((a) => a.hof === 'cand').length}人）`),
      h('div', { class: 'note' }, 'フル代表・J1で長く主力・海外で活躍・大きな移籍に届くと「候補」。引退のときに生涯の成績で正式に殿堂入りします。'));
    body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, hof.map((a) => h('div', { class: 'pitem', style: `cursor:default;align-items:flex-start;gap:6px;border-left:4px solid ${a.hof === 'full' ? '#d9a400' : '#9aa6b8'}` },
      h('span', { class: 'chip', style: `background:${a.hof === 'full' ? '#d9a400' : '#9aa6b8'};color:#fff` }, a.hof === 'full' ? '殿堂入り' : '候補'),
      h('div', { class: 'grow' }, h('b', {}, a.name), h('div', { class: 'note' }, `${a.year}年卒・${a.club}（${a.league}）・通算${YA.statLine(a, a.pos === 'GK')}・代表${a.caps || 0}試合・タイトル${(a.titles || []).length}`), a.hof === 'full' ? h('div', { class: 'note', style: 'color:var(--ink)' }, `恩師のひとこと：「${YA.hofWord(w, a)}」`) : null)))));
    if (!hof.length) body.append(h('div', { class: 'note', style: 'margin-top:6px' }, 'まだ殿堂入りした卒業生はいません。'));
  }
  function chronTab(body, w) {
    const rows = YA.chronicle(w);
    // 年ごとの札（新しい年が上）
    const byY = {};
    for (const r of rows) (byY[r.y] = byY[r.y] || []).push(r);
    const ys2 = Object.keys(byY).map(Number).sort((a, b) => b - a);
    body.append(h('div', { class: 'h' }, '年表'), h('div', { class: 'scroll', style: 'margin-top:5px;flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, ys2.map((y) => h('div', { class: 'card', style: 'padding:6px 10px;flex:none' + (y === w.year ? ';border-color:#f0cf55' : '') },
      h('div', { class: 'row', style: 'gap:6px' }, h('b', { style: 'font-size:13px' }, `${y}年目`), y === w.year ? h('span', { class: 'chip trait', style: 'font-size:11px;padding:0 5px' }, 'いま') : null),
      h('div', { style: 'display:flex;flex-wrap:wrap;gap:3px 12px;margin-top:3px' }, byY[y].map((r) => h('span', { style: 'font-size:12px;' + (r.k ? 'color:#a37b00;font-weight:800' : '') }, '・' + r.t)))))));
    if (rows.length) return;
    body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, rows.map((r) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'sub', style: 'width:54px' }, `${r.y}年目`), h('span', { class: 'grow', style: r.k ? 'font-weight:800;color:#a37b00' : '' }, r.t)))));
    if (!rows.length) body.append(h('div', { class: 'note' }, 'まだ記録はありません。'));
  }
  const leanHint = (f) => { const ks = Object.keys(YA.FORM_LEAN || {}).filter((k) => YA.FORM_LEAN[k].includes(f.k)); return ks.length ? ks.map((k) => YA.KIND_LABEL[k]).join('か') + '接し方で育てた子に出やすい' : ''; };
  function dexTab(body, w) {
    const n = YA.dexCount(w), all = YA.AWAKE_FORMS;
    body.append(h('div', { class: 'h' }, `覚醒の図鑑 ${n}/${all.length}`), h('div', { class: 'note' }, '課題で子が覚醒すると、その形が載ります。形は位置と能力に加えて、節目や出来事でどう接してきたか（寄り添う・厳しく・背中を押す・任せる）で出やすさが変わります。5種から10種ごとに（5・10・20・30・40・50・60・70・80種）育成基金のごほうび（300万円〜4000万円）。'));
    const next = [5, 10, 20].find((x) => x > n);
    if (next) body.append(h('div', { class: 'note', style: 'margin-top:3px' }, `次のごほうびまで あと${next - n}種（${YA.DEX_REWARD[next]}万円）`));
    // 4列の札にして、見つけた形を金色で先に（2026-11-16 見つけた形が一覧のいちばん下にあった）
    const sorted = all.slice().sort((x, y) => (!!(w.dex || {})[y.k]) - (!!(w.dex || {})[x.k]));
    body.append(h('div', { class: 'scroll', style: 'margin-top:5px;flex:1;min-height:0;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));grid-auto-rows:max-content;gap:5px;align-content:start' }, sorted.map((f) => {
      const d = (w.dex || {})[f.k];
      return h('div', { class: 'card', style: 'padding:6px 7px;display:flex;flex-direction:column;gap:2px;min-height:74px;flex:none;' + (d ? 'background:linear-gradient(180deg,#fff8d6,#ffefb0);border-color:#e6c200' : 'background:#f3f6fb;opacity:.85') },
        h('div', { class: 'row', style: 'gap:4px' }, h('span', { style: `font-size:16px;color:${d ? '#c99a00' : '#b9c3d3'}` }, d ? '✦' : '？'), h('b', { style: 'font-size:12px;line-height:1.25' }, d ? f.name : '？？？？')),
        h('div', { class: 'note', style: 'font-size:11.5px;line-height:1.35' }, d ? `特性「${f.trait}」` : `向く位置：${f.pos.slice(0, 3).map((x) => YA.posJa ? YA.posJa(x) : x).join('・')}`),
        h('div', { class: 'note', style: 'font-size:11px;line-height:1.35' }, d ? `最初の子 ${d.name}（${d.y}年目）・${d.n}回` : leanHint(f)));
    })));
  }
  function fundTab(body, w) {
    body.append(h('div', { class: 'h' }, `育成基金 ${YA.yen(w.fund || 0)}`), h('div', { class: 'note' }, '卒業生の大きな移籍で入る連帯貢献金の半分が貯まります。クラブの予算とは別で、使い道は自分で決めます（赤字にはできません）。'));
    for (const u of YA.FUND_USES) body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:4px' }, h('div', { class: 'grow' }, h('b', {}, `${u.name}（${YA.yen(u.cost)}）`), h('div', { class: 'note' }, u.note)), h('button', { class: 'btn sm', disabled: !!YA.fundWhy(w, u.k), why: YA.fundWhy(w, u.k) || '', onclick: () => fundAsk(w, u) }, '使う')));
  }
  // 使う前に確かめ、結果を知らせる（2026-11-17 点検：押すとすぐ減り、結果の文も捨てていた）
  function fundAsk(w, u) {
    const go = () => { const r = YA.fundUse(w, u.k); YA.saveWorld(); rerender(); if (YA.toast) YA.toast(r.msg + (r.ok ? `（残り${YA.yen(w.fund || 0)}）` : '')); };
    if (!YA.confirmBox) return go();
    YA.confirmBox(`育成基金から${YA.yen(u.cost)}を「${u.name}」に使いますか`, go, { yes: '使う', note: `${u.note}　使うと残りは${YA.yen((w.fund || 0) - u.cost)}です。` });
  }
  // 監督の経歴（2026-11-25）：年ごとの評価と順位・指導者の力・流儀
  function careerTab(body, w) {
    const c = w.club;
    body.append(h('div', { class: 'h' }, '監督の経歴'), h('div', { class: 'note', style: 'color:var(--ink)' }, `${w.coach && w.coach.name ? w.coach.name + '　' : ''}指導者 ${YA.licenseOf ? YA.licenseOf(w) : ''}（教える${w.coach.teach}・見る目${w.coach.eye}・話す${w.coach.talk}・戦術${w.coach.tactic}）`));
    if (YA.styleOf) { const st = YA.styleOf(w); if (st) body.append(h('div', { class: 'note', style: 'color:var(--ink)' }, '流儀：' + (st.name || st))); }
    body.append(h('div', { class: 'note', style: 'color:var(--ink)' }, `いまのクラブ：${w.clubName}（${YA.TIER_NAME[c.tier]}・${w.year}年目）`));
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '年ごとの評価'));
    const ev = (c.eval || []).slice().reverse();
    body.append(ev.length ? h('div', { class: 'plist' }, ev.map((e) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'chip ' + (e.letter <= 'A' ? 'trait' : 'gray'), style: 'font-size:13px;min-width:26px;justify-content:center' }, e.letter), h('span', { class: 'sub', style: 'width:52px' }, `${e.year}年目`), h('span', { class: 'grow', style: 'font-size:11.5px' }, e.goals.map((g) => `${g.label}${g.ok ? '○' : g.score ? '△' : '×'}`).join(' ')), h('span', { class: 'sub' }, `${e.rank}位`)))) : h('div', { class: 'note' }, 'まだ評価はありません（年度末に出ます）'));
    const al = (w.alumni || []).length;
    body.append(h('div', { class: 'note', style: 'margin-top:6px;color:var(--ink)' }, `送り出した卒業生 ${al}人` + (al ? `（プロ ${(w.alumni || []).filter((a) => a.pro || a.club).length}人）` : '')));
  }
  function viewLineage(main) {
    const w = U().app.w;
    const ui = U().app;
    // 系譜図は 2026-11-21「系譜の画面はいらない」で外した。タブの名前は「記録」、開くと卒業生名鑑
    ui.lt = ui.lt || 'alumni';
    const EXTRA = YA.lineageExtraTabs || [];
    // 2026-11-25 画面の構成の作り直し（ユーザー決定・FM 寄り）：卒業生／クラブの歴史（年表・クラブ史・実績・図鑑・育成基金）／監督（監督の経歴・ライバル・移籍）。
    // 「監督の注文」はクラブ → トップと重なるので外し、「ほか」のクラブ史をここへ移した。実績の上に「次の実績」（ホームから移した）
    const TABS = [['alumni', '卒業生名鑑'], ['hall', '殿堂'], ['chron', '年表'], ['hist', 'クラブ史'], ['ach', '実績'], ['dex', '図鑑'], ['fund', '育成基金'], ['career', '監督の経歴']].concat(EXTRA.filter((x) => x[0] !== 'top').map((x) => [x[0], x[1]]));
    // 小タブが12個で2行に折れていたので、3つの群に分けて1行に（2026-11-18 ユーザビリティ7）。群ごとに最後に見た小タブを覚える
    const GRP = [['alumni', '卒業生', ['alumni', 'hall', 'letters', 'clubs']], ['rec', 'クラブの歴史', ['chron', 'hist', 'ach', 'dex', 'fund']], ['coach', '監督', ['career', 'rival', 'move']]];
    const grpOf = (k) => (GRP.find((g) => g[2].indexOf(k) >= 0) || GRP[1])[0];
    if (!TABS.some((x) => x[0] === ui.lt)) ui.lt = 'alumni';
    const g0 = grpOf(ui.lt);
    ui.ltg = ui.ltg || {};
    ui.ltg[g0] = ui.lt;
    const tabs = h('div', { class: 'tabs', style: 'gap:3px;max-width:100%;align-items:center' },
      h('div', { class: 'row', style: 'gap:0;flex:none;background:var(--navy);border-radius:10px;padding:2px' }, ...GRP.map(([gk, gn, ks]) => h('button', { class: 'btn sm grp' + (g0 === gk ? ' on' : ''), style: 'flex:none;border:none;box-shadow:none;' + (g0 === gk ? '' : 'background:none;color:#c9d6f0'), onclick: () => { const first = TABS.find((x) => grpOf(x[0]) === gk); ui.lt = ui.ltg[gk] || (first && first[0]) || ks[0]; rerender(); } }, gn))),
      h('span', { style: 'width:6px;flex:none' }),
      ...TABS.filter(([k]) => grpOf(k) === g0).map(([k, n]) => h('button', { class: 'btn' + (ui.lt === k ? ' on' : ''), onclick: () => { ui.lt = k; rerender(); } }, n)));
    const body = h('div', { class: 'card pbody', style: 'flex:1;min-height:0;display:flex;flex-direction:column' });
    if (ui.lt === 'hall') hallTab(body, w);
    else if (ui.lt === 'ach') { if (YA.lineageMiniCard) body.append(YA.lineageMiniCard(w)); achTab(body, w); }
    else if (ui.lt === 'hist') { const mt0 = ui.mt; ui.mt = 'rec'; const inner = h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column' }); YA.views.more(inner); ui.mt = mt0; const c2 = inner.querySelector('.card'); body.append(c2 || inner); }
    else if (ui.lt === 'career') careerTab(body, w);
    else if (ui.lt === 'dex') dexTab(body, w);
    else if (ui.lt === 'chron') chronTab(body, w);
    else if (ui.lt === 'fund') fundTab(body, w);
    else if (EXTRA.some((x) => x[0] === ui.lt)) EXTRA.find((x) => x[0] === ui.lt)[2](body, w);
    else { ui.mt = 'alumni'; const inner = h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column' }); YA.views.more(inner); const card = inner.querySelector('.card'); body.append(card || inner); if (inner.querySelector('.tabs')) inner.querySelector('.tabs').remove(); }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }
  YA.views = YA.views || {};
  YA.views.lineage = viewLineage;
  // 次の実績の小窓（YA.lineageMiniCard）は 2026-11-25 にホームから外した（ホームは「今週やること」に絞る）。記録の画面へ移す
})();
