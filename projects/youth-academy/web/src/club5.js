// 中身の厚み 5段目：ライバル監督が口を開く・強化部長を一人の人物に・練習日誌と練習中の出来事・練習の成果が試合に出る。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (n) => String(n).split(' ')[0];
  const all = (w) => Object.values(w.players);
  const A = (w) => all(w).filter((p) => p.team === 'A');
  const conf = (p, d) => { if (p) p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const pickOf = (r, list) => (list.length ? list[r.int(0, list.length - 1)] : null);
  const opt = (label, kind, extra) => ({ label, kind, extra });
  const run = (label, fn) => ({ label, kind: null, run: (w) => { const r = fn(w) || {}; return { line: r.line || '', small: r.small || '' }; } });

  // ---------- ライバル監督 ----------
  // 関係：対戦と出来事で動く（-100〜100）。宿敵／好敵手／認め合う
  YA.rivalRelName = (v) => (v <= -30 ? '宿敵' : v >= 30 ? '認め合う' : '好敵手');
  const rcOf = (w, name) => { try { return (YA.rivalSync(w) || []).find((x) => x.teamName === name); } catch (e) { return null; } };
  const defOf = (k) => (YA.RIVAL_COACHES || []).find((d) => d.k === k) || {};
  const PRE = {
    wall: { first: '「若いの。ユースの試合は、守った方が勝つ」', win: '「前は不覚を取った。今度は一点もやらん」', lose: '「また、守り切らせてもらう」', rivalry: '「お前のところとの試合は、眠れんよ」' },
    poach: { first: '「いい選手を集めてますね。少し分けてほしいくらいです」', win: '「前回は勉強になりました。今日は取り返します」', lose: '「うちの子たち、また楽しみにしてますよ」', rivalry: '「今年も、いい子を何人か取り合いましたね」' },
    teach: { first: '「勝ち負けより、子どもたちが何を持って帰るかです」', win: '「前回の負けで、うちの子たちは大きくなりました」', lose: '「今日もいい試合にしましょう」', rivalry: '「あなたの卒業生の便り、うちにも届いていますよ」' },
    tact: { first: '「あなたの癖は、映像で全部見ました」', win: '「前回の試合、30回見直しました」', lose: '「今日も、同じ手で行きます」', rivalry: '「あなたの手は、もう読めています。読めているはずです」' },
  };
  const POST = {
    win: ['試合のあと、{n}監督が歩み寄ってきた。「……やられました。次は、こうはいかない」', '{n}監督は握手のあと、ベンチを振り返らずに帰っていった。'],
    lose: ['{n}監督が笑った。「いい試合でした。またやりましょう」', '{n}監督は「まだまだですね」とだけ言って去った。'],
    draw: ['{n}監督と目が合った。互いに、苦笑いだった。'],
    big: ['大差で勝った試合のあと、{n}監督は握手を拒んだ。', '大差で負けた試合のあと、{n}監督が「子どもたちに罪はない」と声をかけてきた。'],
  };
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.c5Key === key) return res;
    w.c5Key = key;
    w.rivalRel = w.rivalRel || {};
    try {
      // 試合のあと：前の週の結果に一言
      const g = (w.results || []).slice(-1)[0];
      if (g && g.year === w.year && g.week === w.week - 1) {
        const rc = rcOf(w, g.opp);
        if (rc) {
          const d = defOf(rc.k);
          const res2 = g.gf - g.ga >= 3 || g.ga - g.gf >= 3 ? 'big' : g.gf > g.ga ? 'win' : g.gf < g.ga ? 'lose' : 'draw';
          const list = POST[res2];
          let line = list[YA.hash(rc.k + w.year + w.week) % list.length].replace('{n}', sur(d.name || ''));
          if (res2 === 'big') line = g.gf > g.ga ? POST.big[0].replace('{n}', sur(d.name || '')) : POST.big[1].replace('{n}', sur(d.name || ''));
          w.rivalRel[rc.k] = clamp((w.rivalRel[rc.k] || 0) + (res2 === 'big' && g.gf > g.ga ? -15 : res2 === 'win' ? -6 : res2 === 'lose' ? 4 : 2), -100, 100);
          YA.noteTier(w, 2, `${line}（${d.name}との関係：${YA.rivalRelName(w.rivalRel[rc.k])}）`);
        }
      }
      // 試合の前：相手が名物監督なら一言
      const opp = YA.matchOf && YA.matchOf(w) ? YA.opponentOf(w) : null;
      const rc = opp ? rcOf(w, opp.name) : null;
      if (rc) {
        const d = defOf(rc.k);
        const L = PRE[rc.k] || PRE.teach;
        const rec = rc.rec || { w: 0, d: 0, l: 0 };
        const n = rec.w + rec.d + rec.l;
        const last = (w.results || []).filter((x) => x.opp === opp.name).slice(-1)[0];
        const line = n === 0 ? L.first : Math.abs(w.rivalRel[rc.k] || 0) >= 30 ? L.rivalry : last && last.gf > last.ga ? L.win : L.lose;
        YA.noteTier(w, 1, `今週の相手は${d.name}（${d.title}）の${opp.name}。${line}（通算 ${rec.w}勝${rec.d}分${rec.l}敗）`);
      }
    } catch (er) { /* 日程の無い週 */ }
    YA.clubEventWeek(w);
    return res;
  };

  // ---------- 強化部長 ----------
  const DIR_NAMES = ['大河内 剛', '早瀬 美佐子', '宇佐美 修', '堀之内 誠一', '真壁 千尋', '久我 栄治'];
  YA.directorOf = function (w) {
    if (!w.director) {
      const n = DIR_NAMES[YA.hash(String(w.seed) + w.clubName) % DIR_NAMES.length];
      const pk = Object.keys(YA.STAFF_PERS || { 理論派: 1 });
      w.director = { name: n, pers: pk[YA.hash(n + 'p') % pk.length], rel: 50, since: w.year };
    }
    return w.director;
  };
  const dirLine = (w) => { const d = YA.directorOf(w); return `強化部長の${d.name}（${d.pers}）`; };
  // 年度末の評価に、理由と来年の注文を添える
  const ev0 = YA.yearEndEval || null;
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    const r = ys0.apply(this, arguments);
    const d = YA.directorOf(w);
    const last = w.club && w.club.eval && w.club.eval[w.club.eval.length - 1];
    if (last && last.year === w.year - 1 && !w.club.dirSaid) {
      const why = last.letter === 'S' || last.letter === 'A' ? '目標以上の結果と、卒業生の進路が評価されました' : last.letter === 'B' ? '目標はおおむね届きました' : last.letter === 'C' ? '成績か育成のどちらかが物足りませんでした' : '結果も育成も、厳しい一年でした';
      const ask = last.letter === 'D' || last.letter === 'C' ? 'まずは目標の順位を守ってください' : (w.alumni || []).filter((a) => a.year === w.year - 1 && a.status === 'pro').length < 2 ? '来年はプロを2人以上、送り出してほしい' : '今の形を続けてください。地元の子も使ってほしい';
      YA.noteTier(w, 1, `${dirLine(w)}との面談。評価は${last.letter}。「${why}。${ask}」`);
      d.rel = clamp(d.rel + (last.letter === 'S' || last.letter === 'A' ? 8 : last.letter === 'D' ? -10 : 0), 0, 100);
    }
    return r;
  };
  const CE = [
    { id: 'budgetnego', name: '予算の交渉', c: (w) => w.week >= 3 && w.week <= 6, t: (w) => `${dirLine(w)}から「来年の予算、施設とスカウトのどちらに厚く振りますか」と聞かれた。`,
      o: () => [run('施設に振る', (w) => { w.club.facPts = (w.club.facPts || 0) + 200; return { line: '施設の積み立てが進んだ。', small: '施設 +200' }; }), run('スカウトに振る', (w) => { w.scoutPlus = (w.scoutPlus || 0) + 1; return { line: '今年は、月ごとに見に行ける回数が1回増えた。' }; }), run('部長に任せる', (w) => { YA.directorOf(w).rel += 4; return { line: '「では、こちらで」' }; })] },
    { id: 'president', name: '社長の交代', c: (w) => w.year >= 3 && YA.hash('pr' + w.year + w.seed) % 4 === 0 && w.week === 15, t: (w) => `クラブの社長が替わった。${dirLine(w)}が「新しい社長は、結果を急ぐ人です」と耳打ちした。`,
      o: () => [run('結果で応える', (w) => { if (w.club) w.club.trust = clamp(w.club.trust - 2, 0, 100); return { line: '緊張感が増した。' }; }), run('育成の考えを説明しに行く', (w) => { if (w.club) w.club.trust = clamp(w.club.trust + 3, 0, 100); return { line: '社長は「なるほど」と言った。' }; }), run('様子を見る', () => ({ line: '' }))] },
    { id: 'sponsor', name: 'スポンサーの注文', c: (w) => w.week >= 8 && w.week <= 20 && all(w).some((p) => p.team === 'B'), t: (w) => `スポンサー企業から「地元出身の子を、もっと試合で使ってほしい」と注文が来た。`,
      o: () => [run('地元の子を使うと約束する', (w) => { const p = all(w).find((x) => x.team === 'B'); if (p && YA.addPromise) YA.addPromise(w, p, 4, 'Aで使う'); if (YA.addRep) YA.addRep(w, 1); return { line: '', small: '評判 +1' }; }), run('起用は監督が決めると伝える', (w) => { if (w.club) w.club.trust = clamp(w.club.trust - 2, 0, 100); return { line: '部長が困った顔をしている。' }; }), run('部長に間に入ってもらう', (w) => { YA.directorOf(w).rel -= 3; return { line: '' }; })] },
    { id: 'topbind', name: 'トップとの板挟み', c: (w) => !!w.top && w.week >= 10 && w.week <= 30, t: (w) => `トップの監督が「ユースのいい子を、練習に貸してくれ」と言ってきた。大会が近い。`,
      o: () => [run('貸す', (w) => { const p = A(w).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; if (p) { p.away = Math.max(p.away || 0, 1); if (p.prog) p.prog.判断 = (p.prog.判断 || 0) + 0.4; } return { line: 'トップの練習で、もまれて帰ってくるはずだ。', small: '1週不在・判断が伸びる' }; }), run('大会のあとにしてもらう', () => ({ line: '「しかたない」と言われた。' })), run('部長に判断してもらう', (w) => { YA.directorOf(w).rel += 2; return { line: '' }; })] },
    { id: 'cut', name: '予算の削減', c: (w) => w.club && w.club.trust < 45 && w.week === 18, t: (w) => `${dirLine(w)}が「今年の後半は、予算を少し削らせてください」と頭を下げてきた。`,
      o: () => [run('受け入れる', (w) => { YA.directorOf(w).rel += 6; w.club.total = Math.round(w.club.total * 0.95); return { line: '', small: '予算 −5%' }; }), run('育成の予算だけは守ってほしいと頼む', (w) => { w.club.total = Math.round(w.club.total * 0.97); return { line: '半分だけ聞いてもらえた。' }; }), run('断る', (w) => { YA.directorOf(w).rel -= 8; w.club.trust = clamp(w.club.trust - 3, 0, 100); return { line: '' }; })] },
    { id: 'newground', name: '新しい練習場', c: (w) => w.club && w.club.trust >= 65 && w.week === 20, t: (w) => `${dirLine(w)}から「人工芝の練習場を作る話があります。意見をください」`,
      o: () => [run('雨でも使えるように、と頼む', (w) => { w.club.facPts = (w.club.facPts || 0) + 300; return { line: '', small: '施設 +300' }; }), run('寮を先に、と頼む', (w) => { for (const p of all(w).filter((x) => x.dorm !== false)) conf(p, 2); return { line: '' }; }), run('任せる', () => ({ line: '' }))] },
    { id: 'scandal2', name: '不祥事の対応', c: (w) => (w.disc || 60) < 45 && w.week >= 5, t: (w) => `選手が街で騒いでいたと、クラブに苦情が入った。${dirLine(w)}が「どう対応しますか」と聞いてきた。`,
      o: () => [run('監督が謝りに行く', (w) => { w.disc = clamp((w.disc || 60) + 4, 0, 100); return { line: '先方は許してくれた。' }; }), run('選手に謝らせる', (w) => { w.disc = clamp((w.disc || 60) + 6, 0, 100); return { line: '子どもたちが頭を下げに行った。' }; }), run('クラブに任せる', (w) => { w.club.trust = clamp(w.club.trust - 3, 0, 100); return { line: '' }; })] },
    { id: 'anniv', name: '創立記念', c: (w) => w.year % 5 === 0 && w.week === 12, t: (w) => `クラブの創立記念の式典がある。卒業生も招かれる。`,
      o: () => [run('卒業生と試合をする', (w) => { for (const p of all(w)) conf(p, 2); return { line: '卒業生の本気に、子どもたちが目を丸くしていた。' }; }), run('子どもたちに挨拶をさせる', (w) => { if (YA.addRep) YA.addRep(w, 1); return { line: '' }; }), run('練習を優先する', () => ({ line: '' }))] },
    { id: 'visit', name: '社長の視察', c: (w) => w.week === 9 || w.week === 24, t: (w) => `社長が練習の視察に来る。${dirLine(w)}が「いいところを見せてください」と言う。`,
      o: () => [run('いつもどおりの練習を見せる', (w) => { w.club.trust = clamp(w.club.trust + 1, 0, 100); return { line: '「普段どおりがいい」と言われた。' }; }), run('紅白戦を見せる', (w) => { w.club.trust = clamp(w.club.trust + 2, 0, 100); for (const p of A(w)) p.fat = clamp((p.fat || 0) + 3, 0, 100); return { line: '' }; }), run('高1の成長を見せる', (w) => { for (const p of all(w).filter((x) => x.grade === 1)) conf(p, 2); return { line: '' }; })] },
    { id: 'renew', name: '契約更新の面談', c: (w) => w.club && w.club.contract && w.club.contract.left === 1 && w.week === 30, t: (w) => `${dirLine(w)}と、契約更新の前の面談。「来年も、お願いしたいと思っています」`,
      o: () => [run('条件より育成の予算を求める', (w) => { w.club.alloc.scout = Math.min(60, w.club.alloc.scout + 4); return { line: '' }; }), run('ありがたく受ける', (w) => { YA.directorOf(w).rel += 6; return { line: '' }; }), run('少し考えさせてほしいと言う', (w) => { YA.directorOf(w).rel -= 3; return { line: '' }; })] },
    { id: 'relegated', name: 'トップ降格の余波', c: (w) => !!w.top && (w.top.hist || []).slice(-1)[0] && /降格/.test(JSON.stringify((w.top.hist || []).slice(-1)[0])) && w.week === 4, t: (w) => `トップが降格した。${dirLine(w)}が「ユースの予算にも影響が出ます」と言った。`,
      o: () => [run('ユースから上げる子を増やすと約束する', (w) => { w.club.trust = clamp(w.club.trust + 3, 0, 100); return { line: '' }; }), run('受け入れる', (w) => { w.club.total = Math.round(w.club.total * 0.95); return { line: '', small: '予算 −5%' }; }), run('育成の予算は守ってほしいと頼む', () => ({ line: '' }))] },
    { id: 'dirtalk', name: '強化部長と食事', c: (w) => w.week === 33, t: (w) => `${dirLine(w)}に食事に誘われた。「本音を聞かせてください」`,
      o: () => [run('育成の夢を語る', (w) => { YA.directorOf(w).rel += 8; return { line: '「あなたに任せてよかった」' }; }), run('クラブへの不満を言う', (w) => { YA.directorOf(w).rel -= 4; w.club.trust = clamp(w.club.trust + 1, 0, 100); return { line: '少し空気が張りつめた。' }; }), run('当たり障りなく話す', () => ({ line: '' }))] },
    // ライバル監督との出来事
    { id: 'jointtrain', name: '合同練習の誘い', c: (w) => w.week >= 30 && w.week <= 38, t: (w) => { const d = (YA.RIVAL_COACHES || [])[YA.hash('jt' + w.year) % 4] || {}; return `${d.name || '名物監督'}から「冬に、合同練習をしませんか」と誘いが来た。`; },
      o: () => [run('受ける', (w) => { for (const p of all(w)) if (p.prog) p.prog.判断 = (p.prog.判断 || 0) + 0.15; const d = (YA.RIVAL_COACHES || [])[YA.hash('jt' + w.year) % 4]; if (d) w.rivalRel = Object.assign(w.rivalRel || {}, { [d.k]: ((w.rivalRel || {})[d.k] || 0) + 10 }); return { line: '手の内を見せ合う、いい練習になった。' }; }), run('手の内は見せないと断る', () => ({ line: '' })), run('高1だけで受ける', (w) => { for (const p of all(w).filter((x) => x.grade === 1)) conf(p, 3); return { line: '' }; })] },
    { id: 'poachkid', name: '引き抜き騒ぎ', c: (w) => all(w).some((p) => p.team === 'B' && p.grade <= 2 && (p.unrest || 0) >= 2), t: (w) => { const p = all(w).find((x) => x.team === 'B' && x.grade <= 2 && (x.unrest || 0) >= 2); return `氷室監督のクラブが、Bの${p.name}に声をかけているらしい。`; },
      o: () => [run('本人と話して引き止める', (w) => { const p = all(w).find((x) => x.team === 'B' && x.grade <= 2 && (x.unrest || 0) >= 2); if (p) p.unrest = Math.max(0, p.unrest - 2); return { line: '' }; }), run('相手クラブに抗議する', (w) => { w.rivalRel = Object.assign(w.rivalRel || {}, { poach: ((w.rivalRel || {}).poach || 0) - 15 }); return { line: '氷室監督とは、口をきかなくなった。' }; }), run('本人の意思に任せる', (w) => { const p = all(w).find((x) => x.team === 'B' && x.grade <= 2 && (x.unrest || 0) >= 2); if (p && YA.hash(p.id) % 2) p._leave = true; return { line: '' }; })] },
    { id: 'article', name: '取材記事', c: (w) => w.week === 21, t: (w) => { const d = (YA.RIVAL_COACHES || [])[YA.hash('ar' + w.year) % 4] || {}; return `サッカー雑誌に、${d.name || '名物監督'}のインタビューが載った。こちらのクラブにも触れている。`; },
      o: () => [run('記事を読む', (w) => { const d = (YA.RIVAL_COACHES || [])[YA.hash('ar' + w.year) % 4]; const v = d ? (w.rivalRel || {})[d.k] || 0 : 0; return { line: v >= 0 ? '「あそこの卒業生は、みんな顔がいい」と褒めてあった。' : '「あそこは、育てるより集めるのがうまい」と書かれていた。' }; }), run('子どもたちにも見せる', (w) => { for (const p of A(w)) conf(p, 1); return { line: '' }; }), run('読まない', () => ({ line: '' }))] },
  ];
  YA.CLUB_EVENTS = CE.map((x) => x.id);
  YA.EVENTS.push({ id: 'clubev', name: 'クラブの出来事', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.clubev = '強化部長やクラブ、ライバル監督との出来事です。選んだことで、クラブの信頼度や予算、監督どうしの関係が動きます。';
  function cprep(w, e) {
    const d = CE.find((x) => x.id === e.ck);
    const def = YA.EVENTS.find((x) => x.id === 'clubev');
    if (!d || !def) return false;
    let body = '';
    try { body = d.t(w); } catch (er) { return false; }
    def.name = d.name;
    def.text = () => body;
    def.opts = d.o();
    return true;
  }
  const v0 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'clubev' && !cprep(w, e)) return null; return v0.apply(this, arguments); };
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) { if (e.id === 'clubev') cprep(w, e); return r0.apply(this, arguments); };
  YA.CLUB_EV_P = 0.06;
  YA.clubEventWeek = function (w) {
    if (!w.club || w.week >= YA.WEEKS - 1) return;
    const r = YA.rngOf((w.seed | 0) * 59 + w.year * 40 + w.week);
    w.clubEvDone = w.clubEvDone && w.clubEvDone.y === w.year ? w.clubEvDone : { y: w.year, ids: [] };
    const cands = CE.filter((d) => w.clubEvDone.ids.indexOf(d.id) < 0 && (() => { try { return !!d.c(w); } catch (er) { return false; } })());
    if (!cands.length || !r.chance(YA.CLUB_EV_P)) return; // 2026-11-15「★以外のイベントが多発する」で 0.35→0.06
    const d = cands[r.int(0, cands.length - 1)];
    w.clubEvDone.ids.push(d.id);
    w.forced = (w.forced || []).concat([{ id: 'clubev', ck: d.id, pid: null, x: null, week: w.week, year: w.year }]);
  };

  // ---------- 練習日誌（毎週・読むだけ）----------
  const DIARY = [
    (w, x) => x.top ? `${x.top.name}の伸びが目立った週だった。` : '',
    (w, x) => x.focus ? `今週の重点「${x.focus}」は、${x.fat > 55 ? '疲れもあって、まだ形になりきらない' : '少しずつ形になってきた'}。` : '',
    (w, x) => x.stay ? `${x.stay.name}が、今週も最後まで居残りをしていた。` : '',
    (w, x) => x.coach ? `${x.coach.role}の${sur(x.coach.name)}：「${(YA.STAFF_PERS[x.coach.pers] || {}).say || ''}」` : '',
    (w, x) => (x.fat > 60 ? '全体に疲れが見える。週の後半は動きが重かった。' : x.fat < 35 ? '体が軽い。練習の強度を上げられそうだ。' : ''),
    (w, x) => (x.late ? `${x.late.name}が遅刻した。規律が少し緩んでいる。` : ''),
    (w, x) => (x.star ? `★の${x.star.name}は、${x.star.conf > 60 ? '表情が明るい' : '少し考え込んでいる'}。` : ''),
    (w, x) => (x.g1 ? `高1の${x.g1.name}が、上級生に食らいついていた。` : ''),
    (w, x) => (x.gk ? `GKの${x.gk.name}が、紅白戦で好セーブを連発した。` : ''),
    (w, x) => (x.weather ? x.weather : ''),
    (w, x) => (x.inj ? `${x.inj.name}は別メニューで調整中。` : ''),
    (w, x) => (x.loud ? `${x.loud.name}の声が、グラウンドによく響いていた。` : ''),
    (w, x) => (x.quiet ? `${x.quiet.name}は、今週ほとんど喋らなかった。` : ''),
    (w, x) => (x.pair ? `${x.pair[0].name}と${x.pair[1].name}のコンビが、紅白戦で何度も崩した。` : ''),
    (w, x) => (x.match ? `週末の${x.match}に向けて、相手の映像を見た。` : ''),
    (w, x) => (x.newb ? `${x.newb.name}が、新しい技を試して成功させた。` : ''),
    (w, x) => (x.cap ? `主将の${x.cap.name}が、練習の前に全員を集めて話していた。` : ''),
    (w, x) => (x.b ? `Bの${x.b.name}が、紅白戦でAの子を抜き去った。` : ''),
    (w, x) => (x.after ? '練習のあと、何人かがボールを片付けずに話し込んでいた。' : ''),
    (w, x) => (x.sun ? '夕焼けのなか、最後のミニゲームが盛り上がった。' : ''),
  ];
  YA.diaryOf = function (w) {
    const ps = all(w);
    const r = YA.rngOf((w.seed | 0) * 61 + w.year * 40 + w.week);
    const grow = ps.map((p) => [p, Object.values(p.gain || {}).reduce((a, b) => a + b, 0)]).sort((a, b) => b[1] - a[1]);
    const staff = (w.club && w.club.staff || []).filter((s) => /コーチ/.test(s.role));
    const opp = (() => { try { return YA.matchOf && YA.matchOf(w) ? YA.opponentOf(w).name : null; } catch (e) { return null; } })();
    const x = {
      top: grow[0] && grow[0][1] > 0 ? grow[0][0] : null, focus: w.plan && w.plan.teamFocus, fat: ps.reduce((s, p) => s + (p.fat || 0), 0) / (ps.length || 1),
      stay: pickOf(r, ps.filter((p) => (p.conf || 50) >= 65)), coach: staff.length && YA.STAFF_PERS ? (YA.staffInfo ? YA.staffInfo(pickOf(r, staff)) : null) : null,
      late: (w.disc || 60) < 50 ? pickOf(r, ps) : null, star: pickOf(r, ps.filter((p) => p.star)), g1: pickOf(r, ps.filter((p) => p.grade === 1 && (p.conf || 50) >= 55)),
      gk: r.chance(0.3) ? pickOf(r, ps.filter((p) => p.pos === 'GK')) : null, weather: w.week >= 31 && w.week <= 35 ? '雪の残るグラウンドで、足元が滑った。' : w.week >= 13 && w.week <= 18 ? '暑さで、給水の回数を増やした。' : w.week >= 6 && w.week <= 9 ? '雨で、室内の練習に切り替えた日があった。' : '',
      inj: pickOf(r, ps.filter((p) => (p.inj || 0) > 0)), loud: r.chance(0.3) ? pickOf(r, ps.filter((p) => p.pers && Object.values(p.pers).some((v) => v === 'リーダー気質' || v === 'お調子者'))) : null,
      quiet: r.chance(0.2) ? pickOf(r, ps.filter((p) => (p.conf || 50) < 40)) : null, pair: (() => { const f = (w.rel || []).find((q) => q.k === 'friend' && w.players[q.a] && w.players[q.b] && w.players[q.a].team === 'A'); return f && r.chance(0.3) ? [w.players[f.a], w.players[f.b]] : null; })(),
      match: opp, newb: r.chance(0.25) ? pickOf(r, ps.filter((p) => p.grade <= 2)) : null, cap: r.chance(0.2) && w.captain ? w.players[w.captain] : null, b: r.chance(0.25) ? pickOf(r, ps.filter((p) => p.team === 'B')) : null, after: r.chance(0.15), sun: r.chance(0.15),
    };
    const lines = DIARY.map((f) => { try { return f(w, x); } catch (e) { return ''; } }).filter(Boolean);
    const out = [];
    while (lines.length && out.length < 3) out.push(lines.splice(r.int(0, lines.length - 1), 1)[0]);
    return out;
  };
  const rw1 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw1.apply(this, arguments);
    const key = w.year * 100 + w.week;
    if (w.diaryKey !== key) {
      w.diaryKey = key;
      const d = YA.diaryOf(w);
      w.diary = (w.diary || []).concat([{ y: w.year, w: w.week, t: d }]).slice(-12);
      if (d.length) YA.noteTier(w, 3, `練習日誌：${d.join(' ')}`);
    }
    return res;
  };

  // ---------- 練習中の出来事（20種・一話）----------
  const PE = [
    ['p_stay', '居残り', (w, r) => pickOf(r, all(w).filter((p) => (p.conf || 50) >= 60)), (p) => `練習が終わっても、${p.name}がひとりでシュートを打ち続けている。`, [opt('付き合う', 'warm', (w, p) => { p.prog = p.prog || {}; p.prog.フィニッシュ = (p.prog.フィニッシュ || 0) + 0.3; }), opt('早く帰らせる', 'firm', (w, p) => { p.fat = clamp((p.fat || 0) - 5, 0, 100); }), opt('好きにさせる', 'wait')]],
    ['p_clash', 'ぶつかり合い', (w, r) => pickOf(r, A(w).filter((p) => p.pos === 'DF')), (p) => `紅白戦で、${p.name}が激しく当たりすぎた。相手の子が倒れている。`, [opt('止めて注意する', 'firm'), opt('強度は大事だと認める', 'push', (w, p) => conf(p, 3)), opt('相手の子を先に気づかう', 'warm')]],
    ['p_scare', 'ひやりとした怪我', (w, r) => pickOf(r, all(w).filter((p) => (p.fat || 0) >= 55)), (p) => `${p.name}が足首をひねった。大事には至らなそうだが、顔をしかめている。`, [opt('すぐ練習から外す', 'warm', (w, p) => { p.rest = 'rest'; }), opt('テーピングして続けさせる', 'push', (w, p) => { if (YA.hash(p.id + w.week) % 4 === 0) p.inj = Math.max(p.inj || 0, 2); }), opt('本人に任せる', 'wait')]],
    ['p_newskill', '新しい技', (w, r) => pickOf(r, all(w).filter((p) => p.grade <= 2)), (p) => `${p.name}が、練習で新しいフェイントを決めた。周りがどよめいている。`, [opt('試合でも使えと言う', 'push', (w, p) => { p.prog = p.prog || {}; p.prog.ドリブル = (p.prog.ドリブル || 0) + 0.3; }), opt('基本も大事だと言う', 'firm'), opt('一緒に喜ぶ', 'warm', (w, p) => conf(p, 4))]],
    ['p_upset', '紅白戦の下剋上', (w, r) => pickOf(r, all(w).filter((p) => p.team === 'B')), (p) => `紅白戦で、Bが勝った。決勝点は${p.name}だ。`, [opt('Bの子を次の試合で使う', 'push', (w, p) => { if (YA.addPromise) YA.addPromise(w, p, 3, 'Aで使う'); conf(p, 5); }), opt('Aに奮起を促す', 'firm', (w) => { for (const q of A(w)) conf(q, -1); }), opt('両方を褒める', 'warm', (w) => { for (const q of all(w)) conf(q, 1); })]],
    ['p_gksave', 'GKの好セーブ', (w, r) => pickOf(r, all(w).filter((p) => p.pos === 'GK')), (p) => `${p.name}が、紅白戦で至近距離のシュートを止めた。`, [opt('皆の前で褒める', 'warm', (w, p) => conf(p, 5)), opt('次はキャッチしろと言う', 'push'), opt('何も言わない', 'wait')]],
    ['p_scold', 'コーチの叱責', (w, r) => pickOf(r, all(w).filter((p) => (p.conf || 50) < 50)), (p) => `コーチが${p.name}を強く叱った。${p.name}はうつむいている。`, [opt('あとで話を聞く', 'warm', (w, p) => conf(p, 5)), opt('コーチの側に立つ', 'firm'), opt('コーチと話す', 'push')]],
    ['p_teach', '後輩への指導', (w, r) => pickOf(r, all(w).filter((p) => p.grade === 3)), (p) => `${p.name}が、高1に止め方を教えている。`, [opt('時間を作ってやる', 'warm', (w) => { for (const q of all(w).filter((x) => x.grade === 1)) { q.prog = q.prog || {}; q.prog.ファーストタッチ = (q.prog.ファーストタッチ || 0) + 0.1; } }), opt('自分の練習を優先させる', 'firm'), opt('見守る', 'wait')]],
    ['p_spy', '偵察', (w, r) => pickOf(r, A(w)), () => `練習場の外に、他クラブのスタッフらしき人が立っている。`, [opt('練習を非公開にする', 'firm'), opt('気にせず続ける', 'wait'), opt('声をかけてみる', 'warm', (w) => { if (YA.addRep) YA.addRep(w, 0); })]],
    ['p_rain', '雨の紅白戦', (w, r) => pickOf(r, A(w)), () => `土砂降りの中の紅白戦。ボールが止まらない。`, [opt('そのまま続ける', 'push', (w) => { for (const q of A(w)) { q.prog = q.prog || {}; q.prog.ファーストタッチ = (q.prog.ファーストタッチ || 0) + 0.1; } }), opt('室内に移る', 'warm'), opt('早めに切り上げる', 'wait')]],
    ['p_longkick', 'ロングキック勝負', (w, r) => pickOf(r, all(w).filter((p) => p.pos === 'DF' || p.pos === 'GK')), (p) => `${p.name}たちが、練習のあとロングキックの飛距離を競っている。`, [opt('一緒に混ざる', 'warm', (w) => { for (const q of all(w)) conf(q, 1); }), opt('狙いの正確さも競わせる', 'push', (w, p) => { p.prog = p.prog || {}; p.prog.パス = (p.prog.パス || 0) + 0.2; }), opt('ほどほどにと言う', 'firm')]],
    ['p_sprint', '走り込み', (w, r) => pickOf(r, all(w).filter((p) => (p.fat || 0) < 50)), (p) => `走り込みで、${p.name}がずっと先頭を走っている。`, [opt('皆の手本だと褒める', 'warm', (w, p) => conf(p, 4)), opt('さらに追い込む', 'push', (w, p) => { p.fat = clamp((p.fat || 0) + 6, 0, 100); }), opt('ペースを守らせる', 'wait')]],
    ['p_tactic', '戦術の確認', (w, r) => pickOf(r, A(w)), (p) => `戦術の確認で、${p.name}が「こっちの方がいい」と意見を言ってきた。`, [opt('試してみる', 'push', (w, p) => conf(p, 4)), opt('理由を説明して戻す', 'warm'), opt('指示に従わせる', 'firm')]],
    ['p_ball', 'ボール磨き', (w, r) => pickOf(r, all(w).filter((p) => p.grade === 1)), (p) => `高1の${p.name}たちが、誰に言われたわけでもなくボールを磨いていた。`, [opt('ありがとうと伝える', 'warm', (w, p) => conf(p, 3)), opt('練習に戻れと言う', 'firm'), opt('黙って見ている', 'wait')]],
    ['p_lefty', '逆足の練習', (w, r) => pickOf(r, all(w).filter((p) => p.grade <= 2)), (p) => `${p.name}が、逆足で何度もボールを蹴っている。うまくいかない。`, [opt('付き合う', 'warm', (w, p) => { p.prog = p.prog || {}; p.prog.テクニック = (p.prog.テクニック || 0) + 0.2; }), opt('得意な足を伸ばせと言う', 'firm'), opt('続けさせる', 'wait')]],
    ['p_minigame', 'ミニゲームの熱', (w, r) => pickOf(r, all(w)), () => `ミニゲームが白熱して、終わりの笛が聞こえないほどだ。`, [opt('延長を許す', 'warm', (w) => { for (const q of all(w)) conf(q, 1); }), opt('時間を守らせる', 'firm'), opt('もう1本だけ', 'push')]],
    ['p_video', '映像を見る', (w, r) => pickOf(r, A(w)), (p) => `${p.name}が、自分の試合の映像を見せてほしいと言ってきた。`, [opt('一緒に見る', 'warm', (w, p) => { p.prog = p.prog || {}; p.prog.判断 = (p.prog.判断 || 0) + 0.2; }), opt('分析担当に任せる', 'push'), opt('今は練習だと言う', 'firm')]],
    ['p_rest', '自主的な休み', (w, r) => pickOf(r, all(w).filter((p) => (p.fat || 0) >= 65)), (p) => `${p.name}が「今日は休ませてください」と言ってきた。疲れているのは確かだ。`, [opt('休ませる', 'warm', (w, p) => { p.rest = 'rest'; }), opt('軽めで参加させる', 'push', (w, p) => { p.rest = 'light'; }), opt('甘えるなと言う', 'firm')]],
    ['p_new', '新入りの壁', (w, r) => pickOf(r, all(w).filter((p) => p.grade === 1)), (p) => `${p.name}が、上級生のスピードについていけず、何度もボールを失っている。`, [opt('高1だけの練習を作る', 'warm', (w) => { for (const q of all(w).filter((x) => x.grade === 1)) conf(q, 2); }), opt('上級生の中に放り込み続ける', 'push', (w, p) => { p.prog = p.prog || {}; p.prog.判断 = (p.prog.判断 || 0) + 0.2; }), opt('見守る', 'wait')]],
    ['p_fans', '練習の見物', (w, r) => pickOf(r, A(w)), () => `練習の見物に、近所の小学生が何人も来ている。`, [opt('サインに応じさせる', 'warm', (w) => { if (YA.addRep) YA.addRep(w, 1); }), opt('一緒にボールを蹴らせる', 'push', (w) => { for (const q of all(w)) conf(q, 1); }), opt('練習に集中させる', 'firm')]],
  ];
  YA.PRACTICE_EVENTS = PE.map((x) => x[0]);
  for (const [id, name, pick, text, opts] of PE) YA.EVENTS.push({ id, name: '練習：' + name, weight: 0.25, pick, text: (p, w) => text(p, w), opts });
  for (const [id] of PE) YA.EVENT_ABOUT[id] = '練習中の小さな出来事です。どう声をかけたかは、その子の記憶に残ります。';
  const quoteOf = (label) => String(label || '').replace(/（[^）]*）/g, '').trim();
  const pset = new Set(YA.PRACTICE_EVENTS);
  const r1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e.pid ? w.players[e.pid] : null;
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const o = def && def.opts && def.opts[idx];
    const out = r1.apply(this, arguments);
    if (p && o && pset.has(e.id) && w.players[p.id] && YA.memAdd) YA.memAdd(w, p, e.id, o.kind, quoteOf(o.label));
    return out;
  };

  // ---------- 練習の成果が試合に出る ----------
  const FOCUS_SCENE = { 攻撃の形: ['through', 'onetwo', 'cross'], セットプレー: ['fk', 'ck', 'longthrow', 'pk'], '1対1': ['dribble'], 走り込み: ['counter'], 判断: ['steal', 'through'], 守備の連係: [] };
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const res = am0.apply(this, arguments);
    try {
      if (which === 'A' && scheduled && w.plan && w.plan.teamFocus && m && m.scenes) {
        const f = w.plan.teamFocus;
        const types = FOCUS_SCENE[f] || [];
        const g = m.scenes.filter((sc) => sc.goal && sc.side === 'home' && types.indexOf(sc.type) >= 0);
        if (g.length) YA.noteTier(w, 2, `練習の成果：重点「${f}」でやった形（${g.map((sc) => sc.typeName).join('・')}）から点が取れた`);
        else if (f === '守備の連係' && m.score && m.score.away === 0) YA.noteTier(w, 2, '練習の成果：重点「守備の連係」の形で、無失点に抑えた');
      }
    } catch (er) { /* 試合の形が違う */ }
    return res;
  };
})();
