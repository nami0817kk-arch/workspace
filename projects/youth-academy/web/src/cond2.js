// 選手を構成する要素 段階5「状態」（2026-11-19 ⑧）
// ・怪我の部位と重さ（p.injPart・p.injSev）・ぶり返し（戻ってから6週は同じ所を痛めやすい）
// ・成長痛（背が急に伸びた子。伸びが鈍り、怪我をしやすい）
// ・心の状態（p.mind：スランプ・燃え尽き・ホームシック・プレッシャー）。面談や休みで抜ける
// ・8週のグラフ（自信・疲れ・試合の採点。p.wk8）
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const rngW = (w, p, salt) => YA.rngOf(YA.hash(String(p.id) + '|' + salt) + (w.seed | 0) * 7 + w.year * 401 + w.week * 13);

  // ---------- 怪我 ----------
  YA.INJ_PARTS = [['足首', 3], ['ハムストリング', 2.5], ['太もも', 2], ['膝', 1.6], ['ふくらはぎ', 1.5], ['腰', 1.2], ['鼠径部', 1], ['肩', 0.6], ['足の甲', 0.8], ['頭', 0.3]];
  YA.injSevName = (n) => (n >= 8 ? '重傷' : n >= 3 ? '中程度' : '軽傷');
  YA.RELAPSE_WEEKS = 6;
  YA.RELAPSE_K = 1.6; // 2 だと怪我が年30件を超えた（tool/balance.js）
  function scanInj(w) {
    for (const p of all(w)) {
      if (p.inj > 0 && !p.injPart) {
        const r = rngW(w, p, 'part');
        const re = p.relapseW > 0 && p.lastPart && r() < 0.6;
        p.injPart = re ? p.lastPart : r.weighted(YA.INJ_PARTS, (x) => x[1])[0];
        if (re) p.inj += r.int(1, 2);
        p.injSev = YA.injSevName(p.inj);
        p.injRe = !!re;
        p.injLog = (p.injLog || []).concat([{ y: w.year, w: w.week, part: p.injPart, sev: p.injSev, n: p.inj, re: !!re }]).slice(-12);
        if (p.hist && p.hist[0] && /怪我/.test(p.hist[0].t) && p.hist[0].y === w.year && p.hist[0].w === w.week) p.hist[0].t += `・${p.injPart}（${p.injSev}）${re ? '・再発' : ''}`;
        if (re && YA.noteTier) YA.noteTier(w, 1, `${p.num}番 ${p.name}：${p.injPart}の怪我が再発した（全治${p.inj}週）`, p.id);
      } else if (!(p.inj > 0) && p.injPart) {
        p.lastPart = p.injPart;
        p.relapseW = p.injSev === '軽傷' ? 3 : YA.RELAPSE_WEEKS;
        p.injPart = null;
        p.injSev = null;
      }
    }
  }
  YA.scanInj = scanInj;
  const ik0 = YA.injK || (() => 1);
  YA.injK = function (p) {
    return ik0(p) * (p.relapseW > 0 ? YA.RELAPSE_K : 1) * (p.gpain > 0 ? 1.15 : 1) * (p.mind && p.mind.k === 'burnout' ? 1.15 : 1);
  };

  // ---------- 心の状態 ----------
  YA.MIND = {
    slump: { name: 'スランプ', grow: 0.9, conf: -1.5, unrest: 0, about: '試合でうまくいかない日が続いている。いい試合をするか、褒めると抜けやすい' },
    burnout: { name: '燃え尽き', grow: 0.75, conf: -1, unrest: 0.25, about: '疲れが溜まりすぎて、気持ちが切れかけている。休ませると抜けやすい' },
    homesick: { name: 'ホームシック', grow: 0.9, conf: -1.5, unrest: 0.2, about: '家が恋しくなっている。悩みを聞くと抜けやすい' },
    pressure: { name: 'プレッシャー', grow: 1, conf: -1, unrest: 0, about: '期待の重さを感じている。大事な試合で硬くなる。背中を押すと抜けやすい' },
  };
  function setMind(w, p, k, weeks) {
    if (p.mind) return;
    p.mind = { k, w: weeks, y: w.year, s: w.week };
    p.mindLog = (p.mindLog || []).concat([{ y: w.year, w: w.week, k }]).slice(-10);
    const ft = `${p.num}番 ${p.name}が${YA.MIND[k].name}に陥っている。${YA.MIND[k].about}`;
    if (YA.noteMinor) YA.noteMinor(w, p, `${p.num}番 ${String(p.name).split(' ')[0]}が${YA.MIND[k].name}に陥った`, ft, p.star ? 1 : 2);
    else if (YA.noteTier) YA.noteTier(w, p.star ? 1 : 2, ft, p.id);
    if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: YA.MIND[k].name });
  }
  function endMind(w, p, why) {
    if (!p.mind) return;
    const k = p.mind.k;
    p.mind = null;
    p.mindCool = 10; // 抜けてから10週は次の心の状態に陥らない
    const mt = `${p.name}の${YA.MIND[k].name}が抜けた${why ? '（' + why + '）' : ''}`;
    if (YA.noteMinor) YA.noteMinor(w, p, `${p.num}番 ${String(p.name).split(' ')[0]}の${YA.MIND[k].name}が抜けた`, mt, 3);
    else if (YA.noteTier) YA.noteTier(w, 3, mt, p.id);
  }
  YA.setMind = setMind;
  YA.endMind = endMind;
  // 大一番で硬くなる（body.js の bigGameMod に足す）
  const bg0 = YA.bigGameMod || (() => 0);
  YA.bigGameMod = function (p, close, big) {
    return bg0(p, close, big) - (p.mind && p.mind.k === 'pressure' && (close || big) ? 1 : 0);
  };
  // 伸び
  const gk0 = YA.growK || (() => 1);
  YA.growK = function (p) {
    return gk0(p) * (p.gpain > 0 ? 0.85 : 1) * (p.mind ? YA.MIND[p.mind.k].grow : 1);
  };
  // 面談で抜けやすい
  const tk0 = YA.talk;
  YA.talk = function (w, pid, k) {
    const res = tk0.apply(this, arguments);
    const p = w.players[pid];
    if (!p || !p.mind || (res && res.ok === false)) return res;
    const fit = { slump: ['praise', 'push'], burnout: ['listen'], homesick: ['listen'], pressure: ['push', 'listen'] }[p.mind.k];
    if (fit.indexOf(k) >= 0) { p.mind.w -= 3; if (p.mind.w <= 0) endMind(w, p, '面談で'); } else p.mind.w -= 1;
    return res;
  };

  // ---------- 毎週 ----------
  const st0 = YA.startWeek;
  YA.startWeek = function (w) { const r = st0.apply(this, arguments); scanInj(w); return r; };
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which) {
    const res = am0.apply(this, arguments);
    scanInj(w);
    try {
      for (const [id, mp] of Object.entries((m && m.home && m.home.players) || {})) {
        const p = w.players[id];
        if (!p || !mp.st || !(mp.st.minutes > 0)) continue;
        p._wkR = Math.round(mp.st.rating * 10) / 10;
        if (p.mind && p.mind.k === 'slump' && mp.st.rating >= 7) endMind(w, p, 'いい試合をして');
      }
    } catch (e) { /* 形の違う試合 */ }
    return res;
  };
  const rv0 = YA.resolveEvent;
  YA.resolveEvent = function (w) { const r = rv0.apply(this, arguments); scanInj(w); return r; };
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    scanInj(w);
    const res = ew0.apply(this, arguments);
    scanInj(w);
    for (const p of all(w)) {
      const r = rngW(w, p, 'mind');
      if (p.relapseW > 0) p.relapseW--;
      // 成長痛：4週で2cm以上伸びた高1・高2
      p.hH = (p.hH || []).concat([p.height]).slice(-5);
      if (p.gpain > 0) { p.gpain--; if (!p.gpain && YA.noteMinor) YA.noteMinor(w, p, `${p.num}番 ${String(p.name).split(' ')[0]}の成長痛がおさまった`, `${p.name}の成長痛がおさまった`, 3); }
      else if (p.grade <= 2 && p.hH.length >= 5 && p.hH[4] - p.hH[0] >= 2 && r() < 0.3) {
        p.gpain = r.int(3, 6);
        if (YA.noteMinor) YA.noteMinor(w, p, `${p.num}番 ${String(p.name).split(' ')[0]}が成長痛`, `${p.num}番 ${p.name}が成長痛を訴えている（背が伸びている時期。${p.gpain}週ほど伸びが鈍り、体を痛めやすい）`);
        if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: '成長痛' });
      }
      // 心の状態
      if (p.mind) {
        const M = YA.MIND[p.mind.k];
        p.conf = clamp(p.conf + M.conf, 0, 100);
        p.unrest = (p.unrest || 0) + M.unrest;
        p.mind.w -= p.mind.k === 'burnout' && p.rest === 'rest' ? 2 : 1;
        if (p.mind.w <= 0) endMind(w, p, '');
      } else if (p.mindCool > 0) p.mindCool--;
      else if (!(p.inj > 0) && !(p.away > 0)) {
        const rl = (p.rl || []).slice(-3);
        p._hiFat = p.fat >= 75 ? (p._hiFat || 0) + 1 : 0;
        const pro = p.hid ? p.hid['プロ意識'] || 10 : 10;
        const adapt = p.hid ? p.hid['適応力'] || 10 : 10;
        const big = p.hid ? p.hid['大一番の強さ'] || 10 : 10;
        const lonely = p.pers && (p.pers['目指すもの'] === '寂しがり' || p.pers['目指すもの'] === '家族思い');
        // スランプは A の試合で3つ続けて悪いとき（B の採点は数えない）
        const rlA = (p.rl || []).filter((x) => x.t === 'A').slice(-3);
        if (rlA.length >= 3 && rlA.every((x) => x.r < 5.9) && rlA[2].y === w.year && w.week - rlA[2].w <= 2 && r() < 0.35) setMind(w, p, 'slump', r.int(4, 7));
        else if (p._hiFat >= (pro >= 15 ? 4 : 5) && r() < 0.3) setMind(w, p, 'burnout', r.int(3, 6));
        else if (p.grade === 1 && p.dorm !== false && w.week <= 16 && p.homeY !== w.year && r() < (0.02 + (p.far ? 0.03 : 0) + (adapt <= 8 ? 0.02 : 0) + (lonely ? 0.04 : 0))) { p.homeY = w.year; setMind(w, p, 'homesick', r.int(3, 5)); }
        else if ((p.star || w.captain === p.id || (YA.isBigWeek && YA.isBigWeek(w.week + 1))) && big <= 9 && r() < 0.02 + (YA.isBigWeek && YA.isBigWeek(w.week + 1) ? 0.08 : 0)) setMind(w, p, 'pressure', r.int(2, 4));
      }
      // 8週のグラフ
      p.wk8 = (p.wk8 || []).concat([{ y: w.year, w: w.week, c: Math.round(p.conf), f: Math.round(p.fat), r: p._wkR != null ? p._wkR : null, i: p.inj > 0 ? 1 : 0, m: p.mind ? p.mind.k : null }]).slice(-8);
      p._wkR = null;
    }
    return res;
  };

  // ---------- 見せ方 ----------
  const sw0 = YA.stateWords;
  if (sw0) {
    YA.stateWords = function (p) {
      let out = sw0.apply(this, arguments);
      if (p.inj > 0 && p.injPart) out = out.map(([t, k]) => (/^怪我/.test(t) ? [`怪我：${p.injPart}（${p.injSev}${p.injRe ? '・再発' : ''}）あと${p.inj}週`, k] : [t, k]));
      if (!(p.inj > 0) && p.relapseW > 0) out.push([`${p.lastPart || '古傷'}が再発しやすい（あと${p.relapseW}週）`, 'bad']);
      if (p.gpain > 0) out.push([`成長痛（あと${p.gpain}週）`, 'bad']);
      if (p.mind) out.push([`${YA.MIND[p.mind.k].name}`, 'bad']);
      return out;
    };
  }
  YA.wk8El = function (p, doc) {
    const xs = p.wk8 || [];
    if (xs.length < 2) return null;
    const NS = 'http://www.w3.org/2000/svg';
    const s = (tag, at, txt) => { const e = doc.createElementNS(NS, tag); for (const k in at) e.setAttribute(k, at[k]); if (txt != null) e.textContent = txt; return e; };
    const W = 160, H = 46, n = 8;
    const svg = s('svg', { viewBox: `0 0 ${W} ${H + 10}`, class: 'wk8', width: '100%', style: 'max-width:320px;display:block;margin-top:3px' });
    svg.append(s('rect', { x: 0, y: 0, width: W, height: H, fill: '#f5f8fd', rx: 3 }));
    const X = (i) => 6 + (i + (n - xs.length)) * ((W - 12) / (n - 1));
    const Y = (v) => H - 3 - (v / 100) * (H - 6);
    const line = (key, col) => svg.append(s('polyline', { points: xs.map((x, i) => `${X(i).toFixed(1)},${Y(x[key]).toFixed(1)}`).join(' '), fill: 'none', stroke: col, 'stroke-width': 1.6 }));
    xs.forEach((x, i) => { if (x.i || x.m) svg.append(s('rect', { x: X(i) - 6, y: 0, width: 12, height: H, fill: x.i ? 'rgba(214,58,58,.12)' : 'rgba(160,112,216,.12)' })); });
    line('c', '#1a9d57');
    line('f', '#f0a020');
    xs.forEach((x, i) => { if (x.r != null) svg.append(s('circle', { cx: X(i), cy: Y(clamp((x.r - 4) / 5, 0, 1) * 100), r: 2.2, fill: '#1f6feb' })); });
    svg.append(s('text', { x: 2, y: H + 8, 'font-size': 6.5, fill: '#4a5a72' }, '8週：緑＝自信 橙＝疲れ 青＝採点 赤＝怪我 紫＝心'));
    return svg;
  };
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        const sec = Array.from(el.querySelectorAll('.ovsec')).find((s) => s.querySelector('.ovh') && s.querySelector('.ovh').textContent === '状態');
        if (sec) {
          if (p.mind) { const d = doc.createElement('div'); d.className = 'ovinfo'; d.style.cssText = 'font-size:11.5px;color:#5a2a8a'; d.textContent = `${YA.MIND[p.mind.k].name}：${YA.MIND[p.mind.k].about}`; sec.append(d); }
          const g = YA.wk8El(p, doc);
          if (g) sec.append(g);
        }
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
