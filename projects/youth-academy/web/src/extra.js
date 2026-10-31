// おまかせ進行（1週・次の試合・1年。テスト用）、指導者の作成と経歴、最初の1か月の案内、セーブ枠、効果音。
// どれも見せ方に依存しない（画面は views3.js）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- おまかせ進行（決定57：止まる条件を決めて、練習・起用をおまかせで何週も進める）----------
  // 必ず止める出来事（決定76 の①）。おまかせの途中でもここでは止まって、自分で選ぶ
  YA.SIM_IMPORTANT = ['quit', 'injury', 'top', 'nat'];
  // おまかせのときの選び方（出来事ごとの既定。無難な側）
  const AUTO_CHOICE = { rival: 1, late: 1, fight: 1, slack: 1, quit: 0, injury: 0, top: 0, nat: 0 };
  YA.autoChoice = (id) => (AUTO_CHOICE[id] != null ? AUTO_CHOICE[id] : 0);

  // 年度はじめ・成長・契約の画面で出る選択を、既定で済ませる
  YA.autoPrompts = function (w, notes) {
    if (w.pendingContract) {
      const last = w.club.eval[w.club.eval.length - 1];
      const refuse = w.club.trust < 30 || (last && last.letter === 'D');
      if (!refuse) {
        YA.renewContract(w);
        notes && notes.push('契約を更新しました');
      } else {
        const o = w.pendingContract.offers[0];
        YA.moveTo(w, o, '更新されず、移りました。');
        notes && notes.push(`${o.name}に移りました`);
      }
    }
    if (w.pendingCoach) {
      w.coach.teach = Math.min(20, w.coach.teach + 1);
      w.pendingCoach = false;
    }
    if (w.yearIntro) {
      w.rules = YA.RULES.slice(0, 2);
      w.yearIntro = false;
    }
  };
  // スカウト：暦に合わせて、既定の数だけ自動で決める（4〜11月は月3回出て、11月に有望な子へ声をかける／11月に内部昇格／1月にセレクション）
  YA.autoScout = function (w) {
    const S = w.scouting;
    if (!S) return;
    const wn = YA.scoutWindow(w);
    const best = (kind) => S.cands.filter((x) => x.kind === kind && x.status === 'open').sort((a, b) => (YA.ovr(b.p) + (b.p.pot - YA.abSum(b.p)) / 60) - (YA.ovr(a.p) + (a.p.pot - YA.abSum(a.p)) / 60));
    if (wn.scout) {
      for (let i = 0; i < 3 && YA.scoutActsLeft(w) > 0; i++) if (!YA.scoutOut(w, YA.DEST_ORDER[(w.week + i) % 3]).ok) break;
      if (w.week === 27) for (const c of best('scout').slice(0, 3)) YA.signCand(w, c.id);
    }
    if (wn.int) for (const c of best('int').slice(0, 5)) YA.signCand(w, c.id);
    if (wn.sel) {
      if (S.selOpen && !S.testsDone) YA.runSelection(w, ['紅白戦', '面接']);
      for (const c of best('sel').slice(0, 3)) YA.signCand(w, c.id);
    }
  };
  // A戦を自動で回して結果を名簿に戻す
  YA.playAuto = function (w) {
    const home = YA.teamFromWorld(w, 'A');
    const opp = YA.opponentOf(w);
    const away = YA.makeOpponent(opp, w.seed + w.week * 7 + w.year);
    const m = new YA.Match({ seed: w.seed + w.week * 3 + w.year, home, away, settings: { autoStop: false } });
    m.opp = opp;
    m.scheduled = true;
    let g = 0;
    while (!m.finished && g++ < 3000) m.step();
    m.applied = true;
    YA.applyMatch(w, m, 'A', opp, true);
    w.phase = 'after';
    w.matchDone = true;
    return m;
  };

  // 1ステップ進める。戻り値：{ stop?, played?, ended?, grad? }
  function step(w, o, log) {
    const ph = w.phase;
    if (ph === 'plan') {
      // 年度はじめ・契約満了・指導者の成長は、止まる設定なら自分で決める
      if (o.stopOnImportant && (w.pendingContract || w.pendingCoach || w.yearIntro)) return { stop: w.pendingContract ? '契約満了の相談' : w.pendingCoach ? '指導者の成長' : '年度はじめの目標' };
      YA.autoPrompts(w, log.notes);
      YA.autoScout(w);
      if (YA.SCHED(w.week).t === 'camp' && !w.campChoice) {
        const opts = YA.campOptions(w);
        w.campChoice = opts.find((x) => x.k === 'domestic' && x.ok) ? 'domestic' : 'none';
      }
      if (o.autoPlan !== false) YA.autoPlan(w);
      YA.startWeek(w);
      return {};
    }
    if (ph === 'event') {
      for (const e of w.events.slice()) {
        if (o.stopOnImportant && YA.SIM_IMPORTANT.indexOf(e.id) >= 0) return { stop: '出来事（' + (YA.EVENTS.find((x) => x.id === e.id) || {}).name + '）' };
        if (YA.SIM_IMPORTANT.indexOf(e.id) >= 0) log.important++;
        const v = YA.eventView(w, e);
        if (v) {
          const r = YA.resolveEvent(w, e, Math.min(YA.autoChoice(e.id), v.opts.length - 1));
          log.events.push(v.name);
          if (r.leave) log.notes.push(r.leave);
        }
        w.events.shift();
      }
      YA.afterEvents(w);
      return {};
    }
    if (ph === 'match') {
      YA.playAuto(w);
      return { played: true };
    }
    // after
    const wasEnd = w.week >= YA.WEEKS;
    const grad = YA.endWeek(w);
    return { ended: true, grad: wasEnd ? grad : null };
  }

  // おまかせで進める。until: 'week' | 'match' | 'year'
  YA.simulate = function (w, opts) {
    const o = Object.assign({ until: 'week', stopOnImportant: true }, opts || {});
    const before = { year: w.year, week: w.week, rec: Object.assign({}, w.rec), sums: {}, n: w.inboxN || 0, alumni: w.alumni.length, trust: w.club.trust, rep: w.club.rep, total: w.club.total, salaries: w.club.staff.reduce((s, x) => s + x.salary, 0), inboxN: w.inboxN || 0 };
    for (const p of Object.values(w.players)) before.sums[p.id] = YA.abSum(p);
    const log = { events: [], notes: [], weeks: 0, matches: [], grad: null, stopped: null, important: 0, picks: 0 };
    const startYear = w.year;
    let guard = 0;
    let lastN = w.inboxN || 0;
    while (guard++ < 800) {
      const r = step(w, o, log);
      // 設定で「必ず止める」にしたお知らせ（決定76）が出たら止まる
      if (o.stopOnImportant && w.noticeTier && YA.noticeKind) {
        const hit = (w.inbox || []).filter((n) => (n.n || 0) > lastN).find((n) => w.noticeTier[YA.noticeKind(n.text)] === 1);
        lastN = w.inboxN || lastN;
        if (hit) {
          log.stopped = 'お知らせ（' + YA.noticeKind(hit.text) + '）';
          break;
        }
      }
      if (r.stop) {
        log.stopped = r.stop;
        break;
      }
      if (r.played) {
        log.matches.push(w.results[w.results.length - 1]);
        if (o.until === 'match') break;
      }
      if (r.ended) {
        log.weeks++;
        if (r.grad) log.grad = r.grad;
        if (o.until === 'week') break;
        if (o.until === 'year' && w.year !== startYear) {
          // 年度が替わったあとの選択は、止まる設定でなければ済ませる
          if (!o.stopOnImportant) YA.autoPrompts(w, log.notes);
          break;
        }
      }
    }
    return YA.simReport(w, before, log);
  };

  YA.simReport = function (w, before, log) {
    const lines = [];
    const fresh = (w.inbox || []).filter((n) => (n.n || 0) > before.n);
    const span = `${before.year}年目 ${before.week}週 → ${w.year}年目 ${w.week}週（${log.weeks}週）`;
    if (log.stopped) lines.push({ k: 'stop', t: `ここで止まりました：${log.stopped}` });
    const mm = log.matches;
    if (mm.length) {
      const wn = mm.filter((x) => x.gf > x.ga).length;
      const dr = mm.filter((x) => x.gf === x.ga).length;
      lines.push({ k: 'match', t: `Aチーム ${mm.length}試合：${wn}勝${dr}分${mm.length - wn - dr}敗（得点${mm.reduce((s, x) => s + x.gf, 0)}・失点${mm.reduce((s, x) => s + x.ga, 0)}）` });
    }
    if (w.lastStandings && log.grad) {
      const me = w.lastStandings.find((x) => x.me);
      if (me) lines.push({ k: 'league', t: `リーグ最終順位 ${me.rank}位（勝点${me.p}）${w.leagueEndMove < 0 ? '→昇格' : w.leagueEndMove > 0 ? '→降格' : ''}` });
    } else if (w.league) lines.push({ k: 'league', t: `リーグ現在 ${YA.myRank(w)}位` });
    if (log.grad && log.grad.eval) lines.push({ k: 'eval', t: `年末の評価 ${log.grad.eval.letter}（` + log.grad.eval.goals.map((g) => `${g.label}${g.ok ? '○' : g.score ? '△' : '×'}`).join(' ') + '）' });
    if (log.grad) lines.push({ k: 'grad', t: `${log.grad.out.length}人が卒業、新入生${log.grad.entered}人。` + (log.grad.contrib ? `連帯貢献金 ${log.grad.contrib}万円。` : '') + (log.grad.dismissed ? '解任されました。' : '') });
    // 成長
    const gains = [];
    for (const p of Object.values(w.players)) if (before.sums[p.id] != null) gains.push([p, YA.abSum(p) - before.sums[p.id]]);
    gains.sort((a, b) => b[1] - a[1]);
    if (gains.length) lines.push({ k: 'grow', t: `能力の合計の伸び（平均）+${(gains.reduce((s, x) => s + x[1], 0) / gains.length).toFixed(1)}。上位：` + gains.slice(0, 3).map(([p, g]) => `${p.name.split(' ')[0]}+${g}`).join('・') });
    const count = (re) => fresh.filter((n) => re.test(n.text)).length;
    lines.push({ k: 'misc', t: `怪我${count(/怪我/)}件／特性の習得${count(/身につけた/)}件／成長期${count(/成長期に入った/)}件／出来事${log.events.length}件／連帯貢献金など${count(/連帯貢献金/)}件` });
    if (log.events.length) {
      const c = {};
      for (const n of log.events) c[n] = (c[n] || 0) + 1;
      lines.push({ k: 'events', t: '出来事：' + Object.entries(c).map(([k, v]) => `${k}×${v}`).join('、') });
    }
    const big = fresh.filter((n) => n.tier === 1).slice(-6).map((n) => n.text);
    // ---- 指標（テスト・釣り合いの点検用）----
    const tiers = { 1: 0, 2: 0, 3: 0 };
    for (const n of fresh) tiers[n.tier] = (tiers[n.tier] || 0) + 1;
    const salaries = w.club.staff.reduce((s2, x) => s2 + x.salary, 0);
    const quits = w.alumni.slice(before.alumni).filter((a) => a.status === 'left').length;
    const gradPaths = { pro: 0, univ: 0, amateur: 0 };
    const newAl = w.alumni.slice(before.alumni).filter((a) => a.status !== 'left');
    for (const a of newAl) gradPaths[a.status] = (gradPaths[a.status] || 0) + 1;
    const weeksN = Math.max(1, log.weeks);
    // 1週に自分で選ぶ回数の見積もり：練習の確認1・試合前の確認1・出来事・面談の目安1（出来事の選択肢は1回ずつ）
    const picksPerWeek = Math.round((2 + log.events.length / weeksN + 1) * 10) / 10;
    // 1回の選択を約25秒、試合を約2分半とすると、1週の想定の時間（分）
    const minutesPerWeek = Math.round(((picksPerWeek * 25) / 60 + 2.5 * (mm.length / weeksN) + 0.7) * 10) / 10;
    const lastEval = log.grad && log.grad.eval ? log.grad.eval : null;
    const me = w.lastStandings && log.grad ? w.lastStandings.find((x) => x.me) : null;
    const metrics = {
      year: before.year, weeks: log.weeks, matches: mm.length,
      rank: me ? me.rank : null, move: log.grad ? w.leagueEndMove : null, letter: lastEval ? lastEval.letter : null, score: lastEval ? lastEval.score : null,
      trustBefore: Math.round(before.trust), trustAfter: Math.round(w.club.trust), repAfter: Math.round(w.club.rep),
      budget: w.club.total, salaries, budgetBefore: before.total,
      growthAvg: gains.length ? Math.round((gains.reduce((s2, x) => s2 + x[1], 0) / gains.length) * 10) / 10 : 0,
      injuries: count(/怪我/), traits: count(/身につけた/), spurts: count(/成長期に入った/), peaks: count(/伸び盛り/), walls: count(/壁/), declines: count(/能力が下が/),
      quits, gradPaths, noticesByTier: tiers, events: log.events.length, important: log.important, picksPerWeek, minutesPerWeek,
      players: Object.keys(w.players).length, alumni: w.alumni.length, tier: w.club.tier, level: w.league ? w.league.level : null,
    };
    lines.push({ k: 'budget', t: `予算 ${w.club.total}万円（給料${salaries}万円）／信頼度 ${before.trust < w.club.trust ? '↑' : before.trust > w.club.trust ? '↓' : '→'} ${Math.round(before.trust)}→${Math.round(w.club.trust)}／評判 ${Math.round(w.club.rep)}` });
    if (log.grad) lines.push({ k: 'path', t: `卒業生の進路：プロ${gradPaths.pro}・大学${gradPaths.univ}・社会人${gradPaths.amateur}／退団${quits}人` });
    lines.push({ k: 'notice', t: `お知らせ：必ず止まる${tiers[1] || 0}・お知らせ${tiers[2] || 0}・記録だけ${tiers[3] || 0}／必ず止める出来事 ${log.important}回` });
    lines.push({ k: 'time', t: `1週に自分で選ぶ回数の目安 ${picksPerWeek}回 → 想定${minutesPerWeek}分（目標は1週8〜10分）` });
    return { title: 'おまかせ進行の結果', span, lines, big, stopped: log.stopped, weeks: log.weeks, matches: mm.length, metrics };
  };

  // ---------- 指導者の作成（決定50）と、最初のクラブ（決定49）----------
  YA.CAREERS = [
    { k: 'pro', name: '元プロ選手', note: '見る目と話す力に優れる。人脈でクラブの評判が高めから始まる', coach: { eye: 2, talk: 2 }, exp: 0, rep: 8 },
    { k: 'high', name: '高校で指導していた', note: '教える力に優れ、指導の経験がある（B級）。評判は低めから', coach: { teach: 3, talk: 1 }, exp: 3, rep: -4 },
    { k: 'abroad', name: '海外で学んだ', note: '戦術に優れ、B級の資格を持つ。人脈は少ない', coach: { tactic: 3, eye: 1 }, exp: 3, rep: 0 },
    { k: 'grind', name: '叩き上げ', note: '全体にバランスよく、現場を知っている', coach: { teach: 2, tactic: 1, talk: 1, eye: 1 }, exp: 0, rep: 0 },
  ];
  YA.CAREER_POINTS = 6;
  YA.START_CLUBS = [
    { tier: 1, name: '横浜 ブルーウィングU-18', note: '1部。予算が大きく、期待も大きい' },
    { tier: 1, name: '名古屋 シルバーホークU-18', note: '1部。育成に定評がある' },
    { tier: 2, name: '湘南 レガーレU-18', note: '2部。標準的な始まり' },
    { tier: 2, name: '千葉 アルバトロスU-18', note: '2部。堅実なクラブ' },
    { tier: 2, name: '仙台 ノースウィンドU-18', note: '2部。若手を使う方針' },
    { tier: 3, name: '新潟 ミストラルU-18', note: '3部。予算は小さいが、のびのび育てられる' },
    { tier: 3, name: '岡山 クレセントU-18', note: '3部。設備は古い' },
    { tier: 3, name: '福岡 サンライズU-18', note: '3部。地元の期待は静か' },
  ];
  // 画面で選んだ内容から、新しい世界の設定を作る
  YA.makeStart = function (form) {
    const career = YA.CAREERS.find((c) => c.k === form.career) || YA.CAREERS[3];
    const coach = Object.assign(YA.newCoach(), {});
    for (const [k, v] of Object.entries(career.coach)) coach[k] += v;
    for (const [k, v] of Object.entries(form.points || {})) coach[k] = clamp(coach[k] + Math.max(0, v), 1, 20);
    coach.exp = career.exp;
    const club = YA.START_CLUBS[form.club != null ? form.club : 2];
    return { coach, coachName: (form.name || '').trim() || '監督', tier: club.tier, clubName: club.name, noFire: !!form.noFire, repAdj: career.rep, career: career.k };
  };

  // ---------- 最初の1か月の案内（決定77）：状況に合わせた吹き出し ----------
  YA.tutorialText = function (w) {
    if (!w || !w.tut || !w.tut.on || w.year > 1 || w.week > 4) return null;
    if (w.yearIntro) return '最初に、クラブの目標とチームの約束事を決めます。難しい目標は評価が高く出ますが、信頼度が低いと変えられません。';
    const ph = w.phase;
    if (ph === 'plan') return w.week === 1
      ? '① 今週の練習を組みます。「練習」タブで月〜金のメニューを決め、選手ごとの重点を決めます（「おまかせ」でも大丈夫）。決まったら「練習を確定して週を進める」。'
      : '練習を組んで、週を進めましょう。「選手」タブで面談（月1回まで）もできます。';
    if (ph === 'event') return '② 出来事が起きました。選手に言葉をかけて、どう対応するかを選びます。同じ言葉でも、性格で反応が変わります。';
    if (ph === 'match') return '③ 試合です。「試合へ」で布陣・役割・戦い方を決めてキックオフ。試合中は「止める」で交代・指示・声かけができます。見ずに結果だけ見ることもできます。';
    return '④ 結果を見たら「次の週へ」。伸びた能力はホームの「今月の伸び」で分かります。1か月たつと、この案内は自動で消えます。';
  };

  // ---------- セーブ枠（決定78）：無料2枠。書き出し・復元・控え ----------
  YA.SLOT_COUNT = 2;
  YA.slotKey = (i) => (i === 0 ? 'world' : 'world' + i);
  YA.slotSummary = function (w) {
    if (!w || !w.players) return null;
    return `${w.clubName}（${w.year}年目 ${w.week}週）／${w.club ? YA.TIER_NAME[w.club.tier] : ''} ${w.rec ? w.rec.w + '勝' + w.rec.d + '分' + w.rec.l + '敗' : ''}`;
  };
  YA.exportWorld = (w) => JSON.stringify({ app: 'youth-academy', v: w.v, world: w });
  YA.importWorld = function (text) {
    let o;
    try {
      o = JSON.parse(text);
    } catch (e) {
      return { ok: false, msg: '読み取れませんでした（コピーした文字が欠けているかもしれません）' };
    }
    const w = o && o.app === 'youth-academy' ? o.world : null;
    if (!w || !w.players || !w.lineupA || !(w.v >= 3)) return { ok: false, msg: 'このアプリのセーブデータではありません' };
    return { ok: true, world: w };
  };

  // ---------- 効果音（音源ファイルなし。ブラウザで鳴らす短い音）----------
  YA.sfx = {
    on: true,
    ctx: null,
    play(kind) {
      if (!this.on) return;
      try {
        const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
        if (!AC) return;
        this.ctx = this.ctx || new AC();
        const c = this.ctx;
        if (c.state === 'suspended') c.resume();
        const now = c.currentTime;
        const tone = (f, t0, d, type, vol) => {
          const o = c.createOscillator();
          const g = c.createGain();
          o.type = type || 'sine';
          o.frequency.value = f;
          g.gain.setValueAtTime(vol || 0.08, now + t0);
          g.gain.exponentialRampToValueAtTime(0.0001, now + t0 + d);
          o.connect(g);
          g.connect(c.destination);
          o.start(now + t0);
          o.stop(now + t0 + d + 0.02);
        };
        if (kind === 'tap') tone(520, 0, 0.05, 'triangle', 0.035);
        else if (kind === 'goal') [523, 659, 784, 1046].forEach((f, i) => tone(f, i * 0.11, 0.26, 'triangle', 0.1));
        else if (kind === 'concede') [392, 330, 262].forEach((f, i) => tone(f, i * 0.15, 0.3, 'sawtooth', 0.05));
        else if (kind === 'whistle') {
          tone(2200, 0, 0.22, 'sine', 0.06);
          tone(2000, 0.26, 0.34, 'sine', 0.06);
        } else if (kind === 'save') tone(300, 0, 0.12, 'square', 0.05);
        else if (kind === 'miss') tone(190, 0, 0.2, 'sawtooth', 0.04);
      } catch (e) {}
    },
  };
})();

