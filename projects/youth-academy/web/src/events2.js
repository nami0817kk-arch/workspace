// 中身の厚み 2段目その2：子どうしの関係（13種）と、一話で終わる出来事（寮・季節・試合のあと・関係）。
// 一話の出来事は YA.EVENTS に重みつきで足す（毎週の出来事の数は変えず、中身の種類を増やす）。選んだことは記憶に残る。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (p) => String(p.name).split(' ')[0];
  const say = (p, s) => `${sur(p)}「${YA.voice ? YA.voice(p, s) : s}」`;
  const conf = (p, d) => { if (p) p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const all = (w) => Object.values(w.players);
  const A = (w) => all(w).filter((p) => p.team === 'A');
  const prog = (p, a, d) => { p.prog = p.prog || {}; p.prog[a] = (p.prog[a] || 0) + d; };
  const disc = (w, d) => { w.disc = clamp((w.disc || 60) + d, 0, 100); };
  const pickOf = (r, list) => (list.length ? list[r.int(0, list.length - 1)] : null);
  const opt = (label, kind, extra) => ({ label, kind, extra });

  // ---------- 関係（13種）----------
  YA.REL_NAME = { friend: '同期の親友', rival: '犬猿の仲', mentor: '師弟', posrival: 'ポジション争い', childhood: '幼なじみ', room: '寮の同室', caprebel: '主将との反発', savior: '恩人', gk: 'GKの師弟', reconciled: '不仲から親友へ', faction: '派閥', overtaken: '追い抜いた後輩', samejh: '同じ中学' };
  const has = (w, a, b, k) => (w.rel || []).some((x) => ((x.a === a && x.b === b) || (x.a === b && x.b === a)) && (!k || x.k === k));
  const addRel = (w, a, b, k) => { if (a && b && a !== b && !has(w, a, b, k)) (w.rel = w.rel || []).push({ a, b, k }); };
  YA.relWith = (w, p, k) => (w.rel || []).filter((x) => x.k === k && (x.a === p.id || x.b === p.id)).map((x) => w.players[x.a === p.id ? x.b : x.a]).filter(Boolean);
  // 年度はじめ：師弟・GKの師弟・寮の同室・同じ中学・幼なじみ（事情）を結ぶ
  YA.relSync = function (w) {
    w.rel = (w.rel || []).filter((x) => w.players[x.a] && w.players[x.b]);
    const ps = all(w);
    for (const g1 of ps.filter((p) => p.grade === 1)) {
      const t = ps.filter((q) => q.grade === 3 && q.main === g1.main && !YA.relWith(w, q, 'mentor').length)[0];
      if (t && YA.hash(g1.id + t.id) % 3 === 0) addRel(w, t.id, g1.id, g1.pos === 'GK' ? 'gk' : 'mentor');
    }
    const dorm = ps.filter((p) => p.dorm !== false && !YA.relWith(w, p, 'room').length).sort((a, b) => a.grade - b.grade || YA.hash(a.id) - YA.hash(b.id));
    for (let i = 0; i + 1 < dorm.length; i += 2) if (dorm[i].grade === dorm[i + 1].grade) addRel(w, dorm[i].id, dorm[i + 1].id, 'room');
    for (const p of ps.filter((x) => x.bg === 'childhood' && !YA.relWith(w, x, 'childhood').length)) {
      const q = ps.find((x) => x.id !== p.id && x.grade === p.grade && !YA.relWith(w, x, 'childhood').length);
      if (q) addRel(w, p.id, q.id, 'childhood');
    }
    const jh = ps.filter((p) => p.grade === 1);
    for (const p of jh) { const q = ps.find((x) => x.grade >= 2 && YA.hash(x.id + 'jh') % 23 === YA.hash(p.id + 'jh') % 23); if (q && YA.hash(p.id) % 4 === 0) addRel(w, p.id, q.id, 'samejh'); }
  };
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) { const r = ys0.apply(this, arguments); YA.relSync(w); return r; };
  // 毎週：師弟は後輩の頭（判断・予測）が少し伸びる。GKの師弟はGKの能力
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.relKey !== key) {
      w.relKey = key;
      for (const x of w.rel || []) {
        const a = w.players[x.a], b = w.players[x.b];
        if (!a || !b) continue;
        if (x.k === 'mentor') { prog(b, '判断', 0.04); prog(b, '予測', 0.04); }
        if (x.k === 'gk') { prog(b, '反応', 0.05); prog(b, 'ポジショニング', 0.04); }
      }
    }
    return res;
  };

  // ---------- 一話の出来事 ----------
  const lastGame = (w) => (w.results || []).slice(-1)[0] || null;
  const justPlayed = (p, w) => p.lm && p.lm.y === w.year && p.lm.w >= w.week - 1;
  const EV = [
    // 寮
    { id: 'dormmom', name: '寮母さん', w: 0.5, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false && p.grade === 1)),
      text: (p) => `寮母さんが言いに来た。「${sur(p)}くん、夜にひとりで泣いてるみたいなんです」`,
      opts: [opt('寮母さんと一緒に話を聞く', 'warm', (w, p) => { conf(p, 6); p.unrest = Math.max(0, (p.unrest || 0) - 1); }), opt('同室の子に頼む', 'push', (w, p) => { const r = YA.relWith(w, p, 'room')[0]; conf(p, r ? 5 : 1); conf(r, 2); }), opt('寮母さんに任せる', 'wait')] },
    { id: 'yashoku', name: '夜食', w: 0.4, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false && p.grade >= 2)),
      text: (p) => `${p.name}たちが、消灯のあとに寮の台所で夜食を作っていた。いい匂いがする。`,
      opts: [opt('一緒に食べる', 'warm', (w) => { for (const q of all(w).filter((x) => x.dorm !== false)) conf(q, 1); }), opt('今日だけだと言う', 'wait'), opt('決まりは決まりだと叱る', 'firm', (w) => disc(w, 2))] },
    { id: 'roomswap', name: '部屋替え', w: 0.3, pick: (w, r) => pickOf(r, all(w).filter((p) => YA.relWith(w, p, 'room').length && (p.unrest || 0) >= 1)),
      text: (p, w) => { const q = YA.relWith(w, p, 'room')[0]; return `${say(p, `${q ? sur(q) : '同室の子'}と、部屋を替えてもらえませんか`)}`; },
      opts: [opt('理由を聞いてから決める', 'warm', (w, p) => conf(p, 3)), opt('替える', 'push', (w, p) => { w.rel = (w.rel || []).filter((x) => !(x.k === 'room' && (x.a === p.id || x.b === p.id))); }), opt('我慢させる', 'firm', (w, p) => { p.unrest = (p.unrest || 0) + 1; })] },
    { id: 'lightsout', name: '消灯のあと', w: 0.3, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false && p.grade === 3)),
      text: (p) => `見回りのとき、高3の部屋から声がした。${p.name}たちが、進路のことを夜遅くまで話していた。`,
      opts: [opt('そっと戸を閉める', 'wait', (w) => { for (const q of all(w).filter((x) => x.grade === 3)) conf(q, 1); }), opt('一緒に少し話す', 'warm', (w, p) => conf(p, 4)), opt('早く寝ろと言う', 'firm')] },
    { id: 'dormbday', name: '寮の誕生日会', w: 0.3, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false)),
      text: (p) => `今日は${p.name}の誕生日だ。寮の子たちが、こっそりケーキを用意している。`,
      opts: [opt('監督からも一言添える', 'warm', (w, p) => conf(p, 6)), opt('練習のあとに時間を作る', 'push', (w) => { for (const q of all(w).filter((x) => x.dorm !== false)) conf(q, 1); }), opt('気づかないふりをする', 'wait')] },
    { id: 'tvfight', name: 'テレビの取り合い', w: 0.25, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false && p.grade === 1)),
      text: (p) => `寮の談話室で、海外サッカーの中継と歌番組の取り合いになった。${p.name}が先輩に言い返したらしい。`,
      opts: [opt('皆で中継を見ながら解説する', 'warm', (w) => { for (const q of all(w).filter((x) => x.dorm !== false)) prog(q, '判断', 0.05); }), opt('当番制を決めさせる', 'push', (w) => disc(w, 1)), opt('放っておく', 'wait')] },
    // 季節
    { id: 's_welcome', name: '新入生の歓迎会', w: 2, when: (w) => w.week >= 2 && w.week <= 3, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade === 1)),
      text: (p) => `新入生の歓迎会。上級生が出し物を用意した。${p.name}が緊張した顔で前に出てきた。`,
      opts: [opt('一言ずつ話させる', 'push', (w) => { for (const q of all(w).filter((x) => x.grade === 1)) conf(q, 2); }), opt('上級生に盛り上げさせる', 'warm', (w) => { for (const q of all(w)) conf(q, 1); }), opt('早めに切り上げる', 'wait')] },
    { id: 's_rain', name: '梅雨', w: 1.2, when: (w) => w.week >= 8 && w.week <= 12, pick: (w, r) => pickOf(r, all(w).filter((p) => (p.fat || 0) > 50)),
      text: (p) => `雨続きでグラウンドがぬかるんでいる。${p.name}が「体が重い」とこぼした。`,
      opts: [opt('室内で戦術の勉強に替える', 'warm', (w) => { for (const q of A(w)) prog(q, '判断', 0.1); }), opt('雨でもやる', 'push', (w) => { for (const q of all(w)) q.fat = clamp((q.fat || 0) + 3, 0, 100); }), opt('軽めにする', 'wait', (w) => { for (const q of all(w)) q.fat = clamp((q.fat || 0) - 4, 0, 100); })] },
    { id: 's_heat', name: '猛暑', w: 1.2, when: (w) => w.week >= 14 && w.week <= 18, pick: (w, r) => pickOf(r, all(w).filter((p) => (p.fat || 0) > 45)),
      text: (p) => `猛暑の練習。${p.name}の顔色が悪い。トレーナーが「熱中症が心配です」と言う。`,
      opts: [opt('すぐ日陰で休ませる', 'warm', (w, p) => { p.fat = clamp((p.fat || 0) - 15, 0, 100); }), opt('練習を朝と夕方に分ける', 'push', (w) => { for (const q of all(w)) q.fat = clamp((q.fat || 0) - 5, 0, 100); }), opt('このまま続ける', 'firm', (w, p) => { if (YA.hash(p.id + w.week) % 4 === 0) p.inj = Math.max(p.inj || 0, 1); })] },
    { id: 's_home', name: '冬の帰省', w: 1.5, when: (w) => w.week >= 28 && w.week <= 29, pick: (w, r) => pickOf(r, all(w).filter((p) => p.dorm !== false)),
      text: (p) => `寮生が年末に帰省する。${p.name}が「帰らずに残って練習したい」と言ってきた。`,
      opts: [opt('家族のところへ帰らせる', 'warm', (w, p) => { conf(p, 4); p.fat = 0; }), opt('残って一緒に練習する', 'push', (w, p) => { prog(p, 'テクニック', 0.3); }), opt('本人に任せる', 'wait')] },
    { id: 's_firstkick', name: '初蹴り', w: 2, when: (w) => w.week === 31, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade === 3)),
      text: (p) => `新年の初蹴り。卒業間近の${p.name}たちが、最後の初蹴りだと言っている。`,
      opts: [opt('高3と後輩の試合をする', 'push', (w) => { for (const q of all(w)) conf(q, 1); }), opt('今年の目標を書かせる', 'warm', (w) => { for (const q of all(w).filter((x) => x.grade < 3)) conf(q, 1); }), opt('いつもどおり練習する', 'wait')] },
    { id: 's_snow', name: '雪', w: 1.2, when: (w) => w.week >= 32 && w.week <= 35, pick: (w, r) => pickOf(r, all(w)),
      text: () => `大雪でグラウンドが真っ白だ。練習ができない。`,
      opts: [opt('皆で雪かきをする', 'push', (w) => { for (const q of all(w)) { conf(q, 1); q.fat = clamp((q.fat || 0) + 3, 0, 100); } }), opt('体育館で体幹の練習', 'warm', (w) => { for (const q of all(w)) prog(q, 'バランス', 0.1); }), opt('休みにする', 'wait', (w) => { for (const q of all(w)) q.fat = clamp((q.fat || 0) - 8, 0, 100); })] },
    { id: 's_spring', name: '春休みの遠征', w: 1.2, when: (w) => w.week >= 37 && w.week <= 39, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade <= 2)),
      text: (p) => `春休みの遠征の行き先を決める。${p.name}が「強いところとやりたいです」と言う。`,
      opts: [opt('格上の相手を選ぶ', 'push', (w) => { for (const q of all(w).filter((x) => x.grade <= 2)) prog(q, '判断', 0.15); }), opt('勝てる相手で自信をつける', 'warm', (w) => { for (const q of all(w).filter((x) => x.grade <= 2)) conf(q, 2); }), opt('遠征はやめて休ませる', 'wait')] },
    // 試合のあと
    { id: 'm_hero', name: '決勝点のあと', w: 1, pick: (w, r) => pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.st && p.st.goals >= 1 && p.lm.rating >= 7.5)),
      text: (p) => `この前の試合で決めた${p.name}が、少し浮かれている。練習で手を抜く場面があった。`,
      opts: [opt('調子に乗るなと締める', 'firm'), opt('次も期待していると言う', 'push', (w, p) => { p.spurt = Math.max(p.spurt || 0, 1); }), opt('今日くらいはと見逃す', 'wait')] },
    { id: 'm_pk', name: 'PKを外した', w: 0.6, pick: (w, r) => pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.lm.rating < 6 && ['ST', 'SS', 'AM'].indexOf(p.main) >= 0)),
      text: (p) => `${p.name}が、この前の試合の大事な場面でシュートを外した。今日は誰とも話していない。`,
      opts: [opt('次もお前が蹴れと言う', 'push'), opt('隣に座って話を聞く', 'warm'), opt('そっとしておく', 'wait')] },
    { id: 'm_debutgoal', name: '初ゴール', w: 1.2, pick: (w, r) => pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.st && p.st.goals >= 1 && !(p.mem || []).some((m) => m.k === 'm_debutgoal') && p.grade <= 2)),
      text: (p) => `${p.name}が、Aでの初ゴールを決めた。試合球を大事そうに抱えている。`,
      opts: [opt('ボールにサインして渡す', 'warm', (w, p) => conf(p, 6)), opt('ここからだと言う', 'push', (w, p) => { p.spurt = Math.max(p.spurt || 0, 2); }), opt('皆の前で褒める', 'push', (w) => { for (const q of A(w)) conf(q, 1); })] },
    { id: 'm_rout', name: '大敗のロッカー', w: 1.5, pick: (w, r) => { const g = lastGame(w); return g && g.year === w.year && g.week >= w.week - 1 && g.ga - g.gf >= 3 ? pickOf(r, A(w)) : null; },
      text: (p, w) => { const g = lastGame(w); return `${g.gf}-${g.ga}の大敗。ロッカーが静まり返っている。主将の${(w.captain && w.players[w.captain] ? w.players[w.captain].name : p.name)}が、こちらを見ている。`; },
      opts: [opt('全員に一つずつ課題を言わせる', 'push', (w) => { for (const q of A(w)) prog(q, '判断', 0.1); }), opt('「切り替えよう」とだけ言う', 'warm', (w) => { for (const q of A(w)) conf(q, 2); }), opt('厳しく叱る', 'firm', (w) => { for (const q of A(w)) conf(q, -2); disc(w, 2); })] },
    { id: 'm_comeback', name: '逆転勝ちのあと', w: 1, pick: (w, r) => { const g = lastGame(w); return g && g.year === w.year && g.week >= w.week - 1 && g.gf > g.ga && g.gf >= 2 ? pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.lm.rating >= 7)) : null; },
      text: (p) => `粘って勝った試合のあと、${p.name}がまだ興奮している。「あの時間帯、全員が走ってました」`,
      opts: [opt('その粘りを褒める', 'warm', (w) => { for (const q of A(w)) conf(q, 2); }), opt('前半の課題も話す', 'push', (w) => { for (const q of A(w)) prog(q, '集中', 0.08); }), opt('今日は休ませる', 'wait', (w) => { for (const q of A(w)) q.fat = clamp((q.fat || 0) - 6, 0, 100); })] },
    { id: 'm_ref', name: '誤審', w: 0.6, pick: (w, r) => { const g = lastGame(w); return g && g.year === w.year && g.week >= w.week - 1 && g.gf < g.ga ? pickOf(r, A(w)) : null; },
      text: (p) => `この前の試合の判定に、子どもたちが納得していない。${p.name}が「あれはファウルじゃなかった」と言っている。`,
      opts: [opt('判定は受け入れろと言う', 'firm', (w) => disc(w, 2)), opt('悔しさを次にぶつけろと言う', 'push'), opt('協会に問い合わせる', 'warm', (w) => { if (w.club) w.club.trust = clamp(w.club.trust - 1, 0, 100); })] },
    { id: 'm_hurt', name: '相手を怪我させた', w: 0.4, pick: (w, r) => pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.pos === 'DF')),
      text: (p) => `${p.name}のタックルで、相手の選手が担架で運ばれた。故意ではない。本人は青い顔をしている。`,
      opts: [opt('一緒に相手のお見舞いに行く', 'warm', (w, p) => { conf(p, 3); if (YA.addRep) YA.addRep(w, 1); }), opt('プレーは正当だったと伝える', 'push'), opt('しばらく様子を見る', 'wait', (w, p) => conf(p, -4))] },
    { id: 'm_bench', name: 'ベンチ外の応援', w: 0.6, pick: (w, r) => pickOf(r, all(w).filter((p) => p.team === 'B' && p.grade === 3)),
      text: (p) => `試合のスタンドで、ベンチに入れなかった${p.name}たち高3が、ずっと声を出していた。`,
      opts: [opt('試合のあと、高3に頭を下げる', 'warm', (w) => { for (const q of all(w).filter((x) => x.grade === 3 && x.team === 'B')) { conf(q, 4); q.unrest = Math.max(0, (q.unrest || 0) - 1); } }), opt('Aの子たちにお礼を言わせる', 'push', (w) => disc(w, 2)), opt('何も言わない', 'wait')] },
    { id: 'm_hat', name: 'ハットトリック', w: 2, pick: (w, r) => pickOf(r, A(w).filter((p) => justPlayed(p, w) && p.st && p.st.goals >= 3)),
      text: (p) => `${p.name}がハットトリックを決めた。地元の新聞が写真を撮りに来ている。`,
      opts: [opt('取材を受けさせる', 'push', (w, p) => { conf(p, 5); if (YA.addRep) YA.addRep(w, 1); }), opt('チームのおかげだと言わせる', 'warm', (w) => { for (const q of A(w)) conf(q, 1); }), opt('取材は断る', 'firm')] },
    // 関係
    { id: 'r_mentor', name: '師弟', w: 0.6, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade === 3 && YA.relWith(w, p, 'mentor').length)),
      text: (p, w) => { const q = YA.relWith(w, p, 'mentor')[0]; return `${p.name}が、後輩の${q.name}に居残りで教えている。${say(p, 'こいつ、昔の自分に似てるんです')}`; },
      opts: [opt('二人の時間を増やす', 'warm', (w, p) => { const q = YA.relWith(w, p, 'mentor')[0]; prog(q, '判断', 0.3); prog(q, 'ポジショニング', 0.3); }), opt('高3は自分の練習を優先させる', 'firm'), opt('見守る', 'wait')] },
    { id: 'r_overtaken', name: '追い抜かれた先輩', w: 0.5, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade === 3 && p.team === 'B' && all(w).some((q) => q.grade === 1 && q.team === 'A' && q.main === p.main))),
      text: (p, w) => { const q = all(w).find((x) => x.grade === 1 && x.team === 'A' && x.main === p.main); return `高1の${q ? q.name : '後輩'}に先発を取られた${p.name}が、黙って居残り練習をしている。`; },
      opts: [opt('後輩の面倒を見る役を頼む', 'push', (w, p) => { const q = all(w).find((x) => x.grade === 1 && x.team === 'A' && x.main === p.main); if (q) addRel(w, p.id, q.id, 'mentor'); conf(p, 3); }), opt('チャンスはあると言う', 'warm', (w, p) => conf(p, 4)), opt('現実を伝える', 'firm', (w, p) => { conf(p, -3); p.unrest = (p.unrest || 0) + 1; })] },
    { id: 'r_samejh', name: '同じ中学', w: 0.4, pick: (w, r) => pickOf(r, all(w).filter((p) => p.grade === 1 && YA.relWith(w, p, 'samejh').length)),
      text: (p, w) => { const q = YA.relWith(w, p, 'samejh')[0]; return `高1の${p.name}は、同じ中学の先輩の${q.name}にくっついて回っている。`; },
      opts: [opt('先輩に面倒を頼む', 'warm', (w, p) => conf(p, 4)), opt('自分の友達を作れと言う', 'push', (w, p) => { const f = all(w).find((x) => x.grade === p.grade && x.id !== p.id); if (f) addRel(w, p.id, f.id, 'friend'); }), opt('見守る', 'wait')] },
    { id: 'r_faction', name: '派閥', w: 0.3, pick: (w, r) => { const c = w.captain && w.players[w.captain]; return c && (w.disc || 60) < 55 ? pickOf(r, all(w).filter((p) => p.grade === 3 && p.id !== c.id && YA.ovr(p) >= YA.ovr(c))) : null; },
      text: (p) => `${p.name}のまわりに、主将とは別の輪ができている。ロッカーの空気が二つに割れている。`,
      opts: [opt('二人に一緒にチームを引っ張らせる', 'push', (w, p) => { disc(w, 3); conf(p, 2); }), opt('チーム全員で話す', 'warm', (w) => disc(w, 2)), opt('主将を守る', 'firm', (w, p) => { p.unrest = (p.unrest || 0) + 2; })] },
    { id: 'r_savior', name: '恩人', w: 0.3, pick: (w, r) => pickOf(r, all(w).filter((p) => (p.inj || 0) >= 1 && p.grade <= 2)),
      text: (p, w) => { const q = all(w).find((x) => x.grade === 3 && x.id !== p.id && x.main === p.main) || all(w).find((x) => x.grade === 3); return `${p.name}の怪我に最初に気づいたのは、高3の${q ? q.name : '先輩'}だった。「顔色が変だったので」`; },
      opts: [opt('その先輩を皆の前で褒める', 'warm', (w, p) => { const q = all(w).find((x) => x.grade === 3 && x.main === p.main) || all(w).find((x) => x.grade === 3); if (q) { conf(q, 4); addRel(w, q.id, p.id, 'savior'); } }), opt('二人で話す時間を作る', 'push', (w, p) => { const q = all(w).find((x) => x.grade === 3); if (q) addRel(w, q.id, p.id, 'savior'); }), opt('何も言わない', 'wait')] },
  ];
  YA.EVENTS2 = EV.map((e) => e.id);
  for (const e of EV) {
    YA.EVENTS.push({ id: e.id, name: e.name, weight: e.when ? e.w : e.w * 0.5, pick: (w, r) => (e.when && !e.when(w) ? null : e.pick(w, r)), text: (p, w) => e.text(p, w), opts: e.opts });
  }
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  for (const e of EV) YA.EVENT_ABOUT[e.id] = YA.EVENT_ABOUT[e.id] || '季節・寮・試合のあと・子どうしの関係から起きる、一話で終わる出来事です。どう向き合ったかは、その子の記憶に残ります。';
  // 選んだことを記憶に（★でない子も）
  const quoteOf = (label) => { const m = /「([^」]+)」/.exec(label || ''); return m ? m[1] : String(label || '').replace(/（[^）]*）/g, '').trim(); };
  const set = new Set(YA.EVENTS2);
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e.pid ? w.players[e.pid] : null;
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const o = def && def.opts && def.opts[idx];
    const out = r0.apply(this, arguments);
    if (p && o && set.has(e.id) && w.players[p.id] && YA.memAdd) YA.memAdd(w, p, e.id, o.kind, quoteOf(o.label));
    return out;
  };
  // 卒業式：同期の親友・師弟に触れる
  const say0 = YA.say;
  YA.say = function (w, p, scene) {
    const s = say0.apply(this, arguments);
    if (scene !== 'thanks' || !p || !w) return s;
    const f = YA.relWith(w, p, 'friend').concat(YA.relWith(w, p, 'reconciled')).find((q) => q.grade === p.grade);
    const m = YA.relWith(w, p, 'mentor').find((q) => q.grade < p.grade);
    if (f && YA.hash(p.id + 'f') % 2 === 0) return s + `　${sur(f)}と同期で、よかったです。`;
    if (m) return s + `　${sur(m)}、あとは頼んだ。`;
    return s;
  };
  YA.MEM_NAME = Object.assign(YA.MEM_NAME || {}, Object.fromEntries(EV.map((e) => [e.id, e.name])), { chain: '続き物', promise: '約束' });
})();
