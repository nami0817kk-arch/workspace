// 広告と課金の決まりを、偽の広告・偽のストアで確かめる(docs/app-pitfalls.md の5件を当てる)。
import 'dart:io';
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/monetization/ad_service.dart';
import 'package:basketball_career/monetization/monetization.dart';
import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/settings_screen.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds implements AdService {
  bool rewardedReady = true;
  bool watchToEnd = true;
  bool interstitialReady = true;
  int rewarded = 0;
  int interstitials = 0;
  int reloads = 0;
  bool disposed = false;

  @override
  Future<void> initialize() async {}
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
    rewarded++;
    return watchToEnd ? RewardResult.earned : RewardResult.closedEarly;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return true;
  }

  @override
  void dispose() => disposed = true;
}

class FakeStore implements PurchaseService {
  bool available = true;
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  bool? entitlement;
  Future<void> Function(String)? delivered;
  Future<void> Function(String)? revoked;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) => delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => revoked = cb;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<String?> priceLabel() async => '¥370';
  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    // 本物と同じく、成立したらストアからの通知が先に届く
    if (buyResult == PurchaseOutcome.purchased) {
      await delivered?.call(PurchaseService.removeAdsId);
    }
    return buyResult;
  }

  @override
  Future<bool?> hasEntitlement() async => entitlement;
  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}

/// 何も保存しない。
class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}

