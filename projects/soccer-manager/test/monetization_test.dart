import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/monetization/reward_offer.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/reward_funds_card.dart';
import 'package:soccer_manager/widgets/supporter_section.dart';

/// 常に広告が用意できていて、指定した結果を返す差し替え用の実装。
class _FakeAdService implements AdService {
  _FakeAdService({this.ready = true, this.watchedToEnd = true});

  bool ready;
  bool watchedToEnd;
  int showCount = 0;
  bool interstitialReady = true;
  int interstitialShowCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => ready;

  @override
  Future<bool> showRewardedAd() async {
    showCount++;
    return watchedToEnd;
  }

  @override
  bool get isInterstitialAdReady => interstitialReady;

  @override
  Future<void> showInterstitialAd() async {
    if (!interstitialReady) return;
    interstitialShowCount++;
  }

  @override
  void dispose() {}
}

class _FakePurchaseService implements PurchaseService {
  /// 受け取り口。本物は待っているかどうかに関係なく呼ぶ。
  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId, String? purchaseId)? onDeliveredCallback;

  _FakePurchaseService({this.outcome = PurchaseOutcome.purchased});

  PurchaseOutcome outcome;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceLabel() async => '¥480';

  /// 本物のストアは、結果を返す前に通知で商品を届ける。ここを返すだけに
  /// すると「払ったのに届かない」形のテストになってしまう。
  @override
  Future<PurchaseOutcome> buySupporter() async {
    if (outcome == PurchaseOutcome.purchased) {
      await onDeliveredCallback?.call(
          PurchaseService.supporterProductId, 'tx-${_seq++}');
    }
    return outcome;
  }

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;

  /// ストアから通知だけが届いた状態(待っている人が居ない)を作る。
  int _seq = 0;

  Future<void> deliverFromStore(String productId) async =>
      onDeliveredCallback?.call(productId, 'tx-${_seq++}');

  @override
  Future<PurchaseOutcome> restorePurchases() async {
    if (outcome == PurchaseOutcome.purchased) {
      await onDeliveredCallback?.call(
          PurchaseService.supporterProductId, 'tx-${_seq++}');
    }
    return outcome;
  }

  @override
  void dispose() {}
}

Future<MonetizationController> _build({
  _FakeAdService? ads,
  _HeldAdService? heldAds,
  _FakePurchaseService? purchases,
}) async {
  final controller = MonetizationController(
    adService: heldAds ?? ads ?? _FakeAdService(),
    purchases: purchases ?? _FakePurchaseService(),
  );
  await controller.initialize();
  return controller;
}

