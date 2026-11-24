import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/first_days_guide.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 最初の数日の案内。5枚の説明をやめ、状況の「やること」で1つずつ案内する
/// (2026-11-25)。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame() async {
    final gs = GameState();
    await gs.startNewGame('案内FC');
    return gs;
  }

  TodoItem? guideOf(GameState gs) => TodoAdvisor.build(gs)
      .where((t) => t.kind == TodoKind.firstSteps)
      .firstOrNull;

  test('始めたばかりは1段目が「やること」のおすすめの先頭に出る', () async {
    final gs = await newGame();
    final items = TodoAdvisor.build(gs);
    final rec = items.recommended.toList();
    expect(rec.first.kind, TodoKind.firstSteps);
    expect(rec.first.title, contains('1/5'));
    expect(rec.first.place, TodoPlaces.financeOverview);
    // 行き先の左メニューに青い点が付く。
    expect(items.recommendedAt(TodoMenu.finance), greaterThan(0));
  });

  test('押すと次の段に替わり、5段目は押しても残る', () async {
    final gs = await newGame();
    final seen = <String>[];
    for (var i = 0; i < 4; i++) {
      final t = guideOf(gs)!;
      seen.add(t.tag!);
      FirstDaysGuide.markSeen(gs, t.tag!);
    }
    expect(seen, ['finance', 'squad', 'transfer', 'office']);
    final last = guideOf(gs)!;
    expect(last.title, contains('5/5'));
    FirstDaysGuide.markSeen(gs, last.tag!);
    expect(guideOf(gs)?.tag, 'advance', reason: '最後の段は最初のリーグ戦まで残す');
  });

  test('見た段は保存して読み戻せる', () async {
    final gs = await newGame();
    FirstDaysGuide.markSeen(gs, 'finance');
    final restored = SaveGame.fromJson(gs.save!.toJson());
    expect(restored.firstRunStepsSeen, contains('guide_finance'));
  });

  test('最初のリーグ戦を終えたら、案内は出ない', () async {
    final gs = await newGame();
    expect(guideOf(gs), isNotNull);
    for (var i = 0; i < 12 && gs.isPreseason; i++) {
      await gs.playNextMatchday();
      if (gs.isHalfTime) await gs.playSecondHalf();
    }
    expect(gs.isPreseason, isFalse);
    expect(guideOf(gs), isNull);
  });

  test('案内を閉じたセーブには出ない', () async {
    final gs = await newGame();
    gs.save!.firstRunGuideDismissed = true;
    expect(guideOf(gs), isNull);
  });
}
