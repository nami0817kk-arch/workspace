import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/shareholder_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 株主の期待(オーナー型の2つ目のメーター)。
///
/// サポーター側の期待は既存の信頼度が受け持ち、資金のマイナスと収支の評価
/// だけを株主の期待へ振り分けている。振り分けが崩れると、お金の問題で
/// 成績の信頼度が下がる(元の挙動)に戻ってしまう。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ShareholderEngine', () {
    test('黒字でシーズンを終えると上がり、赤字なら下がる', () {
      expect(ShareholderEngine.deltaForSeasonEnd(budget: 0), greaterThan(0));
      expect(ShareholderEngine.deltaForSeasonEnd(budget: 5000), greaterThan(0));
      expect(ShareholderEngine.deltaForSeasonEnd(budget: -1), lessThan(0));
    });

    test('増減は0〜100に収まる', () {
      expect(ShareholderEngine.applied(95, 8), 100);
      expect(ShareholderEngine.applied(5, -12), 0);
      expect(ShareholderEngine.applied(60, 8), 68);
    });
  });

  group('セーブ', () {
    test('株主の期待は保存して読み戻せる', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      gameState.save!.shareholderExpectation = 37;

      final restored = SaveGame.fromJson(gameState.save!.toJson());
      expect(restored.shareholderExpectation, 37);
    });

    test('株主の期待が無い旧セーブは、既定の60で読み込める', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final json = gameState.save!.toJson()..remove('shareholderExpectation');

      final restored = SaveGame.fromJson(json);
      expect(restored.shareholderExpectation, 60);
    });
  });

  group('資金のマイナスの振り分け', () {
    test('赤字が閾値の週数続くと、株主の期待が下がり、成績の信頼度は下がらない',
        () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final save = gameState.save!;
      final start = save.shareholderExpectation;
      final confidenceBefore = save.confidence;
      // 次の週で、赤字の連続がちょうど閾値(8週)に届く。
      save.budget = -999999;
      save.consecutiveNegativeBudgetWeeks =
          BoardEngine.negativeBudgetPenaltyThresholdWeeks - 1;

      await gameState.playNextMatchday();
      if (gameState.isHalfTime) await gameState.playSecondHalf();

      expect(save.shareholderExpectation, lessThan(start));
      // 信頼度は試合結果(1試合±3)でしか動かない。資金の減点(-8)は受けない。
      expect(
        save.confidence,
        inInclusiveRange(confidenceBefore - 3, confidenceBefore + 3),
      );
    });

    test('赤字でも閾値に届かない週は、株主の期待は変わらない', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final save = gameState.save!;
      final start = save.shareholderExpectation;
      save.budget = -999999;
      save.consecutiveNegativeBudgetWeeks = 0;

      await gameState.playNextMatchday();
      if (gameState.isHalfTime) await gameState.playSecondHalf();

      expect(save.shareholderExpectation, start);
    });
  });
}
