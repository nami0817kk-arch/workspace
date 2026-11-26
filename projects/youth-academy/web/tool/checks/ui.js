// 画面の決まりの点検（2026-11-17 画面の直し）。DOM が無いので、文字列を返す関数と、ソースの文字だけを見る。
// 画面そのもの（押せないボタンの理由・確認の窓・説明の出し方）は tool/views.js が jsdom で見る。
'use strict';
const fs = require('fs');
const path = require('path');

module.exports = (YA, ok) => {
  const src = (f) => fs.readFileSync(path.join(__dirname, '..', '..', 'src', f), 'utf8');
  const bareMan = /\d万(?!円)/; // 「99万」のような「万」だけのお金

  // お金の表示：YA.yen は「万円」か「億円」で、「万」だけにならない
  {
    const cases = [[0, '0円'], [15, '15万円'], [99, '99万円'], [800, '800万円'], [9999, '9999万円'], [12000, '1.2億円'], [100000, '10億円']];
    const bad = cases.filter(([m, want]) => YA.yen(m) !== want).map(([m]) => m + '→' + YA.yen(m));
    ok(!bad.length, 'ui: お金の表示 YA.yen が万円／億円で出る ' + bad.join(' '));
    ok([1, 50, 600, 4000, 12345, 250000].every((m) => !bareMan.test(YA.yen(m))), 'ui: YA.yen に「万」だけの表示が無い');
  }
  // 画面のソースに「〇〇万」だけの表示が残っていない（給料・予算・育成基金・連帯貢献金）
  {
    const lines = [];
    for (const f of ['views.js', 'views2.js', 'lineage.js', 'staracts.js']) {
      src(f).split('\n').forEach((l, i) => {
        // `${x}万` や '+ '万'' の形（「万円」「万人」「万回」は除く）
        if (/\}万(?![円人回])|'万'/.test(l) && !/連帯貢献金/.test(l)) lines.push(f + ':' + (i + 1));
      });
    }
    ok(!lines.length, 'ui: 画面のソースに「万」だけのお金の表示が無い ' + lines.slice(0, 5).join(' '));
  }
  // 育成基金：使った結果の文が返る（画面はこれを知らせる）
  {
    const w = { fund: 900, club: { facPts: 0 }, players: {}, year: 1 };
    const u = (YA.FUND_USES || [])[0];
    if (u) {
      const r0 = YA.fundUse({ fund: 0, club: {}, players: {}, year: 1 }, u.k);
      ok(!r0.ok && /足りません/.test(r0.msg) && !bareMan.test(r0.msg), 'ui: 育成基金が足りないときは理由の文');
      w.fund = u.cost + 10;
      const r1 = YA.fundUse(w, u.k);
      ok(r1.ok && /使いました/.test(r1.msg) && !bareMan.test(r1.msg), 'ui: 育成基金を使うと結果の文が返る ' + r1.msg);
    }
  }
  // 週を進めるボタンは1つの言葉（「この週で行く」）。最初の説明とコーチの一言も同じ言葉
  {
    const v = src('views.js');
    ok(v.includes("'この週で行く ▶'") && !v.includes('練習を確定して週を進める') && !v.includes('今月の練習のまま週を進める'), 'ui: 週を進めるボタンは「この週で行く ▶」にそろう');
    const intro = JSON.stringify(YA.INTRO || []) + JSON.stringify(YA.COACH_TIPS || {});
    ok(intro.includes('この週で行く') && !/練習を確定して週を進める|週を進める」/.test(intro), 'ui: 最初の説明とコーチの一言も「この週で行く」');
    // ホームと練習で同じ大きさ（同じ定数を使う）
    ok((v.match(/style: WEEK_GO_STYLE/g) || []).length >= 2 && /WEEK_GO_STYLE = 'min-height:42px;font-size:14px'/.test(v), 'ui: 「この週で行く」はホームと練習で同じ大きさ（42px・14px）');
    // 「先週と同じ」は先週が無ければ押せず、理由がある
    ok(/disabled: !w\.lastPlan, why: 'まだ先週の練習がありません/.test(v) && (v.match(/sameAsLast\(w\)/g) || []).length >= 2, 'ui: 「先週と同じ」は先週が無いと押せず理由が付く（1枚の画面と細かい画面の両方）');
  }
  // 系譜の小タブの名前が、クラブの小タブ（トップ）や左の帯（クラブ）と重ならない
  {
    const names = (YA.lineageExtraTabs || []).map((x) => x[1]);
    ok(names.includes('監督の注文') && names.includes('移籍先クラブ') && !names.includes('トップ') && !names.includes('クラブ'), 'ui: 系譜の小タブは「監督の注文」「移籍先クラブ」 ' + names.join('・'));
    ok(new Set(names).size === names.length, 'ui: 系譜の小タブの名前が重ならない');
  }
  // 大事な数字の字は11px以上：位置の札（.pos）・ポジション別の人数・能力の1年の伸び・伸びしろの水準名
  {
    const css = src('style.css');
    const m = css.match(/\.pos\{[^}]*font-size:([\d.]+)px/);
    ok(m && +m[1] >= 11, 'ui: 位置の札 .pos の字は11px以上 ' + (m && m[1]));
    const v2 = src('views2.js');
    const grid = v2.slice(v2.indexOf('function posCountGrid'), v2.indexOf('YA.posCountGrid ='));
    const small = (grid.match(/font-size:([\d.]+)px/g) || []).map((x) => +x.match(/[\d.]+/)[0]).filter((x) => x < 11);
    ok(grid.length > 0 && !small.length && grid.includes("'不足'"), 'ui: ポジション別の人数は11px以上で、足りない位置に「不足」の札 ' + small.join(','));
    const u = src('ui.js');
    const ab = u.slice(u.indexOf('function abBar'), u.indexOf('function goldHint'));
    const s2 = (ab.match(/font-size:([\d.]+)px/g) || []).map((x) => +x.match(/[\d.]+/)[0]).filter((x) => x < 11);
    ok(ab.length > 0 && !s2.length, 'ui: 能力の今月・1年の伸びの字は11px以上 ' + s2.join(','));
  }
  // 長押しの説明（title）を使わない：性格の札・★の働きかけ・伸びしろ・図鑑の手がかり
  {
    const u = src('ui.js');
    ok(!/chip pers', title:/.test(u) && /k === 'tip'/.test(u), 'ui: 性格の札は title ではなく押すと説明（tip）');
    ok(!/title: d\.about/.test(src('staracts.js')), 'ui: 課題中の子への働きかけの説明は本文に出す');
    ok(!/title: d \? '' : leanHint/.test(src('lineage.js')), 'ui: 図鑑の手がかりは title にしない（本文に出ている）');
    ok(!/chip trait', title: YA\.futureRange/.test(src('views.js')), 'ui: 伸びしろの水準名は title にしない');
  }
  // 確認の窓：取り返せない操作は動詞の赤いボタン、「やめる」が主ボタン
  {
    const v3 = src('views3.js');
    const box = v3.slice(v3.indexOf('function confirmBox'), v3.indexOf('YA.confirmBox = confirmBox'));
    ok(box.length > 0 && !box.includes("'はい'") && box.includes("'danger'"), 'ui: 確認の窓の確定は「はい」ではなく動詞、取り返せない操作は赤');
    const calls = v3.match(/confirmBox\('[^']*'[^\n]*/g) || [];
    ok(calls.length >= 4 && calls.every((c) => /yes: '[^']+'/.test(c) && /danger: true/.test(c)), 'ui: 削除・控えに戻す・やり直す・引退の確認は動詞の赤いボタン');
  }
};
