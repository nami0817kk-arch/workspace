// 中身の厚み 4段目：スカウト。声をかけると本人と家族に会う場面になり、口説き方を選ぶ。
// 家の型11・口説き方12・会う場面18・地域8・断られ方5・取り合いの相手・取り逃した子が相手の先発に・担当スカウトの見立ての癖・入って分かる事情。
// 口説いたときの約束は、その子の記憶の最初の1件になる（守れたかは入団後に返ってくる）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (n) => String(n).split(' ')[0];

  YA.HOME = {
    pro: { name: 'プロ一直線', note: 'とにかく上を目指せる場所を探している', fit: ['minutes', 'top', 'ten'] },
    free: { name: '放任', note: '本人に任せている', fit: ['honest', 'star'] },
    worry: { name: '心配性', note: '怪我と寮の暮らしを心配している', fit: ['dorm', 'room'] },
    poor: { name: '家計が厳しい', note: 'お金のことを気にしている', fit: ['grant', 'dorm'] },
    grand: { name: '祖父母が決める', note: '祖父母の意見が強い', fit: ['record', 'fan'] },
    self: { name: '本人だけで決める', note: '本人の気持ちしだい', fit: ['star', 'alum'] },
    jhcoach: { name: '中学の監督が強い', note: '中学の監督の言うことを聞く', fit: ['record', 'honest'] },
    busy: { name: '共働きで忙しい', note: '送り迎えや生活の面倒を見られない', fit: ['dorm', 'room'] },
    bro: { name: '兄が別のクラブ', note: '兄と同じクラブを勧められている', fit: ['minutes', 'sibling'] },
    fan: { name: '父がこのクラブのファン', note: '父はもうその気だ', fit: ['fan', 'top'] },
    abroad: { name: '海外に移る予定', note: '数年後に家族で海外へ行くかもしれない', fit: ['honest', 'minutes'] },
  };
  YA.PITCH = {
    minutes: { name: '出場機会を約束する', say: 'すぐに試合に出られるよう、使っていく', promise: '出場機会' },
    record: { name: '育成の実績を見せる', say: 'これまで送り出した卒業生を見てほしい' },
    star: { name: '特に目をかけると約束する', say: 'この子は、こちらが特に見ていく', promise: '目をかける' },
    dorm: { name: '寮と生活の安心を伝える', say: '寮母さんもいるし、生活は任せてほしい' },
    room: { name: '寮の部屋を見せる', say: '一度、寮を見に来てください' },
    grant: { name: '奨学金の話をする', say: '遠征費や寮費は、制度で支えられる' },
    alum: { name: '憧れの卒業生に会わせる', say: 'うちの卒業生に会ってみないか' },
    fan: { name: 'クラブへの思いを語る', say: 'この街のクラブを一緒に強くしたい' },
    sibling: { name: '兄弟も見ると約束する', say: '下の子も、ちゃんと見ていく' },
    top: { name: 'トップの試合に招く', say: '次のトップの試合、招待します' },
    ten: { name: '10番を約束する', say: 'いずれ10番を背負ってほしい', promise: '10番' },
    honest: { name: '弱点を正直に言う', say: '今のままでは通用しない所もある。それも含めて育てたい' },
  };
  const SCENES = ['本人と面談した', '家族と食卓を囲んだ', '中学の監督に会った', '中学の試合を見に行った', '返事を延ばされた', '最後に電話をかけた', '中学の文化祭の日に会った', '祖父母の家に招かれた', '雨の日の練習を見に行った', '怪我で休んでいるところに会いに行った', '他クラブの監督と鉢合わせした', '本人から手紙が届いた', '中学の卒業式のあとに会った', '家族旅行の帰りに会った', '兄弟の試合の会場で会った', '夏祭りの会場で会った', '病院の待合室で会った', 'クラブの試合に招いた'];
  YA.SCOUT_REGIONS = [['北国', '雪国で室内の練習が多く、足元がうまい'], ['港町', '気が強く、競り合いに強い'], ['都市部', '競争に慣れていて、要領がいい'], ['山あい', '体力があり、我慢強い'], ['南国', 'のびのび育ち、ひらめきがある'], ['城下町', '礼儀正しく、まじめ'], ['工業地帯', '粘り強く、仲間思い'], ['郊外', 'バランスがよく、素直']];
  const keysOf = (o) => Object.keys(o);
  YA.candMeta = function (w, c) {
    if (!c.home) {
      const hk = keysOf(YA.HOME);
      c.home = hk[YA.hash(c.id + 'home') % hk.length];
      c.region = YA.hash(c.id + 'rg') % YA.SCOUT_REGIONS.length;
      c.scene = SCENES[YA.hash(c.id + 'sc') % SCENES.length];
    }
    return c;
  };
  // 会う場面で出す口説き方3つ：家に合うもの1つ＋ほか2つ（並びは混ぜる）
  YA.pitchOptions = function (w, c) {
    YA.candMeta(w, c);
    const fit = YA.HOME[c.home].fit;
    const all = keysOf(YA.PITCH);
    const a = fit[YA.hash(c.id + 'f') % fit.length];
    const rest = all.filter((k) => fit.indexOf(k) < 0);
    const b = rest[YA.hash(c.id + 'b') % rest.length];
    const d = rest.filter((k) => k !== b)[YA.hash(c.id + 'd') % (rest.length - 1)];
    const list = [a, b, d];
    return list.sort((x, y) => YA.hash(c.id + x) % 7 - YA.hash(c.id + y) % 7);
  };

  // 声をかけたら、会う場面へ
  const sign0 = YA.signCand;
  YA.signCand = function (w, id) {
    const r = sign0.apply(this, arguments);
    const c = w.scouting && w.scouting.cands.find((x) => x.id === id);
    if (r && r.ok && c && c.kind === 'scout' && c.status === 'offered' && !c.pitch) {
      YA.candMeta(w, c);
      w.forced = (w.forced || []).concat([{ id: 'meet', cid: c.id, pid: null, x: null, week: w.week, year: w.year }]);
      r.msg += '。会う場面で、口説き方を選びます';
    }
    return r;
  };
  YA.EVENTS.push({ id: 'meet', name: '声かけ', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.meet = '声をかけた子と家族に会いました。家の事情に合う口説き方をすると、入団を決めてくれやすくなります。約束したことは、入団後に守れたかが返ってきます。';
  const rivalName = (w) => { try { const r = YA.rivalOf(w); return r ? `${r.coach}監督（${r.club}）` : null; } catch (e) { return null; } };
  function meetPrep(w, e) {
    const c = w.scouting && w.scouting.cands.find((x) => x.id === e.cid);
    const def = YA.EVENTS.find((x) => x.id === 'meet');
    if (!c || !def) return false;
    YA.candMeta(w, c);
    const H = YA.HOME[c.home];
    const rg = YA.SCOUT_REGIONS[c.region];
    const p = c.p;
    const rv = c.rival ? rivalName(w) : null;
    def.name = `声かけ：${p.name}`;
    def.text = () => `${p.name}（${p.pos}・${rg[0]}の子。${rg[1]}）に声をかけ、${c.scene}。家は「${H.name}」――${H.note}。${rv ? `${rv}も、この子を狙っているらしい。` : ''}何と言って口説くか。`;
    def.opts = YA.pitchOptions(w, c).map((k) => ({ label: `${YA.PITCH[k].name}（「${YA.PITCH[k].say}」）`, kind: null, run: (ww) => {
      c.pitch = k;
      c.pitchFit = H.fit.indexOf(k) >= 0 ? 1 : k === 'honest' && c.home !== 'pro' ? 0.3 : -0.3;
      c.persSeen = true;
      const line = c.pitchFit >= 1 ? '家族の表情がやわらいだ。手応えがある。' : c.pitchFit > 0 ? 'うなずいてはくれた。' : '家族は少し考え込んでしまった。';
      return { line, small: '返事は12月に届きます' };
    } }));
    return true;
  }
  const v0 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'meet' && !meetPrep(w, e)) return null; return v0.apply(this, arguments); };
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) { if (e.id === 'meet') meetPrep(w, e); return r0.apply(this, arguments); };
  YA.EXTRA_SIM_IMPORTANT = YA.EXTRA_SIM_IMPORTANT || [];

  // 返事：口説き方が合っていれば決めてくれやすい。断られたら理由が分かる。取り逃した子は相手のクラブへ
  const WHY = { pro: 'もっと条件のいいクラブを選んだ', free: '迷っているうちに、返事の期限が過ぎた', worry: '家族が寮の暮らしを心配して反対した', poor: '他クラブの奨学金の条件がよかった', grand: '祖父母が首を縦に振らなかった', self: '本人が「高校サッカーで全国に出たい」と言った', jhcoach: '中学の監督が別のクラブを勧めた', busy: '家から通えるクラブを選んだ', bro: '兄と同じクラブを選んだ', fan: '最後の電話で、心変わりした', abroad: '家族で海外へ移ることになった' };
  const ro0 = YA.resolveOffers;
  YA.resolveOffers = function (w) {
    const offered = w.scouting.cands.filter((c) => c.status === 'offered');
    const keep = new Map();
    for (const c of offered) { keep.set(c, c.amb); if (c.pitchFit) c.amb = c.amb - c.pitchFit * 10; }
    const r = ro0.apply(this, arguments);
    for (const [c, a] of keep) c.amb = a;
    for (const c of offered) {
      YA.candMeta(w, c);
      if (c.status === 'declined') {
        const to = c.rival ? (YA.rivalOf ? (YA.rivalOf(w) || {}).club : null) : null;
        YA.noteTier(w, 2, `${c.p.name}が断ってきた理由：${c.pitchFit < 0 ? '口説き方が家の気持ちに合わなかった' : WHY[c.home]}`);
        if (to) (w.lostKids = w.lostKids || []).push({ name: c.p.name, pos: c.p.pos, to, y: w.year, pot: c.p.pot });
      } else if (c.status === 'signed' && c.pitch) {
        // 口説いたときの約束を、その子の記憶の最初の1件に
        c.p.mem = (c.p.mem || []).filter((m) => m.k !== 'pitch');
        c.p.mem.unshift({ y: w.year, w: w.week, g: 0, k: 'pitch', c: c.pitch, q: YA.PITCH[c.pitch].say, promise: YA.PITCH[c.pitch].promise || null });
        c.p.homeType = c.home;
      }
    }
    return r;
  };
  // 約束の答え合わせ（入団した年の年度末）
  const gt0 = YA.gradTalks;
  if (gt0) YA.gradTalks = function (w) {
    if (w.week === YA.WEEKS - 1) for (const p of Object.values(w.players)) {
      const m = (p.mem || []).find((x) => x.k === 'pitch' && x.promise && !x.checked);
      if (!m || p.grade !== 1) continue;
      m.checked = true;
      const kept = m.promise === '出場機会' ? (p.minsA || 0) >= 180 : m.promise === '目をかける' ? !!(p.star || p.kEver) : m.promise === '10番' ? true : true;
      m.kept = kept;
      if (YA.addTr) YA.addTr(w, p, kept ? 4 : -6, kept ? '口説いたときの約束を守った' : '口説いたときの約束が守られていない');
      if (!kept) { p.unrest = (p.unrest || 0) + 2; YA.noteTier(w, 1, `${p.name}が「入るとき、${m.promise === '出場機会' ? '試合に出られると言われた' : '目をかけると言われた'}のに」とこぼしている`, p.id); }
    }
    return gt0.apply(this, arguments);
  };
  const SAYP = { 'pitch': (p, m) => (m.kept === false ? `入るときに「${m.q}」と言われたのに、と思ったこともありました。` : `「${m.q}」――あの日、そう言ってもらって、ここに決めました。`) };
  YA.pitchRecall = (p) => { const m = (p.mem || []).find((x) => x.k === 'pitch'); return m ? SAYP.pitch(p, m) : null; };

  // 取り逃した子が、相手の先発に
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.lostKey === key) return res;
    w.lostKey = key;
    try {
      const opp = YA.matchOf && YA.matchOf(w) ? YA.opponentOf(w) : null;
      if (opp) for (const k of w.lostKids || []) {
        if (k.to === opp.name && w.year - k.y >= 1 && w.year - k.y <= 3 && k.seenY !== w.year) {
          k.seenY = w.year;
          YA.noteTier(w, 1, `今週の相手、${opp.name}の先発に、${w.year - k.y}年前に声をかけて逃した${k.name}（${k.pos}）がいる`);
        }
      }
    } catch (er) { /* 日程の無い週 */ }
    return res;
  };

  // 担当スカウトの見立ての癖：好みの型の子は、ランクを一つ高く見る
  const PREFS = [['スピード', ['スピード', '加速']], ['技術', ['テクニック', 'ドリブル']], ['体格', ['強さ', 'ジャンプ']], ['頭脳', ['判断', '視野']]];
  YA.scoutPref = function (w) {
    const s = w.club && w.club.staff.find((x) => x.role === 'スカウト');
    if (!s) return null;
    const pf = PREFS[YA.hash(s.name + 'pref') % PREFS.length];
    return { name: s.name, label: pf[0], abs: pf[1] };
  };
  const RANKS = ['E', 'D', 'C', 'B', 'A', 'S'];
  const cv0 = YA.candView;
  YA.candView = function (w, c) {
    const v = cv0.apply(this, arguments);
    const pf = YA.scoutPref(w);
    if (pf && c.kind === 'scout' && c.seen <= 2) {
      const strong = pf.abs.every((a) => (c.p.ab[a] || 0) >= 11);
      if (strong && v.rank !== 'S') { v.rank = RANKS[RANKS.indexOf(v.rank) + 1]; v.biased = pf.label; }
    }
    YA.candMeta(w, c);
    v.home = c.persSeen ? YA.HOME[c.home].name : null;
    v.region = YA.SCOUT_REGIONS[c.region][0];
    return v;
  };
  const sh0 = YA.scoutHint;
  YA.scoutHint = function (w) {
    const h = sh0.apply(this, arguments);
    const pf = YA.scoutPref(w);
    return h && pf ? `${h}（担当の${sur(pf.name)}は、${pf.label}のある子を高く見る癖がある）` : h;
  };

  // 入って分かる事情：会っていても見えなかった事情が、入団後に分かることがある
  const in0 = YA.intake;
  YA.intake = function (w) {
    const r = in0.apply(this, arguments);
    for (const p of Object.values(w.players)) {
      if (p.grade !== 1 || p.hiddenChecked) continue;
      p.hiddenChecked = true;
      const bg = YA.bgOf ? YA.bgOf(w, p) : null;
      if (bg && (YA.BG_SYS[bg] === '危うい' || bg === 'divorce' || bg === 'carer') && YA.hash(p.id + 'hid') % 3 === 0) {
        p.bgKnow = 2;
        YA.noteTier(w, 2, `入団してから分かった：${p.name}は「${YA.BG_NAME[bg]}」`, p.id);
      }
    }
    return r;
  };
})();
