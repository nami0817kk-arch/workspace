import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';
import 'package:goso_boat/monetization/ad_service.dart';
import 'package:goso_boat/monetization/monetization.dart';
import 'package:goso_boat/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds implements AdService {
  bool rewardedReady = true;
  bool watchToEnd = true;
  bool interstitialReady = true;
  int interstitials = 0;
  int rewardeds = 0;
  int reloads = 0;
  int initializes = 0;
  int disposes = 0;

  @override
  Future<void> initialize() async => initializes++;
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => interstitialReady;
  @override
  Future<bool> waitForRewarded(Duration max) async => rewardedReady;
  @override
  void ensureLoaded() => reloads++;
  @override
  Future<RewardResult> showRewardedAd() async {
    rewardeds++;
    return watchToEnd ? RewardResult.earned : RewardResult.closedEarly;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return true;
  }

  @override
  void dispose() => disposes++;
}

class FakeStore extends NoOpPurchaseService {
  PurchaseOutcome next = PurchaseOutcome.purchased;
  Future<void> Function(String)? _delivered;
  Future<void> Function(String)? _revoked;
  @override
  set onDelivered(Future<void> Function(String productId)? cb) => _delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => _revoked = cb;

  /// ストアから直接届く（家族の承認・起動時の再送）。
  Future<void> deliver([String id = PurchaseService.removeAdsId]) async => _delivered?.call(id);
  Future<void> revoke() async => _revoked?.call(PurchaseService.removeAdsId);

  /// 端末の購入記録（null=読めない）。
  bool? entitlement;
  @override
  Future<bool?> hasEntitlement() async => entitlement;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<PurchaseOutcome> buyRemoveAds() async => next;
  @override
  Future<PurchaseOutcome> restore() async => next;
}

Level lv(int world) =>
    Level(id: '$world-1', world: world, cast: const {Role.police: 3, Role.prisoner: 1}, capacity: 2, par: 5);

Future<(Monetization, FakeAds, FakeStore)> make([Map<String, Object> saved = const {}, bool? entitlement]) async {
  SharedPreferences.setMockInitialValues(saved);
  final ads = FakeAds(), store = FakeStore()..entitlement = entitlement;
  final m = Monetization(await SharedPreferences.getInstance(), ads: ads, store: store);
  await m.start();
  return (m, ads, store);
}