void main() {
  // ニュース文を日本語で突き合わせているため、表示言語を固定する。
  // (テスト環境の端末ロケールは en で、既定のままだと英語が返る)
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('収益化', () {
    test('広告を最後まで見れば特典を受け取れる', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      expect(money.requiresAd, isTrue);
      expect(await money.claimReward(), ClaimResult.granted);
      expect(ads.showCount, 1);
      expect(money.claimedToday, 1);
    });

    test('広告を途中で閉じたら回数を消費しない', () async {
      // 見ていないのに回数だけ減ると、利用者から見れば単なる損。
      final money = await _build(ads: _FakeAdService(watchedToEnd: false));

      expect(await money.claimReward(), ClaimResult.adNotCompleted);
      expect(money.claimedToday, 0);
      expect(money.remainingToday, RewardOffer.dailyLimitFree);
    });

    test('広告の在庫が無いときは押せない', () async {
      final money = await _build(ads: _FakeAdService(ready: false));

      expect(money.canClaim, isFalse);
      expect(await money.claimReward(), ClaimResult.unavailable);
    });

    test('1日の上限を超えて受け取れない', () async {
      final money = await _build();

      for (var i = 0; i < RewardOffer.dailyLimitFree; i++) {
        expect(await money.claimReward(), ClaimResult.granted);
      }
      expect(money.remainingToday, 0);
      expect(await money.claimReward(), ClaimResult.limitReached);
    });

    test('サポーターは広告なしで受け取れて、上限も増える', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      expect(await money.buySupporter(), PurchaseOutcome.purchased);
      expect(money.isSupporter, isTrue);
      expect(money.requiresAd, isFalse);
      expect(money.dailyLimit, RewardOffer.dailyLimitSupporter);

      expect(await money.claimReward(), ClaimResult.granted);
      expect(ads.showCount, 0, reason: 'サポーターに広告を見せてはいけない');
    });

    test('サポーター状態は再起動後も残り、復元でも戻る', () async {
      final first = await _build();
      await first.buySupporter();

      // 同じ端末で起動し直した想定。
      final again = await _build();
      expect(again.isSupporter, isTrue);

      // 購入情報が消えた端末で復元した想定。
      SharedPreferences.setMockInitialValues({});
      final restored = await _build();
      expect(restored.isSupporter, isFalse);
      expect(await restored.restorePurchases(), PurchaseOutcome.purchased);
      expect(restored.isSupporter, isTrue);
    });

    test('購入をやめても失敗扱いにしない', () async {
      final money = await _build(
        purchases: _FakePurchaseService(outcome: PurchaseOutcome.canceled),
      );
      expect(await money.buySupporter(), PurchaseOutcome.canceled);
      expect(money.isSupporter, isFalse);
    });

    test('特典額はディビジョンに比例し、下部ほど少ない', () async {
      // 1部の額を5部で配ると序盤の経営判断が消し飛ぶ。
      expect(RewardOffer.fundsFor(1), greaterThan(RewardOffer.fundsFor(5)));
      for (var tier = 1; tier < 5; tier++) {
        expect(RewardOffer.fundsFor(tier),
            greaterThan(RewardOffer.fundsFor(tier + 1)));
      }
    });

    test('特典を受け取ると営業ブーストが貯まり、理由がニュースに残る。資金は増えない', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final before = gameState.save!.budget;

      expect(gameState.claimMarketingBoost(), 1);
      expect(gameState.marketingBoostWeeks, 1);
      // 資金を直接配らない。赤字を消せる力は持たせない。
      expect(gameState.save!.budget, before);
      expect(gameState.save!.newsLog.first.text, contains('営業'));
    });

    test('営業ブーストが上限のときは広告が出ず、回数も減らない。次の節の収入だけ増える',
        () async {
      // 以前は上限を超えて受け取れて(広告も出て)、3節で黙って止まっていた。
      // 利用者から見ると「広告を見たのに入らず、回数だけ減った」。
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final id = gameState.save!.userTeamId;
      final plain = gameState.weeklyIncomeFor(id);
      // 放映権は営業では増えない。
      final broadcast = gameState.weeklyIncomeParts(id).broadcast;

      // 前の日までに上限まで貯めてあり、今日の回数はまだ残っている場面。
      for (var i = 0; i < GameStateSquad.marketingBoostCap; i++) {
        gameState.claimMarketingBoost();
      }
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      expect(money.remainingToday, greaterThan(0));
      expect(gameState.marketingBoostWeeks, GameStateSquad.marketingBoostCap);
      expect(gameState.marketingBoostFull, isTrue);
      expect(gameState.marketingBoostWeeksUntilRoom, 1);

      final shown = ads.showCount;
      final used = money.claimedToday;
      final news = gameState.save!.newsLog.length;
      expect(await money.claimReward(bankFull: gameState.marketingBoostFull),
          ClaimResult.bankFull);
      expect(ads.showCount, shown, reason: '上限なのに広告を出している');
      expect(money.claimedToday, used, reason: '上限なのに回数を減らしている');
      // ゲーム側も、上限で呼ばれたら何も変えない(ニュースにも残さない)。
      expect(gameState.claimMarketingBoost(), GameStateSquad.marketingBoostCap);
      expect(gameState.save!.newsLog.length, news,
          reason: '入っていないのに「営業を強化した」と残している');
      expect(gameState.marketingBoostWeeks, GameStateSquad.marketingBoostCap);
      expect(
          gameState.weeklyIncomeFor(id),
          closeTo(
              ((plain - broadcast) * GameStateSquad.marketingBoostMultiplier)
                      .round() +
                  broadcast,
              2));
    });

    test('シーズンの切り替わりでは全画面広告が出る', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      expect(money.willShowSeasonInterstitial, isTrue);
      await money.showSeasonInterstitial();
      expect(ads.interstitialShowCount, 1);
    });

    test('サポーターには全画面広告を出さない', () async {
      // 「買えば全画面広告が消える」ことがこの買い切りの主な値打ちで、
      // ここが崩れると設定画面とストア掲載文の説明が嘘になる。
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      await money.buySupporter();

      expect(money.isSupporter, isTrue);
      expect(money.willShowSeasonInterstitial, isFalse);
      await money.showSeasonInterstitial();
      expect(ads.interstitialShowCount, 0);
    });

    test('広告の在庫が無くてもシーズンの進行は止まらない', () async {
      // 在庫切れは珍しくない(通信断・配信なし)。ここで待たされたり
      // 例外になったりすると、次のシーズンへ進めなくなる。
      final ads = _FakeAdService()..interstitialReady = false;
      final money = await _build(ads: ads);

      expect(money.willShowSeasonInterstitial, isFalse);
      await money.showSeasonInterstitial();
      expect(ads.interstitialShowCount, 0);
    });
  });

  group('営業ブーストの上限', () {
    test('上限なら、結果を後から返す広告でも表示を頼まずに断る', () async {
      // 本物の広告は show がすぐ返り、結果は後から来る(app-pitfalls の9)。
      // 断る判定が広告の結果待ちの後ろにあると、表示だけ始まってしまう。
      final ads = _HeldAdService();
      final money = await _build(ads: null, heldAds: ads);

      ClaimResult? result;
      final claim =
          money.claimReward(bankFull: true).then((r) => result = r);
      await Future<void>.delayed(Duration.zero);
      expect(ads.showCount, 0, reason: '上限なのに広告の表示を頼んでいる');
      await claim;
      expect(result, ClaimResult.bankFull);
      expect(money.claimedToday, 0);
      expect(money.remainingToday, RewardOffer.dailyLimitFree);
    });

    test('上限の1つ手前なら、後から届く結果を待って受け取り、上限で止まる', () async {
      final gameState = GameState();
      await gameState.startNewGame('手前FC');
      for (var i = 0; i < GameStateSquad.marketingBoostCap - 1; i++) {
        gameState.claimMarketingBoost();
      }
      expect(gameState.marketingBoostFull, isFalse);

      final ads = _HeldAdService();
      final money = await _build(heldAds: ads);
      ClaimResult? result;
      final claim = money
          .claimReward(bankFull: gameState.marketingBoostFull)
          .then((r) => result = r);
      await Future<void>.delayed(Duration.zero);
      expect(ads.showCount, 1);
      expect(result, isNull, reason: '広告が閉じる前に結果が出ている');

      ads.finish(watched: true);
      await claim;
      expect(result, ClaimResult.granted);
      gameState.claimMarketingBoost();
      expect(gameState.marketingBoostWeeks, GameStateSquad.marketingBoostCap);
      expect(gameState.marketingBoostFull, isTrue);

      // 次はもう広告を出さない。
      expect(await money.claimReward(bankFull: gameState.marketingBoostFull),
          ClaimResult.bankFull);
      expect(ads.showCount, 1);
      expect(money.claimedToday, 1);
    });

    test('サポーターでも上限なら断り、回数を減らさない', () async {
      final money = await _build();
      await money.buySupporter();
      expect(money.isSupporter, isTrue);

      expect(await money.claimReward(bankFull: true), ClaimResult.bankFull);
      expect(money.claimedToday, 0);
      expect(money.remainingToday, RewardOffer.dailyLimitSupporter);
    });

    testWidgets('上限のとき、カードのボタンは押せず、理由と残りが出る', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ads = _HeldAdService();
      late final MonetizationController money;
      late final GameState gameState;
      await tester.runAsync(() async {
        money = await _build(heldAds: ads);
        gameState = GameState();
        await gameState.startNewGame('満杯FC');
      });
      for (var i = 0; i < GameStateSquad.marketingBoostCap; i++) {
        gameState.claimMarketingBoost();
      }

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: gameState),
          ChangeNotifierProvider<MonetizationController>.value(value: money),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: RewardFundsCard())),
        ),
      ));
      await tester.pump();

      expect(
          find.text('貯められるのは${GameStateSquad.marketingBoostCap}節まで'
              '（あと1節ぶん使うと見られます）'),
          findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(button.onPressed, isNull, reason: '上限なのに押せる');

      await tester.tap(find.byWidgetPredicate((w) => w is ButtonStyleButton));
      await tester.pump();
      expect(ads.showCount, 0, reason: '上限なのに広告を出している');
      expect(money.claimedToday, 0);

      await tester.runAsync(gameState.flushPendingSave);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('価格の表示', () {
    test('ストアの半角の「¥」は全角に置き換える', () {
      // 同梱フォント(NotoSansJP・ShipporiMincho)には U+00A5 が無い。
      expect(MonetizationController.displayPrice('¥480'), '￥480');
      expect(MonetizationController.displayPrice('￥480'), '￥480');
      expect(MonetizationController.displayPrice('\$4.99'), '\$4.99');
    });

    testWidgets('サポーターの購入ボタンは全角の「￥」で出る', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late final MonetizationController money;
      await tester.runAsync(() async => money = await _build());
      expect(money.priceLabel, '￥480');

      await tester.pumpWidget(
        ChangeNotifierProvider<MonetizationController>.value(
          value: money,
          child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: SupporterSection())),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('サポーターになる（￥480）'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing,
          reason: '同梱フォントに無い半角の「¥」が画面に出ている');
      expect(find.text('課金と広告'), findsOneWidget);
    });
  });
}

/// 本物の広告と同じく、表示を頼んだ後で結果が届く差し替え。
///
/// [finish] を呼ぶまで [showRewardedAd] の結果は返らない。
class _HeldAdService implements AdService {
  int showCount = 0;
  Completer<bool>? _gate;

  void finish({required bool watched}) => _gate!.complete(watched);

  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => true;

  @override
  Future<bool> showRewardedAd() {
    showCount++;
    _gate = Completer<bool>();
    return _gate!.future;
  }

  @override
  bool get isInterstitialAdReady => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}
