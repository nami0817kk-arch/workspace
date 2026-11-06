// 広告と課金の決まりを、偽の広告・偽のストアで確かめる(docs/app-pitfalls.md の5件を当てる)。
import 'dart:io';
import 'dart:math';

import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/monetization/ad_service.dart';
import 'package:basketball_career/monetization/monetization.dart';
import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/settings_screen.dart';
import 'package:flutter/material.dart';
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

Future<(Monetization, FakeAds, FakeStore)> open(
    [Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final ads = FakeAds(), store = FakeStore();
  final m = Monetization(await SharedPreferences.getInstance(),
      ads: ads, store: store);
  await m.start();
  return (m, ads, store);
}

Future<GmController> gmController(Monetization m) async =>
    GmController(money: m, prefs: await SharedPreferences.getInstance(), seedSource: Random(1));

/// シーズンの途中(1区切りも進めていない)まで進めたコントローラ。
Future<GmController> inSeason(Monetization m) async {
  final c = await gmController(m);
  c.newCareer(Scenario.middle);
  c.startSeason();
  return c;
}

/// 解任された直後の任期にする。
void makeFired(Career car) {
  car.trust = 1;
  car.startSeason();
  car.target = gamesPerSeason;
  while (car.phase == Phase.season) {
    car.playBlock();
  }
  car.playPlayoffs();
}

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

  group('動画の直後は重ねない・広告を消す案内', () {
    Future<void> due(Monetization m) async {
      for (var i = 0; i < Monetization.interstitialEvery; i++) {
        await m.tournamentPlayed();
      }
    }

    test('動画を見た2分のあいだは全画面広告を出さず、番は次へ回す', () async {
      final (m, ads, _) = await open();
      var now = DateTime(2026, 11, 5, 12);
      m.clock = () => now;
      await due(m);
      expect(await m.beforeRecover(), RecoverGate.granted);
      now = now.add(const Duration(seconds: 30));
      expect(await m.beforeAction(), isFalse);
      expect(ads.interstitials, 0);
      expect(m.interstitialDue, isTrue, reason: '番は消えない');
      now = now.add(Monetization.rewardedCooldown);
      expect(await m.beforeAction(), isTrue);
      expect(ads.interstitials, 1);
    });

    test('途中で閉じた動画も「見た」に数える。出せなかった動画は数えない', () async {
      final (m, ads, _) = await open();
      final now = DateTime(2026, 11, 5, 12);
      m.clock = () => now;
      await due(m);
      ads.rewardedReady = false;
      expect(await m.beforeRecover(), RecoverGate.unavailable);
      expect(await m.beforeAction(), isTrue, reason: '動画は出ていないので、全画面広告は出してよい');
      await due(m);
      ads
        ..rewardedReady = true
        ..watchToEnd = false;
      expect(await m.beforeRecover(), RecoverGate.declined);
      expect(await m.beforeAction(), isFalse);
    });

    test('案内は全画面広告の2回目と、その後4回ごとに1度だけ。出せなかった広告は数えない', () async {
      final (m, ads, _) = await open();
      final offers = <int>[];
      for (var i = 1; i <= 10; i++) {
        await due(m);
        if (i == 4) {
          ads.interstitialReady = false;
          expect(await m.beforeAction(), isFalse);
          ads.interstitialReady = true;
        }
        expect(await m.beforeAction(), isTrue);
        if (m.removeAdsOfferDue) {
          offers.add(m.interstitialsShown);
          await m.markRemoveAdsOffered();
          expect(m.removeAdsOfferDue, isFalse, reason: '同じ番で二度出さない');
        }
      }
      expect(m.interstitialsShown, 10);
      expect(offers, [2, 6, 10]);
    });

    test('数えは端末に残る(再起動しても同じ番で二度出さない)', () async {
      final (m, _, _) = await open({'interstitialsShown': 2, 'removeAdsOfferedAt': 2});
      expect(m.removeAdsOfferDue, isFalse);
      final (m2, _, _) = await open({'interstitialsShown': 2});
      expect(m2.removeAdsOfferDue, isTrue);
    });

    test('広告を消した人には案内しない', () async {
      final (m, _, _) = await open({'interstitialsShown': 2, 'adFree': true});
      expect(m.removeAdsOfferDue, isFalse);
    });

    test('コントローラ: 2回目の全画面広告のあとに案内が立つ。ストアに繋がらなければ立てない', () async {
      for (final available in [true, false]) {
        final (m, ads, store) = await open({'interstitialsShown': 1});
        store.available = available;
        final c = await inSeason(m);
        await due(m);
        await c.playBlock();
        expect(ads.interstitials, 1);
        expect(c.offerRemoveAds, available, reason: 'ストア $available');
        expect(m.removeAdsOfferDue, isFalse, reason: '出さなかったときも、同じ番では二度聞かない');
      }
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

  group('コントローラ(GMの任期)', () {
    test('試合の区切りを3回終えたら、次の区切りを進める前に全画面広告が1回出る。区切りの直後には出ない', () async {
      final (m, ads, _) = await open();
      final c = await inSeason(m);
      for (var i = 0; i < 3; i++) {
        await c.playBlock();
      }
      expect(ads.interstitials, 0, reason: '3回目の区切りの直後には出ない');
      expect(m.interstitialDue, isTrue);
      await c.playBlock();
      expect(ads.interstitials, 1);
      expect(c.career!.phase, Phase.playoffs, reason: '広告のあと、そのまま進む');
    });

    test('動画を見終えるとスカウトが2回増える(ドラフトごとに1回)。読み込めなければ増えない', () async {
      final (m, ads, _) = await open();
      final c = await inSeason(m);
      final car = c.career!;
      while (car.phase == Phase.season) {
        car.playBlock();
      }
      car.playPlayoffs();
      car.fired = false;
      c.toOffseason();
      expect(car.phase, Phase.draft);
      final before = car.scoutsLeft;
      ads.rewardedReady = false;
      expect(await c.scoutsWithAd(), RecoverGate.unavailable);
      expect(car.scoutsLeft, before);
      ads.rewardedReady = true;
      expect(await c.scoutsWithAd(), RecoverGate.granted);
      expect(car.scoutsLeft, before + 2);
      expect(await c.scoutsWithAd(), RecoverGate.unavailable, reason: 'ドラフトごとに1回');
      expect(ads.rewarded, 1);
    });

    test('解任されたら、動画で1回だけオーナーを説得できる。広告を消した人は動画なし', () async {
      for (final adFree in [false, true]) {
        final (m, ads, _) = await open({if (adFree) 'adFree': true});
        final c = await gmController(m);
        c.newCareer(Scenario.lastWindow);
        final car = c.career!;
        makeFired(car);
        expect(car.fired, isTrue);
        expect(await c.rescueWithAd(), RecoverGate.granted);
        expect(car.fired, isFalse);
        expect(car.trust, greaterThan(0));
        expect(ads.rewarded, adFree ? 0 : 1);
        expect(car.canRescue, isFalse, reason: '1回の任期で1回だけ');
      }
    });

    test('広告の無い環境では、タダで説得させない', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(1));
      c.newCareer(Scenario.lastWindow);
      makeFired(c.career!);
      expect(await c.rescueWithAd(), RecoverGate.unavailable);
      expect(c.career!.fired, isTrue);
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

    testWidgets('全画面広告のあとの案内から「広告を消す」を買える。「今はいい」なら何も起きない', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final buy in [false, true]) {
        final (m, ads, _) = await open({'interstitialsShown': 1, 'tournamentsSinceAd': Monetization.interstitialEvery});
        final c = await inSeason(m);
        await tester.pumpWidget(BasketballCareerApp(controller: c));
        await tester.pumpAndSettle();
        await tester.runAsync(() => c.playBlock());
        await tester.pumpAndSettle();
        expect(ads.interstitials, 1);
        expect(find.text('広告なしで遊ぶ'), findsOneWidget);
        expect(find.text('広告を消す(￥370)'), findsOneWidget);
        await tester.tap(find.text(buy ? '広告を消す(￥370)' : '今はいい'));
        await tester.pumpAndSettle();
        expect(find.text('広告なしで遊ぶ'), findsNothing);
        expect(m.adFree, buy);
        expect(c.offerRemoveAds, isFalse);
        if (buy) expect(find.text('ありがとう! 広告が出なくなった。'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('解任の画面の「動画を見て、オーナーを説得する」を押すと続けられる', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (m, ads, _) = await open();
      final c = await gmController(m);
      c.newCareer(Scenario.lastWindow);
      makeFired(c.career!);
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      while (find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK').first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('動画を見て、オーナーを説得する(1回だけ)'));
      await tester.pumpAndSettle();
      expect(ads.rewarded, 1);
      expect(c.career!.fired, isFalse);
      expect(find.text('動画を見て、オーナーを説得する(1回だけ)'), findsNothing);
      await tester.pumpWidget(const SizedBox());
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
      final controller = File('lib/ui/gm_controller.dart').readAsStringSync();
      expect(controller.contains('mounted'), isFalse,
          reason: '報酬の受け取りを mounted の後ろに置かない');
      for (final f in Directory('lib/ui/gm').listSync().whereType<File>()) {
        final ui = f.readAsStringSync();
        expect(ui.contains('beforeRecover') || ui.contains('beforeAction'), isFalse,
            reason: '${f.path} が広告を直接扱っている。受け取りはコントローラが持つ');
      }
    });
  });

  test('値段の表示: 半角の円記号を、同梱フォントにある全角の円記号にそろえる', () {
    expect(displayPrice('¥370'), '￥370');
    expect(displayPrice('￥370'), '￥370');
    expect(displayPrice('US\$2.99'), 'US\$2.99');
  });
}
