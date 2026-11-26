// 文の点検（2026-11-17「全て直す」82〜100）：数シード×3年を回して、お知らせと出来事の文・選択肢・結果を集め、
// 日本語の壊れ（くだけた口調の活用・欠けた文・二重のかぎかっこ・「あの……」の重なり・undefined など）と、
// 場面の食い違い（試合の無い週の試合の文・退団した子が卒業生として顔を出す・同じ反応の文ばかり）を数える。
//   node tool/checks/text.js      … 数だけを出す（直す前と後の比べに使う）
'use strict';

// 出来事の選び方は画面と同じ順で、選択肢は週と種類からばらす（いつも1番目だと反応の文が偏って見える）
function collect(YA, seeds, years) {
  const out = { events: [], notes: [], seeds: seeds.length };
  const views = new WeakMap();
  const ev0 = YA.eventView;
  YA.eventView = function (w, e) {
    const v = ev0.apply(this, arguments);
    if (v && e && typeof e === 'object') views.set(e, { name: v.name, text: v.text, opts: v.opts.slice() });
    return v;
  };
  try {
    for (const seed of seeds) {
      const st = YA.testStart({ seed, tier: 2 });
      const w = st.w;
      let lastN = w.inboxN || 0;
      let guard = 0;
      const grab = () => {
        for (const n of w.inbox || []) if ((n.n || 0) > lastN) out.notes.push({ seed, year: n.year, week: n.week, text: n.text });
        lastN = w.inboxN || lastN;
      };
      while (w.year <= years && guard++ < 6000) {
        const ph = w.phase;
        if (ph === 'plan') {
          YA.autoPrompts(w, []);
          YA.autoScout(w);
          if (YA.SCHED(w.week).t === 'camp' && !w.campChoice) w.campChoice = 'none';
          YA.autoPlan(w);
          YA.startWeek(w);
        } else if (ph === 'event') {
          for (const e of w.events.slice()) {
            const last = (w.results || []).slice(-1)[0];
            const prevMatch = !!(last && last.year === w.year && last.week === w.week - 1);
            const thisMatch = !!YA.matchOf(w);
            const v = YA.eventView(w, e);
            if (v) {
              const idx = YA.hash(String(seed) + w.year + '_' + w.week + e.id) % v.opts.length;
              const shown = views.get(e) || v;
              const r = YA.resolveEvent(w, e, idx);
              out.events.push({ seed, year: w.year, week: w.week, id: e.id, sub: e.lk || e.ck || e.cid || e.ms || e.k || null, ck: e.cid ? ((w.chains || []).find((c) => c.id === e.cid) || {}).k || null : null,
                prevMatch, thisMatch, name: shown.name, text: shown.text, opts: shown.opts, pick: shown.opts[idx], kind: null, line: (r && r.line) || '', small: (r && r.small) || '', leave: (r && r.leave) || '', who: e.who || null });
            }
            w.events.shift();
          }
          YA.afterEvents(w);
        } else if (ph === 'match') YA.playAuto(w);
        else YA.endWeek(w);
        grab();
      }
      out.alumni = (out.alumni || []).concat((w.alumni || []).map((a) => ({ name: a.name, status: a.status })));
    }
  } finally {
    YA.eventView = ev0;
  }
  return out;
}

