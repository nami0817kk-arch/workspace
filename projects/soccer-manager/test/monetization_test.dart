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
import 'package:soccer_manager/widgets/supporter_section.dart';

/// 全画面広告の差し替え。出した回数を数える。
class _FakeAdService implements AdService {
  bool interstitialReady = true;
  int interstitialShowCount = 0;

  @override
  Future<void> initialize() async {}

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
  Future<String?> priceLabel() async => '¥370';

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

  int _seq = 0;

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
  _FakePurchaseService? purchases,
}) async {
  final controller = MonetizationController(
    adService: ads ?? _FakeAdService(),
    purchases: purchases ?? _FakePurchaseService(),
  );
  await controller.initialize();
  return controller;
}

/// ゲームの中の月を数で(年×12+月-1)。
int _month(int year, int month) =>
    GameStateSupporters.monthKeyOf(DateTime(year, month));

void main() {
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('全画面広告はゲームの中で3か月ごと', () {
    test('初めは数え始めるだけで出さず、3か月たったら1回出る', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      // 始めてすぐ広告が出ると、最初の印象が悪い。
      expect(await money.showQuarterlyInterstitial(_month(2026, 7)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2026, 8)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2026, 9)), isFalse);
      expect(ads.interstitialShowCount, 0);

      expect(await money.showQuarterlyInterstitial(_month(2026, 10)), isTrue);
      expect(ads.interstitialShowCount, 1);

      // 同じ月にもう一度進めても出ない。次は3か月後。
      expect(await money.showQuarterlyInterstitial(_month(2026, 10)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2026, 12)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2027, 1)), isTrue);
      expect(ads.interstitialShowCount, 2);
    });

    test('何か月もまとめて進めても、出るのは1回だけ', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      await money.showQuarterlyInterstitial(_month(2026, 7));

      // シーズン終了まで進めた(10か月)。
      expect(await money.showQuarterlyInterstitial(_month(2027, 5)), isTrue);
      expect(ads.interstitialShowCount, 1);
      // そこから数え直す。
      expect(await money.showQuarterlyInterstitial(_month(2027, 7)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2027, 8)), isTrue);
    });

    test('別のセーブを開いて月が戻ったら、そこから数え直す', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      await money.showQuarterlyInterstitial(_month(2030, 1));

      expect(await money.showQuarterlyInterstitial(_month(2026, 7)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2026, 9)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2026, 10)), isTrue);
      expect(ads.interstitialShowCount, 1);
    });

    test('数えた月はアプリを起動し直しても残る', () async {
      final first = await _build();
      await first.showQuarterlyInterstitial(_month(2026, 7));

      final ads = _FakeAdService();
      final again = await _build(ads: ads);
      expect(await again.showQuarterlyInterstitial(_month(2026, 10)), isTrue);
      expect(ads.interstitialShowCount, 1);
    });

    test('広告の在庫が無くても進行は止まらない', () async {
      // 在庫切れは珍しくない(通信断・配信なし)。ここで待たされたり
      // 例外になったりすると、先へ進めなくなる。
      final ads = _FakeAdService()..interstitialReady = false;
      final money = await _build(ads: ads);
      await money.showQuarterlyInterstitial(_month(2026, 7));

      await money.showQuarterlyInterstitial(_month(2026, 10));
      expect(ads.interstitialShowCount, 0);
    });
  });

  group('広告を消す（買い切り）', () {
    test('買うと全画面広告が出なくなる', () async {
      // 「買えば全画面広告が消える」がこの買い切りの中身そのもので、
      // ここが崩れると設定画面とストア掲載文の説明が嘘になる。
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      await money.showQuarterlyInterstitial(_month(2026, 7));

      expect(await money.buySupporter(), PurchaseOutcome.purchased);
      expect(money.isSupporter, isTrue);
      expect(await money.showQuarterlyInterstitial(_month(2026, 10)), isFalse);
      expect(await money.showQuarterlyInterstitial(_month(2027, 5)), isFalse);
      expect(ads.interstitialShowCount, 0);
    });

    test('買った状態は再起動後も残り、復元でも戻る', () async {
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

    test('前に「サポーター」として買った記録でも広告は消える', () async {
      // 商品IDも端末の記録の鍵も変えていない。前の版で買った人が
      // 名前の変更で広告ありに戻らないこと。
      SharedPreferences.setMockInitialValues({'monetization.supporter': true});
      final ads = _FakeAdService();
      final money = await _build(ads: ads);
      expect(money.isSupporter, isTrue);
      await money.showQuarterlyInterstitial(_month(2026, 7));
      await money.showQuarterlyInterstitial(_month(2026, 10));
      expect(ads.interstitialShowCount, 0);
      expect(PurchaseService.supporterProductId, 'soccer_manager_supporter');
    });

    test('購入をやめても失敗扱いにしない', () async {
      final money = await _build(
        purchases: _FakePurchaseService(outcome: PurchaseOutcome.canceled),
      );
      expect(await money.buySupporter(), PurchaseOutcome.canceled);
      expect(money.isSupporter, isFalse);
    });
  });

  group('前の版の名残', () {
    test('資金パックの額はディビジョンに比例し、下部ほど少ない', () async {
      // 売るのはやめたが、受け取り損ねたぶんはこの額で渡す。
      expect(RewardOffer.fundsFor(1), greaterThan(RewardOffer.fundsFor(5)));
      for (var tier = 1; tier < 5; tier++) {
        expect(RewardOffer.fundsFor(tier),
            greaterThan(RewardOffer.fundsFor(tier + 1)));
      }
    });

    test('前の版で貯めた営業ブーストは、使い切るまで次の節の収入を増やす', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final id = gameState.save!.userTeamId;
      final plain = gameState.weeklyIncomeFor(id);
      // 放映権は営業では増えない。
      final broadcast = gameState.weeklyIncomeParts(id).broadcast;

      gameState.save!.marketingBoostWeeks = 2;
      expect(gameState.marketingBoostWeeks, 2);
      expect(
          gameState.weeklyIncomeFor(id),
          closeTo(
              ((plain - broadcast) * GameStateSquad.marketingBoostMultiplier)
                      .round() +
                  broadcast,
              2));
    });
  });

  group('価格の表示', () {
    test('ストアの半角の「¥」は全角に置き換える', () {
      // 同梱フォント(NotoSansJP・ShipporiMincho)には U+00A5 が無い。
      expect(MonetizationController.displayPrice('¥480'), '￥480');
      expect(MonetizationController.displayPrice('￥480'), '￥480');
      expect(MonetizationController.displayPrice('\$4.99'), '\$4.99');
    });

    testWidgets('「広告を消す」の購入ボタンは全角の「￥」で出る', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late final MonetizationController money;
      await tester.runAsync(() async => money = await _build());
      expect(money.priceLabel, '￥370');

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

      expect(find.text('広告を消す（￥370）'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing,
          reason: '同梱フォントに無い半角の「¥」が画面に出ている');
      expect(find.text('広告と課金'), findsOneWidget);
      // 1.2.0 では「サポーターの期待」がある。課金の名前と取り違えないよう、
      // 課金の欄に「サポーター」の語を出さない。
      expect(find.textContaining('サポーター'), findsNothing);
      // 動画広告はやめた。
      expect(find.textContaining('営業を強化'), findsNothing);
    });
  });
}
