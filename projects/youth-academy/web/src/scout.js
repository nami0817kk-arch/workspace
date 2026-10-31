// スカウト・セレクション・内部昇格（U-15）・入団、卒業生の追跡と連帯貢献金、
// 指導者の成長、キャプテン、ポジション変更、選手同士の関係。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 指導者の成長（決定16）----------
  YA.COACH_ABS = [['teach', '教える力', '練習での伸びが大きくなる'], ['eye', '見る目', '候補の中身とポジションの適性が見えやすくなる'], ['talk', '話す力', '面談や声かけへの反応が良くなる'], ['tactic', '戦術', '試合でチームがまとまりやすくなる']];
  YA.newCoach = () => ({ teach: 8, eye: 8, talk: 8, tactic: 8, exp: 0 });
  YA.licenseOf = (w) => ['C', 'B', 'A', 'S'][Math.min(3, Math.floor((w.coach.exp || 0) / 3))] + '級';
  YA.coachMult = (w) => 1 + ((w.coach ? w.coach.teach : 8) - 10) * 0.012;

  // ---------- スカウト ----------
  const POS_ABS = { GK: YA.AB_GK, DF: ['タックル', 'マーク', 'ポジショニング', '予測', 'ヘディング', '強さ'], MF: ['パス', '視野', '判断', 'ドリブル', '運動量', 'テクニック'], FW: ['フィニッシュ', 'ドリブル', 'スピード', 'オフザボール', '加速', 'ヘディング'] };
  YA.ovrAt = (p, pos) => YA.POS_ABS15[pos].reduce((s, n) => s + p.ab[n], 0) / YA.POS_ABS15[pos].length;
  YA.newScouting = () => ({ cands: [], tests: [], testsDone: false, selOpen: false, intOpen: false, nextId: 0, acts: { m: -1, n: 0 }, seq: 0 });
  const eyeOf = (w) => clamp((YA.staffAb(w, 'スカウト') + (w.coach ? w.coach.eye : 8)) / 2, 3, 18);
  YA.eyeLevel = eyeOf;
  const KIND_NAME = { scout: 'スカウト', sel: 'セレクション', int: '内部昇格（U-15）' };
  YA.CAND_KIND = KIND_NAME;

  // ---------- 暦：いつ何を決めるか ----------
  // 内部昇格は11月（25〜27週）／スカウトは4〜11月に月3回まで、返事は12月（28週）／セレクションは1月（31〜34週）に合否が決まる。
  // 初年度も同じ暦で、決めた子は翌年の高1になる
  YA.SCOUT_RESULT_WEEK = 28;
  YA.SCOUT_PER_MONTH = 3;
  YA.INT_CANDS = 20; // 内部昇格の候補（中3）。8人まで決める
  YA.scoutWindow = function (w) {
    const wk = w.week;
    // scout＝声をかけられる（4〜11月）、explore＝スカウトに出られる（返事の届く28週を除く一年中。12月以降に会えた子は来年度の候補）
    return { int: wk >= 25 && wk <= 27, scout: wk <= 27, explore: wk !== YA.SCOUT_RESULT_WEEK, sel: wk >= 31 && wk <= 34 };
  };
  YA.scoutActsLeft = function (w) {
    const a = w.scouting && w.scouting.acts;
    const used = a && a.m === YA.monthIdx(w.week) ? a.n : 0;
    return Math.max(0, YA.SCOUT_PER_MONTH - used);
  };
  const useAct = function (w) {
    const S = w.scouting;
    const m = YA.monthIdx(w.week);
    if (!S.acts || S.acts.m !== m) S.acts = { m, n: 0 };
    S.acts.n++;
  };
  // ホームに出す一言（なければ null）
  YA.scoutHint = function (w) {
    if (!w.scouting) return null;
    const wn = YA.scoutWindow(w);
    if (wn.int) return '内部昇格を決める（11月）';
    if (wn.sel) return 'セレクションの合否を決める（1月）';
    if (wn.explore) return YA.scoutActsLeft(w) > 0 ? `スカウトに出る（${wn.scout ? '' : '来年度の下見・'}今月あと${YA.scoutActsLeft(w)}回）` : 'スカウトの報告を見る（今月は出終わり）';
    return null;
  };

  // スカウトの行き先（栄冠ナイン風：行き先を選んで出る。月3回まで）
  YA.DESTS = {
    local: { name: '地元の中学・クラブ', cost: 5, note: '近くを回る。人数は多めでライバルは少ない', q: -0.3, rival: 0.15, foreign: 0.02 },
    strong: { name: '強豪の中学・ユース', cost: 12, note: '粒ぞろいの子に会える。ほかのクラブも狙っている', q: 0.8, rival: 0.65, foreign: 0.04 },
    wide: { name: '全国・海外へ遠征', cost: 20, note: '当たり外れが大きい。外国籍の子に会えることも', q: 0.1, rival: 0.35, foreign: 0.25 },
  };
  const DEST_ORDER = ['local', 'strong', 'wide'];
  YA.DEST_ORDER = DEST_ORDER;

  function genCand(w, rng, kind, dest) {
    const S = w.scouting;
    const D = dest ? YA.DESTS[dest] : null;
    const pos = rng.pick(['GK', 'CB', 'CB', 'LB', 'RB', 'DM', 'CM', 'CM', 'AM', 'LM', 'RM', 'LW', 'RW', 'SS', 'ST', 'ST']);
    const used = new Set(Object.values(w.players).map((p) => p.name));
    // セレクションの応募者は、取りこぼされた子が来る：原石（今は低いが伸びしろが大きい）・低め（今も伸びしろも低い）・位置ちがい（登録が合っていない）
    const prof = kind === 'sel' ? (() => { const x = rng(); return x < 0.4 ? 'raw' : x < 0.7 ? 'low' : 'mis'; })() : null;
    let q = clamp(rng.int(-2, 2) * (dest === 'wide' ? 1.1 : 0.8) + (kind === 'scout' ? (eyeOf(w) - 10) * 0.08 + (D ? D.q : 0) : 0) + (kind === 'int' ? 0.2 : 0), -2, 2.4);
    if (prof === 'raw') q = -2 + rng() * 0.5;
    else if (prof === 'low') q = -1.8 + rng() * 0.8;
    else if (prof === 'mis') q = -0.8 + rng() * 1.2;
    const id = 'c' + ++S.nextId + '_' + w.year;
    const gpos = prof === 'mis' && pos === 'GK' ? 'CM' : pos;
    const p = YA.genPlayer(rng, id, 1, gpos, q, used);
    p.grade = 0;
    if (prof === 'raw') p.pot = YA.abSum(p) + rng.int(150, 220);
    else if (prof === 'low') p.pot = YA.abSum(p) + rng.int(20, 55);
    else if (prof === 'mis') {
      // 実力は十分だが、登録は別の括りのポジション
      const far = YA.POS15.filter((x) => x !== 'GK' && YA.GROUP[x] !== p.pos && p.apt[x] <= p.apt[p.best] - 1).sort((x, y) => p.apt[x] - p.apt[y]);
      if (far.length) {
        p.main = far[rng.int(0, Math.min(2, far.length - 1))];
        p.pos = YA.GROUP[p.main];
      }
    }
    // 外国籍の選手は年に0〜1人（決定53）。海外のスカウトか、まれな応募から
    const FOREIGN = [['ブラジル', ['ルーカス・シウバ', 'カルロス・メンドンサ', 'ガブリエル・ソウザ']], ['韓国', ['キム・ジュノ', 'パク・ソンミン', 'イ・ヒョヌ']], ['ナイジェリア', ['エマニュエル・オコロ', 'ダニエル・アデバヨ']], ['アルゼンチン', ['マテオ・ゴンザレス', 'ニコラス・ペレス']], ['オーストラリア', ['ジャック・ウィルソン', 'ライアン・テイラー']]];
    let foreign = false;
    if (kind !== 'int' && !S.foreignDone && rng() < (kind === 'scout' && D ? D.foreign : 0.07)) {
      const f = rng.pick(FOREIGN);
      p.nation = f[0];
      p.name = rng.pick(f[1]);
      p.ab['スピード'] = clamp(p.ab['スピード'] + 2, 1, 20);
      p.ab['強さ'] = clamp(p.ab['強さ'] + 1, 1, 20);
      p.pot += 15;
      p.fam = p.fam || {};
      foreign = true;
      S.foreignDone = true;
    } else p.nation = '日本';
    const c = { id, p, kind, prof, foreign, seen: kind === 'int' ? 2 : kind === 'scout' ? 1 : 0, status: 'open', rival: kind === 'scout' && rng.chance(D ? D.rival : 0.4), persSeen: kind === 'int', amb: rng.int(0, 10), where: D ? D.name : null };
    S.cands.push(c);
    return c;
  }
  // スカウトに出る：行き先を選ぶと、数人の候補に出会える。月3回まで・4〜11月・経費がかかる
  YA.scoutOut = function (w, dest) {
    const S = w.scouting;
    const D = YA.DESTS[dest];
    if (!D) return { ok: false, msg: '行き先を選んでください' };
    const wn = YA.scoutWindow(w);
    if (!wn.explore) return { ok: false, msg: '返事が届く週は、スカウトに出られません' };
    if (YA.scoutActsLeft(w) <= 0) return { ok: false, msg: `今月のスカウトは${YA.SCOUT_PER_MONTH}回使いました。来月また出られます` };
    const room = 12 - S.cands.filter((c) => c.kind === 'scout' && c.status === 'open').length;
    if (room <= 0) return { ok: false, msg: '候補がいっぱいです。見送る子を決めてください' };
    if (YA.budget(w).scout - w.club.spent.scout < D.cost) return { ok: false, msg: 'スカウトの配分が足りません' };
    const r = YA.rngOf(w.seed * 29 + w.year * 131 + w.week * 7 + ++S.seq * 977 + YA.hash(dest));
    const eye = eyeOf(w);
    let n = dest === 'local' ? 1 + (r() < 0.5 ? 1 : 0) : dest === 'wide' ? 1 + (r() < 0.4 ? 1 : 0) : 1;
    if (r() < (eye - 8) * 0.05) n++;
    n = Math.min(n, 3, room);
    const found = [];
    for (let i = 0; i < n; i++) {
      const c = genCand(w, r, 'scout', dest);
      if (!wn.scout) c.next = true; // 12月以降に会えた子：来年度の候補（声をかけられるのは4月から）
      found.push(c);
    }
    w.club.spent.scout += D.cost;
    useAct(w);
    return { ok: true, msg: `${D.name}で${n}人の候補に会いました。` + (wn.scout ? '名前は「スカウトの報告」に並んでいます' : '来年度の候補として残り、4月から声をかけられます'), found };
  };
  // 見送る：候補の一覧から外して、枠を空ける
  YA.passCand = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    if (!c || c.kind !== 'scout' || c.status !== 'open') return { ok: false, msg: '見送れません' };
    c.status = 'passed';
    return { ok: true, msg: `${c.p.name}は見送りました` };
  };
  YA.openSelection = function (w) {
    const S = w.scouting;
    if (S.selOpen) return;
    S.selOpen = true;
    const r = YA.rngOf(w.seed * 37 + w.year * 17);
    const n = 14 + Math.floor(w.club.rep / 8);
    for (let i = 0; i < n; i++) genCand(w, r, 'sel');
    YA.noteTier(w, 1, `セレクションの応募が${n}人ありました。1月のうちに、テストの内容を決めて入れる子を選んでください（クラブ→スカウト）`);
  };
  // 中3の練習参加（11月の初め・25週）：内部昇格の候補20人がA・Bの練習に混ざる。実際に動きを見られるので見えている度合いが上がる。26週に指導者の申し送りで残りが見える
  YA.openInternal = function (w, junior) {
    const S = w.scouting;
    if (S.intOpen) {
      if (!junior) {
        for (const c of S.cands) if (c.kind === 'int') {
          c.seen = Math.min(3, c.seen + 1);
          c.persSeen = true;
        }
        YA.noteTier(w, 2, 'U-15の指導者から、各候補の申し送り（性格など）が届きました。内部昇格を決めるのは11月のうちです');
      }
      return;
    }
    S.intOpen = true;
    const r = YA.rngOf(w.seed * 41 + w.year * 19);
    for (let i = 0; i < YA.INT_CANDS; i++) genCand(w, r, 'int');
    if (junior) {
      for (const c of S.cands) if (c.kind === 'int') c.seen = Math.min(3, c.seen + 1);
      YA.noteTier(w, 1, '11月です。中3の20人が練習に参加しました。内部昇格の候補として動きを見られます。8人まで決められます（クラブ→スカウト）');
    } else YA.noteTier(w, 1, 'U-15の指導者から、内部昇格の候補20人の申し送りが届きました（クラブ→スカウト）');
  };
  // 11月の終わり：内部昇格が決まる。12月の初め：スカウトの返事。1月の終わり：セレクションの合否が決まる
  YA.closeInternal = function (w) {
    if (!w.scouting.intOpen) return;
    YA.noteTier(w, 1, `内部昇格が決まりました（${YA.signedCount(w, 'int')}人）。来年の高1になります`);
  };
  YA.closeSelection = function (w) {
    if (!w.scouting.selOpen) return;
    YA.noteTier(w, 1, `セレクションの合否が決まりました（${YA.signedCount(w, 'sel')}人合格）。来年の高1になります`);
  };
  YA.testDays = (w) => 2 + (YA.budget(w).scout >= 300 ? 1 : 0);
  YA.TESTS = [['紅白戦', '動きと判断が見える'], ['技術テスト', 'ボールの扱いが見える'], ['体力測定', '足の速さ・体力が見える'], ['面接', '性格と目指すものが見える']];
  YA.runSelection = function (w, tests) {
    const S = w.scouting;
    if (S.testsDone) return;
    S.tests = tests.slice(0, YA.testDays(w));
    for (const c of S.cands) if (c.kind === 'sel') {
      c.seen = Math.min(3, c.seen + (S.tests.length >= 3 ? 2 : 1));
      if (S.tests.indexOf('面接') >= 0) c.persSeen = true;
    }
    S.testsDone = true;
    YA.noteTier(w, 2, `セレクションを実施しました（${S.tests.join('・')}）`);
  };
  YA.scoutVisit = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    const b = YA.budget(w);
    if (!c || c.kind !== 'scout' || c.status !== 'open') return { ok: false, msg: '見に行けません' };
    if (!YA.scoutWindow(w).explore) return { ok: false, msg: '返事が届く週は、見に行けません' };
    if (YA.scoutActsLeft(w) <= 0) return { ok: false, msg: `今月のスカウトは${YA.SCOUT_PER_MONTH}回使いました。来月また出られます` };
    if (c.seen >= 3) return { ok: false, msg: 'これ以上は見えません' };
    if (b.scout - w.club.spent.scout < 10) return { ok: false, msg: 'スカウトの配分が足りません' };
    w.club.spent.scout += 10;
    useAct(w);
    c.seen++;
    if (c.seen >= 2) c.persSeen = true;
    return { ok: true, msg: `${c.p.name}を見に行きました（見える範囲が広がった）` };
  };
  const LIMIT = { scout: 3, sel: 3, int: 8 };
  // 決められる期間（内部昇格は11月・スカウトの声かけは4〜11月・セレクションは1月）
  const WHEN = { int: ['int', '内部昇格を決めるのは11月です'], scout: ['scout', 'スカウトの声かけは4月〜11月です（返事は12月）'], sel: ['sel', 'セレクションの合否を決めるのは1月です'] };
  const inWindow = (w, kind) => YA.scoutWindow(w)[WHEN[kind][0]];
  const held = (w, kind) => w.scouting.cands.filter((c) => (c.status === 'signed' || c.status === 'offered') && (!kind || c.kind === kind)).length;
  YA.signedCount = (w, kind) => w.scouting.cands.filter((c) => c.status === 'signed' && (!kind || c.kind === kind)).length;
  YA.signCand = function (w, id) {
    const S = w.scouting;
    const c = S.cands.find((x) => x.id === id);
    if (!c || c.status !== 'open') return { ok: false, msg: 'すでに決まっています' };
    if (!inWindow(w, c.kind)) return { ok: false, msg: WHEN[c.kind][1] };
    if (c.next) return { ok: false, msg: `${c.p.name}は来年度の候補です。声をかけられるのは4月からです` };
    if (held(w) >= 12) return { ok: false, msg: '新入生の枠（12人）がいっぱいです' };
    if (c.foreign) {
      const reg = Object.values(w.players).filter((q) => YA.isForeign(q)).length + S.cands.filter((x) => x.foreign && (x.status === 'signed' || x.status === 'offered')).length;
      if (reg >= 5) return { ok: false, msg: '外国籍の選手の登録は5人までです' };
    }
    const lim = LIMIT[c.kind];
    if (held(w, c.kind) >= lim) return { ok: false, msg: `${KIND_NAME[c.kind]}からは${lim}人までです` };
    if (c.kind === 'scout') {
      c.status = 'offered';
      return { ok: true, msg: `${c.p.name}に声をかけました。返事は12月に届きます` };
    }
    c.status = 'signed';
    return { ok: true, msg: `${c.p.name}の入団が決まりました` };
  };
  YA.unsign = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    if (c && (c.status === 'signed' || c.status === 'offered') && inWindow(w, c.kind)) c.status = 'open';
  };
  // 声をかけた子の返事（12月の初め・28週）
  YA.resolveOffers = function (w) {
    const r = YA.rngOf(w.seed * 43 + w.year * 23 + w.week);
    for (const c of w.scouting.cands) if (c.status === 'offered') {
      const pr = clamp(0.5 + (w.club.rep - 50) / 120 - (c.rival && !c.rivalBeat ? 0.18 : 0) + (c.rivalBeat ? 0.06 : 0) - (c.amb - 5) * 0.015, 0.12, 0.92);
      if (r() < pr) {
        if (c.rival) w.rivalLosses = (w.rivalLosses || 0) + 1;
        c.status = 'signed';
        YA.noteTier(w, 1, `${c.p.name}（${c.p.pos}）が入団を決めました！`);
      } else {
        c.status = 'declined';
        if (c.rival) w.rivalWins = (w.rivalWins || 0) + 1;
        YA.noteTier(w, 2, `${c.p.name}は${c.rival ? YA.rivalOf(w).coach + '監督の' + YA.rivalOf(w).club : '別の道'}を選びました`);
      }
    }
  };
  const RANK_BASE = 5;
  const RANK_SPAN = 8;
  // 見える情報（見る目と回数で幅が決まる）
  YA.candView = function (w, c) {
    const p = c.p;
    const eye = eyeOf(w);
    const width = Math.max(0.6, 5.2 - c.seen * 1.4 - (eye - 8) * 0.18);
    let hs = 0;
    for (const ch of c.id) hs = (hs * 31 + ch.charCodeAt(0)) % 997;
    const sh = ((hs % 100) / 100 - 0.5) * width * 0.8;
    const o = YA.ovr(p);
    const lo = o - width / 2 + sh;
    const room = p.pot - YA.abSum(p);
    const st = clamp(Math.round(room / 45), 0, 5);
    const sw = c.seen >= 3 ? 0 : c.seen >= 1 ? 1 : 2;
    // 栄冠ナイン風のランク（見えている範囲の真ん中から。S〜E）。見る回数が増えるほど確かになる
    const score = ((lo + width / 2) - RANK_BASE) / RANK_SPAN * 0.5 + (clamp(st - sw, 0, 5) + clamp(st + sw, 0, 5)) / 2 / 5 * 0.5;
    const rank = score >= 0.78 ? 'S' : score >= 0.64 ? 'A' : score >= 0.5 ? 'B' : score >= 0.36 ? 'C' : score >= 0.22 ? 'D' : 'E';
    return { rank, ovr: [Math.round(lo * 10) / 10, Math.round((lo + width) * 10) / 10], stars: [clamp(st - sw, 0, 5), clamp(st + sw, 0, 5)], traits: c.seen >= 1 ? p.traits : null, pers: c.persSeen ? p.pers : null, height: p.height, pos: p.pos, label: YA.POS_LABEL[p.main], name: p.name, kind: c.kind, nation: p.nation && p.nation !== '日本' ? p.nation : null };
  };

  // 入団（3月）：決まった子を学年1の選手にする。足りない分は一般入団で埋める
  YA.intake = function (w, rng, used) {
    const S = w.scouting || YA.newScouting();
    const signed = S.cands.filter((c) => c.status === 'signed').slice(0, 12);
    const names = new Set(used);
    let n = 0;
    const faces = new Set(Object.values(w.players).map((q) => q.face).filter((f) => f != null));
    for (const c of signed) {
      const p = c.p;
      // 候補のときの顔が、在籍の子と重なっていたら選び直す
      if (p.face != null && faces.has(p.face)) p.face = null;
      if (p.face != null) faces.add(p.face);
      p.grade = 1;
      p.id = 'p' + ++w.nextId;
      p.team = 'B';
      p.num = 0;
      p.hist = [{ y: w.year, w: 40, t: KIND_NAME[c.kind] + 'で入団' }];
      w.players[p.id] = p;
      names.add(p.name);
      n++;
    }
    // 一般入団（見ていない子）。ポジションが偏らないよう足りない所を補う
    const have = { GK: 0, DF: 0, MF: 0, FW: 0 };
    for (const p of Object.values(w.players)) if (p.grade === 1) have[p.pos]++;
    const want = { GK: 1, DF: 4, MF: 4, FW: 3 };
    // GKが1人もいないと困るので、決まった子を1人外してでも一般入団のGKを入れる
    if (have.GK === 0 && n >= 12) {
      const last = Object.values(w.players).filter((p) => p.grade === 1 && p.pos !== 'GK').pop();
      if (last) { delete w.players[last.id]; n--; have[last.pos]--; }
    }
    for (const pos of ['GK', 'DF', 'MF', 'FW']) {
      while (have[pos] < want[pos] && n < 12) {
        const id = 'p' + ++w.nextId;
        const q = clamp(Math.round((rng() + rng() + rng() - 1.5) * 2), -2, 2);
        const G15 = { GK: ['GK'], DF: ['CB', 'CB', 'LB', 'RB'], MF: ['DM', 'CM', 'CM', 'AM'], FW: ['LW', 'RW', 'ST'] }[pos];
        const p = YA.genPlayer(rng, id, 1, G15[rng.int(0, G15.length - 1)], q, names);
        p.hist = [{ y: w.year, w: 40, t: '一般入団' }];
        w.players[id] = p;
        have[pos]++;
        n++;
      }
    }
    const carry = S.cands.filter((c) => c.kind === 'scout' && c.next && c.status === 'open');
    w.scouting = YA.newScouting();
    for (const c of carry) {
      c.next = false;
      w.scouting.cands.push(c);
    }
    if (carry.length) YA.noteTier(w, 2, `去年の冬に会った${carry.length}人が、今年のスカウトの候補に入っています（クラブ→スカウト）`);
    return n;
  };

  // ---------- 卒業生の追跡・連帯貢献金 ----------
  const PRO = ['横浜', '川崎', '鹿島', '浦和', '柏', '名古屋', '大阪', '神戸', '広島', '福岡', '仙台', '札幌', '新潟', '町田'];
  const PRO_N = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'サンライズ', 'レッドフォックス', 'ノースウィンド', 'ミストラル', 'クレセント'];
  const UNIV = ['関東の強豪大学', '関西の強豪大学', '東京の大学', '地方の大学'];
  YA.alumniEntry = function (w, p, note) {
    const o = Math.round(YA.ovr(p) * 10) / 10;
    const r = YA.rngOf(w.seed + p.num * 7 + w.year);
    const status = p._path || (o >= 13.2 ? 'pro' : o >= 10.5 ? 'univ' : 'amateur');
    return { name: p.name, pos: p.pos, year: w.year, ovr: o, note, grade: 3, age: 18, status, club: status === 'pro' ? r.pick(PRO) + ' ' + r.pick(PRO_N) : status === 'univ' ? r.pick(UNIV) : '社会人', apps: 0, goals: 0, nat: p.nat || 0, transfers: 0, retired: false, traits: p.traits.slice(), pushed: p._push || null, abroad: !!(p._sold && o >= 13) };
  };
  YA.alumniTick = function (w) {
    const r = YA.rngOf(w.seed * 67 + w.year * 29);
    let contrib = 0;
    for (const a of w.alumni) {
      if (a.retired || a.age == null) continue;
      a.age++;
      if (a.age <= 23) a.ovr = Math.round((a.ovr + r() * 0.7) * 10) / 10;
      else if (a.age >= 30) a.ovr = Math.round((a.ovr - r() * 0.5) * 10) / 10;
      if (a.status === 'univ' && a.age >= 22 && a.ovr >= 12.4 && r() < (a.pushed === 'univ' ? 0.6 : 0.4)) {
        a.status = 'pro';
        a.club = r.pick(PRO) + ' ' + r.pick(PRO_N);
        YA.noteTier(w, 2, `卒業生の${a.name}が大学を経てプロ入りしました（${a.club}）`);
      }
      if (a.status === 'pro') {
        a.apps += Math.round(clamp((a.ovr - 10) * 7 + r.int(-5, 8), 0, 34));
        a.goals += Math.round(clamp((a.ovr - 11) * (a.pos === 'FW' ? 3 : a.pos === 'MF' ? 1.2 : 0.4) + r.int(-1, 3), 0, 25));
        if (a.age >= 19 && a.age <= 30 && r() < 0.17) {
          // 力のある若い選手は、海外のクラブへ移ることもある
          const abroad = a.ovr >= 13.8 && a.age <= 27 && r() < 0.35;
          // 国内の移籍金は小さく、海外は大きい
          const fee = Math.round(abroad ? Math.pow(Math.max(0, a.ovr - 9), 2.2) * 560 : Math.pow(Math.max(0, a.ovr - 9), 2) * 80);
          const share = Math.round(fee * 0.015);
          a.transfers++;
          a.club = abroad ? '海外（' + r.pick(['イングランド', 'ドイツ', 'スペイン', 'オランダ', 'ベルギー', 'ポルトガル']) + '）' + r.pick(PRO_N) : r.pick(PRO) + ' ' + r.pick(PRO_N);
          if (abroad) a.abroad = true;
          contrib += share;
          YA.noteTier(w, 1, `卒業生の${a.name}が${a.club}へ${abroad ? '海外移籍' : '移籍'}（移籍金およそ${fee}万円）。連帯貢献金 +${share}万円がクラブに入ります`);
        }
        // U-21代表（決定16）：21歳以下で力のある卒業生。のちにフル代表の足がかり
        if (a.age <= 21 && a.ovr >= 12.2 && r() < 0.22) {
          a.u21 = (a.u21 || 0) + 1;
          if (a.u21 === 1) YA.noteTier(w, 1, `卒業生の${a.name}がU-21日本代表に選ばれました`);
        }
        if (a.ovr >= 14 && r() < (a.u21 ? 0.14 : 0.1)) {
          a.nat = (a.nat || 0) + 1;
          YA.noteTier(w, 1, `卒業生の${a.name}が日本代表に初めて選ばれました！`);
        }
      }
      if (a.age >= 33 || a.ovr < 9) {
        a.retired = true;
        a.note = '引退';
      }
    }
    if (contrib) {
      w.club.solidarity = (w.club.solidarity || 0) + contrib;
      w.solidTotal = (w.solidTotal || 0) + contrib;
    }
    return contrib;
  };

  // ---------- キャプテン（決定32）----------
  YA.setCaptain = function (w, pid, kind) {
    const key = kind === 'vice' ? 'vice' : 'captain';
    const old = w[key] && w.players[w[key]];
    if (old && old.id !== pid) {
      old.conf = clamp(old.conf - 8, 0, 100);
      old.unrest += 1;
    }
    w[key] = pid;
    const p = w.players[pid];
    const fragile = p.pers['大舞台'] === 'プレッシャーに弱い' || p.pers['気持ちの強さ'] === '繊細';
    const leader = p.pers['人との関わり'] === 'リーダー気質';
    if (key === 'captain') {
      p.conf = clamp(p.conf + (fragile ? -2 : 5), 0, 100);
      if (leader) p.spurt = Math.max(p.spurt, 3);
    }
    return fragile && key === 'captain' ? `${p.name}は重圧を感じているようだ` : leader ? `${p.name}はリーダー気質で、チームがまとまりそうだ` : `${p.name}を指名しました`;
  };

  // ---------- ポジション変更（決定31）----------
  YA.bestPosOf = (p) => p.best || p.main;
  YA.changePos = function (w, pid, pos) {
    const p = w.players[pid];
    if (p.main === pos) return { ok: false, msg: 'すでにそのポジションです' };
    if (p.pos === 'GK' || pos === 'GK') return { ok: false, msg: 'GKとの行き来は、この版ではできません' };
    const r = YA.rngOf(w.seed + w.week * 3 + p.num + YA.hash(pos));
    const stub = p.pers['教えの受け止め方'] === '頑固' ? 0.55 : p.pers['教えの受け止め方'] === '反骨心' ? 0.35 : 0.08;
    if (r() < stub) { p.conf = clamp(p.conf - 3, 0, 100); return { ok: false, msg: `${p.name}は納得せず、「今のポジションでやりたい」と断った` }; }
    const best = p.best;
    const L = YA.POS_LABEL;
    p.main = pos;
    p.pos = YA.GROUP[pos];
    p.adapt = 12;
    p.hist.unshift({ y: w.year, w: w.week, t: `ポジション変更（${L[pos]}）` });
    // いまの並びに入っているなら、新しいポジションの役割に直す
    for (const k of ['lineupA', 'lineupB']) w[k].forEach((sl, i) => { if (sl.pid === pid) YA.fixSlotRole(sl, i); });
    if (pos === best) { p.spurt = Math.max(p.spurt, 5); p.bestKnown = true; return { ok: true, msg: `${L[pos]}に変更。しっくりきているようだ（向いていたポジション）。慣れるまで約12週` }; }
    return { ok: true, msg: `${L[pos]}に変更しました。適性は${p.apt[pos]}（いまの最適は${L[best]}）。慣れるまで約12週は力が落ちます` };
  };

  // ---------- 選手同士の関係（決定20）----------
  YA.relations = function (w) {
    const r = YA.rngOf(w.seed * 83 + w.year * 5 + w.week);
    w.rel = (w.rel || []).filter((x) => w.players[x.a] && w.players[x.b]);
    const ps = Object.values(w.players);
    const has = (a, b) => w.rel.some((x) => (x.a === a && x.b === b) || (x.a === b && x.b === a));
    let guard = 0;
    while (w.rel.filter((x) => x.k === 'friend').length < 8 && guard++ < 200) {
      const a = r.pick(ps);
      const b = r.pick(ps);
      if (a === b || has(a.id, b.id) || a.grade !== b.grade) continue;
      w.rel.push({ a: a.id, b: b.id, k: 'friend' });
    }
    guard = 0;
    while (w.rel.filter((x) => x.k === 'rival').length < 6 && guard++ < 300) {
      const a = r.pick(ps);
      const b = r.pick(ps);
      if (a === b || has(a.id, b.id) || a.pos !== b.pos || a.pos === 'GK' || Math.abs(YA.ovr(a) - YA.ovr(b)) > 1.2) continue;
      w.rel.push({ a: a.id, b: b.id, k: 'rival' });
    }
  };
  YA.relOf = function (w, pid) {
    const out = [];
    for (const x of w.rel || []) if (x.a === pid || x.b === pid) out.push({ k: x.k, other: w.players[x.a === pid ? x.b : x.a] });
    return out.filter((x) => x.other);
  };

  // ---------- 毎週の小さな処理 ----------
  YA.weekExtras = function (w) {
    const r = YA.rngOf(w.seed * 53 + w.year * 61 + w.week);
    if (!w.scouting) w.scouting = YA.newScouting(); // 古い保存データ（クラブを移ったあと空になっていた）
    // 古い保存データ：性格は2つまでに減らす
    for (const p of Object.values(w.players)) YA.trimPers(p);
    if (w.scouting) for (const c of w.scouting.cands) YA.trimPers(c.p);
    // 古い保存データ：最初のセレクションの途中だったものは、その状態を閉じる
    if (w.firstSel) {
      w.firstSel = null;
      w.scouting = YA.newScouting();
    }
    // 入団の暦：4月 スカウトが始まる／11月 内部昇格／12月 スカウトの返事／1月 セレクション
    if (w.week === 1) YA.noteTier(w, 2, `新しい入団の季節です。スカウトは月${YA.SCOUT_PER_MONTH}回まで出られ、声をかけられるのは4月〜11月（返事は12月）。内部昇格は11月、セレクションは1月に決めます。決めた子は来年の高1になります`);
    if (w.week === 25) YA.openInternal(w, true);
    if (w.week === 26) YA.openInternal(w);
    if (w.week === YA.SCOUT_RESULT_WEEK) {
      YA.closeInternal(w);
      YA.resolveOffers(w);
    }
    if (w.week === 31) YA.openSelection(w);
    if (w.week === 35) YA.closeSelection(w);
    // 38週：卒業する上位の子から、進路の相談が届く
    if (w.week === 38) {
      const sr = Object.values(w.players).filter((p) => p.grade === 3 && YA.ovr(p) >= 10.8).sort((a, b) => YA.ovr(b) - YA.ovr(a)).slice(0, 4);
      w.forced = (w.forced || []).concat(sr.map((p) => ({ id: 'career', pid: p.id, week: w.week, year: w.year })));
    }
    if (YA.rivalWeek) YA.rivalWeek(w);
    YA.refreshFocus(w);
    for (const p of Object.values(w.players)) {
      if (p.away > 0) p.away--;
      if (p.suspend > 0) p.suspend--;
      if (p.adapt > 0) p.adapt--;
      if (p.dorm) p.fat = clamp(p.fat - 2, 0, 100);
      // 本当に向いているポジションに気づく
      if (p.pos !== 'GK' && !p.bestKnown && r() < 0.012 * (w.coach ? w.coach.eye / 10 : 1)) {
        const best = p.best;
        if (best && best !== p.main && p.apt[best] - p.apt[p.main] > 1.0) {
          p.bestKnown = true;
          YA.noteTier(w, 1, `${p.num}番 ${p.name} は、${YA.POS_LABEL[best]}のほうが向いているかもしれません（いまは${YA.POS_LABEL[p.main]}。ポジション変更を検討）`, p.id);
        }
      }
    }
    // ライバルに差を付けられた子の不満
    const inA = new Set(w.lineupA.map((x) => x.pid));
    for (const x of w.rel || []) {
      if (x.k !== 'rival') continue;
      const a = w.players[x.a];
      const b = w.players[x.b];
      if (!a || !b) continue;
      const lo = inA.has(a.id) && !inA.has(b.id) ? b : inA.has(b.id) && !inA.has(a.id) ? a : null;
      if (lo) lo.unrest += lo.pers['気持ちの強さ'] === '負けず嫌い' ? 0.2 : 0.08; // 毎週の自然な和らぎ（0.5）より小さく、積み上がらない
    }
    // キャプテンの重圧
    const cap = w.captain && w.players[w.captain];
    if (cap && (cap.pers['大舞台'] === 'プレッシャーに弱い' || cap.pers['気持ちの強さ'] === '繊細') && cap.conf > 20) cap.conf -= 0.6;
    // 規律の自然な減衰
    w.disc = clamp((w.disc == null ? 60 : w.disc) - 0.4, 0, 100);
    // 信頼度のゆるやかな動き
    if (w.week % 8 === 0) {
      const rank = YA.myRank(w);
      YA.addTrust(w, rank <= 4 ? 1 : rank >= 10 ? -1 : 0);
    }
    if (w.club.reqYoung > 0) w.club.reqYoung--;
  };
})();