// ---------- 追加の出来事：外国籍の適応・飛び級（U-15）----------
(function () {
  'use strict';
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const E = YA.EVENTS;
  const pname = (p) => p.num + '番 ' + p.name;
  E.push({
    id: 'adapt', name: '外国籍の選手の適応', weight: 0.8,
    pick: (w, r) => {
      const c = Object.values(w.players).filter((p) => YA.isForeign(p) && (p.adaptF || 0) < 3);
      return c.length ? r.pick(c) : null;
    },
    text: (p) => `${pname(p)}（${p.nation}出身）が、言葉や食事、生活の違いに戸惑っている。チームメイトとも、まだ打ち解けきれていない`,
    opts: [
      { label: '通訳や寮の世話役をつけて、生活を支える', kind: 'warm', extra: (w, p) => { p.adaptF = (p.adaptF || 0) + 1.5; p.unrest = Math.max(0, p.unrest - 1); } },
      { label: '日本語の勉強を促し、練習で仲間と組ませる', kind: 'push', extra: (w, p) => { p.adaptF = (p.adaptF || 0) + 1; p.spurt = Math.max(p.spurt, 2); } },
      { label: '本人に任せて、様子を見る', kind: 'wait', extra: (w, p) => { p.unrest += 1; } },
    ],
  });
  E.push({
    id: 'jump', name: '飛び級の打診（U-15）', weight: 0.5, club: true,
    pick: (w, r) => (w.week >= 5 && w.week <= 30 ? { id: '', _club: 0 } : null),
    text: (p, w) => 'U-15の指導者から相談が届いた。「中3のエースを、高1のチームで鍛えてもらえないか。飛び級は伸びるが、体への負担と怪我のおそれがある」',
    opts: [
      {
        label: '受け入れる（Bチームに加わる。伸びるが怪我に注意）', kind: 'push', extra: null,
        run: (w, p, r) => {
          const used = new Set(Object.values(w.players).map((q) => q.name));
          const pos = r.pick(['CB', 'DM', 'CM', 'AM', 'LW', 'RW', 'ST']);
          const id = 'p' + ++w.nextId;
          const n = YA.genPlayer(r, id, 1, pos, 2.2, used);
          n.team = 'B';
          n.jump = true;
          n.pot += 25;
          n.rate = Math.min(1.5, n.rate + 0.25);
          n.fat = 35;
          n.hist = [{ y: w.year, w: w.week, t: 'U-15から飛び級で加わった' }];
          w.players[id] = n;
          YA._numbers(w);
          w.benchB = (w.benchB || []).concat([id]).slice(0, 12);
          YA.addTrust(w, 1, 'U-15との協力');
          return { line: `${n.name}（${YA.POS_LABEL[n.main]}）がBチームに加わった。伸びしろは大きいが、体の負担に気をつけたい`, small: '新しい選手が1人加わる' };
        },
      },
      {
        label: '断る（まだ早いと伝える）', kind: 'firm', extra: null,
        run: (w) => { YA.addTrust(w, -2, 'U-15の飛び級の打診を断った'); return { line: 'U-15の指導者は、残念そうに引き下がった', small: '信頼度 -2' }; },
      },
    ],
  });
  // 外国籍の選手が慣れるまでの間は力が落ちる（適応が進むと和らぐ）：毎週の処理で進める
  const wk = YA.weekExtras;
  YA.weekExtras = function (w) {
    wk(w);
    for (const p of Object.values(w.players)) {
      if (YA.isForeign(p)) {
        p.adaptF = Math.min(6, (p.adaptF || 0) + 0.1);
        p.adapt = Math.max(p.adapt || 0, p.adaptF < 3 ? 1 : 0);
      }
    }
  };
})();

