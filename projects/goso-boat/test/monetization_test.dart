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
  int interstitials = 0;
  int rewardeds = 0;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  Future<bool> showRewardedAd() async {
    rewardeds++;
    return watchToEnd;
  }

  @override
  Future<void> showInterstitialAd() async => interstitials++;
  @override
  void dispose() {}
}

class FakeStore extends NoOpPurchaseService {
  PurchaseOutcome next = PurchaseOutcome.purchased;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<PurchaseOutcome> buyRemoveAds() async => next;
  @override
  Future<PurchaseOutcome> restore() async => next;
}

Level lv(int world) => Level(id: '$world-1', world: world, cast: const {Role.police: 3, Role.prisoner: 1}, capacity: 2, par: 5);

Future<(Monetization, FakeAds, FakeStore)> make() async {
  SharedPreferences.setMockInitialValues({});
  final ads = FakeAds(), store = FakeStore();
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

  test('ヒント: 動画が読み込めていなければ、そのまま出す（詰まらせない）', () async {
    final (m, ads, _) = await make();
    ads.rewardedReady = false;
    expect(m.hintNeedsAd, isFalse);
    expect(await m.beforeHint(), HintGate.granted);
    expect(ads.rewardeds, 0);
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
}
