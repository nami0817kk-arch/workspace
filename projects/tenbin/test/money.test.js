// 広告と「広告を消す」の決まり（prototype/monetization.js）
var assert = require('assert'), T = require('../prototype/monetization.js');
function prefs() { var d = {}; return { get: function (k, v) { return k in d ? d[k] : v; }, set: function (k, v) { d[k] = v; }, d: d }; }
function setup(mode, presentResult) {
  var clock = { t: 0 }, shown = [];
  var ads = new T.FakeAds({ mode: mode || 'normal', loadMs: 5, now: function () { return clock.t; },
    present: function (kind) { shown.push(kind); return Promise.resolve(presentResult || 'earned'); } });
  var p = prefs(), m = new T.Money(p, ads, new T.FakeStore());
  return { m: m, ads: ads, p: p, clock: clock, shown: shown };
}
(async function () {
  // 動画: 最後まで見たら渡す
  var a = setup(); await a.m.start(); await new Promise(function (r) { setTimeout(r, 20); });
  assert.strictEqual(await a.m.beforeReward(), 'granted');
  assert.deepStrictEqual(a.shown, ['rewarded']);
  // 1本は1回だけ。次は読み直してから出す（読み込み中なら待つ）
  var waited = false;
  assert.strictEqual(await a.m.beforeReward(function () { waited = true; }), 'granted');
  // 途中で閉じたら渡さない
  var b = setup('closeEarly'); await b.m.start();
  assert.strictEqual(await b.m.beforeReward(), 'declined');
  // 在庫が無ければ渡さない（タダでは渡さない）
  var c = setup('nofill'); await c.m.start();
  assert.strictEqual(await c.m.beforeReward(), 'unavailable');
  // 表示に失敗したら渡さない
  var d = setup('showFail'); await d.m.start(); await new Promise(function (r) { setTimeout(r, 20); });
  assert.strictEqual(await d.m.beforeReward(), 'showFailed');
  // 裏に回っている間は出さない
  var e = setup(); e.m.isForeground = function () { return false; }; await e.m.start(); await new Promise(function (r) { setTimeout(r, 20); });
  assert.strictEqual(await e.m.beforeReward(), 'unavailable'); assert.strictEqual(e.shown.length, 0);
  // 広告は55分で期限切れ（1時間で切れるため）。期限切れは出さずに読み直す
  var f = setup(); await f.m.start(); await new Promise(function (r) { setTimeout(r, 20); });
  assert.ok(f.ads.isRewardedReady()); f.clock.t = 56 * 60 * 1000; assert.ok(!f.ads.isRewardedReady(), '期限切れなのに出せる扱い');
  assert.strictEqual(await f.m.beforeReward(), 'granted', '期限切れのあと読み直して出せない');

  // 全画面: はじめの3回は出さない。そのあと3回に1回
  var g = setup(); await g.m.start();
  var shownAt = [];
  for (var game = 1; game <= 12; game++) {
    g.m.gameEnded(); await new Promise(function (r) { setTimeout(r, 10); });   // 結果を見ている間に読み込む
    if (await g.m.beforeNextGame(true)) shownAt.push(game);
  }
  // はじめの3回を見送ったあと、4・5・6回目と数えて6回目のあとに初めて出る
  assert.deepStrictEqual(shownAt, [6, 9, 12], '全画面の出る回が違う: ' + shownAt);
  // 在庫が無ければ数えはそのまま（次にもう一度試す）
  var h = setup(); await h.m.start(); for (game = 0; game < 4; game++) h.m.gameEnded();
  h.ads.mode = 'nofill'; h.ads.ready.interstitial = null;
  h.p.set('sinceAd', 2); assert.strictEqual(await h.m.beforeNextGame(true), false); assert.strictEqual(h.p.get('sinceAd'), 3);

  // 広告を消す: 全画面が出ない・動画なしで渡す。復元でも戻る
  var k = setup(); await k.m.start(); await k.m.buy();
  assert.ok(k.m.adFree()); assert.strictEqual(await k.m.beforeReward(), 'granted'); assert.deepStrictEqual(k.shown, []);
  for (game = 0; game < 10; game++) { k.m.gameEnded(); assert.strictEqual(await k.m.beforeNextGame(true), false); }
  var store = k.m.store, k2 = new T.Money(prefs(), new T.FakeAds({ loadMs: 1 }), store);
  assert.strictEqual(await k2.restore(), 'purchased'); assert.ok(k2.adFree(), '購入の復元で広告が消えない');
  console.log('money ok');
})().catch(function (e) { console.error(e); process.exit(1); });