void main() {
  test('全画面広告は3面に1回。舞台1のあいだは出さない', () async {
    final (m, ads, _) = await make();
    for (var i = 0; i < 6; i++) {
      await m.afterClear(lv(1));
    }
    expect(ads.interstitials, 0, reason: '舞台1');
    expect((await SharedPreferences.getInstance()).getInt('clearsSinceAd'), isNull, reason: '舞台1は数えもしない');
    expect(m.interstitialDue(lv(2)), isFalse);
    final shown = [for (var i = 0; i < 6; i++) await m.afterClear(lv(2))];
    expect(shown, [false, false, true, false, false, true]);
    expect(ads.interstitials, 2);
  });

  test('ヒント: 動画を見終えたら出す、途中で閉じたら出さない', () async {
    final (m, ads, _) = await make();
    expect(m.hintNeedsAd, isTrue);
    expect(await m.beforeHint(), HintGate.granted);
    ads.watchToEnd = false;
    expect(await m.beforeHint(), HintGate.declined);
    expect(ads.rewardeds, 2);
  });

  test('ヒント: 動画が読み込めていなければ出さない（タダの逃げ道は作らない）', () async {
    final (m, ads, _) = await make();
    ads.rewardedReady = false;
    expect(m.hintNeedsAd, isTrue);
    expect(await m.beforeHint(), HintGate.unavailable);
    expect(ads.rewardeds, 0);
    expect(ads.reloads, 1, reason: '読み込めていなければ、次に押すときのために読み直しを始める');
  });

  test('全画面広告を出せなかった（在庫なし）ときは数えを戻さず、次の面でもう一度試す', () async {
    final (m, ads, _) = await make();
    ads.interstitialReady = false;
    final shown = [for (var i = 0; i < 4; i++) await m.afterClear(lv(2))];
    expect(shown, [false, false, false, false]);
    ads.interstitialReady = true;
    expect(await m.afterClear(lv(2)), isTrue, reason: '出せるようになった最初の「次の面へ」で出す');
    expect(await m.afterClear(lv(2)), isFalse, reason: '出した後は数え直す');
  });

  test('保護者の承認待ちでは、まだ広告なしにしない', () async {
    final (m, _, store) = await make();
    store.next = PurchaseOutcome.pending;
    expect(await m.buy(), PurchaseOutcome.pending);
    expect(m.adFree, isFalse);
  });

  test('広告を消すと、全画面広告も動画も出ない', () async {
    final (m, ads, _) = await make();
    expect(await m.buy(), PurchaseOutcome.purchased);
    expect(m.adFree, isTrue);
    for (var i = 0; i < 9; i++) {
      await m.afterClear(lv(3));
    }
    expect(ads.interstitials, 0);
    expect(m.hintNeedsAd, isFalse);
    expect(await m.beforeHint(), HintGate.granted);
    expect(ads.rewardeds, 0);
    expect(await m.canBuy, isFalse, reason: '買った後はボタンを出さない');
  });

  test('復元で広告なしに戻る。取りやめ・失敗では変わらない', () async {
    final (m, _, store) = await make();
    store.next = PurchaseOutcome.canceled;
    await m.buy();
    expect(m.adFree, isFalse);
    store.next = PurchaseOutcome.failed;
    await m.restore();
    expect(m.adFree, isFalse);
    store.next = PurchaseOutcome.purchased;
    await m.restore();
    expect(m.adFree, isTrue);
  });

  test('買った人は、起動しても広告を準備しない', () async {
    final (_, ads, _) = await make({'adFree': true});
    expect(ads.initializes, 0);
  });

  test('「買う」を押さずに届いた購入でも広告が消え、別の商品では消えない', () async {
    final (m, ads, store) = await make();
    await store.deliver('other_product');
    expect(m.adFree, isFalse);
    await store.deliver();
    expect(m.adFree, isTrue);
    expect(ads.disposes, 1, reason: '読み込み済みの広告も捨てる');
    for (var i = 0; i < 9; i++) {
      await m.afterClear(lv(2));
    }
    expect(ads.interstitials, 0);
  });

  test('返金されたら広告が戻る', () async {
    final (m, ads, store) = await make();
    await m.buy();
    expect(m.adFree, isTrue);
    await store.revoke();
    expect(m.adFree, isFalse);
    expect(m.hintNeedsAd, isTrue);
    expect(ads.initializes, 2, reason: '広告の準備をやり直す');
    for (var i = 0; i < 3; i++) {
      await m.afterClear(lv(2));
    }
    expect(ads.interstitials, 1, reason: '返金の後は全画面広告も戻る');
  });

  test('全画面広告の数えは再起動しても続く', () async {
    final (m, ads, _) = await make({'clearsSinceAd': 2});
    expect(m.interstitialDue(lv(2)), isTrue);
    expect(await m.afterClear(lv(2)), isTrue);
    expect(ads.interstitials, 1);
    expect(m.interstitialDue(lv(2)), isFalse);
  });

  test('起動時に購入記録と照らし合わせる: 閉じている間の返金で広告が戻り、再インストール後は自動で広告なしに戻る', () async {
    final (m1, _, _) = await make({'adFree': true}, false);
    expect(m1.adFree, isFalse, reason: '記録が全部返金済みなら広告を戻す');
    final (m2, _, _) = await make({}, true);
    expect(m2.adFree, isTrue, reason: '有効な記録があれば「購入を復元」を押さなくても戻る');
    final (m3, _, _) = await make({'adFree': true}, null);
    expect(m3.adFree, isTrue, reason: '記録が読めないときは何もしない');
  });

  test('返金の通知が来ても、ほかに有効な取引があれば広告は戻さない', () async {
    final (m, _, store) = await make({'adFree': true}, null);
    store.entitlement = true;
    await store.revoke();
    expect(m.adFree, isTrue);
  });

  test('全画面広告の番で手元に無ければ、クリアした時点で読み込みを始める', () async {
    final (m, ads, _) = await make({'clearsSinceAd': 2});
    ads.interstitialReady = false;
    expect(m.interstitialDue(lv(2)), isFalse, reason: '手元に無いときは待たせない');
    final before = ads.reloads;
    m.prepareNext(lv(2));
    expect(ads.reloads, before + 1);
  });

  test('表示に失敗・在庫なしはタダで出さない。見ている間に広告を消せば出す。広告なしでは読み直さない', () async {
    SharedPreferences.setMockInitialValues({});
    final ads = _ResultAds(), store = FakeStore();
    final m = Monetization(await SharedPreferences.getInstance(), ads: ads, store: store);
    await m.start();
    expect(await m.beforeHint(), HintGate.showFailed);
    ads.result = RewardResult.unavailable;
    expect(await m.beforeHint(), HintGate.unavailable);
    final r0 = ads.reloads;
    m.refreshAds();
    expect(ads.reloads, r0 + 1);
    ads
      ..result = RewardResult.closedEarly
      ..during = store.deliver;
    expect(await m.beforeHint(), HintGate.granted);
    m.refreshAds();
    expect(ads.reloads, r0 + 1, reason: '広告を消した後は読み直さない');
  });

  test('読み込み中なら知らせてから6秒まで待ち、届けば動画を見せる', () async {
    SharedPreferences.setMockInitialValues({});
    final ads = _WaitingAds()..rewardedReady = false;
    final m = Monetization(await SharedPreferences.getInstance(), ads: ads, store: FakeStore());
    await m.start();
    var waiting = 0;
    final gate = m.beforeHint(onWaiting: () => waiting++);
    await Future<void>.delayed(Duration.zero);
    expect(waiting, 1);
    expect(ads.waitedFor, const Duration(seconds: 6));
    expect(ads.rewardeds, 0, reason: '届く前には見せない');
    ads.arrive.complete(true);
    expect(await gate, HintGate.granted);
    expect(ads.rewardeds, 1);
  });
}

class _ResultAds extends FakeAds {
  RewardResult result = RewardResult.showFailed;
  Future<void> Function()? during;
  @override
  Future<RewardResult> showRewardedAd() async {
    rewardeds++;
    await during?.call();
    return result;
  }
}

class _WaitingAds extends FakeAds {
  final arrive = Completer<bool>();
  Duration? waitedFor;
  @override
  Future<bool> waitForRewarded(Duration max) {
    waitedFor = max;
    return arrive.future.then((ok) => rewardedReady = ok);
  }
}
