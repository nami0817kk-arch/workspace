import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/reward_funds_card.dart';

/// 常に広告を最後まで見せられる差し替え用の実装。
class _FakeAds implements AdService {
  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => true;
  @override
  Future<bool> showRewardedAd() async => true;
  @override
  bool get isInterstitialAdReady => false;
  @override
  Future<void> showInterstitialAd() async {}
  @override
  void dispose() {}
}

class _NoStore implements PurchaseService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<String?> priceLabel() async => null;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}

void main() {
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('特典を1回受け取ると、加算もニュースも1回だけ', (tester) async {
    // Tr.pick(ja, en) は両方の引数を評価する。受け取り処理を文字列の中に
    // 書いていたため、日本語ぶんと英語ぶんで2回加算されていた。実機では
    // 表示額の2倍が入り、ニュースも2件並ぶ。画面を描かないと踏めないので、
    // ここはウィジェットとして操作して確かめる。
    SharedPreferences.setMockInitialValues({});
    late final MonetizationController money;
    late final GameState gameState;
    await tester.runAsync(() async {
      money = MonetizationController(
          adService: _FakeAds(), purchases: _NoStore());
      await money.initialize();
      gameState = GameState();
      await gameState.startNewGame('テストFC');
    });

    final before = gameState.save!.budget;
    final newsBefore = gameState.save!.newsLog.length;
    final expected = gameState.rewardFundsAmount;

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

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(gameState.save!.budget - before, expected,
        reason: '受け取り額が表示と違う(二重加算になっていないか)');
    expect(gameState.save!.newsLog.length - newsBefore, 1,
        reason: '1回の受け取りでニュースが複数残っている');
    expect(money.claimedToday, 1);

    // 保存の遅延書き込みとスナックバーのタイマーを残したままだと、
    // ウィジェットツリーの破棄で「Timer is still pending」になる。
    await tester.runAsync(gameState.flushPendingSave);
    await tester.pump(const Duration(seconds: 5));
  });
}
