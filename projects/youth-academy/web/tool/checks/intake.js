// 入団まわり（2026-11-20「他にもバグないか確認して」で、10年通しで見つかったもの）
'use strict';
module.exports = (YA, ok) => {
  // 候補の名前が、半年のあいだに入った在籍の子と重なっていたら、入団のときに付け直す
  {
    const w = YA.newWorld(611);
    w.scouting = YA.newScouting();
    const ps = Object.values(w.players);
    const taken = ps[0].name;
    const cand = YA.genPlayer(YA.rngOf(7), 'c1', 1, 'CM', 0, new Set());
    cand.name = taken;
    w.scouting.cands = [{ id: 'c1', p: cand, kind: 'int', status: 'signed', seen: 3 }];
    for (const p of ps) if (p.grade === 3) delete w.players[p.id];
    YA.intake(w, YA.rngOf(8), YA.usedNames(w));
    const names = Object.values(w.players).map((p) => p.name);
    ok(names.filter((n) => n === taken).length === 1, '入団: 在籍の子と同じ名前の候補は、名前を付け直して入る');
    ok(new Set(names).size === names.length, '入団: 同じ名前の子が二人いない');
  }
  // 年度末の入団で入った子にも、その週のうちに出身地がある
  {
    const w = YA.newWorld(612);
    let n = 0;
    while (w.week !== 40 && n++ < 60) YA.simulate(w, { until: 'week', stopOnImportant: false });
    YA.simulate(w, { until: 'week', stopOnImportant: false });
    const ps = Object.values(w.players);
    ok(w.week <= 2 && ps.every((p) => p.born), '入団: 年度が替わった直後も全員に出身地がある ' + ps.filter((p) => !p.born).length);
  }
};
