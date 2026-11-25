// 英語（日本語を学ぶ人向け）の表示の確かめ: ローマ字・ことばの意味・画面の文字
var assert = require('assert'), fs = require('fs'), path = require('path');
var W = require('../prototype/words.js'), M = require('../prototype/meanings.js');
var all = W.short.concat(W.middle, W.long);

// 1. ことばのほとんどに意味がある（無いのは辞書に載らない切れ端だけ）
var missing = all.filter(function (w) { return !M[w]; });
assert.deepStrictEqual(missing, [], '意味の無いことば（辞書に無い切れ端は words.js から外す）');
// 学ぶ人に見せない言葉（2026-11-25 に英語の意味を見て外した。死体・犯罪・股間など）
['したい', 'まいそう', 'けつ', 'こかん', 'ほうか', 'はんにん', 'はんこう', 'かんきん', 'ふはい', 'とらわれ', 'くちふえ'].forEach(function (w) { assert.ok(all.indexOf(w) < 0, '外したはずの言葉がある: ' + w); });
assert.ok(M['うまい'] && /delicious/.test(M['うまい'][1]), 'うまい は delicious（skillful ではなく）');
Object.keys(M).forEach(function (w) {
  var m = M[w];
  assert.ok(Array.isArray(m) && m.length === 2 && typeof m[0] === 'string' && m[1], '形がおかしい: ' + w);
  assert.ok(m[1].length <= 28, '意味が長すぎて画面からはみ出す: ' + w + ' ' + m[1]);
  assert.ok(!/[()（）]/.test(m[1]), '括弧の補足が残っている: ' + w + ' ' + m[1]);
});
// 2. 手で選んだことばは、ねらった意味になっている（頻度で選ぶと とり→取り、りす→骨折 になっていた）
var want = { 'ねこ': 'cat', 'とり': 'bird', 'りす': 'squirrel', 'いか': 'squid', 'たこ': 'octopus', 'しか': 'deer',
  'かき': 'persimmon', 'かえる': 'frog', 'はし': 'bridge', 'めろん': 'melon', 'さくら': 'cherry' };
Object.keys(want).forEach(function (w) { assert.ok(M[w] && M[w][1].indexOf(want[w]) >= 0, w + ' の意味: ' + (M[w] && M[w][1])); });

// 3. 画面の中のローマ字（index.html の romaji を取り出して動かす）
var html = fs.readFileSync(path.join(__dirname, '../prototype/index.html'), 'utf8');
var src = html.slice(html.indexOf('var ROMA = {'), html.indexOf('window.__romaji'));
var romaji = new Function(src + 'return romaji;')();
[['ねこ', 'neko'], ['しかく', 'shikaku'], ['つち', 'tsuchi'], ['ふね', 'fune'], ['きんえん', "kin'en"], ['ほんや', "hon'ya"], ['さんぽ', 'sanpo'], ['ほん', 'hon'], ['てんき', 'tenki']]
  .forEach(function (c) { if (c[0] === 'さんぽ') return; assert.strictEqual(romaji(c[0]), c[1], c[0]); });
// 濁点・小さい字（2026-11-25）
[['さんぽ', 'sanpo'], ['かぜ', 'kaze'], ['ぶどう', 'budou'], ['きょう', 'kyou'], ['しゃしん', 'shashin'], ['ちゃわん', 'chawan'], ['じゅんばん', 'junban'],
 ['きって', 'kitte'], ['まっちゃ', 'matcha'], ['がっこう', 'gakkou'], ['いっぱい', 'ippai'], ['きんようび', "kin'youbi"], ['りょこう', 'ryokou'], ['にゅうがく', 'nyuugaku']]
  .forEach(function (c) { assert.strictEqual(romaji(c[0]), c[1], c[0]); });
var KINDS = Object.keys(require('../prototype/glyphs.js').chars);
KINDS.forEach(function (k) { assert.ok(/^\(?[a-z]+\)?$/.test(romaji(k)), 'ローマ字の無い字: ' + k); });
// ことばの中に、読めない（ローマ字にならない）字が残らない
require('../prototype/words.js').short.concat(require('../prototype/words.js').middle, require('../prototype/words.js').long)
  .forEach(function (w) { assert.ok(/^[a-z']+$/.test(romaji(w)), 'ローマ字にならないことば: ' + w + ' → ' + romaji(w)); });

// 4. 画面の文字: 日本語の文字列は T('日本語', 'English') の形で英語と対になっている。
//    （英語の画面に日本語が残らないように。決まった例外だけ許す: ローマ字の表・英語を先に書いた三項・試作だけのボタン・クレジットの日本語の段）
// 改行が CRLF でも見つける（手元の Windows では CRLF で見つからず、この点検が素通りしていた。2026-11-25）
var body = html.replace(/\r\n/g, '\n'); body = body.slice(body.indexOf('<script>\n(function'));
assert.ok(body.length > 10000, 'ゲームの script が見つからない');
var lines = body.split('\n'), bad = [];
lines.forEach(function (line, i) {
  var code = line.replace(/\/\/.*$/, '');
  if (!/'[^']*[ぁ-んァ-ヶ一-龠][^']*'/.test(code)) return;
  if (/T\(|ROMA|name: '|ja: |試作用|normal:ふつう|mini\('|fillText\('(ねこ|うみ)'|lang="ja"|: \{ glue: \[|glue: \['のり'|cancelled: ''|declined: '|'tenbin-kana-|kana \+ |\['ねこ'|^\s*'[ぁ-ん]': '[a-z]+'|lang === 'en' \?|id="unbuy"|MIT）|CC BY-SA 4\.0）|speak\('ねこ', true\)|YOON|SMALL_ROMA|=== 'っ'|measureText\('あ'\)|KANA_SAY = /.test(code)) return;
  bad.push((i + 1) + ': ' + line.trim().slice(0, 100));
});
assert.deepStrictEqual(bad, [], '英語と対になっていない日本語の文字列');
// 5. 読み上げ: 日本語の声で、ひらがなのまま読む（漢字を読ませると読みを取り違える）。押したことばを読む
assert.ok(/u\.lang = 'ja-JP'/.test(html) && /new SpeechSynthesisUtterance\(w\)/.test(html), '読み上げが日本語・ひらがなでない');
assert.ok(/data-say="' \+ w \+ '"/.test(html) && /data-say="' \+ a\.text \+ '"/.test(html), 'ことば帳・結果のことばを押して読み上げられない');
// 5b. 押したことばは、音が無い端末でも意味の札が出る（日本語の画面でも意味を見られる）
assert.ok(/function showWord\(w\)/.test(html) && /closest\('\[data-say\]'\)[^\n]*showWord\(/.test(html), 'ことばを押しても意味の札が出ない');
assert.ok(!/synth \? ' data-say=/.test(html), '音が無いと、ことばを押せない');
assert.ok(/T\('英語の意味', 'Meaning'\)/.test(html), '意味の札に意味が無い');
// 6. 意味の出どころをクレジットに出している
assert.ok(html.indexOf('JMdict') >= 0, 'クレジットに JMdict が無い');
console.log('lang ok', all.length - missing.length + '/' + all.length);
