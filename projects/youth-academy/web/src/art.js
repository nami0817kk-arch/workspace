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
  // 選手の顔：名前から決めて p.face に残す（同じ名簿のなかでは重ならない）
  YA.faceSrc = function (w, p) {
    const F = IMG().faces;
    if (!F.length || !p) return null;
    if (p.face == null || p.face >= F.length) {
      const used = new Set();
      if (w) for (const q of Object.values(w.players)) if (q.face != null) used.add(q.face);
      let k = YA.hash(p.name || String(p.id)) % F.length;
      for (let i = 0; i < F.length && used.has(k); i++) k = (k + 1) % F.length;
      p.face = k;
    }
    return F[p.face];
  };
  YA.faceEl = (w, p, px) => {
    const s = YA.faceSrc(w, p);
    return s ? img(s, 'face', px || 28, p.name) : null;
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
