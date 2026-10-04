#!/usr/bin/env node
// 取調室の事件データ検査。Node のみ（外部パッケージなし）。
//
//   node projects/torishirabe/tool/check_cases.js            … 検査。1つでも外れたら終了コード1
//   node projects/torishirabe/tool/check_cases.js --list     … 検査のあと、事件一覧を Markdown の表で出す
//   node projects/torishirabe/tool/check_cases.js 別の.html  … 別のファイルを検査する
//
// prototype/game.html の /*DATA-START*/ 〜 /*DATA-END*/ を読み、事件ごとに確かめる:
//   1. facts と食い違う証言の行がちょうど1つで、その人が culprit（answer.testimony もその証言）
//   2. その行を否定する手がかりがちょうど1枚で、answer.clue と一致する。他の組では食い違いが起きない
//      （手がかりの主張はすべて facts どおり）
//   3. via の特徴が facts どおりで、本人の証言か別の手がかりで確定している。同じ特徴の人が他にいない
//   4. 手がかりの本文に word（省略時は value）と via の値が含まれる
//   5. id の重複がない、参照先（人物・証言・手がかり・facts の見出し）が全部ある
//   6. kind（見破り方の種類）が中身と合っている
//        居場所 / 時刻 / 持ち物 … via なし。嘘の行の見出しに「居場所」「時刻」「持」を含む
//        特徴       … via あり。特徴を本人が証言している
//        組み合わせ … via あり。特徴は本人の証言になく、別の手がかりでだけ確定する

"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const args = process.argv.slice(2);
const wantList = args.includes("--list");
const fileArg = args.find(a => !a.startsWith("--"));
const FILE = fileArg ? path.resolve(fileArg) : path.join(__dirname, "..", "prototype", "game.html");

const LEVELS = ["易しい", "普通", "難しい"];
const KINDS = ["居場所", "時刻", "持ち物", "特徴", "組み合わせ"];

function fatal(msg) {
  console.error("NG: " + msg);
  process.exit(1);
}

// --- データを取り出す（印が見つからない・重複するなら止める） ---
let html;
try { html = fs.readFileSync(FILE, "utf8"); } catch (e) { fatal(`${FILE} が読めない: ${e.message}`); }
const START = "/*DATA-START*/", END = "/*DATA-END*/";
const count = (s, sub) => s.split(sub).length - 1;
if (count(html, START) !== 1) fatal(`${START} がちょうど1つでない（${count(html, START)} 個）`);
if (count(html, END) !== 1) fatal(`${END} がちょうど1つでない（${count(html, END)} 個）`);
const src = html.slice(html.indexOf(START) + START.length, html.indexOf(END));
if (!src.trim()) fatal("DATA-START と DATA-END の間が空");
let CASES;
try { CASES = vm.runInNewContext("(" + src + ")", Object.create(null), { timeout: 2000 }); }
catch (e) { fatal("データが JavaScript として読めない: " + e.message); }
if (!Array.isArray(CASES) || CASES.length === 0) fatal("データが空でない配列ではない");

// --- 検査 ---
const errors = [];
const rows = [];
const caseIds = new Set();

