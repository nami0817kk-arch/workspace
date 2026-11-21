import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/owner_goal.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/owner_goal_card.dart';

/// 状況のオーナーの目標: 決める前は1行の札だけで、押すと選ぶ画面が開き、
/// 選ぶと目標が決まる(2026-11-21、選択肢7つを状況に並べるのをやめた)。
void main() {
  testWidgets('目標の札を押して選ぶと、目標が決まる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('Seiran FC');
    });
    expect(game.ownerGoal, isNull);
    final first = game.selectableOwnerGoals.first;

    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: game,
      child: const MaterialApp(home: Scaffold(body: OwnerGoalCard())),
    ));
    // 決める前は選択肢を並べない。
    expect(find.text(first.label), findsNothing);

    await tester.tap(find.text('オーナーの目標を決める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(first.label));
    await tester.pumpAndSettle();

    expect(game.ownerGoal?.label, first.label);
    expect(find.text('オーナーの目標'), findsOneWidget);
  });
}