// 数える
function measure(YA, data) {
  const texts = [];
  for (const e of data.events) {
    texts.push(e.text, e.line, e.small, e.leave);
    for (const o of e.opts) texts.push(o);
  }
  for (const n of data.notes) texts.push(n.text);
  const all = texts.filter((s) => typeof s === 'string' && s);
  const count = (re) => all.filter((s) => re.test(s)).length;
  const m = {};
  // 82：くだけた口調の活用の壊れ（「もらいたっす」「なりたっす」「広がりたっす」「〜んっす」）
  m.casual = count(/(らい|かい|わい|あい|がり|なり|まり|わり|ち|び|ぎ)たっす|んっす/);
  // 85：年度末の会話の欠け（「。のことを、本人もよく覚えていた」）
  m.memHole = count(/(^|[。」）])のことを、本人も/);
  // 86：かぎかっこの二重
  m.dblQuote = count(/「「|」」/);
  // 98：「あの……」の重なり・点が4つ以上
  m.ano = count(/あの……(…|‥)/);
  // undefined・NaN・式の残り
  m.junk = count(/undefined|NaN|\$\{|\{n\}|\[object/);
  // 88：試合の無い週に、前の試合の文（前の週にA戦が無いのに「試合中」「退場」「毎試合」）
  const MATCH_TXT = /試合中、|退場になった|毎試合来る|大会の日が重なった|大会当日/;
  m.noMatch = data.events.filter((e) => MATCH_TXT.test(e.text) && !(/大会の日が重なった|大会当日/.test(e.text) ? e.thisMatch : e.prevMatch)).length;
  m.matchTxt = data.events.filter((e) => MATCH_TXT.test(e.text)).length;
  // 89：試合の無い週の「試合を優先」「試合から外す」
  m.noMatchOpt = data.events.filter((e) => !e.thisMatch && e.opts.some((o) => /試合を優先|試合から外す/.test(o))).length;
  // 84：退団した子が卒業生として顔を出す（「（1年卒・）」の空欄も）
  m.leftVisit = data.events.filter((e) => e.id === 'visit' && /年卒・）|年卒）/.test(e.text)).length;
  // 83：引き止めに失敗したのに「ありがとうございます」
  m.leaveThanks = data.events.filter((e) => e.leave && /ありがとうございます|もっと頑張ります|やってやります/.test(e.line)).length
    + data.notes.filter((n) => /去った/.test(n.text) && /ほっとした|ありがとうございます|やってやります/.test(n.text)).length;
  // 97：約束事が無いのに「約束どおり処分」は club.js 側で直す（数は文の数だけ見る）
  m.rulesTxt = count(/約束どおり処分/);
  // 99：同じ言い回し
  m.spurtLong = count(/成長期に入った（伸びやすい時期。/);
  m.weekGain = count(/今週よく伸びた/);
  m.lightBody = data.notes.filter((n) => /体が軽い。練習の強度を上げられそうだ/.test(n.text)).length;
  m.diary = data.notes.filter((n) => /^練習日誌：/.test(n.text)).length;
  // 91：反応の文の偏り（選手に当たった出来事の結果の文で、いちばん多い2つの割合）
  // 反応の文は句点の無い短い文（world.js の react）。「（…）」の中に付いた続き物の反応も数える
  const lines = data.events.filter((e) => e.line && !e.leave).map((e) => (/（([^（）。]+)）$/.exec(e.line) || [null, e.line])[1]).filter((l) => l && !/。/.test(l) && !/^[^「]*「[^」]*」$/.test(l));
  const freq = {};
  for (const l of lines) freq[l] = (freq[l] || 0) + 1;
  const top = Object.values(freq).sort((a, b) => b - a);
  m.reactN = lines.length;
  m.reactTop2 = lines.length ? Math.round(((top[0] || 0) + (top[1] || 0)) / lines.length * 100) : 0;
  // 95：選んでも何も起きない（結果の文も小さな効果も空）
  m.empty = data.events.filter((e) => !e.line && !e.small && !e.leave).length;
  m.events = data.events.length;
  m.notes = data.notes.length;
  return m;
}

const SEEDS = [1, 2, 3, 4];
module.exports = (YA, ok) => {
  const data = collect(YA, SEEDS, 3);
  const m = measure(YA, data);
  ok(m.events > 150, '文の点検：出来事が集まる ' + m.events);
  ok(m.casual === 0, '文の点検：くだけた口調の壊れ（もらいたっす・んっす）が無い ' + m.casual);
  ok(m.memHole === 0, '文の点検：年度末の会話に「。のことを」が無い ' + m.memHole);
  ok(m.dblQuote === 0, '文の点検：かぎかっこが二重にならない ' + m.dblQuote);
  ok(m.ano === 0, '文の点検：「あの……」が点と重ならない ' + m.ano);
  ok(m.junk === 0, '文の点検：undefined・NaN・{ が出ない ' + m.junk);
  ok(m.noMatch === 0, '文の点検：試合の無い週に試合の文が出ない ' + m.noMatch);
  ok(m.noMatchOpt === 0, '文の点検：試合の無い週に「試合を優先」が出ない ' + m.noMatchOpt);
  ok(m.leftVisit === 0, '文の点検：退団した子が卒業生として顔を出さない ' + m.leftVisit);
  ok(m.leaveThanks === 0, '文の点検：去る子が「ありがとうございます」と言わない ' + m.leaveThanks);
  ok(m.reactN < 20 || m.reactTop2 <= 35, '文の点検：反応の文の上位2つが35%以下 ' + m.reactTop2 + '%');
  ok(m.spurtLong <= SEEDS.length * 3, '文の点検：成長期の長い説明は初回だけ ' + m.spurtLong);
  ok(m.weekGain <= SEEDS.length * 3 * 25, '文の点検：「今週よく伸びた」がまとめてある ' + m.weekGain);
  ok(!m.diary || m.lightBody / m.diary <= 0.15, '文の点検：日誌の「体が軽い」が多すぎない ' + m.lightBody + '/' + m.diary);
  // 約束事を決めていない年は「約束どおり処分する」を出さない・試合の無い週は「次の試合から外す」を出さない
  {
    const w = YA.newWorld(5);
    const p = Object.values(w.players)[0];
    w.rules = [];
    w.week = 34; // 32・33週は新春フェスティバル（育成の直し）、34週は試合が無い
    const v = YA.eventView(w, { id: 'fight', pid: p.id, week: w.week, year: w.year });
    ok(v && !v.opts.some((x) => /約束どおり処分|次の試合から外す/.test(x)), '文の点検：約束事の無い年・試合の無い週の規律の選択肢 ' + (v && v.opts.join('／')));
    w.rules = YA.RULES.slice();
    w.week = 5;
    const v2 = YA.eventView(w, { id: 'fight', pid: p.id, week: w.week, year: w.year });
    ok(v2 && v2.opts.some((x) => /約束どおり処分/.test(x)) && v2.opts.some((x) => /次の試合から外す/.test(x)), '文の点検：約束事を決めた年・試合の週は処分を選べる');
    // 1人だけの代表招集は2択で、「それぞれ」を言わない
    w._natCall = [p.id];
    const v3 = YA.eventView(w, { id: 'natcall', pid: null, week: w.week, year: w.year });
    ok(v3 && v3.opts.length === 2 && !v3.opts.some((x) => /全員/.test(x)), '文の点検：1人の代表招集は送り出す／断るの2択 ' + (v3 && v3.opts.join('／')));
    const r3 = YA.resolveEvent(w, { id: 'natcall', pid: null, week: w.week, year: w.year }, 0);
    ok(r3 && !/それぞれ/.test(r3.line), '文の点検：1人の代表招集で「それぞれ」と言わない ' + (r3 && r3.line));
  }
  // くだけた口調の活用
  if (YA.casualize) {
    for (const [a, b] of [['僕を責めないでもらいました。', 'もらったっす。'], ['応援団になりました。', 'なったっす。'], ['教えるの、好きなんです', '好きなんすよ'], ['続けられませんでした。', '続けられなかったっす。'], ['働くことを選びました。', '選んだっす。']]) ok(YA.casualize(a).endsWith(b), '文の点検：くだけた口調 ' + a + ' → ' + YA.casualize(a));
  }
  // 退団した子は卒業生の顔出しの候補に入らない
  if (YA.visitor) {
    const w = { year: 3, seed: 1, alumni: [{ name: 'A', status: 'left', ovr: 20, year: 1 }, { name: 'B', status: 'pro', ovr: 10, year: 1, club: 'X' }] };
    for (let y = 1; y < 8; y++) { w.year = y; const a = YA.visitor(w); ok(!a || a.status !== 'left', '文の点検：退団した子は顔を出さない'); }
  }
};
module.exports.collect = collect;
module.exports.measure = measure;

if (require.main === module) {
  const path = require('path');
  for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'core', 'lineage', 'rivals', 'story', 'memory', 'chains', 'chains2', 'events2', 'staff', 'scout2', 'club5', 'life', 'func', 'pronews', 'staracts', 'shop', 'stars2', 'kadai']) require(path.join(__dirname, '../../src/' + f + '.js'));
  const YA = globalThis.YA;
  const n = +process.argv[2] || 8;
  const seeds = Array.from({ length: n }, (_, i) => i + 1);
  const data = collect(YA, seeds, 3);
  console.log(JSON.stringify(measure(YA, data)));
  if (process.argv[3] === 'dump') require('fs').writeFileSync(process.argv[4] || 'text-dump.json', JSON.stringify(data, null, 1));
}
