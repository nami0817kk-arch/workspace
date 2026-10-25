// 広告と「広告を消す」の決まり(2026-10-21)。本物の AdMob と App Store の代わりに、結果を決められる偽物をつなぐ。
// docs/app-pitfalls.md の穴(払ったのに届かない・見たのに入らない・期限切れ・「await load」で待てない)も見張る。
import 'dart:io';
import 'dart:math';

import 'package:baseball_manager/game/game.dart' show Phase;
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/monetization/ad_service.dart';
import 'package:baseball_manager/monetization/monetization.dart';
import 'package:baseball_manager/monetization/purchase_service.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds implements AdService {
  bool ready = true;
  bool interstitialReady = true;
  RewardResult result = RewardResult.earned;
  int rewarded = 0;
  int interstitials = 0;
  int reloads = 0;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => ready;
  @override
  bool get isInterstitialReady => interstitialReady;
  @override
  Future<bool> waitForRewarded(Duration max) async => ready;
  @override
  void ensureLoaded() => reloads++;
  @override
  Future<RewardResult> showRewardedAd() async {
    rewarded++;
    return result;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return true;
  }

  @override
  void dispose() {}
}

class FakeStore implements PurchaseService {
  bool available = true;
  String? price = '¥370';
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  PurchaseOutcome restoreResult = PurchaseOutcome.purchased;

  /// 広告を消す の購入記録(前からの検査用)。
  bool? entitlement;

  /// ほかの商品の購入記録。
  final Map<String, bool?> entitlements = {};

  /// 復元で届く商品(既定は広告を消すだけ)。
  List<String> restoreIds = [PurchaseService.removeAdsId];
  final List<String> bought = [];
  int get buys => bought.length;
  Future<void> Function(String)? delivered;
  Future<void> Function(String)? revoked;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) =>
      delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => revoked = cb;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<String?> priceLabel(String productId) async =>
      productId == PurchaseService.removeAdsId
          ? price
          : (price == null ? null : '¥250');
  @override
  Future<PurchaseOutcome> buy(String productId) async {
    bought.add(productId);
    // 本物と同じく、成立したらストアからの通知が先に届く
    if (buyResult == PurchaseOutcome.purchased) {
      await delivered?.call(productId);
    }
    return buyResult;
  }

  @override
  Future<bool?> hasEntitlement(String productId) async =>
      productId == PurchaseService.removeAdsId
          ? entitlement
          : entitlements[productId];
  @override
  Future<PurchaseOutcome> restore() async {
    if (restoreResult == PurchaseOutcome.purchased) {
      for (final id in restoreIds) {
        await delivered?.call(id);
      }
    }
    return restoreResult;
  }

  @override
  void dispose() {}
}