// ---------- 点検用：新しい世界でNか年おまかせ（シード指定で同じ結果になる）----------
(function () {
  'use strict';
  const YA = globalThis.YA;
  const CLUB_BY_TIER = { 1: 0, 2: 2, 3: 5 };
  // 1年ずつ進められる形（画面を固めないために、呼び出し側が間に待ちを入れられる）
  YA.testStart = function (opts) {
    const o = Object.assign({ seed: 1, years: 1, tier: 2, career: 'grind' }, opts || {});
    const w = YA.newWorld(o.seed, YA.makeStart({ name: '点検', career: o.career, club: CLUB_BY_TIER[o.tier] != null ? CLUB_BY_TIER[o.tier] : 2, points: {}, noFire: !!o.noFire }));
    w.yearIntro = false;
    return { w, o, years: [], done: 0 };
  };
  YA.testYear = function (st) {
    const rep = YA.simulate(st.w, { until: 'year', stopOnImportant: false });
    st.years.push(rep);
    st.done++;
    return rep;
  };
  YA.testSummary = function (st) {
    const ms = st.years.map((r) => r.metrics);
    const avg = (f) => (ms.length ? Math.round((ms.reduce((a, m) => a + f(m), 0) / ms.length) * 10) / 10 : 0);
    const letters = {};
    for (const m of ms) letters[m.letter] = (letters[m.letter] || 0) + 1;
    return {
      years: ms.length,
      avgRank: avg((m) => m.rank || 0), letters,
      growthAvg: avg((m) => m.growthAvg), injuries: avg((m) => m.injuries), quits: avg((m) => m.quits),
      pro: avg((m) => m.gradPaths.pro), picks: avg((m) => m.picksPerWeek), minutes: avg((m) => m.minutesPerWeek),
      budget: avg((m) => m.budget), players: ms.length ? ms[ms.length - 1].players : 0,
    };
  };
  YA.runTest = function (opts) {
    const st = YA.testStart(opts);
    for (let i = 0; i < st.o.years; i++) YA.testYear(st);
    st.summary = YA.testSummary(st);
    return st;
  };
  // 数字の異常（NaN・無限大）を探す。見つかったら場所を返す
  YA.findBadNumber = function (obj, path, depth) {
    path = path || 'w';
    depth = depth || 0;
    if (depth > 8) return null;
    if (typeof obj === 'number') return Number.isFinite(obj) ? null : path;
    if (!obj || typeof obj !== 'object') return null;
    for (const k of Object.keys(obj)) {
      const r = YA.findBadNumber(obj[k], path + '.' + k, depth + 1);
      if (r) return r;
    }
    return null;
  };
})();
