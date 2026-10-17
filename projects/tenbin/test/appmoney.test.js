// アプリの中で動くとき（AppMoney）: 頼みを post で出し、返事（tenbin* の関数）で進む。
// 番号の違う返事・「やめる」のあとの返事は捨てる。全画面の数えはこちらに残り、出すのはアプリに頼む
var assert = require('assert'), T = require('../prototype/monetization.js');
function prefs() { var d = {}; return { get: function (k, v) { return k in d ? d[k] : v; }, set: function (k, v) { d[k] = v; }, d: d }; }
(async function () {
  var sent = [], clock = { t: 0 }, p = prefs();
  var m = new T.AppMoney(p, function (o) { sent.push(o); }, { adFree: false }, { now: function () { return clock.t; } });
  // 動画: 頼みが出て、同じ番号の返事で決まる
  var waited = false, r = m.beforeReward(function () { waited = true; });
  assert.deepStrictEqual(sent.pop(), { type: 'reward', id: 1 });
  globalThis.tenbinAdWaiting(); assert.ok(waited, '読み込み中が届かない');
  globalThis.tenbinAdResult('granted', 99);   // 別の番号は捨てる
  globalThis.tenbinAdResult('granted', 1);
  assert.strictEqual(await r, 'granted');
  // 前の動画を扱っている間は受けない
  var r2 = m.beforeReward(); assert.strictEqual(await m.beforeReward(), 'unavailable');
  globalThis.tenbinAdResult('declined', 2); assert.strictEqual(await r2, 'declined');
  // やめる: アプリに知らせ、あとから届いた結果は捨てる
  var r3 = m.beforeReward(); m.cancelReward();
  assert.deepStrictEqual(sent.slice(-2), [{ type: 'reward', id: 3 }, { type: 'rewardCancel', id: 3 }]);
  assert.strictEqual(await r3, 'cancelled');
  globalThis.tenbinAdResult('granted', 3);   // 何も起きない
  // 全画面: 数えはこちら。番になったらアプリに出してもらい、閉じたら次へ
  for (var g = 0; g < 5; g++) m.gameEnded();
  p.set('sinceAd', 2); clock.t = 10 * 60 * 1000;   // 動画から十分たった
  sent.length = 0;
  var b = m.beforeNextGame(true);
  assert.deepStrictEqual(sent, [{ type: 'between' }]);
  globalThis.tenbinBetweenDone(true); assert.strictEqual(await b, true); assert.strictEqual(p.get('sinceAd'), 0);
  // 出せなかったら数えを戻す
  p.set('sinceAd', 2); b = m.beforeNextGame(true); globalThis.tenbinBetweenDone(false);
  assert.strictEqual(await b, false); assert.strictEqual(p.get('sinceAd'), 3);
  // 次に出す番なら、結果を見ている間に読み込みを頼む
  sent.length = 0; p.set('sinceAd', 2); m.gameEnded(); assert.deepStrictEqual(sent, [{ type: 'prepInter' }]);
  // 買う: アプリの状態が届いたら終わり。広告を消したら動画なしで渡し、全画面も頼まない
  var bought = m.buy(); assert.deepStrictEqual(sent.pop(), { type: 'buy' });
  var msgs = []; m.onChange(function (msg) { msgs.push(msg); });
  globalThis.tenbinSetApp({ adFree: true, msg: '広告を消しました' });
  assert.strictEqual(await bought, 'purchased'); assert.deepStrictEqual(msgs, ['広告を消しました']);
  assert.strictEqual(await m.beforeReward(), 'granted');
  sent.length = 0; p.set('sinceAd', 2); assert.strictEqual(await m.beforeNextGame(true), false); assert.deepStrictEqual(sent, []);
  console.log('appmoney ok');
})().catch(function (e) { console.error(e); process.exit(1); });
