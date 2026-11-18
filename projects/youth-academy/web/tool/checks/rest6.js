// 108件の点検の残り6件（2026-11-18「直す」）：退場の出場停止・カスタム戦術の練習・卒業生と同じ名前・
// 同じクラブへの移籍・夏の大会の決勝前の場面
'use strict';
module.exports = (YA, ok) => {
  // ---- 退場した子は、次に試合のある週に出場停止
  {
    const w = YA.newWorld(41);
    const opp = YA.opponentOf(w);
    const m = new YA.Match({ seed: 9, home: YA.teamFromWorld(w, 'A'), away: YA.makeOpponent(opp, 77), settings: { autoStop: false } });
    let g = 0;
    while (!m.finished && g++ < 3000) m.step();
    const pid = w.lineupA.find((s) => w.players[s.pid].pos !== 'GK').pid;
    const p = w.players[pid];
    p.sentOff = true;
    YA.applyMatch(w, m, 'A', opp, true);
    ok(p.banM === 1, '退場した子に出場停止が付く');
    const am = YA.applyMatch;
    let seenA = null;
    YA.applyMatch = function (ww, mm, which) { if (which === 'A') seenA = Object.keys(mm.home.players); return am.apply(this, arguments); };
    try {
      YA.simulate(w, { until: 'week', stopOnImportant: false });
    } finally { YA.applyMatch = am; }
    ok(seenA && seenA.indexOf(pid) < 0, '出場停止の子は次の試合の登録に入らない');
    ok(!(p.banM > 0), '出場停止は1試合で終わる');
    YA.simulate(w, { until: 'week', stopOnImportant: false });
    ok(!(p.suspend > 0), '次の次の週には出られる');
    // 前の試合の退場を持ち越さない
    const m2 = new YA.Match({ seed: 10, home: YA.teamFromWorld(w, 'A'), away: YA.makeOpponent(opp, 78), settings: { autoStop: false } });
    ok(Object.values(m2.home.players).every((q) => !q.sentOff), '新しい試合では退場の印が消えている');
  }

  // ---- カスタムの戦術でも、もとの型で練習の上乗せが付く
  {
    const w = YA.newWorld(42);
    w.tactic = Object.assign({}, YA.TACTICS['ハイプレス'], { type: 'カスタム', baseType: 'ハイプレス' });
    ok(YA.tacBase(w.tactic) === 'ハイプレス', 'カスタムはもとの型で見る');
    const got = w.lineupA.map((s) => YA.tacticTrainBonus(w, w.players[s.pid])).filter((x) => x.tactic === 'ハイプレス').length;
    ok(got >= 3, `カスタムの戦術でも練習の上乗せが付く（${got}人）`);
  }

  // ---- 夏の大会：決勝まで勝ち上がると、次の週に決勝の前の場面が出て、場面のあとに決勝が決まる
  {
    const w = YA.newWorld(43);
    const c = w.cup.summer;
    for (const o of c.gopps) c.gtable[o.id].p = 0;
    c.gtable.me.p = 9;
    c.gtable.me.gf = 9;
    const kw = YA.koWin;
    YA.koWin = () => true;
    try {
      YA._summerAfterGroup(w);
      ok(c.finalPending && c.alive && c.round === c.opps.length - 1, '準決勝まで勝つと決勝を待つ');
      w.week = YA.SUMMER_CUP_WEEKS[1] + 1;
      w.forced = [];
      YA.rivalWeek(w);
      const e = (w.forced || []).find((x) => x.id === 'scene' && x.sc === 'cup' && x.cup === 'summer');
      ok(!!e, '夏の決勝の前の場面が出る');
      if (e) {
        const v = YA.eventView(w, e);
        ok(v && /決勝の前/.test(v.text || '') && /←これから/.test(v.text || ''), '場面の文に決勝の相手が「これから」と出る');
        YA.resolveEvent(w, e, 0);
      }
      ok(!c.finalPending && c.result === '優勝', '場面のあとに決勝が決まる');
    } finally { YA.koWin = kw; }
  }

  // ---- 何年か回して：卒業生と同じ名前が出ない・同じクラブへは移らない
  {
    const w = YA.newWorld(44);
    let g = 0;
    while (w.year < 7 && g++ < 400) YA.simulate(w, { until: 'week', stopOnImportant: false });
    const names = (w.alumni || []).map((a) => a.name).concat(Object.values(w.players).map((p) => p.name));
    const dup = names.length - new Set(names).size;
    ok(dup === 0, `卒業生といまの選手で同じ名前が無い（重なり ${dup}・${names.length}人）`);
    const mv = [].concat(...(w.alumni || []).map((a) => a.moves || []));
    const same = mv.filter((x) => x.from && x.from === x.to).length;
    ok(mv.length > 0 && same === 0, `移籍元と移籍先が同じクラブにならない（${same}/${mv.length}）`);
  }
};
