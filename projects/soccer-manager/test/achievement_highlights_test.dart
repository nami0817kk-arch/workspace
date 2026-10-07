import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/achievement_engine.dart';
import 'package:soccer_manager/logic/achievement_highlights.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/achievement.dart';
import 'package:soccer_manager/screens/achievements_screen.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「あと少し」の選び方の検査。
///
/// 実績は33件あり、5つのカテゴリに達成済みと未達成が混ざって並ぶ。
/// どれが手の届く位置にあるかは全部のバーを見比べないと分からないので、
/// 近いものだけを先に出す。何を近いと呼ぶかをここで固定しておく。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Achievement fake(String id, int current, int target) => Achievement(
        id: id,
        category: AchievementCategory.record,
        name: id,
        description: id,
        isUnlocked: (save, team) => false,
        progress: (save, team) => (current, target),
      );

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('実績FC');
    return game;
  }

  test('半分に届いていないものは「あと少し」に出さない', () async {
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      [fake('far', 1, 10), fake('near', 9, 10)],
      game.save!,
      game.userTeam,
      isUnlocked: (_) => false,
    );

    expect(result.map((p) => p.achievement.id), ['near']);
  });

  test('近い順に並ぶ', () async {
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      [fake('half', 5, 10), fake('almost', 19, 20), fake('most', 7, 10)],
      game.save!,
      game.userTeam,
      isUnlocked: (_) => false,
    );

    expect(result.map((p) => p.achievement.id), ['almost', 'most', 'half']);
  });

  test('同じ割合なら、残り回数が少ない方が先', () async {
    // 1/2 と 50/100 はどちらも50%だが、前者は1試合で届く。
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      [fake('big', 50, 100), fake('small', 1, 2)],
      game.save!,
      game.userTeam,
      isUnlocked: (_) => false,
    );

    expect(result.first.achievement.id, 'small');
  });

  test('出すのは3件まで', () async {
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      [for (var i = 0; i < 8; i++) fake('a$i', 9, 10)],
      game.save!,
      game.userTeam,
      isUnlocked: (_) => false,
    );

    expect(result.length, AchievementHighlights.maxHighlights);
  });

  test('達成済みのものは出さない', () async {
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      [fake('done', 10, 10), fake('open', 9, 10)],
      game.save!,
      game.userTeam,
      isUnlocked: (id) => id == 'done',
    );

    expect(result.map((p) => p.achievement.id), ['open']);
  });

  test('進み具合を数値で表せない実績は対象外', () async {
    final game = await newGame();
    final noProgress = Achievement(
      id: 'back_to_back',
      category: AchievementCategory.title,
      name: '連覇',
      description: '連覇する',
      isUnlocked: (save, team) => false,
    );

    final result = AchievementHighlights.almostThere(
      [noProgress],
      game.save!,
      game.userTeam,
      isUnlocked: (_) => false,
    );

    expect(result, isEmpty);
  });

  test('始めたばかりのセーブでは、実際の実績定義で落ちない', () async {
    // 通算勝利0・シーズン0の状態で全定義を通す。割り算やnull参照で
    // 落ちないこと自体を見ておく(実績画面を開くたびに走る処理)。
    final game = await newGame();
    final result = AchievementHighlights.almostThere(
      AchievementEngine.all,
      game.save!,
      game.userTeam,
      isUnlocked: game.isAchievementUnlocked,
    );

    expect(result.length, lessThanOrEqualTo(AchievementHighlights.maxHighlights));
    for (final p in result) {
      expect(p.ratio, greaterThanOrEqualTo(AchievementHighlights.nearThreshold));
      expect(p.remaining, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('実績画面の一番上に「あと少し」が出る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final GameState gameState;
    // testWidgets は疑似時間で動くため、SharedPreferences を待つ処理は
    // そのままでは完了しない。セットアップだけ実時間で走らせる。
    await tester.runAsync(() async {
      gameState = GameState();
      await gameState.startNewGame('あと少しFC');
    });
    // 通算50勝の実績まであと5勝の状態にする。
    gameState.save!.careerWins = 45;
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);

    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: gameState,
      child: const MaterialApp(home: AchievementsScreen()),
    ));
    await tester.pump();

    expect(find.text('あと少し'), findsOneWidget,
        reason: '近い実績があるのに見出しが出ていない');
    // カテゴリ欄にも残るが、そちらは画面外(ListView が作らない)なので
    // 一番上の欄のぶんだけが見える。
    expect(find.text('通算50勝'), findsWidgets);
    expect(find.textContaining('あと5'), findsOneWidget,
        reason: '残り数が出ていない');
    expect(tester.takeException(), isNull);
  });
}
