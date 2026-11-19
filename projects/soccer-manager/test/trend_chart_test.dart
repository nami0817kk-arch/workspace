import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/trend_chart.dart';

/// 推移のグラフの検査。記録が少なくても多くても、例外なく描ける。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<void> pump(WidgetTester tester, GameState game) async {
    Tr.language = AppLanguage.japanese;
    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: game,
      child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: TrendsCard()))),
    ));
    await tester.pump();
  }

  testWidgets('始めたばかり(記録なし)でも描け、線になる前の案内が出る', (tester) async {
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('推移FC');
    });
    await pump(tester, game);
    expect(tester.takeException(), isNull);
    expect(find.text('2季以上たつと線になります'), findsWidgets);
  });

  testWidgets('3季ぶんの記録があれば、線と最初と最後の値が出る', (tester) async {
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('推移FC');
    });
    final s = game.save!;
    for (var i = 1; i <= 3; i++) {
      s.seasonHistory.add(SeasonRecord(
        season: i,
        clubName: s.clubName,
        leagueName: 'L',
        divisionTier: 5 - i,
        finalRank: 3,
        teamCount: 18,
        played: 34,
        won: 20,
        draw: 7,
        lost: 7,
        goalsFor: 50,
        goalsAgainst: 30,
      ));
      s.clubValueHistory[i] = 10000 * i;
    }
    await pump(tester, game);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('第1季'), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
