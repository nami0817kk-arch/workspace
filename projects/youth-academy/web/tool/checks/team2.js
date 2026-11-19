// 選手を構成する要素 段階7（team2.js）：仲良しの輪・輪が割れる・主将の性格・チームの雰囲気
'use strict';
module.exports = (YA, ok) => {
  const w = YA.newWorld(1501);
  YA.makeCircles(w);
  const cs = w.circles;
  ok(cs.length >= 3 && cs.length <= 7, `仲良しの輪が3〜7つ（${cs.length}）`);
  ok(cs.every((c) => c.ids.length >= 2 && c.name && c.kind), '輪には名前と寮か自宅かがある');
  ok(cs.every((c) => { const g = c.ids.map((id) => w.players[id].grade); return g.filter((x) => x === c.grade).length >= g.length * 0.5; }), '輪は学年でまとまりやすい');
  const inC = Object.values(w.players).filter((p) => p.circle).length;
  ok(inC >= 26, `ほとんどの子がどこかの輪にいる（${inC}/36）`);
  // 主将の性格
  const capOf = (t) => { const c = Object.values(w.players)[0]; w.captain = c.id; const old = c.pers['人との関わり']; c.pers['人との関わり'] = t; const e = YA.capEffect(w); c.pers['人との関わり'] = old; return e; };
  ok(capOf('リーダー気質').v > capOf('一匹狼').v && capOf('リーダー気質').k < capOf('一匹狼').k, '主将の性格でまとまりやすさが変わる');
  // 1年回す：雰囲気が動き、割れることがある
  const w2 = YA.newWorld(1502);
  let splits = 0;
  for (let s = 0; s < 3; s++) {
    const ww = s ? YA.newWorld(1502 + s) : w2;
    YA.simulate(ww, { until: 'year', stopOnImportant: false });
    if (ww.inbox.some((n) => /ロッカーの空気が割れている/.test(n.text))) splits++;
    ok(ww.atmo >= 0 && ww.atmo <= 100 && (ww.atmoHist || []).length >= 8, '雰囲気が毎週記録される ' + ww.atmo);
  }
  console.log('輪が割れた世界', splits, '/3');
  // 割れると雰囲気が下がり、働きかけでおさまる
  w.atmo = 60;
  w.split = { a: cs[0].id, b: cs[1].id, w: 0 };
  for (let k = 0; k < 6; k++) { w.week = 10 + k; YA.teamWeek(w); }
  ok(w.atmo < 60, '割れていると雰囲気が下がる ' + w.atmo);
  let ended = false;
  for (let k = 0; k < 12 && !ended; k++) { w.teamActM = null; w.week = 10 + k; YA.teamAct(w, 'talk'); ended = !w.split; if (!ended) w.split = w.split || null; }
  ok(ended, '輪の中心と話すと、ぎくしゃくがおさまる');
  ok(YA.teamActWhy(w) && !YA.teamAct(w, 'meet').ok, '働きかけは月1回');
  // 効き目
  ok(YA.atmoMod({ atmo: 90 }) > 0 && YA.atmoMod({ atmo: 20 }) < 0, '雰囲気が試合の力に効く');
  ok(YA.teamFromWorld(w, 'A').atmo === w.atmo, '試合のチームに雰囲気が渡る');
};
