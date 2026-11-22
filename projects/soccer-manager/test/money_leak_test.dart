import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/reward_funds_card.dart';

import 'support/stub_purchase_service.dart';
import 'support/legacy_market.dart';
import 'support/sell_via_offer.dart';

/// お金が湧く道・消える道の検査。
///
/// 資金のやりくりはこのゲームの土台で、そこが崩れると経営シミュレーション
/// として成り立たない。資金パックを買う理由も消える。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('分割払いの残金', () {
    test('分割で買ってすぐ売っても、資金は増えない', () async {
      // 残金を破棄していた頃は、頭金30%を払って市場価値の70%で売るだけで
      // 1回あたり市場価値の21%が手元に残った(実測)。市場の選手全員に
      // 対して何度でもできた。
      final game = GameState();
      await game.startNewGame('抜け道FC');
      game.save!.budget = 100000;
      final before = game.save!.budget;

      game.save!.wageBudget = 999999; // 年俸の枠で止めない
      // 市場の選手は作るたびに違い、登録の決まりで買えない選手もいる。
      // 買えた選手で確かめる。
      String? targetId;
      for (final p in [...legacyMarket(game)]) {
        if (await game.buyPlayerOnInstallments(p.id)) {
          targetId = p.id;
          break;
        }
      }
      expect(targetId, isNotNull, reason: '分割で買える選手がいない');
      expect(await sellViaOffer(game, targetId!), isNotNull);

      expect(game.save!.budget, lessThanOrEqualTo(before),
          reason: '買って売るだけで資金が増えている');
      expect(game.save!.pendingInstallments, isEmpty);
    });

    test('精算したことはニュースに残る', () async {
      // 黙って引かれると、収支が追えなくなる。
      Tr.language = AppLanguage.japanese;
      addTearDown(() => Tr.language = AppLanguage.system);
      final game = GameState();
      await game.startNewGame('明細FC');
      game.save!.budget = 100000;

      game.save!.wageBudget = 999999; // 年俸の枠で止めない
      // 市場の選手は作るたびに違い、登録の決まりで買えない選手もいる。
      // 買えた選手で確かめる。
      String? targetId;
      for (final p in [...legacyMarket(game)]) {
        if (await game.buyPlayerOnInstallments(p.id)) {
          targetId = p.id;
          break;
        }
      }
      expect(targetId, isNotNull, reason: '分割で買える選手がいない');
      await sellViaOffer(game, targetId!);

      expect(game.save!.newsLog.any((n) => n.text.contains('分割払いの残金')), isTrue,
          reason: '残金の精算が記録されていない');
    });

    test('分割払いが無い選手を売っても、余計な引き落としは無い', () async {
      final game = GameState();
      await game.startNewGame('通常FC');
      game.save!.budget = 100000;
      // 年俸の枠で止まると売り買いの前提が崩れる(市場の先頭が高い選手だと
      // 1割ほどの確率で枠を超える)。ここで見たいのは資金の出入りだけ。
      game.save!.wageBudget = 1000000;

      // 登録の枠(国籍・年齢)で買えない選手もいるので、買えるまで市場を順に試す。
      Player? bought;
      for (final c in legacyMarket(game).take(15)) {
        if (await game.buyPlayer(c.id)) {
          bought = c;
          break;
        }
      }
      expect(bought, isNotNull);
      final target = bought!;
      final afterBuy = game.save!.budget;
      final o = await sellViaOffer(game, target.id);
      expect(o, isNotNull);

      // 入るのはオファーの額。他の国のクラブへ売ったときだけ、連帯貢献金が
      // 引かれる。
      final solidarity = game.solidarityFor(target, o!.amount);
      expect(
          game.save!.budget,
          inInclusiveRange(
              afterBuy + o.amount - solidarity, afterBuy + o.amount));
    });
  });

  group('シーズンの更新', () {
    test('連打しても二重に走らない', () async {
      // 賞金・理事会の報奨金・昇格ボーナスがもう一度支払われ、シーズンも
      // 2つ進む。覆い(isBusy)が描かれるのは次のフレームなので、その前の
      // 連打は素通りしていた。
      final game = GameState();
      await game.startNewGame('連打FC');
      await game.simulateAheadMatchdays(60); // シーズンを終わらせる
      expect(game.save!.league.isSeasonComplete, isTrue,
          reason: 'シーズンが終わっていない(前提が崩れている)');

      final season = game.save!.league.season;
      final first = game.startNextSeason();
      final second = game.startNextSeason();
      await Future.wait([first, second]);

      expect(game.save!.league.season, season + 1, reason: 'シーズンが2つ進んでいる');
    });
  });

  group('広告の特典', () {
    testWidgets('見終えた後に画面を離れても、営業ブーストは入る', (tester) async {
      // 広告は最後まで見ているので、こちらには収入が立つ。受け取りを
      // mounted の後ろに置いていた頃は、回数だけ消費して資金が入らなかった。
      SharedPreferences.setMockInitialValues({});
      final ads = _HeldAdService();
      late final MonetizationController money;
      late final GameState game;
      await tester.runAsync(() async {
        money = MonetizationController(
            adService: ads, purchases: StubPurchaseService());
        await money.initialize();
        game = GameState();
        await game.startNewGame('離脱FC');
      });
      Tr.language = AppLanguage.japanese;
      addTearDown(() => Tr.language = AppLanguage.system);

      final before = game.marketingBoostWeeks;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<MonetizationController>.value(value: money),
        ],
        child: const MaterialApp(home: Scaffold(body: RewardFundsCard())),
      ));
      await tester.pump();

      await tester.tap(find.byType(FilledButton).first);
      await tester.pump(); // 広告の再生中(ここで止まっている)

      // 広告を見ているあいだに画面を離れる。
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<MonetizationController>.value(value: money),
        ],
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ));
      await tester.pump();

      ads.finish(); // ここで広告が最後まで再生される
      await tester.pump();
      await tester.pump();

      expect(game.marketingBoostWeeks, greaterThan(before),
          reason: '広告を見たのに営業ブーストが入っていない');
      expect(money.claimedToday, 1);

      // 受け取りが保存を予約する。残したままテストを終えると、未処理の
      // タイマーとして検出される。
      await tester.pump(GameState.persistDebounce);
    });
  });
}

/// 再生を明示的に終わらせるまで待たせる広告。
class _HeldAdService implements AdService {
  final _gate = Completer<bool>();

  void finish() => _gate.complete(true);

  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => true;

  @override
  Future<bool> showRewardedAd() => _gate.future;

  @override
  bool get isInterstitialAdReady => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}