Future<(Monetization, FakeAds, FakeStore)> open(
    [Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final ads = FakeAds(), store = FakeStore();
  final m = Monetization(await SharedPreferences.getInstance(),
      ads: ads, store: store);
  await m.start();
  return (m, ads, store);
}

Player kid() => Player(
    name: 'キッズ', age: 8, potential: 50, heightCm: 130, heightGenes: 0.5);

void main() {
  group('全画面広告', () {
    test('大会を3回終えるまでは出ない。3回目の次の操作で出て、数え直す', () async {
      final (m, ads, _) = await open();
      for (var i = 0; i < Monetization.interstitialEvery - 1; i++) {
        await m.tournamentPlayed();
        expect(await m.beforeAction(), isFalse);
      }
      await m.tournamentPlayed();
      expect(m.interstitialDue, isTrue);
      expect(await m.beforeAction(), isTrue);
      expect(ads.interstitials, 1);
      expect(m.interstitialDue, isFalse);
    });

    test('在庫が無くて出せなければ、進行を止めず次の機会に回す', () async {
      final (m, ads, _) = await open();
      ads.interstitialReady = false;
      for (var i = 0; i < Monetization.interstitialEvery; i++) {
        await m.tournamentPlayed();
      }
      expect(await m.beforeAction(), isFalse);
      expect(m.interstitialDue, isTrue, reason: '出せなかった分は次に回る');
      ads.interstitialReady = true;
      expect(await m.beforeAction(), isTrue);
    });

    test('広告を消した人には出ない', () async {
      final (m, ads, _) = await open({'adFree': true});
      for (var i = 0; i < 6; i++) {
        await m.tournamentPlayed();
      }
      expect(m.interstitialDue, isFalse);
      expect(await m.beforeAction(), isFalse);
      expect(ads.interstitials, 0);
    });
  });

  group('動画で回復', () {
    test('最後まで見れば回復できる', () async {
      final (m, ads, _) = await open();
      expect(await m.beforeRecover(), RecoverGate.granted);
      expect(ads.rewarded, 1);
    });

    test('途中で閉じたら回復しない', () async {
      final (m, ads, _) = await open();
      ads.watchToEnd = false;
      expect(await m.beforeRecover(), RecoverGate.declined);
    });

    test('動画を読み込めなければ、タダでは回復させない', () async {
      final (m, ads, _) = await open();
      ads.rewardedReady = false;
      expect(await m.beforeRecover(), RecoverGate.unavailable);
      expect(ads.rewarded, 0);
      expect(ads.reloads, greaterThan(0), reason: '読み直しを始める');
    });

    test('広告を消した人は、動画なしで回復できる', () async {
      final (m, ads, _) = await open({'adFree': true});
      expect(await m.beforeRecover(), RecoverGate.granted);
      expect(ads.rewarded, 0);
    });
  });

  group('動画で特殊能力ポイント', () {
    test('最後まで見るとポイントがもらえ、1日3回まで。日付が変わると戻る', () async {
      final (m, ads, _) = await open();
      var now = DateTime(2026, 10, 25, 12);
      m.clock = () => now;
      expect(m.spAdsLeft, 3);
      for (var i = 0; i < 3; i++) {
        expect(await m.claimSpReward(), RecoverGate.granted);
      }
      expect(m.spAdsLeft, 0);
      expect(await m.claimSpReward(), RecoverGate.unavailable, reason: '4回目はもらえない');
      expect(ads.rewarded, 3, reason: '回数を使い切ったら動画も出さない');
      now = DateTime(2026, 10, 26, 0, 5);
      expect(m.spAdsLeft, 3);
      expect(await m.claimSpReward(), RecoverGate.granted);
    });

    test('途中で閉じた・読み込めないときは、回数を使わない', () async {
      final (m, ads, _) = await open();
      m.clock = () => DateTime(2026, 10, 25, 12);
      ads.watchToEnd = false;
      expect(await m.claimSpReward(), RecoverGate.declined);
      ads.watchToEnd = true;
      ads.rewardedReady = false;
      expect(await m.claimSpReward(), RecoverGate.unavailable);
      expect(m.spAdsLeft, 3);
    });

    test('広告を消した人は、動画なしでもらえる(回数の上限は同じ)', () async {
      final (m, ads, _) = await open({'adFree': true});
      m.clock = () => DateTime(2026, 10, 25, 12);
      for (var i = 0; i < 3; i++) {
        expect(await m.claimSpReward(), RecoverGate.granted);
      }
      expect(await m.claimSpReward(), RecoverGate.unavailable);
      expect(ads.rewarded, 0);
    });

    test('回数は端末に残る(再起動しても使い切ったまま)', () async {
      final (m, _, _) = await open();
      m.clock = () => DateTime(2026, 10, 25, 12);
      for (var i = 0; i < 3; i++) {
        await m.claimSpReward();
      }
      final (m2, _, _) = await open({'spAdDay': '2026-10-25', 'spAdCount': 3});
      m2.clock = () => DateTime(2026, 10, 25, 20);
      expect(m2.spAdsLeft, 0);
    });

    test('コントローラが受け取ると、ポイントが+1される。使い切ったら増えない', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ads = FakeAds();
      final m = Monetization(prefs, ads: ads, store: FakeStore());
      m.clock = () => DateTime(2026, 10, 25, 12);
      final c = GameController(
          store: _NullStore(), rng: Random(1), events: false, money: m);
      c.game = Game.start('x', rng: Random(1), events: false);
      final before = c.game!.sp;
      for (var i = 0; i < 5; i++) {
        await c.watchAdForSp();
      }
      expect(c.game!.sp, before + 3, reason: '1日3回まで');
    });
  });

  group('広告を消す', () {
    test('購入が成立すると広告が止まり、全画面広告が出なくなる', () async {
      final (m, ads, _) = await open();
      expect(m.adFree, isFalse);
      expect(await m.buy(), PurchaseOutcome.purchased);
      expect(m.adFree, isTrue);
      expect(ads.disposed, isTrue);
    });

    test('待っていないところへ届いた購入も受け取る(家族の承認・起動時の再送)', () async {
      final (m, _, store) = await open();
      await store.delivered!(PurchaseService.removeAdsId);
      expect(m.adFree, isTrue);
    });

    test('別の商品の通知は無視する', () async {
      final (m, _, store) = await open();
      await store.delivered!('other_product');
      expect(m.adFree, isFalse);
    });

    test('返金されたら広告が戻る。ほかに有効な取引があれば戻さない', () async {
      final (m, _, store) = await open({'adFree': true});
      store.entitlement = true;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(m.adFree, isTrue);
      store.entitlement = false;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(m.adFree, isFalse);
    });

    test('起動時に購入記録と照合する(再インストール後は復元を押さなくても戻る)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FakeStore()..entitlement = true;
      final m = Monetization(await SharedPreferences.getInstance(),
          ads: FakeAds(), store: store);
      await m.start();
      expect(m.adFree, isTrue);
    });
  });

  group('回復(ゲーム)', () {
    Game tired() => Game(
          eventsEnabled: false,
          player: kid(),
          rng: Random(1),
          condition: const Condition(fatigue: 70, morale: 30),
        );

    test('1ターンに1回まで。ターンが変わると使える', () {
      final g = tired();
      expect(g.canRecover, isTrue);
      g.recover();
      expect(g.condition.fatigue, 30);
      expect(g.condition.morale, 40);
      expect(g.canRecover, isFalse);
      expect(() => g.recover(), throwsStateError);
      g.condition = const Condition(fatigue: 70);
      g.choose(Action.rest, Ability.pass);
      expect(g.canRecover, isTrue);
    });

    test('元気なときは使えない', () {
      final g = Game(eventsEnabled: false, player: kid(), rng: Random(1));
      expect(g.canRecover, isFalse);
    });

    test('怪我が1ターン早く治る', () {
      final g = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        condition: const Condition(injuredTerms: 3),
      );
      g.recover();
      expect(g.condition.injuredTerms, 2);
    });
  });

  group('コントローラ', () {
    test('広告の無い環境では、タダで回復させない', () async {
      final c = GameController(rng: Random(1), events: false);
      c.game = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        condition: const Condition(fatigue: 80),
      );
      await c.recover();
      expect(c.game!.condition.fatigue, 80);
    });

    test('動画を見終えると回復し、読み込めなければ回復しない', () async {
      final (m, ads, _) = await open();
      final c = GameController(rng: Random(1), events: false, money: m);
      c.game = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        condition: const Condition(fatigue: 80),
      );
      ads.rewardedReady = false;
      await c.recover();
      expect(c.game!.condition.fatigue, 80);
      expect(c.recoverMessage, contains('読み込めなかった'));
      ads.rewardedReady = true;
      await c.recover();
      expect(c.game!.condition.fatigue, 40);
    });

    test('大会を3回終えた次の操作で、全画面広告が1回出る', () async {
      final (m, ads, _) = await open();
      final c = GameController(rng: Random(1), events: false, money: m);
      c.setClutchPolicy(null); // 勝負どころは自動で選ぶ(止まらない)
      c.game = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        slot: 1,
      );
      // 夏の大会を3回(3年ぶん)終える。広告は大会の直後ではなく、次の操作の前に出る。
      for (var year = 0; year < 3; year++) {
        while (c.game!.slot != 1) {
          await c.play(Action.rest);
        }
        await c.play(Action.rest); // 夏(大会)
        expect(ads.interstitials, 0, reason: '大会の直後には出ない');
      }
      await c.play(Action.rest); // 次の操作
      expect(ads.interstitials, 1);
    });
  });

  group('画面', () {
    testWidgets('設定にプライバシー・問い合わせ・ライセンスがある', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen(money: null)));
      await tester.pumpAndSettle();
      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.text('問い合わせ・広告の報告'), findsOneWidget);
      expect(find.text('ライセンス'), findsOneWidget);
    });

    testWidgets('設定に広告を消す(価格つき)と購入の復元がある', (tester) async {
      final (m, _, _) = await open();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(money: m)));
      await tester.pumpAndSettle();
      // ストアが返す半角の円記号は、同梱フォントにある全角の円記号で出す(displayPrice)。
      expect(find.text('広告を消す(￥370)'), findsOneWidget);
      expect(find.text('購入を復元'), findsOneWidget);
    });

    testWidgets('疲れていると「動画を見て元気になる」が出て、押すと回復する', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (m, ads, _) = await open();
      final c = GameController(rng: Random(1), events: false, money: m);
      c.game = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        condition: const Condition(fatigue: 80),
      );
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('動画を見て元気になる'), findsOneWidget);
      await tester.tap(find.text('動画を見て元気になる'));
      await tester.pumpAndSettle();
      expect(ads.rewarded, 1);
      expect(c.game!.condition.fatigue, 40);
      expect(find.text('動画を見て元気になる'), findsNothing, reason: '1ターンに1回');
    });

    testWidgets('広告を消した人は動画なしで「元気になる」', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (m, ads, _) = await open({'adFree': true});
      final c = GameController(rng: Random(1), events: false, money: m);
      c.game = Game(
        eventsEnabled: false,
        player: kid(),
        rng: Random(1),
        condition: const Condition(fatigue: 80),
      );
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('元気になる'));
      await tester.pumpAndSettle();
      expect(ads.rewarded, 0);
      expect(c.game!.condition.fatigue, 40);
    });
  });

  group('原文の検査(落とし穴 #3)', () {
    final src = File('lib/monetization/ad_service.dart').readAsStringSync();

    test('広告の読み込みを await で待たない(返るのは「頼み終えた」時点)', () {
      expect(src.contains('await InterstitialAd.load('), isFalse);
      expect(src.contains('await RewardedAd.load('), isFalse);
    });

    test('1時間で期限切れになる前に読み直す', () {
      expect(src, contains('Duration(minutes: 55)'));
    });

    test('広告ユニットIDの既定は Google のテスト用ID(本物は CI で渡す)', () {
      expect(AdMobAdService.isUsingTestUnitId, isTrue);
    });

    test('見終えた報酬を、画面を離れても受け取る(受け取りは mounted を見ない場所にある)', () {
      final controller = File('lib/ui/controller.dart').readAsStringSync();
      expect(controller.contains('mounted'), isFalse,
          reason: '報酬の受け取りを mounted の後ろに置かない');
      for (final f in ['game_screen', 'home_screen', 'history_screen', 'special_picker']) {
        final ui = File('lib/ui/$f.dart').readAsStringSync();
        expect(ui.contains('beforeRecover') || ui.contains('claimSpReward'), isFalse,
            reason: '$f が広告を直接扱っている。受け取りはコントローラが持つ');
      }
    });
  });

  test('値段の表示: 半角の円記号を、同梱フォントにある全角の円記号にそろえる', () {
    expect(displayPrice('¥370'), '￥370');
    expect(displayPrice('￥370'), '￥370');
    expect(displayPrice('US\$2.99'), 'US\$2.99');
  });
}
