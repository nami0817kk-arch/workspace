// エンジンを自動で遊ばせて、進み方を測る。
//   node tool/sim.js                … ふつうの遊び方（1日5回×5分）で35日
//   node tool/sim.js --quick        … 7日だけ（CI で「止まらない・壊れない」ことを見る）
//   PLAY=heavy node tool/sim.js     … よく遊ぶ人（1日5回、合わせて80分）
//   CREED=abbaab node tool/sim.js   … 社訓の選び方（組ごとに a か b）
//   DAYS=60 / SEED=3 / LOG=1（その回ごとの行を出す）
const fs = require('fs'), vm = require('vm'), path = require('path');
const file = 'game.html';
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', file), 'utf8');
const eng = src.split('/*ENGINE-START*/')[1].split('/*ENGINE-END*/')[0];
vm.runInThisContext(eng + ';globalThis.__setClock=f=>{NOW=f};globalThis.__setRng=f=>{RNG=f};');

const QUICK = process.argv.includes('--quick');
const DAYS = +(process.env.DAYS || (QUICK ? 7 : 35));
const PLAY = process.env.PLAY || 'casual';
const CREED = (process.env.CREED || 'bbbaab').split('');
const LOG = !!process.env.LOG;
let seed = +(process.env.SEED || 1);
__setRng(() => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x80000000; });
let clock = Date.UTC(2026, 0, 1, 0, 0, 0) - 9 * 3600e3;   // 1日目 0:00（日本時間）
__setClock(() => clock);

// [時, 分の長さ]
const SES = PLAY === 'heavy' ? [[7, 20], [12, 15], [18, 15], [21, 20], [23, 10]] : [[8, 5], [12, 5], [17, 5], [20, 5], [23, 5]];
const ADS = PLAY !== 'noads';   // 広告を見る人：毎回の最初に採掘の倍率、留守は2倍で受け取る

function buy(S){
  for (let g = 0; g < 2000; g++) {
    const M = mods(S);
    const req = isBed(S.depth) ? reqAt(S.depth) : 0;
    const opts = [];
    const pc = pickCost(S, S.pick), base = crewBase(S, M), pb = pickBoost(S, M);
    let pv = base * pb * (pickMul(S.pick + 1) / pickMul(S.pick) - 1);
    if (S.pick < req) pv = 1e300;
    opts.push({ c: pc, v: pv / pc, f: () => buyPick(S) });
    WK.forEach((w, i) => { const c = wkCost(S, i, S.w[i], M); opts.push({ c, v: w.dps * (i < HUMAN ? M.human : M.machine) * CREW_K * pb / c, f: () => buyWorker(S, i) }); });
    opts.sort((a, b) => b.v - a.v);
    const o = opts[0];
    if (S.ore < o.c) return;
    o.f();
  }
}
function useFrags(S){
  for (let L = 0; L < NLAYER; L++) {
    while (appraise(S, L, null)) {}
    if (appraiseCost(S, L) == null) while (S.frag[L] > 0) sellFrag(S, L);
  }
}
let S = fresh();
const firstLayer = {}, rebirths = [], daily = [];
let lastProg = 0, stall = 0;
const tm = () => { const d = (clock - (Date.UTC(2026, 0, 1) - 9 * 3600e3)) / 864e5; return `${Math.floor(d) + 1}日目${String(Math.floor(d % 1 * 24)).padStart(2, '0')}時`; };
const note = () => { const L = Math.floor(S.best / LAYER_LEN); for (let k = 1; k <= L; k++) if (!firstLayer[k]) firstLayer[k] = tm(); };
for (let day = 1; day <= DAYS; day++) {
  for (const [h, len] of SES) {
    const start = Date.UTC(2026, 0, day, h, 0, 0) - 9 * 3600e3 - 864e5 + 864e5 * 0 ;
    const t0 = Date.UTC(2026, 0, 1) - 9 * 3600e3 + (day - 1) * 864e5 + h * 3600e3;
    if (S.last && t0 > S.last) {
      clock = t0;
      const a = awaySeconds(S, clock);
      if (a.sec > 60 && crewDps(S, false) > 0) { const r = simulateAway(S, a.sec); S = claimAwayState(S, r, ADS ? 2 : 1); }
    }
    clock = t0;
    // 代替わり：名声が倍になるか、3回続けて進みが止まったら
    if (canRebirth(S)) {
      const g = fameGain(S);
      if (g >= S.fame + 5 || (stall >= 3 && g >= S.fame * 0.3)) {
        const cr = CREED.slice(0, creedSlots(S.gen)).map(c => c);
        rebirths.push(`${tm()} ${S.gen}代目→ 深さ${S.genDepth}m 名声+${g}`);
        rebirth(S, cr); stall = 0; lastProg = 0;
      }
    }
    // 広告を見る人は毎回の最初に1本（×2）。よく遊ぶ人は最初に4本（×5）、そのあとも5分ごとに1本ずつ上げる
    if (ADS) for (let k = 0; k < (PLAY === 'heavy' ? 4 : 1); k++) startBoost(S);
    let veinT = 0;
    for (let s = 0; s < len * 60; s++) {
      clock += 1000;
      tick(S, 1, null);
      if (PLAY === 'heavy' && s % 300 === 299) startBoost(S);
      if (++veinT >= 120) { veinT = 0; if (RNG() < 0.7) claimVein(S); }
      if (s % 5 === 0) buy(S);
      if (s % 60 === 0) useFrags(S);
    }
    buy(S); useFrags(S); checkAch(S);
    S.last = clock;
    note();
    if (S.genDepth <= lastProg + 1) stall++; else stall = 0;
    lastProg = S.genDepth;
    if (LOG) console.log(`${tm()} ${S.gen}代 深さ${S.depth}m Lv${S.pick} 仲間${S.w.join('/')} 図鑑${speciesCountOf(S)} 名声${S.fame}`);
  }
  daily.push({ day, best: S.best, gen: S.gen, z: speciesCountOf(S), sets: setsDone(S).length, ach: Object.keys(S.ach).length });
}
for (const k of Object.keys(S)) if (typeof S[k] === 'number' && !isFinite(S[k])) throw new Error('数値が壊れた: ' + k);
console.log(`遊び方=${PLAY} 社訓=${CREED.join('')} ${DAYS}日`);
console.log('層の底に初めて着いた日: ' + Object.entries(firstLayer).map(([k, v]) => `${k}層 ${v}`).join(' / '));
console.log('代替わり:\n  ' + rebirths.join('\n  '));
const pickDays = [1, 2, 3, 5, 7, 10, 14, 21, 28, 35, 42, 60].filter(d => d <= DAYS);
console.log('日 | 最深 | 代 | 図鑑 | 組 | 実績');
for (const d of pickDays) { const x = daily[d - 1]; console.log(`${x.day}日目 | ${x.best}m | ${x.gen} | ${x.z} | ${x.sets} | ${x.ach}`); }
