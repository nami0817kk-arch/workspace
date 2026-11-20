import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/undoable.dart';

/// お金が動く操作は、押した直後の「取り消す」で元に戻せること。
void main() {
  testWidgets('hiring staff can be undone from the snack bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);
    final game = GameState();
    await tester.runAsync(() => game.startNewGame('取り消しFC'));
    const role = StaffRole.headCoach;
    final candidate = game.staffCandidatesFor(role).first;
    final budgetBefore = game.save!.budget;
    expect(game.staffFor(role), isNull);

    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: game,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runUndoable(
                context,
                action: () => game.hireStaff(candidate.id),
                done: 'hired',
              ),
              child: const Text('hire'),
            ),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text('hire'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(game.staffFor(role)?.id, candidate.id);
    expect(find.text('取り消す'), findsOneWidget);
    // 知らせの帯が下から出きるまで待つ。
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('取り消す'));
    // 取り消しはセーブを読み直す(非同期)ので、実時間で少し待つ。
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(game.staffFor(role), isNull);
    expect(game.save!.budget, budgetBefore);
    // 帯が消えるまで進めてから終える(残った時計がテストの後に走らないように)。
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
