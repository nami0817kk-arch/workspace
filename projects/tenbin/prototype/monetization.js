// 広告と「広告を消す」の決まり（2026-10-04 ユーザー指示「広告の仕組みを作って」）。画面から切り離してあり、node で試験する。
// アプリ（Flutter）にするときは、この決まりを goso-boat の lib/monetization と同じ形の Dart に移し、
// FakeAds / FakeStore を AdMob と StoreKit の実装に差し替える。
//
// - 動画（報酬）: 「つづける」（崩れたあと1回の遊びで1回）と「アイテムをもらう」（アイテムありのとき1回の遊びで1回）。
//   最後まで見たときだけ渡す。読み込めない・途中で閉じた・表示に失敗したら渡さない（タダでは渡さない）
// - 全画面: 結果から次を始めるとき、3回に1回。遊び始めの3回（入れてすぐ）は出さない
// - 広告を消す（買い切り）: 全画面が出ない。動画は見ずに つづける・もらえる
// docs/app-pitfalls.md の穴への備え:
//   2 ごほうびは画面の状態を見ずに渡す（呼ぶ側は onReward を必ず実行する。二度は渡さない）
//   3 広告は55分で読み直す（1時間で期限切れ）。出すまで間がある全画面は、出す直前ではなく結果を見ている間に読む
var TenbinMoney = (function () {
  var INTERSTITIAL_EVERY = 3, FREE_GAMES = 3, REWARD_WAIT_MS = 6000, AD_LIFETIME_MS = 55 * 60 * 1000;
  var REWARD = { earned: 'earned', closedEarly: 'closedEarly', unavailable: 'unavailable', showFailed: 'showFailed' };

  // 偽の広告。読み込みに少し時間がかかり、55分で期限切れになる。ふるまい（mode）を切り替えて失敗の流れも試せる。
  // present(kind) は画面が渡す「広告を見せる」部分（試作では待ち画面）。'earned' | 'closed' を返す
  function FakeAds(opts) {
    opts = opts || {};
    this.mode = opts.mode || 'normal';   // normal | nofill（在庫なし）| closeEarly（途中で閉じる）| showFail（表示に失敗）
    this.loadMs = opts.loadMs == null ? 1200 : opts.loadMs;
    this.now = opts.now || function () { return Date.now(); };
    this.present = opts.present || function () { return Promise.resolve('earned'); };
    this.ready = { rewarded: null, interstitial: null };   // 読み込んだ時刻
    this.loading = { rewarded: null, interstitial: null };
  }
  FakeAds.prototype._fresh = function (k) { var t = this.ready[k]; return t != null && this.now() - t < AD_LIFETIME_MS; };
  FakeAds.prototype._load = function (k) {
    var self = this;
    if (this._fresh(k)) return Promise.resolve(true);
    this.ready[k] = null;   // 期限切れは捨てる
    if (this.loading[k]) return this.loading[k];
    this.loading[k] = new Promise(function (res) {
      setTimeout(function () { self.loading[k] = null; if (self.mode === 'nofill') return res(false); self.ready[k] = self.now(); res(true); }, self.loadMs);
    });
    return this.loading[k];
  };
  FakeAds.prototype.initialize = function () { this._load('rewarded'); return Promise.resolve(); };
  FakeAds.prototype.isRewardedReady = function () { return this._fresh('rewarded'); };
  FakeAds.prototype.isInterstitialReady = function () { return this._fresh('interstitial'); };
  FakeAds.prototype.ensureLoaded = function (k) { this._load(k || 'rewarded'); };
  FakeAds.prototype.waitForRewarded = function (ms) {
    var self = this;
    return Promise.race([this._load('rewarded'), new Promise(function (r) { setTimeout(function () { r(false); }, ms); })])
      .then(function () { return self._fresh('rewarded'); });
  };
  FakeAds.prototype.showRewarded = function () {
    var self = this;
    if (!this._fresh('rewarded')) return Promise.resolve(REWARD.unavailable);
    this.ready.rewarded = null;   // 1本は1回だけ
    if (this.mode === 'showFail') { this._load('rewarded'); return Promise.resolve(REWARD.showFailed); }
    return this.present('rewarded', this.mode).then(function (r) {
      self._load('rewarded');   // 次のために読み直す
      return r === 'earned' && self.mode !== 'closeEarly' ? REWARD.earned : REWARD.closedEarly;
    });
  };
  FakeAds.prototype.showInterstitial = function () {
    var self = this;
    if (!this._fresh('interstitial')) return Promise.resolve(false);
    this.ready.interstitial = null;
    if (this.mode === 'showFail') return Promise.resolve(false);
    return this.present('interstitial', this.mode).then(function () { return true; });
  };
  FakeAds.prototype.dispose = function () { this.ready = { rewarded: null, interstitial: null }; };

  // 偽のストア（試作では本当の購入はしない）
  function FakeStore() { this.owned = false; }
  FakeStore.prototype.buy = function () { this.owned = true; return Promise.resolve('purchased'); };
  FakeStore.prototype.restore = function () { return Promise.resolve(this.owned ? 'purchased' : 'nothing'); };

  // prefs: { get(key, default), set(key, value) }
  function Money(prefs, ads, store, opts) {
    this.prefs = prefs; this.ads = ads; this.store = store;
    this.isForeground = (opts && opts.isForeground) || function () { return true; };
  }
  Money.prototype.adFree = function () { return !!this.prefs.get('adFree', false); };
  Money.prototype.start = function () { if (!this.adFree()) return this.ads.initialize(); return Promise.resolve(); };
  // アプリが前面に戻ったとき（期限切れの広告を読み直す）
  Money.prototype.refresh = function () { if (!this.adFree()) this.ads.ensureLoaded('rewarded'); };

  // 動画の前に呼ぶ。広告を消した人はそのまま。読み込み中なら少し待つ（onWaiting で「読み込み中」を出せる）
  // 返すのは granted（渡してよい）| declined（途中で閉じた）| unavailable（読み込めない）| showFailed
  Money.prototype.beforeReward = function (onWaiting) {
    var self = this;
    if (this.adFree()) return Promise.resolve('granted');
    var wait = this.ads.isRewardedReady() ? Promise.resolve(true)
      : (this.ads.ensureLoaded('rewarded'), onWaiting && onWaiting(), this.ads.waitForRewarded(REWARD_WAIT_MS));
    return wait.then(function (ok) {
      if (self.adFree()) return 'granted';
      if (!ok) return 'unavailable';
      if (!self.isForeground()) return 'unavailable';   // 裏に回っている間に出さない
      return self.ads.showRewarded().then(function (r) {
        if (self.adFree()) return 'granted';   // 見ている間に「広告を消す」が届いた
        return r === REWARD.earned ? 'granted' : r === REWARD.closedEarly ? 'declined' : r;
      });
    });
  };
  // 動画のボタンに「動画」の印を付けるか
  Money.prototype.rewardNeedsAd = function () { return !this.adFree(); };

  // 1回の遊びが終わったときに呼ぶ（全画面の数え）。次に出す番なら、結果を見ている間に読み込む
  Money.prototype.gameEnded = function () {
    this.prefs.set('games', (this.prefs.get('games', 0) || 0) + 1);
    if (this._turn() && !this.ads.isInterstitialReady()) this.ads.ensureLoaded('interstitial');
  };
  Money.prototype._turn = function () {
    return !this.adFree() && (this.prefs.get('games', 0) || 0) > FREE_GAMES && (this.prefs.get('sinceAd', 0) || 0) + 1 >= INTERSTITIAL_EVERY;
  };
  // 結果から次を始める直前に呼ぶ。番なら全画面を出して閉じるまで待つ。出せたら true
  // 在庫が無ければ数えはそのまま（次の回にもう一度試す）。出す前に数え直す（広告の途中で終わっても続けて出ないように）
  Money.prototype.beforeNextGame = function (mayShow) {
    var self = this;
    if (this.adFree() || (this.prefs.get('games', 0) || 0) <= FREE_GAMES) return Promise.resolve(false);
    var n = (this.prefs.get('sinceAd', 0) || 0) + 1;
    if (n < INTERSTITIAL_EVERY || mayShow === false || !this.isForeground()) { this.prefs.set('sinceAd', n); return Promise.resolve(false); }
    this.prefs.set('sinceAd', 0);
    return this.ads.showInterstitial().then(function (shown) { if (!shown) self.prefs.set('sinceAd', n); return shown; });
  };

  Money.prototype.buy = function () { var self = this; return this.store.buy().then(function (r) { if (r === 'purchased') self._setAdFree(); return r; }); };
  Money.prototype.restore = function () { var self = this; return this.store.restore().then(function (r) { if (r === 'purchased') self._setAdFree(); return r; }); };
  Money.prototype._setAdFree = function () { if (!this.adFree()) this.ads.dispose(); this.prefs.set('adFree', true); };

  return { Money: Money, FakeAds: FakeAds, FakeStore: FakeStore, REWARD: REWARD,
    INTERSTITIAL_EVERY: INTERSTITIAL_EVERY, FREE_GAMES: FREE_GAMES, REWARD_WAIT_MS: REWARD_WAIT_MS, AD_LIFETIME_MS: AD_LIFETIME_MS };
})();
if (typeof module !== 'undefined') module.exports = TenbinMoney;
