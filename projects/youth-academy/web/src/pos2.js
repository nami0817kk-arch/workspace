// 選手を構成する要素 段階2「ポジション」（2026-11-19 ④）
// ・どこかしらのポジションは必ず20（本当に向いているポジション。data.js の aptOf）。約1割は20が2つ、まれに3つ（p.p20）
// ・得意な役割（p.favRole。engine の roleFit で「合う」扱い）
// ・左右の得手（p.sideP。aptOf で得意な側 +0.8・逆 -0.8）
// ・出た試合で適性が育つ（p.aptX。17 まで。適応力で速さが変わる）
// ・本当に向いているポジションの気づき方を増やす（その位置で試合に出る・コーチの月の見立て・本人の申し出）
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const rngP = (p, salt) => YA.rngOf(YA.hash(String(p.id) + '|' + p.name + '|' + salt));
  const L = (q) => (YA.POS_LABEL && YA.POS_LABEL[q]) || q;

  YA.P20_TWO = 0.1; // 20が2つの子の割合
  YA.P20_THREE = 0.015; // 20が3つの子の割合
  YA.APT_MATCH = 0.08; // 90分出たときの適性の伸び（17まで）

  function bestOf(p) { return p.pos === 'GK' ? 'GK' : p.best && p.best !== 'GK' ? p.best : p.main; }
  // 能力の重みから、役割の合い方
  function roleScore(p, role) {
    const rd = YA.ROLE_DEF[role];
    if (!rd) return 0;
    let sw = 0, sv = 0;
    for (const [n, k] of Object.entries(rd.absW)) { sw += k; sv += k * ((p.ab && p.ab[n]) || 8); }
    return (sw ? sv / sw : 8) + (rd.traits || []).filter((t) => (p.traits || []).indexOf(t) >= 0).length * 0.8;
  }
  YA.posInit = function (p) {
    if (p.pz) return p;
    const r = rngP(p, 'pos2');
    const best = bestOf(p);
    // 20が2つ・3つ（GK は1つだけ）
    p.p20 = [];
    if (p.pos !== 'GK') {
      const x = r();
      const n = x < YA.P20_THREE ? 2 : x < YA.P20_TWO ? 1 : 0;
      const near = (p.subs || []).concat(YA.NEAR_POS[best] || []).filter((q, i, a) => q !== best && q !== 'GK' && a.indexOf(q) === i);
      for (let k = 0; k < n && near.length; k++) p.p20.push(near.splice(Math.floor(r() * near.length), 1)[0]);
    }
    // 左右の得手：利き足の側が7割、逆（中へ切れ込む型）が3割。両足の子は半分が無し
    if (p.pos !== 'GK') {
      const f = p.foot;
      const y = r();
      p.sideP = f === 'B' ? (y < 0.5 ? null : y < 0.75 ? 'L' : 'R') : f === 'L' ? (y < 0.7 ? 'L' : 'R') : (y < 0.7 ? 'R' : 'L');
    } else p.sideP = null;
    // 得意な役割：本当に向いているポジションの役割のうち、能力に合う上位2つから
    const roles = (YA.ROLES15[best] || []).slice().sort((a, b) => roleScore(p, b) - roleScore(p, a));
    p.favRole = roles.length ? roles[r() < 0.7 ? 0 : Math.min(1, roles.length - 1)] : null;
    p.aptX = p.aptX || {};
    p.pz = 1;
    YA.refreshApt(p);
    return p;
  };
  YA.ensurePos = function (w) { for (const p of all(w)) if (!p.pz && p.apt) YA.posInit(p); };

  const gp0 = YA.genPlayer;
  YA.genPlayer = function () { return YA.posInit(gp0.apply(this, arguments)); };
  const nw0 = YA.newWorld;
  YA.newWorld = function () { const w = nw0.apply(this, arguments); YA.ensurePos(w); return w; };

  YA.sideWord = (p) => (p.sideP === 'L' ? '左サイドが得意' : p.sideP === 'R' ? '右サイドが得意' : '左右どちらでもこなす');
  // 20 のポジション（分かっているものだけ）
  YA.pos20Known = function (p) {
    const best = bestOf(p);
    const out = [];
    if (p.pos === 'GK' || p.bestKnown || p.main === best) out.push(best);
    for (const q of p.p20 || []) if (p.main === q || (p.subs || []).indexOf(q) >= 0 || p.bestKnown) out.push(q);
    return out.filter((q, i, a) => a.indexOf(q) === i);
  };

  // 気づく：本当に向いているポジションが分かる
  function notice(w, p, how) {
    if (p.bestKnown || p.pos === 'GK') return false;
    const best = bestOf(p);
    p.bestKnown = true;
    if (best === p.main) return true; // 登録がもう本職
    YA.noteTier(w, 1, `${p.num}番 ${p.name}：${how}。${L(best)}が本当に向いているポジションのようです（いまは${L(p.main)}）`, p.id);
    if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: `向いているポジションは${L(best)}と分かった` });
    return true;
  }
  YA.posNotice = notice;

  // 試合：出た位置の適性が育つ・本職の位置で出ると気づきやすい
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const res = am0.apply(this, arguments);
    try {
      const t = m && m.home;
      if (!t || !t.lineup || !t.players) return res;
      t.lineup.forEach((s, i) => {
        const p = w.players[s.pid];
        const mp = t.players[s.pid];
        const mins = mp && mp.st ? mp.st.minutes || 0 : 0;
        if (!p || mins <= 0 || p.pos === 'GK') return;
        const q = YA.pos15OfSlot ? YA.pos15OfSlot(s, i) : null;
        if (!q || q === 'GK') return;
        if ((p.apt[q] || 0) < 17) {
          p.aptX = p.aptX || {};
          p.aptX[q] = (p.aptX[q] || 0) + YA.APT_MATCH * Math.min(1, mins / 90) * (YA.adaptK ? YA.adaptK(p) : 1);
          YA.refreshApt(p);
        }
        if (!p.bestKnown && q === bestOf(p) && q !== p.main && mins >= 45) {
          const r = YA.rngOf(YA.hash(p.id + 'pm') + w.year * 97 + w.week);
          if (r() < 0.35 + (mp.st.rating >= 7 ? 0.3 : 0)) notice(w, p, `${L(q)}で出た試合で、動きが見違えた`);
        }
      });
    } catch (e) { /* 形の違う試合 */ }
    return res;
  };

  // 毎週：月のはじめにコーチの見立て・本人の申し出。慣れの速さに適応力を効かせる
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    YA.ensurePos(w);
    const res = ew0.apply(this, arguments);
    const r = YA.rngOf((w.seed | 0) * 13 + w.year * 401 + w.week * 7 + 5);
    const first = YA.calendar && YA.calendar(w.week).nth === 1;
    let told = false;
    for (const p of all(w)) {
      if (p.adapt > 0 && YA.adaptK) {
        const k = YA.adaptK(p);
        if (k > 1 && r() < k - 1) p.adapt = Math.max(0, p.adapt - 1);
        else if (k < 0.9 && r() < (0.9 - k) * 1.5 && p.adapt < 14) p.adapt += 1;
      }
      if (told || !first || p.bestKnown || p.pos === 'GK' || bestOf(p) === p.main || (w.year === 1 && w.week <= 5)) continue;
      const eye = w.coach ? w.coach.eye || 10 : 10;
      if (r() < 0.035 * (eye / 10)) told = notice(w, p, 'コーチ陣の見立てで');
      else if (r() < 0.02 && p.pers && (p.pers['プレーの気質'] === '自信家' || p.pers['目指すもの'] === '野心家' || p.pers['教えの受け止め方'] === '反骨心')) told = notice(w, p, `本人が「${L(bestOf(p))}をやらせてほしい」と申し出てきた`);
    }
    return res;
  };

  // 概要のポジションの欄に、得意な役割・左右・20の位置を足す
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      YA.ensurePos(w);
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        const sec = Array.from(el.querySelectorAll('.ovsec')).find((s) => s.querySelector('.ovh') && s.querySelector('.ovh').textContent === 'ポジション');
        if (sec) {
          const d = doc.createElement('div');
          d.className = 'ovinfo pos2';
          const k20 = YA.pos20Known(p);
          d.textContent = [p.favRole && p.bestKnown !== false ? `得意な役割：${p.favRole}` : null, p.pos === 'GK' ? null : YA.sideWord(p), k20.length ? `適性20：${k20.map(L).join('・')}` : '適性20の位置：まだ分からない'].filter(Boolean).join('　');
          sec.append(d);
        }
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
