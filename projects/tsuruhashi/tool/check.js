// エンジンの決まりごとを確かめる（CI で毎回回る）。
//   node tool/check.js
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
vm.runInThisContext(src.split('/*ENGINE-START*/')[1].split('/*ENGINE-END*/')[0] + ';globalThis.__setClock=f=>{NOW=f};');
let clock = 1.8e12; __setClock(() => clock);
let fails = 0;
const ok = (c, m) => { if (!c) { fails++; console.log('NG ' + m); } else console.log('ok ' + m); };

// 画面の JS が構文として読めること
new Function(src.split('<script>')[1].split('</script>')[0]);
ok(true, '画面の JS が読める');
// 公開する文面に個人の名前を出さない
// 色の番号（#08171d）や「身だしなみ」には当てない
const plain = src.replace(/#[0-9a-fA-F]{3,8}\b/g, '').replace(/身だしなみ/g, '');
ok(!/\bnami\b|0817|なみ/i.test(plain), '個人の名前が入っていない');

ok(ITEMS.length === 50 && new Set(ITEMS.map(i => i.id)).size === 50, '図鑑は50種で id が重ならない');
for (let L = 0; L < NLAYER; L++) { const its = itemsOf(L); ok(its.length === 5 && its.filter(i => i.r === 'l').length === 1 && its.filter(i => i.r === 'r').length === 2, `第${L + 1}層は普通2・★2・★★1`); }
ok(ACH.length === 30 && new Set(ACH.map(a => a.id)).size === 30, '実績は30個');
ok(REQ.length === NLAYER && REQ.every((v, i) => !i || v > REQ[i - 1]), '岩盤の必要Lvは深いほど高い');
ok(CREEDS.every(p => p.a.g && p.a.b && p.b.g && p.b.b), '社訓はどれも良い点と代償を持つ');

// 留守：時計が戻っていたら0、上限で切る
let S = fresh(); S.last = clock + 3600e3;
ok(awaySeconds(S, clock).sec === 0, '時計が戻っていたら留守は0秒');
S.last = clock - 30 * 3600e3;
const a = awaySeconds(S, clock); ok(a.sec === 8 * 3600 && a.capped, '留守は8時間で切る');
S.creed = [null, null, null, 'a']; ok(awaySeconds(S, clock).sec === 12 * 3600, '社訓「留守番上手」で12時間');

// 留守の計算は元の状態を書き換えず、受け取りで仲間とつるはしを保つ
S = fresh(); S.w[0] = 5; S.pick = 4; const before = JSON.stringify(S);
const r = simulateAway(S, 3600);
ok(JSON.stringify(S) === before, '留守の計算は元の状態を書き換えない');
const S2 = claimAwayState(S, r, 2);
ok(S2.w[0] === 5 && S2.pick === 4 && Math.abs(S2.ore - (S.ore + r.ore * 2)) < 1e-6, '2倍で受け取ると鉱石が2倍、仲間とつるはしはそのまま');

// 代替わり：図鑑・かけら・名声は残り、深さ・仲間は戻る
S = fresh(); S.genDepth = 260; S.depth = 260; S.best = 260; S.w[3] = 9; S.found.kosen = 2; S.frag[0] = 7;
ok(canRebirth(S) && fameGain(S) > 0, '240m を越えると代替わりできる');
const g = rebirth(S, ['b']);
ok(g > 0 && S.gen === 2 && S.fame === g && S.depth === 0 && S.w[3] === 0 && S.found.kosen === 2 && S.frag[0] === 7 && S.creed[0] === 'b' && S.history.length === 1, '代替わりで残す物・戻す物');
S.genDepth = 100; ok(!rebirth(S, []), '240m 未満では代替わりできない');

// 鑑定を続ければ、運に関係なく1層ぶんが必ずそろう
S = fresh(); S.frag[2] = 1000; let n = 0;
while (appraise(S, 2, null)) n++;
ok(n === 5 && itemsOf(2).every(i => S.found[i.id]), '鑑定で1層の5種が必ずそろう');
ok(setsDone(S).includes(2), '5種そろうと層の組になる');

// ★★は層の終わり近くでしか出ない
S = fresh(); let lOut = 0; for (let k = 0; k < 3000; k++) { const it = pickItem(S, 50, mods(S)); if (it.r === 'l') lOut++; }
ok(lOut === 0, '★★は層の終わり近くでしか出ない');
let lIn = 0; for (let k = 0; k < 3000; k++) { const it = pickItem(S, 78, mods(S)); if (it.r === 'l') lIn++; }
ok(lIn > 0, '層の終わり近くでは★★が出る');

// 宝の部屋：初めては未発見の物、2回目からはかけら
S = fresh(); S.depth = 20; S.pick = 999; applyDamage(S, 1e9, null, null);
ok(speciesCountOf(S) >= 1, '宝の部屋で未発見の物が出る');
S.room = {}; const f0 = S.frag[0]; const sp = speciesCountOf(S); S.depth = 20; S.dmg = 0; applyDamage(S, hpOf(S, 20), null, null);
ok(S.frag[0] >= f0 + 3 || speciesCountOf(S) > sp, '2回目の宝の部屋はかけら');

// プレイヤーはたたかない：最初から見習い坑夫が2人いて、放っておくだけで掘れる。代替わりの後も同じ
S = fresh(); ok(S.w[0] === 2 && crewDps(S, true) > 0, '最初から見習い坑夫が2人いる');
for (let k = 0; k < 600; k++) tick(S, 1, null);
ok(S.depth > 0 && S.ore > 0, '放っておくだけで掘り進む');
ok(typeof tapOnce === 'undefined', 'たたく操作はエンジンにない');
// つるはしは仲間の力を上げる
const p1 = crewDps(S, true); S.pick = 10; ok(crewDps(S, true) > p1, 'つるはしを強くすると仲間の力が上がる');

// 広告の採掘倍率：見るたびに ×2→×3→×4→×5、見るたびに残り5分、切れたら ×1
S = fresh(); startBoost(S); ok(boostMul(S) === 2 && S.boostUntil - clock === 300e3, '1回目は ×2 を5分');
clock += 200e3; startBoost(S); ok(boostMul(S) === 3 && S.boostUntil - clock === 300e3, '5分のうちに見ると ×3、残りは5分に戻る');
for (let k = 0; k < 8; k++) startBoost(S); ok(boostMul(S) === 11, '倍率に上限はない（10回で ×11）');
ok(boostWait(S) === BOOST_GAP, '動画なしで押した直後は30秒あける');
clock += 301e3; ok(boostMul(S) === 1, '切れたら ×1');
startBoost(S); ok(boostMul(S) === 2, '切れた後はまた ×2 から');
const sw = fresh(); sw.w[0] = 10; const away1 = simulateAway(sw, 600).ore;
sw.boostLv = 3; sw.boostUntil = clock + 300e3; ok(simulateAway(sw, 600).ore > away1, '留守の間も残っていた倍率が効く');

// 古い保存や壊れた保存を読んでも落ちない
S = normalize({ v: 2, w: [1, 2], frag: null, st: null });
ok(S.w.length === WK.length && S.frag.length === NLAYER && S.st.blocks === 0, '欠けた保存を補って読む');

// まとめ買い：×10 の値段は1つずつ買った合計とほぼ同じ（端数の切り上げぶんだけずれる）、最大は買える数だけ
S = fresh(); S.ore = 1e9;
const b10 = wkBulk(S, 0, 10); let one = 0; for (let k = 0; k < 10; k++) one += wkCost(S, 0, S.w[0] + k);
ok(b10.n === 10 && Math.abs(b10.cost - one) <= 10, '×10 の値段は1つずつの合計と合う');
const bm = wkBulk(S, 0, 'max'); ok(bm.cost <= S.ore && wkBulk(Object.assign(fresh(), { ore: S.ore }), 0, bm.n + 1).cost > S.ore, '最大は買える数ちょうど');
ok(buyWorkerN(S, 0, 10) === 10 && S.w[0] === 12, 'まとめて雇える');
S = fresh(); S.ore = 1e6; const pl = S.pick; ok(buyPickN(S, 'max') > 0 && S.pick > pl && S.ore >= 0, 'つるはしも最大まで強くできる');
// 社訓「突貫」で岩盤に必要な Lv が下がる
S = fresh(); const r0 = reqAt(40, S); S.creed = [null, 'b']; ok(reqAt(40, S) < r0, '社訓「突貫」で必要な Lv が下がる');
// 岩盤は Lv が届けば普通のブロックと同じ固さ
ok(hpOf(fresh(), 40) === baseHp(40), '岩盤の固さは普通のブロックと同じ');
// 毎秒の鉱石は、仲間がいれば正の数
S = fresh(); ok(oreRate(S) > 0, '毎秒の鉱石が出る');
// 代替わりの後も見習い坑夫が2人いる
S = fresh(); S.genDepth = 250; S.depth = 250; S.best = 250; rebirth(S, ['a']); ok(S.w[0] === 2, '代替わりの後も見習い坑夫が2人');
// 壊れた保存（NaN・負の数・文字）を読んでも安全な値に戻る
S = normalize({ v: 2, ore: NaN, depth: -3, pick: 'x', w: [3, -1, 'a'], gen: 0 });
ok(S.ore === 0 && S.depth === 0 && S.pick === 1 && S.gen === 1 && S.w[1] === 0 && S.w[2] === 0 && S.w[0] === 3, '壊れた数は安全な値に戻す');
// 長い時間の自動プレイでも数が壊れない（深さ 600m・名声が大きい状態で採掘と留守を回す）
S = fresh(); S.fame = 1e6; S.pick = 400; S.w = WK.map(() => 300); S.depth = 600; S.best = 600;
for (let k = 0; k < 200; k++) tick(S, 1, null);
const rr = simulateAway(S, 8 * 3600); S = claimAwayState(S, rr, 2);
ok(isFinite(S.ore) && isFinite(S.dmg) && S.depth >= 600, '深い所でも数が壊れない');

// 課金アイテム（買い切り2つ・特製弁当）
S = fresh(); const cd0 = crewDps(S, true), off0 = mods(S).off;
S.own = { canteen: true, cart: true };
ok(Math.abs(crewDps(S, true) / cd0 - 1.25) < 1e-9, '社員食堂で仲間の力 +25%');
ok(mods(S).off === off0 + 4, '大きな荷車で留守の上限 +4時間');
S.genDepth = 250; S.depth = 250; S.best = 250; rebirth(S, ['a']); ok(owns(S, 'canteen') && owns(S, 'cart'), '買い切りは代替わりしても残る');
S = fresh(); ok(grantBento(S, 3) === 3 && S.bento === 3, '届いた弁当を受け取る');
ok(grantBento(S, 3) === 0 && S.bento === 3, '同じ合計がもう一度届いても二度渡さない');
ok(grantBento(S, 13) === 10 && S.bento === 13, '増えた分だけ足す');
const rb0 = runMul(S); ok(useBento(S) && S.bento === 12 && runMul(S) === rb0 * 2, '弁当を使うと仲間の力 ×2');
const u1 = S.bentoUntil; useBento(S); ok(S.bentoUntil - u1 === 1800e3 && runMul(S) === rb0 * 2, '重ねて使うと時間だけ延びる');
S.bento = 0; ok(!useBento(S), '手持ちがなければ使えない');
// 留守の計算にも弁当が効く（30分ぶんだけ2倍）
S = fresh(); S.w = WK.map(() => 5);
const awayA = simulateAway(S, 3600).ore;
S.bentoUntil = NOW() + 1800e3; S.last = NOW();
const awayB = simulateAway(S, 3600).ore;
ok(awayB > awayA * 1.2, '留守の間も弁当が効く');
// 消したり留守を受け取ったりしても、買った物は残る
S = fresh(); S.own = { cart: true }; S.bento = 2; S.iapGot = { bento: 2 };
S = claimAwayState(S, simulateAway(S, 60), 1); ok(owns(S, 'cart') && S.bento === 2 && S.iapGot.bento === 2, '留守の受け取りで買った物が消えない');
S = normalize({ v: 2, bento: -1, own: 'x', iapGot: null }); ok(S.bento === 0 && typeof S.own === 'object' && typeof S.iapGot === 'object', '壊れた課金の記録は安全な値に戻す');

// 家宝（先代が残すもの）
const deep = () => { const t = fresh(); t.genDepth = 300; t.depth = 300; t.best = 300; t.pick = 150; t.w = [10, 8, 6, 30, 0, 0, 0]; t.ore = 1e6; return t; };
S = deep(); let cs = heirCands(S);
ok(cs.length === 3 && new Set(cs.map(c => c.k)).size === 3 && cs.every(c => HEIRS[c.k] && c.lv === 1), '家宝の候補は3つで重ならない');
ok(JSON.stringify(heirCands(S)) === JSON.stringify(cs), '同じ代なら候補は何度見ても同じ');
rebirth(S, ['a'], { k: 'pick' }); ok(S.pick === 15 && heirLv(S, 'pick') === 1, '先代のつるはし：先代の Lv の10%から始まる');
ok(S.history[0].heir.k === 'pick', '社史に残した家宝が残る');
S = deep(); rebirth(S, ['a'], { k: 'roster' }); ok(S.w[3] === 2 && S.w[0] === 2, '先代の名簿：いちばん多く雇った仲間を連れて始まる');
S = deep(); rebirth(S, ['a'], { k: 'safe' }); ok(S.ore === START_ORE + 50000, '先代の金庫：手持ちの5%を持ち越す');
S = deep(); rebirth(S, ['a'], { k: 'map' }); ok(S.mapTo === 150 && mapMul(S) === 2, '先代の地図：最深の半分までは2倍');
S.depth = 150; ok(mapMul(S) === 1, '地図の深さを過ぎたら元の速さ');
S = deep(); const fg0 = fameGain(S); S.heir = [{ k: 'map', lv: 1 }]; ok(fameGain(S) < fg0, '地図の代償：名声が減る');
// 同じ物で Lv が上がり、棚は3つまで。いっぱいなら手放す物を選ばないと入らない
S = fresh(); ok(takeHeir(S, 'pick') && takeHeir(S, 'pick') && heirLv(S, 'pick') === 2, '同じ家宝で Lv が上がる');
takeHeir(S, 'pick'); ok(!takeHeir(S, 'pick') && heirLv(S, 'pick') === 3, 'Lv は3まで');
takeHeir(S, 'map'); takeHeir(S, 'diary'); ok(!takeHeir(S, 'safe') && S.heir.length === 3, '棚がいっぱいなら、手放す物を選ばないと入らない');
ok(takeHeir(S, 'safe', 0) && S.heir.length === 3 && !heirLv(S, 'pick') && heirLv(S, 'safe') === 1, '手放すと新しい家宝が入る');
S = deep(); S.heir = [{ k: 'pick', lv: 3 }]; ok(!heirCands(S).some(c => c.k === 'pick'), 'Lv3 の家宝は候補に出ない');
S = deep(); rebirth(S, ['a'], null); ok(S.heir.length === 0 && S.history[0].heir === null, '受け取らなくても代替わりできる');
S = normalize({ v: 2, heir: [{ k: 'pick', lv: 9 }, { k: 'xxx', lv: 1 }, null] }); ok(S.heir.length === 1 && S.heir[0].lv === 3, '壊れた家宝の記録は直す');
// 留守の計算でも、地図の速さは地図の深さまで
S = fresh(); S.w = WK.map(() => 3); S.heir = [{ k: 'map', lv: 3 }]; S.mapTo = 5; S.last = NOW();
const awayMap = simulateAway(S, 8 * 3600); S.heir = []; const awayNo = simulateAway(S, 8 * 3600);
ok(awayMap.meters < awayNo.meters * 1.5, '留守でも地図は地図の深さまでしか効かない');

// 動画の特典（留守3倍・名声2倍・鉱脈3倍）
S = fresh(); S.w = WK.map(() => 2); S.last = NOW();
const ra = simulateAway(S, 3600); const o0 = S.ore;
const s3 = claimAwayState(JSON.parse(JSON.stringify(S)), ra, AD_AWAY);
ok(AD_AWAY === 3 && Math.abs((s3.ore - o0) - ra.ore * 3) < Math.max(1, ra.ore * 1e-6), '留守を動画で3倍に');
S = fresh(); S.genDepth = 280; S.depth = 280; S.best = 280; const fg = fameGain(S); rebirth(S, ['a'], null, AD_FAME);
ok(S.fame === Math.floor(fg * 2) && S.history[0].fame === Math.floor(fg * 2), '代替わりの名声を動画で2倍に');
S = fresh(); S.w = WK.map(() => 2); const vo = S.ore, vg = claimVein(S), vx = veinBonus(S, vg);
ok(Math.abs(S.ore - vo - vg * 3) < 1e-6 && vx === vg * 2, '鉱脈を動画で3倍に');

if (fails) { console.log(`\n${fails}件 NG`); process.exit(1); }
console.log('\nすべて ok');
