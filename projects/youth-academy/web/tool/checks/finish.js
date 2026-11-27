// 段5 文章と演出の仕上げ（finish.js。2026-11-27）：会話とお知らせから人の数字を外す・反応は口調ごと・大事なお知らせの一言・
// おまかせでは演出を出さない・効果音3つ。画面の演出（覚醒・気づきの光・課題の場面・新聞）は tool/views.js
'use strict';
module.exports = (YA, ok) => {
  let n = 0;
  const K = (c, m) => { n++; ok(c, '仕上げ：' + m); };
  // 1. 数字を外す
  const cases = [
    ['自信 +5 / 調子 +0.5', ''], ['伸び盛り 16週・自信 +5', '伸び盛り 16週'], ['評判 +1・自信 +3', '評判 +1'], ['信頼度 −5', '信頼度 −5'],
    ['新入生の自信 +2・疲れ −3', ''], ['課題中の子2人の信頼 +1', ''], ['九条 戒との関係 −2', ''], ['自信 −3・話は続く（数週あとに）', '話は続く（数週あとに）'],
    ['卒業生の清水 悠真から、同じMFの池田 想へ一言。「1年目は焦らなくていい」（池田 想の自信 +4）', '卒業生の清水 悠真から、同じMFの池田 想へ一言。「1年目は焦らなくていい」'],
    ['子どもたちが戸惑っている（Aの自信 −3）', '子どもたちが戸惑っている'], ['チーム全員で話す。雰囲気+5。ぎくしゃくがおさまった', 'チーム全員で話す。ぎくしゃくがおさまった'],
    ['試合の前に話した（その試合の自信+8）', '試合の前に話した'], ['育成基金 +150万円', '育成基金 +150万円'], ['疲れ-20・気持ちも少し軽くなったようだ', '気持ちも少し軽くなったようだ'],
  ];
  for (const [a, b] of cases) K(YA.fxStrip(a).text === b, `数字を外す「${a}」→「${YA.fxStrip(a).text}」`);
  // 2. 反応は口調ごとに変わる
  const PERS = { 元気: 'リーダー気質', クール: '完璧主義', 丁寧: '素直', ぶっきらぼう: '一匹狼', おっとり: 'マイペース', 熱血: '闘争的', 弱気: '繊細', 生意気: '反骨心', 無口: '寡黙', お調子者: 'お調子者' };
  const fake = (t, i) => ({ id: 'tone' + i, name: '山田 太郎', num: 9, pers: { a: PERS[t] }, hist: [], conf: 50, form: 0 });
  const ws = { year: 1, week: 3 };
  const seen = new Set();
  for (const [i, t] of YA.TONES.entries()) {
    const p = fake(t, i);
    K(YA.toneOf(p) === t, '口調の割り当て ' + t + ' → ' + YA.toneOf(p));
    for (const d of ['good', 'mid', 'bad']) K(YA.REACT[d][t] && YA.REACT[d][t].length === 3, `反応の台詞 ${d}×${t} が3通り`);
    seen.add(YA.REACT.good[t].join('|'));
    const l = YA.toneLine(ws, p, { line: '表情がやわらいだ', c: 5, f: 0 }, 'warm');
    K(/^表情がやわらいだ。「[^」]+」$/.test(l) && YA.REACT.good[t].some((x) => l.includes(x)), `寄り添った反応に${t}の一言 ${l}`);
    K(YA.toneLine(ws, p, { line: '自分で考えている様子だった', c: 0 }, 'wait') === '自分で考えている様子だった', '見守ったときは様子の文だけ（台詞を足さない）');
    { const sb = YA.reactSay(ws, p, 'bad'); K(YA.REACT.bad[t].indexOf(sb) >= 0, `悪い向きの台詞は${t}の bad から ${sb}`); }
  }
  K(seen.size === YA.TONES.length, '口調ごとに台詞が違う ' + seen.size);
  K(['good', 'mid', 'bad'].every((d) => YA.REACT[d].無口 !== YA.REACT[d].元気), '向きごとに台詞が違う');
  // 3. 実際の世界で：面談・出来事の結果に数字が出ず、口調の一言が付く。働きかけも数字なし
  const w = YA.newWorld(41);
  const ps = Object.values(w.players);
  const tones = new Set();
  for (const p of ps.slice(0, 16)) {
    const r = YA.talk(w, p.id, 'praise');
    K(r.ok && !YA.FX_NUM.test(r.line) && !/\d/.test(r.extra || '') && /「[^」]+」/.test(r.line), `面談の返事に数字が無く、口調の一言 ${p.name}：${r.line}`);
    tones.add(YA.toneOf(p));
  }
  K(tones.size >= 4, '面談した16人の口調が4通り以上 ' + tones.size);
  {
    const p = ps[3];
    p.kd = { t: 'eye', c: null, w0: w.year * 40 + w.week, len: 12, fit: 'yes' }; p.star = true; p.tr = 60;
    for (const k of ['meal', 'stay', 'family', 'rest']) {
      w.saUsed = null;
      const r = YA.starAct(w, p, k);
      K(r.ok && !YA.FX_NUM.test(r.msg) && !/\d+→\d+/.test(r.msg), `働きかけ（${k}）の結果に数字が出ない：${r.msg}`);
    }
    p.kd = null; p.star = false;
    const t = YA.teamAct ? YA.teamAct(w, 'meet') : { ok: true, msg: '' };
    K(t.ok && !YA.FX_NUM.test(t.msg), 'チームへの働きかけの結果に数字が出ない：' + t.msg);
  }
  // 4. 大事なお知らせに一言・同じ言い回しが続かない・本文に数字なし・おまかせで演出が積まれない（2年）
  {
    const st = YA.testStart({ seed: 7, tier: 2 });
    const W = st.w;
    let fxAdd = 0;
    const push0 = YA.fxPush;
    YA.fxPush = function () { fxAdd++; return push0.apply(this, arguments); };
    try { for (let y = 0; y < 2; y++) YA.simulate(W, { until: 'year', stopOnImportant: false }); } finally { YA.fxPush = push0; }
    const imp = W.inbox.filter((x) => { const d = YA.NOTE_SAY.find((k) => k.re.test(x.text)); return d && !(d.tier && x.tier > d.tier) && (d.who !== 'self' || (x.pid && W.players[x.pid])); });
    const said = imp.filter((x) => x.say);
    K(imp.length >= 15 && said.length === imp.length, `大事なお知らせに一言が付く ${said.length}/${imp.length}`);
    const line = (s) => s.replace(/^[^「]*「/, '');
    let rep = 0;
    for (let i = 1; i < said.length; i++) if (line(said[i].say) === line(said[i - 1].say)) rep++;
    K(rep === 0, '一言が続けて同じ言い回しにならない ' + rep);
    const kinds = new Set(said.map((x) => YA.NOTE_SAY.find((k) => k.re.test(x.text)).k));
    K(kinds.size >= 4, '一言の付くお知らせの種類 ' + [...kinds].join('・'));
    K(said.some((x) => /コーチ「|トレーナーの/.test(x.say)) && said.some((x) => !/コーチ「|トレーナーの/.test(x.say)), 'コーチの一言と本人の一言の両方がある');
    K(!W.inbox.some((x) => YA.FX_NUM.test(x.text)), 'お知らせの本文に人の数字が無い');
    K(!W.inbox.some((x) => /^今月の選手の/.test(x.text) && x.say), '月ごとのまとめには一言を付けない');
    K((W.fxQ || []).length === 0, `おまかせ進行では課題の場面を積まない（あきらめ ${fxAdd}回・残り ${(W.fxQ || []).length}）`);
    K((W.events || []).concat(W.forced || []).filter((e) => e.id === 'awake').every((e) => e._fx), 'おまかせのあとの覚醒の窓は演出なし');
    const firsts = W.inbox.filter((x) => /Aの公式戦で初ゴール/.test(x.text));
    K(firsts.length >= 2 && new Set(firsts.map((x) => x.pid)).size === firsts.length, '初ゴールのお知らせ（1人1回） ' + firsts.length);
    console.log(`  仕上げ：一言 ${said.length}/${imp.length}件（${[...kinds].join('・')}）・初ゴール ${firsts.length}件・おまかせのあきらめ ${fxAdd}回`);
  }
  // 5. 効果音3つ（WebAudio の合成。音源ファイルなし）
  {
    const made = {};
    let cur = null;
    const g0 = globalThis.AudioContext;
    globalThis.AudioContext = function () {
      this.state = 'running'; this.currentTime = 0; this.destination = {};
      this.createOscillator = () => { made[cur] = (made[cur] || 0) + 1; return { type: '', frequency: {}, connect() {}, start() {}, stop() {} }; };
      this.createGain = () => ({ gain: { setValueAtTime() {}, exponentialRampToValueAtTime() {} }, connect() {} });
    };
    const on0 = YA.sfx.on, c0 = YA.sfx.ctx;
    try {
      YA.sfx.on = true; YA.sfx.ctx = null;
      for (const k of ['kizuki', 'awake', 'giveup']) { cur = k; YA.sfx.play(k); }
      K(made.kizuki >= 2 && made.awake >= 4 && made.giveup >= 3, '効果音：気づき・覚醒・あきらめを合成で鳴らす ' + JSON.stringify(made));
      YA.sfx.on = false; cur = 'off'; YA.sfx.play('awake');
      K(!made.off, '効果音を消していれば鳴らない');
    } finally { YA.sfx.on = on0; YA.sfx.ctx = c0; if (g0) globalThis.AudioContext = g0; else delete globalThis.AudioContext; }
  }
  console.log(`  仕上げの点検：${n}件`);
  ok(n >= 80, '仕上げの点検が全部走った ' + n);
};