Future<(Monetization, FakeAds, FakeStore)> _open(
    [Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final ads = FakeAds(), store = FakeStore();
  final m = Monetization(prefs, ads: ads, store: store);
  await m.start();
  return (m, ads, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('全画面広告(年が変わる節目)', () {
    test('4年に1回。13歳になるまでは出さない', () async {
      final (m, ads, _) = await _open();
      for (var age = 7; age < 13; age++) {
        expect(await m.afterYear(age), isFalse);
      }
      expect(ads.interstitials, 0);
      // 13歳から数え始めて、4回目に出る
      expect(await m.afterYear(13), isFalse);
      expect(await m.afterYear(14), isFalse);
      expect(await m.afterYear(15), isFalse);
      expect(await m.afterYear(16), isTrue);
      expect(ads.interstitials, 1);
      expect(await m.afterYear(17), isFalse); // 数え直し
    });

    test('在庫が無ければ出さず、次の年にもう一度試す(数えは戻さない)', () async {
      final (m, ads, _) = await _open({'baseball_yearsSinceAd': 3});
      ads.interstitialReady = false;
      expect(await m.afterYear(20), isFalse);
      expect(ads.reloads, greaterThan(0)); // 読み込みを促す
      ads.interstitialReady = true;
      expect(await m.afterYear(21), isTrue);
      expect(ads.interstitials, 1);
    });

    test('広告を消した人には出さない', () async {
      final (m, ads, store) = await _open({'baseball_yearsSinceAd': 3});
      await store.delivered!(PurchaseService.removeAdsId);
      expect(m.adFree, isTrue);
      expect(await m.afterYear(20), isFalse);
      expect(ads.interstitials, 0);
    });
  });

  group('疲れを取る動画', () {
    test('見終えれば渡す。途中で閉じたら渡さない。読み込めていなければ渡さない(タダでは出さない)', () async {
      final (m, ads, _) = await _open();
      expect(await m.beforeRecovery(), RecoveryGate.granted);
      ads.result = RewardResult.closedEarly;
      expect(await m.beforeRecovery(), RecoveryGate.declined);
      ads.result = RewardResult.showFailed;
      expect(await m.beforeRecovery(), RecoveryGate.showFailed);
      ads.ready = false;
      expect(await m.beforeRecovery(), RecoveryGate.unavailable);
    });

    test('広告を消した人は動画なしで渡す', () async {
      final (m, ads, store) = await _open();
      await store.delivered!(PurchaseService.removeAdsId);
      expect(await m.beforeRecovery(), RecoveryGate.granted);
      expect(ads.rewarded, 0);
    });

    test('コントローラー: 疲れが70以上の年に1度、動画で疲れが抜ける', () async {
      final (m, ads, _) = await _open();
      final c = GameController(rng: Random(3), money: m);
      c.newGame('動画', Role.batter);
      final g = c.game!;
      expect(c.canRecoverByAd, isFalse); // 疲れていない
      g.condition = g.condition.copyWith(fatigue: 85);
      expect(c.canRecoverByAd, isTrue);
      final text = await c.recoverByAd();
      expect(text, contains('抜けました'));
      expect(g.condition.fatigue, 25);
      expect(ads.rewarded, 1);
      // 同じ歳には2度目を出さない
      g.condition = g.condition.copyWith(fatigue: 90);
      expect(c.canRecoverByAd, isFalse);
    });

    test('コントローラー: 動画を途中で閉じたら疲れは抜けず、もう一度試せる', () async {
      final (m, ads, _) = await _open();
      ads.result = RewardResult.closedEarly;
      final c = GameController(rng: Random(3), money: m);
      c.newGame('動画', Role.batter);
      final g = c.game!;
      g.condition = g.condition.copyWith(fatigue: 85);
      final text = await c.recoverByAd();
      expect(text, contains('最後まで'));
      expect(g.condition.fatigue, 85);
      expect(c.canRecoverByAd, isTrue);
    });

    test('怪我の最中・広告のないアプリ(テスト)では出ない', () async {
      final (m, _, _) = await _open();
      final c = GameController(rng: Random(3), money: m);
      c.newGame('怪我', Role.batter);
      c.game!.condition =
          c.game!.condition.copyWith(fatigue: 90, injuredTerms: 2);
      expect(c.canRecoverByAd, isFalse);
      final plain = GameController(rng: Random(3));
      plain.newGame('広告なし', Role.batter);
      plain.game!.condition = plain.game!.condition.copyWith(fatigue: 90);
      expect(plain.canRecoverByAd, isFalse);
    });

    test('年が変わった節目に、コントローラーから全画面広告が出る(13歳以上・4年に1回)', () async {
      final (m, ads, _) = await _open({'baseball_yearsSinceAd': 3});
      final c = GameController(rng: Random(3), money: m);
      c.newGame('節目', Role.batter);
      final g = c.game!;
      g.player = g.player.copyWith(age: 15);
      void rest() {
        // 出来事が起きていたら先に答える(行動は季節の段階でしか選べない)
        while (g.phase == Phase.event) {
          c.chooseEvent(0);
        }
        c.act(Plan.rest);
      }

      rest(); // 15歳として覚える
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(ads.interstitials, 0); // 年の変わり目ではない
      g.player = g.player.copyWith(age: 16);
      rest(); // 15 → 16歳
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(ads.interstitials, 1);
    });
  });

  group('広告を消す(買い切り)', () {
    test('購入が届けば広告が消え、保存される', () async {
      final (m, _, store) = await _open();
      expect(m.adFree, isFalse);
      expect(await m.buy(), PurchaseOutcome.purchased);
      expect(m.adFree, isTrue);
      expect(store.buys, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('baseball_adFree'), isTrue);
    });

    test('待っている人がいなくても、届いた購入は受け取る(起動時の再送・家族の承認)', () async {
      final (m, _, store) = await _open();
      await store.delivered!(PurchaseService.removeAdsId); // 購入の操作なしで届く
      expect(m.adFree, isTrue);
    });

    test('別の商品は無視する', () async {
      final (m, _, store) = await _open();
      await store.delivered!('other_product');
      expect(m.adFree, isFalse);
    });

    test('復元できる。対象が無ければ何も変えない', () async {
      final (m, _, store) = await _open();
      store.restoreResult = PurchaseOutcome.unavailable;
      expect(await m.restore(), PurchaseOutcome.unavailable);
      expect(m.adFree, isFalse);
      store.restoreResult = PurchaseOutcome.purchased;
      expect(await m.restore(), PurchaseOutcome.purchased);
      expect(m.adFree, isTrue);
    });

    test('返金されたら広告が戻る。ほかに有効な取引があれば戻さない', () async {
      final (m, _, store) = await _open({'baseball_adFree': true});
      store.entitlement = true;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(m.adFree, isTrue);
      store.entitlement = false;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(m.adFree, isFalse);
    });

    test('起動時に購入記録と照らす: 再インストールでも広告なしに戻る・返金済みなら戻す', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = FakeStore()..entitlement = true;
      final m = Monetization(prefs, ads: FakeAds(), store: store);
      await m.start();
      expect(m.adFree, isTrue);
      store.entitlement = false;
      final m2 = Monetization(prefs, ads: FakeAds(), store: store);
      await m2.start();
      expect(m2.adFree, isFalse);
    });

    test('継承ブースト・育成サポートも買える。届けば持ち、返金されれば戻る。復元で全部戻る', () async {
      final (m, _, store) = await _open();
      expect(m.legacyBoost, isFalse);
      expect(await m.buyItem(PurchaseService.legacyBoostId),
          PurchaseOutcome.purchased);
      expect(m.legacyBoost, isTrue);
      expect(m.adFree, isFalse); // ほかの商品は付かない
      await store.delivered!(PurchaseService.growthSupportId); // 待っていなくても届く
      expect(m.growthSupport, isTrue);
      store.entitlements[PurchaseService.growthSupportId] = false;
      await store.revoked!(PurchaseService.growthSupportId);
      expect(m.growthSupport, isFalse);
      // 再インストール: 端末の記録から戻る
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s2 = FakeStore()
        ..entitlements[PurchaseService.legacyBoostId] = true;
      final m2 = Monetization(prefs, ads: FakeAds(), store: s2);
      await m2.start();
      expect(m2.legacyBoost, isTrue);
      expect(m2.growthSupport, isFalse);
      // 復元
      s2.restoreIds = PurchaseService.allIds;
      await m2.restore();
      expect(m2.adFree && m2.legacyBoost && m2.growthSupport, isTrue);
    });

    test('育成サポートは経験点が1割多い。継承ブーストは継承ポイントが2倍', () async {
      final (m, _, store) = await _open();
      int expOf(GameController c) {
        c.newGame('t', Role.batter);
        c.act(Plan.train);
        return c.game!.lastGain.values.fold(0, (a, b) => a + b);
      }

      final plain = expOf(GameController(rng: Random(4), money: m));
      await store.delivered!(PurchaseService.growthSupportId);
      final boosted = expOf(GameController(rng: Random(4), money: m));
      expect(boosted, greaterThan(plain));
      expect(boosted / plain, closeTo(1.1, 0.06));
      expect(GameController.growthSupportBoost, 1.1);
    });

    test('動画の特典: 経験点(年1回)と継承ポイント(引退のたびに1回)', () async {
      final (m, ads, _) = await _open();
      final c = GameController(rng: Random(3), money: m);
      c.newGame('動画', Role.batter);
      final before = c.game!.exp.total;
      expect(c.canExpByAd, isTrue);
      expect(await c.expByAd(), contains('経験点 +'));
      expect(c.game!.exp.total, greaterThan(before));
      expect(c.canExpByAd, isFalse); // 同じ歳には1回だけ
      expect(ads.rewarded, 1);
      expect(c.canLegacyByAd, isFalse); // 引退してから
    });

    test('商品IDは App Store Connect に作るものと同じ', () {
      expect(PurchaseService.legacyBoostId, 'baseball_manager_legacy_boost');
      expect(PurchaseService.growthSupportId, 'baseball_manager_growth_support');
      expect(PurchaseService.removeAdsId, 'baseball_manager_remove_ads');
    });
  });

  group('設定画面', () {
    Future<void> openSettings(WidgetTester t, GameController c) async {
      t.view.physicalSize = const Size(900, 3000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(BaseballManagerApp(controller: c));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('設定').first);
      await t.pumpAndSettle();
    }

    testWidgets('価格つきの「広告を消す」と復元が出て、買うと広告なしの表示に変わる', (t) async {
      final (m, _, _) = await _open();
      final c = GameController(rng: Random(3), money: m);
      await openSettings(t, c);
      final remove = find.byKey(const Key('remove-ads'));
      await t.scrollUntilVisible(remove, 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('¥370'), findsOneWidget);
      expect(find.byKey(const Key('restore-purchases')), findsOneWidget);
      await t.tap(remove);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ad-free-on')), findsOneWidget);
      expect(find.byKey(const Key('remove-ads')), findsNothing);
    });

    testWidgets('疲れた状態の「動画で休む」は、狭い画面・大きい文字でも溢れず、押すと疲れが抜ける', (t) async {
      final (m, ads, _) = await _open();
      final c = GameController(rng: Random(3), money: m);
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1.0;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(BaseballManagerApp(controller: c));
      await t.pumpAndSettle();
      // 起動時の読み込みが済んでから選手を始める(読み込みが先に走ると、始めた選手が消える)
      c.newGame('疲れ', Role.batter);
      c.game!.condition =
          c.game!.condition.copyWith(fatigue: 85, injuredTerms: 0);
      c.notifyListeners();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final button = find.byKey(const Key('ad-recovery'));
      await t.ensureVisible(button);
      expect(button, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(ads.rewarded, 1);
      expect(c.game!.condition.fatigue, 25);
      expect(find.byKey(const Key('ad-recovery')), findsNothing);
    });

    testWidgets('ストアに繋がらないときは購入の項目を出さない', (t) async {
      final (m, _, store) = await _open();
      store.available = false;
      final c = GameController(rng: Random(3), money: m);
      await openSettings(t, c);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('remove-ads')), findsNothing);
      expect(find.byKey(const Key('restore-purchases')), findsNothing);
    });
  });

  group('広告SDKの使い方(原文を見て確かめる。docs/app-pitfalls.md)', () {
    final src = File('lib/monetization/ad_service.dart').readAsStringSync();

    test('読み込んだ広告は1時間より手前で捨てる', () {
      expect(src, contains('_maxAge = Duration(minutes: 55)'));
    });

    test('「await Ad.load」で待たない(onAdLoaded で完了させる)', () {
      expect(src, isNot(contains('await InterstitialAd.load(')));
      expect(src, isNot(contains('await RewardedAd.load(')));
    });

    test('全年齢向け(G)までに絞る', () {
      expect(src, contains('MaxAdContentRating.g'));
    });

    test('既定は Google のテスト用ID(本物の広告を開発中に出さない)', () {
      expect(src, contains('ca-app-pub-3940256099942544/1712485313'));
      expect(src, contains('ca-app-pub-3940256099942544/4411468910'));
    });

    test('Info.plist に AdMob のアプリIDと SKAdNetwork がある。ATT は使わない', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('GADApplicationIdentifier'));
      expect(plist, contains('SKAdNetworkItems'));
      expect(plist, contains('cstr6suwn9.skadnetwork')); // Google
      expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
    });
  });
}
