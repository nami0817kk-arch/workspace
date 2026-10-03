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
ok(S2.w[0] === 5 && S2.pick === 4 && Math.abs(S2.ore - r.ore * 2) < 1e-6, '2倍で受け取ると鉱石が2倍、仲間とつるはしはそのまま');

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
for (let k = 0; k < 5; k++) startBoost(S); ok(boostMul(S) === 5, '倍率は ×5 まで');
clock += 301e3; ok(boostMul(S) === 1, '切れたら ×1');
startBoost(S); ok(boostMul(S) === 2, '切れた後はまた ×2 から');
const sw = fresh(); sw.w[0] = 10; const away1 = simulateAway(sw, 600).ore;
sw.boostLv = 3; sw.boostUntil = clock + 300e3; ok(simulateAway(sw, 600).ore > away1, '留守の間も残っていた倍率が効く');

// 古い保存や壊れた保存を読んでも落ちない
S = normalize({ v: 2, w: [1, 2], frag: null, st: null });
ok(S.w.length === WK.length && S.frag.length === NLAYER && S.st.blocks === 0, '欠けた保存を補って読む');

if (fails) { console.log(`\n${fails}件 NG`); process.exit(1); }
console.log('\nすべて ok');