CASES.forEach((c, ci) => {
  const tag = `[${ci + 1}番目 ${c && c.id ? c.id : "?"} ${c && c.title ? c.title : ""}]`;
  const err = m => errors.push(`${tag} ${m}`);
  if (!c || typeof c !== "object") { err("事件が object でない"); return; }

  // 基本の欄
  for (const f of ["id", "level", "title", "summary", "solution", "culprit", "kind"]) {
    if (typeof c[f] !== "string" || !c[f].trim()) err(`${f} が無いか空`);
  }
  if (caseIds.has(c.id)) err(`事件 id「${c.id}」が重複`);
  caseIds.add(c.id);
  if (!LEVELS.includes(c.level)) err(`level「${c.level}」は ${LEVELS.join("/")} のどれでもない`);
  if (!KINDS.includes(c.kind)) err(`kind「${c.kind}」は ${KINDS.join("/")} のどれでもない`);
  for (const f of ["persons", "testimonies", "clues"]) {
    if (!Array.isArray(c[f]) || c[f].length === 0) { err(`${f} が無いか空`); return; }
  }
  if (!c.facts || typeof c.facts !== "object") { err("facts が無い"); return; }
  if (!c.answer || typeof c.answer !== "object") { err("answer が無い"); return; }

  // 人物
  const pById = new Map(), pByName = new Map();
  for (const p of c.persons) {
    if (!p.id || !p.name || !p.role) err(`人物の id/name/role が欠けている: ${JSON.stringify(p)}`);
    if (pById.has(p.id)) err(`人物 id「${p.id}」が重複`);
    if (pByName.has(p.name)) err(`人物名「${p.name}」が重複`);
    pById.set(p.id, p); pByName.set(p.name, p);
  }

  // facts の見出し
  for (const k of Object.keys(c.facts)) {
    if (k.split("|").length !== 2 || k.split("|").some(s => !s)) err(`facts の見出し「${k}」は「主|属性」の形でない`);
    if (typeof c.facts[k] !== "string" || !c.facts[k]) err(`facts「${k}」の値が空`);
  }
  const hasFact = k => Object.prototype.hasOwnProperty.call(c.facts, k);

  // 証言・手がかりの id（カードは data-id を共有するので両方あわせて重複禁止）
  const cardIds = new Set();
  const tById = new Map(), kById = new Map();
  const testifiers = new Set();
  for (const t of c.testimonies) {
    if (!t.id) err("証言に id が無い");
    if (cardIds.has(t.id)) err(`カード id「${t.id}」が重複`);
    cardIds.add(t.id); tById.set(t.id, t);
    if (!pById.has(t.person)) err(`証言 ${t.id} の person「${t.person}」が persons に無い`);
    if (testifiers.has(t.person)) err(`${t.person} の証言が2枚ある`);
    testifiers.add(t.person);
    if (!Array.isArray(t.lines) || t.lines.length === 0) { err(`証言 ${t.id} に行が無い`); continue; }
    for (const l of t.lines) {
      if (!l.text || !l.key || typeof l.value !== "string") err(`証言 ${t.id} の行に text/key/value が欠けている: ${JSON.stringify(l)}`);
      else if (!hasFact(l.key)) err(`証言 ${t.id}「${l.text}」の key「${l.key}」が facts に無い`);
    }
  }
  for (const p of c.persons) if (!testifiers.has(p.id)) err(`${p.name} の証言が無い`);
  for (const k of c.clues) {
    if (!k.id || !k.title || !k.text) err(`手がかりに id/title/text が欠けている: ${k.id}`);
    if (cardIds.has(k.id)) err(`カード id「${k.id}」が重複`);
    cardIds.add(k.id); kById.set(k.id, k);
    if (!Array.isArray(k.claims) || k.claims.length === 0) { err(`手がかり ${k.id} に主張が無い`); continue; }
    for (const cl of k.claims) {
      if (!cl.key || typeof cl.value !== "string") { err(`手がかり ${k.id} の主張に key/value が無い`); continue; }
      if (!hasFact(cl.key)) { err(`手がかり ${k.id} の key「${cl.key}」が facts に無い`); continue; }
      // 手がかりは嘘をつかない
      if (c.facts[cl.key] !== cl.value) err(`手がかり ${k.id} の主張「${cl.key}=${cl.value}」が facts（${c.facts[cl.key]}）と違う`);
      const word = cl.word != null ? cl.word : cl.value;
      if (!word || !k.text.includes(word)) err(`手がかり ${k.id} の本文に「${word}」が含まれない`);
    }
  }

  // 参照先
  if (!pById.has(c.culprit)) err(`culprit「${c.culprit}」が persons に無い`);
  if (!tById.has(c.answer.testimony)) err(`answer.testimony「${c.answer.testimony}」が無い`);
  if (!kById.has(c.answer.clue)) err(`answer.clue「${c.answer.clue}」が無い`);

  // 1. facts と食い違う証言の行
  const lies = [];
  for (const t of c.testimonies) for (const l of (t.lines || [])) {
    if (hasFact(l.key) && c.facts[l.key] !== l.value) lies.push({ t, l });
  }
  if (lies.length !== 1) {
    err(`facts と食い違う証言の行が ${lies.length} 個（ちょうど1つのはず）` +
      lies.map(x => `\n      ${x.t.id}「${x.l.text}」`).join(""));
    return;
  }
  const lie = lies[0];
  if (lie.t.person !== c.culprit) err(`嘘の行は ${lie.t.person} の証言にあるが culprit は ${c.culprit}`);
  if (lie.t.id !== c.answer.testimony) err(`嘘の行は ${lie.t.id} にあるが answer.testimony は ${c.answer.testimony}`);

  // 2. 食い違う組（証言カード × 手がかりカード）を全部数える
  const pairs = [];
  for (const t of c.testimonies) for (const k of c.clues) {
    const hit = (t.lines || []).some(l => (k.claims || []).some(cl => cl.key === l.key && cl.value !== l.value));
    if (hit) pairs.push(`${t.id}×${k.id}`);
  }
  const want = `${c.answer.testimony}×${c.answer.clue}`;
  if (pairs.length !== 1 || pairs[0] !== want) {
    err(`食い違う組が [${pairs.join(", ")}]（${want} の1組だけのはず）`);
  }
  const denying = c.clues.filter(k => (k.claims || []).some(cl => cl.key === lie.l.key));
  if (denying.length !== 1) err(`嘘の行「${lie.l.key}」に触れる手がかりが ${denying.length} 枚（ちょうど1枚のはず）`);

  // 3. via
  let answerVia = null, viaByOwn = false, viaByClue = false;
  for (const k of c.clues) for (const cl of (k.claims || [])) {
    if (!cl.via) continue;
    const v = cl.via;
    const who = cl.key.split("|")[0];
    const person = pByName.get(who);
    if (!person) { err(`手がかり ${k.id} の via 付き主張「${cl.key}」の主が人物でない`); continue; }
    if (!v.attr || typeof v.value !== "string") { err(`手がかり ${k.id} の via に attr/value が無い`); continue; }
    const fkey = `${who}|${v.attr}`;
    if (c.facts[fkey] !== v.value) { err(`手がかり ${k.id} の via「${fkey}=${v.value}」が facts（${c.facts[fkey]}）と違う`); continue; }
    const vword = v.word != null ? v.word : v.value;
    if (!k.text.includes(vword)) err(`手がかり ${k.id} の本文に via の「${vword}」が含まれない`);
    // 同じ特徴の人が他にいない
    for (const p of c.persons) {
      if (p.name !== who && c.facts[`${p.name}|${v.attr}`] === v.value) err(`via「${v.attr}=${v.value}」に ${who} と ${p.name} の二人が当てはまる`);
    }
    // 確定のしかた
    const own = c.testimonies.find(t => t.person === person.id);
    const byOwn = !!own && own.lines.some(l => l.key === fkey && l.value === v.value);
    const byClue = c.clues.some(o => o !== k && (o.claims || []).some(oc => oc.key === fkey && oc.value === v.value));
    if (!byOwn && !byClue) err(`手がかり ${k.id} の via「${fkey}」が、本人の証言にも別の手がかりにも無い`);
    if (k.id === c.answer.clue && cl.key === lie.l.key) { answerVia = v; viaByOwn = byOwn; viaByClue = byClue; }
  }

  // 6. kind
  const attr = lie.l.key.split("|")[1] || "";
  const kindOk = {
    "居場所": !answerVia && attr.includes("居場所"),
    "時刻": !answerVia && attr.includes("時刻"),
    "持ち物": !answerVia && attr.includes("持"),
    "特徴": !!answerVia && viaByOwn,
    "組み合わせ": !!answerVia && !viaByOwn && viaByClue,
  }[c.kind];
  if (kindOk === false) err(`kind「${c.kind}」が中身と合わない（嘘の行「${lie.l.key}」、via ${answerVia ? "あり" : "なし"}）`);

  const culprit = pById.get(c.culprit);
  rows.push({ title: c.title, level: c.level, culprit: culprit ? `${culprit.name}（${culprit.role}）` : c.culprit, kind: c.kind,
    persons: c.persons.length, clues: c.clues.length });
});

if (errors.length) {
  console.error(errors.map(e => "NG " + e).join("\n"));
  console.error(`\n${errors.length} 件の外れ（${CASES.length} 事件）`);
  process.exit(1);
}

const tally = (f) => rows.reduce((m, r) => (m[r[f]] = (m[r[f]] || 0) + 1, m), {});
const fmt = (m, order) => order.filter(k => m[k]).map(k => `${k}${m[k]}`).join("・");
console.log(`OK: ${CASES.length} 事件（${fmt(tally("level"), LEVELS)}／${fmt(tally("kind"), KINDS)}）`);

if (wantList) {
  console.log("\n| # | 題名 | 難しさ | 犯人 | 見破り方 | 人数 | 手がかり |");
  console.log("|---|---|---|---|---|---|---|");
  rows.forEach((r, i) => console.log(`| ${i + 1} | ${r.title} | ${r.level} | ${r.culprit} | ${r.kind} | ${r.persons} | ${r.clues} |`));
}
