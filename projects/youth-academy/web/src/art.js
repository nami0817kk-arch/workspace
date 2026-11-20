// 絵の割り当て：選手の顔・クラブのエンブレム・タイトル背景。素材は imgdata.js（tool/art/build_assets.py が作る）
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const IMG = () => YA.IMG || { faces: [], emblems: [], title: '' };
  const img = (src, cls, px, alt) => {
    const e = document.createElement('img');
    e.src = src;
    e.className = cls;
    e.width = px;
    e.height = px;
    e.alt = alt || '';
    e.draggable = false;
    return e;
  };
  // 選手の顔：名前から決めて p.face に残す。名簿のなかでは重ならず、入団の候補ともなるべく重ならない
  YA.faceSrc = function (w, p) {
    const F = IMG().faces;
    if (!F.length || !p) return null;
    const N = F.length * 2; // 左右反転でもう1組
    if (p.face == null || p.face >= N) {
      // 同じ絵の反転も「同じ顔」として避ける（k と k＋枚数）
      const base = (k) => k % F.length;
      const roster = new Set();
      const cands = new Set();
      if (w) for (const q of Object.values(w.players)) if (q.face != null && q !== p) roster.add(base(q.face));
      if (w && w.scouting) for (const c of w.scouting.cands) if (c.p !== p && c.p.face != null && c.status !== 'passed' && c.status !== 'declined') cands.add(base(c.p.face));
      const start = YA.hash(p.name || String(p.id)) % N;
      const probe = (bad) => {
        for (let i = 0; i < N; i++) { const k = (start + i) % N; if (!bad(k)) return k; }
        return -1;
      };
      // まず絵ごと重ならないように。足りなければ反転で別の顔に見せる
      let k = probe((x) => roster.has(base(x)) || cands.has(base(x)));
      if (k < 0) k = probe((x) => roster.has(base(x)));
      if (k < 0) {
        const used = new Set();
        if (w) for (const q of Object.values(w.players)) if (q.face != null && q !== p) used.add(q.face);
        k = probe((x) => used.has(x));
      }
      p.face = k < 0 ? start : k;
    }
    return F[p.face % F.length];
  };
  // ユニフォーム：クラブ名から決まる（愛称に色の言葉があればその色）。シャツ・パンツ・ソックス・差し色・GK
  const KITS = [
    { k: 'blue', shirt: '#1f5fd1', shorts: '#ffffff', socks: '#1f5fd1', acc: '#ffffff' },
    { k: 'red', shirt: '#c8102e', shorts: '#ffffff', socks: '#c8102e', acc: '#ffffff' },
    { k: 'white', shirt: '#eeeeee', shorts: '#1b2438', socks: '#eeeeee', acc: '#1b2438' },
    { k: 'green', shirt: '#0b7a3e', shorts: '#ffffff', socks: '#0b7a3e', acc: '#f2c200' },
    { k: 'yellow', shirt: '#f2c200', shorts: '#1b3c8f', socks: '#f2c200', acc: '#1b3c8f' },
    { k: 'purple', shirt: '#6a1b9a', shorts: '#ffffff', socks: '#6a1b9a', acc: '#ffffff' },
    { k: 'orange', shirt: '#f07800', shorts: '#1b2438', socks: '#f07800', acc: '#ffffff' },
    { k: 'sky', shirt: '#6cb6ea', shorts: '#1b2438', socks: '#6cb6ea', acc: '#ffffff' },
    { k: 'navy', shirt: '#1d2a4d', shorts: '#1d2a4d', socks: '#1d2a4d', acc: '#e0b84a' },
    { k: 'maroon', shirt: '#7a0f2e', shorts: '#ffffff', socks: '#7a0f2e', acc: '#ffd54a' },
    { k: 'redblack', shirt: '#d0103a', shorts: '#111111', socks: '#111111', acc: '#111111' },
    { k: 'teal', shirt: '#0e8f8a', shorts: '#ffffff', socks: '#0e8f8a', acc: '#ffffff' },
  ];
  const KIT_WORDS = [[/スカーレ|レッド|ロッソ|レッズ|フレイム|サンフレ/, 'red'], [/オレンジ|ファジ/, 'orange'], [/グリーン|グルー|リーフ/, 'green'], [/ブルー|マリ|アズー|アクア/, 'blue'], [/ゴールド|イエロー|ソレイユ|サンライズ/, 'yellow'], [/ディアー|アントラ/, 'maroon'], [/ホワイト|シルバー/, 'white']];
  const GK_KITS = ['#f2a900', '#2fbf71', '#ff5fa2', '#222222'];
  YA.KITS = KITS;
  YA.kitOf = function (name) {
    const n = String(name || '').replace(/\s*(U-18|ユース)?\s*B?$/, '');
    const word = KIT_WORDS.find((x) => x[0].test(n));
    const base = (word && KITS.find((x) => x.k === word[1])) || KITS[YA.hash(n || 'x') % KITS.length];
    return Object.assign({ gk: GK_KITS[YA.hash(n + 'gk') % GK_KITS.length] }, base);
  };
  const rgbOf = (hex) => { const v = parseInt(hex.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };
  YA.colorDist = (a, b) => { const x = rgbOf(a), y = rgbOf(b); return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]); };
  // 相手と色が近いときは、アウェイ側が替えのユニフォーム（白か紺）を着る
  YA.awayKit = function (home, away) {
    if (YA.colorDist(home.shirt, away.shirt) >= 130) return away;
    const lightHome = rgbOf(home.shirt).reduce((a, b) => a + b, 0) > 450;
    return Object.assign({}, away, lightHome ? { shirt: '#1d2a4d', shorts: '#1d2a4d', socks: '#1d2a4d', acc: away.shirt } : { shirt: '#f4f4f4', shorts: away.shirt, socks: '#f4f4f4', acc: away.shirt });
  };
  // 肌と髪の色（試合の絵で使う）。顔の絵とは別に、名前から決める
  YA.lookOf = (p) => {
    const h = YA.hash(String(p.id) + (p.name || ''));
    return { skin: ['#f3cfa9', '#e9b98c', '#d49a6a', '#a8714a', '#7a4e33'][h % 5 < 3 ? h % 3 : 3 + (h >> 3) % 2], hair: ['#1a1410', '#2b1d14', '#3d2817', '#5a3b22', '#1a1410', '#8a4f25'][(h >> 5) % 6] };
  };
  // 顔の絵：シャツを自クラブの色に、背景をポジションの色に塗り替える（読み込んでから1回だけ。結果は覚えておく）
  const POS_BG = { GK: ['#fff2cf', '#f5d27a'], DF: ['#e3edff', '#a9c3f0'], MF: ['#e2f5e7', '#9fd6ae'], FW: ['#ffe4e1', '#f2a7a0'] };
  const painted = {};
  const clamp01 = (f) => Math.max(0.45, Math.min(1.25, f));
  function repaint(im, kit, bg) {
    const S = im.naturalWidth || im.width;
    if (!S) return null;
    const cv = document.createElement('canvas');
    cv.width = S;
    cv.height = S;
    const ctx = cv.getContext && cv.getContext('2d');
    if (!ctx) return null;
    ctx.drawImage(im, 0, 0, S, S);
    const data = ctx.getImageData(0, 0, S, S);
    const d = data.data;
    const sh = rgbOf(kit.shirt);
    const ac = rgbOf(kit.acc);
    const top = rgbOf(bg[0]);
    const bot = rgbOf(bg[1]);
    // 背景：縁から続く明るい灰色だけを抜く（髪や肌の中の灰色は残す）
    const isBg = (i) => { const r = d[i], g = d[i + 1], b = d[i + 2]; return r > 190 && Math.abs(r - g) < 12 && Math.abs(g - b) < 14 && Math.abs(r - b) < 16; };
    const seen = new Uint8Array(S * S);
    const stack = [];
    for (let x = 0; x < S; x++) { stack.push(x, (S - 1) * S + x); }
    for (let y = 0; y < S; y++) { stack.push(y * S, y * S + S - 1); }
    while (stack.length) {
      const k = stack.pop();
      if (seen[k]) continue;
      seen[k] = 1;
      if (!isBg(k * 4)) { seen[k] = 2; continue; }
      const x = k % S, y = (k / S) | 0;
      if (x > 0) stack.push(k - 1);
      if (x < S - 1) stack.push(k + 1);
      if (y > 0) stack.push(k - S);
      if (y < S - 1) stack.push(k + S);
    }
    // シャツの色：いちばん下の数行で、背景と肌を除いていちばん多い色（元の絵ごとに赤・青・緑・黄・白・黒・橙と違う）
    const isSkin = (r, g, b) => r > g && g > b && b / r > 0.33 && g / r > 0.55 && r > 70;
    const hist = {};
    for (let y = Math.floor(S * 0.92); y < S; y++) for (let x = 0; x < S; x++) {
      const k = y * S + x, i = k * 4;
      if (seen[k] === 1 || isSkin(d[i], d[i + 1], d[i + 2])) continue;
      const q = (d[i] >> 5) + '_' + (d[i + 1] >> 5) + '_' + (d[i + 2] >> 5);
      (hist[q] = hist[q] || []).push(i);
    }
    const domBin = Object.keys(hist).sort((a, b) => hist[b].length - hist[a].length)[0];
    let dom = null;
    if (domBin) {
      const idx = hist[domBin];
      dom = [0, 1, 2].map((c) => idx.reduce((s, i) => s + d[i + c], 0) / idx.length);
    }
    const domL = dom ? Math.max(30, (dom[0] + dom[1] + dom[2]) / 3) : 0;
    const domTol = dom && domL > 200 ? 46 : 78;
    // 列ごとに、いちばん下の肌の位置。それより上（あご・ひげ）は塗らない
    const lastSkin = new Int16Array(S).fill(-1);
    for (let y = Math.floor(S * 0.5); y < S; y++) for (let x = 0; x < S; x++) { const i = (y * S + x) * 4; if (isSkin(d[i], d[i + 1], d[i + 2])) lastSkin[x] = y; }
    for (let y = 0; y < S; y++) {
      const t = y / S;
      for (let x = 0; x < S; x++) {
        const k = y * S + x, i = k * 4;
        const r = d[i], g = d[i + 1], b = d[i + 2];
        if (seen[k] === 1) {
          // 背景：上から下へのグラデーション（元の明るさの揺れは少し残す）
          const f = (r + g + b) / 3 / 228;
          d[i] = Math.min(255, (top[0] + (bot[0] - top[0]) * t) * f);
          d[i + 1] = Math.min(255, (top[1] + (bot[1] - top[1]) * t) * f);
          d[i + 2] = Math.min(255, (top[2] + (bot[2] - top[2]) * t) * f);
          continue;
        }
        if (y < S * 0.66 || !dom || isSkin(r, g, b) || y <= lastSkin[x] + 1) continue;
        // シャツ：元のシャツの色に近い画素を、明るさの比を保ってクラブの色に（しわと影が残る）
        const dist = Math.hypot(r - dom[0], g - dom[1], b - dom[2]);
        // 色の近さでなめらかに混ぜる（境目で元の色の点が残らないように。下のほうはシャツなので広めに取る）
        const tol = domTol * (y > S * 0.8 ? 1.7 : 1.2);
        const a = dist < domTol * 0.8 ? 1 : dist > tol ? 0 : 1 - (dist - domTol * 0.8) / (tol - domTol * 0.8);
        if (a > 0) {
          const f = clamp01(0.6 + 0.4 * (((r + g + b) / 3) / domL));
          d[i] = Math.min(255, r + (sh[0] * f - r) * a);
          d[i + 1] = Math.min(255, g + (sh[1] * f - g) * a);
          d[i + 2] = Math.min(255, b + (sh[2] * f - b) * a);
        } else if (y > S * 0.7 && (r + g + b) / 3 > 170 && Math.max(r, g, b) - Math.min(r, g, b) > 40) {
          // 肩の線などの差し色
          d[i] = ac[0];
          d[i + 1] = ac[1];
          d[i + 2] = ac[2];
        }
      }
    }
    ctx.putImageData(data, 0, 0);
    try { return cv.toDataURL('image/jpeg', 0.9); } catch (e) { return null; }
  }
  YA.faceEl = (w, p, px) => {
    const s = YA.faceSrc(w, p);
    if (!s) return null;
    const e = img(s, 'face', px || 28, p.name);
    if (p.face >= IMG().faces.length) e.style.transform = 'scaleX(-1)';
    // 自クラブの選手と入団の候補は自クラブの色、ほかは元の絵のまま
    const kitBase = YA.kitOf(w && w.clubName);
    const kit = p.pos === 'GK' ? Object.assign({}, kitBase, { shirt: kitBase.gk, acc: '#ffffff' }) : kitBase;
    const bg = POS_BG[p.pos] || POS_BG.MF;
    const key = (p.face % IMG().faces.length) + '|' + kit.shirt + kit.acc + '|' + bg[0];
    if (painted[key]) { e.src = painted[key]; return e; }
    if (typeof Image === 'undefined') return e;
    const im = new Image();
    im.onload = () => {
      if (!painted[key]) painted[key] = repaint(im, kit, bg) || s;
      e.src = painted[key];
    };
    im.src = s;
    return e;
  };
  // クラブのエンブレム：同じリーグのクラブは重ならないよう、名前順に割り当てる
  const embCache = {};
  YA.emblemIndex = function (w, name) {
    const E = IMG().emblems;
    if (!E.length) return -1;
    const names = ((w && w.league && w.league.teams) || []).map((t) => t.name);
    if (names.indexOf(name) < 0) names.push(name);
    names.sort();
    const key = names.join('|');
    if (!embCache[key]) {
      const used = new Set();
      const m = {};
      for (const n of names) {
        let k = YA.hash(n) % E.length;
        for (let i = 0; i < E.length && used.has(k); i++) k = (k + 1) % E.length;
        used.add(k);
        m[n] = k;
      }
      embCache[key] = m;
    }
    return embCache[key][name];
  };
  YA.emblemEl = (w, name, px) => {
    const k = YA.emblemIndex(w, name);
    return k < 0 ? null : img(IMG().emblems[k], 'emb', px || 20, name);
  };
  YA.titleSrc = () => IMG().title || '';
})();
