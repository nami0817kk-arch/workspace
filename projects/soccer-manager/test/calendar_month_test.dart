// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/day_events.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/state/game_state.dart';

import 'support/app_fonts.dart';
import 'support/shell_harness.dart';

/// カレンダーの月の表: 試合の日に相手の短い名前と H/A、終わった試合は結果。
void main() {
  setUpAll(loadAppFonts);

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('相手の短い名前は愛称(最後の語)。FC などの印だけなら前の語', () {
    expect(MatchFacts.shortName('ロンドン キャノニアーズ'), 'キャノニアーズ');
    expect(MatchFacts.shortName('Manchester Skies'), 'Skies');
    expect(MatchFacts.shortName('蒼海FC'), '蒼海FC');
    expect(MatchFacts.shortName('Seiran FC'), 'Seiran');
    expect(MatchFacts.shortName('  北風  '), '北風');
  });

  for (final en in [false, true]) {
    testWidgets('月の表: 次の試合のマスに相手名と H/A、終わった試合に結果 (${en ? 'en' : 'ja'})',
        (tester) async {
      final game = await pumpShell(tester, en: en, arrange: (gs) async {
        // 第1節に結果を入れ、マスに出るかを見る(表示だけの確かめ)。
        final u = gs.save!.userTeamId;
        final f = gs.save!.league.fixtures
            .firstWhere((f) => f.homeTeamId == u || f.awayTeamId == u);
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: f.homeTeamId == u ? 2 : 1,
          awayGoals: f.homeTeamId == u ? 1 : 2,
          events: const [],
        );
      });
      shellNavOf(tester).go(TodoPlaces.calendar);
      await settleShell(tester);

      // 次の試合(開幕前なので、第1節の次のリーグ戦か、カップ戦)。
      final ahead = game.calendarEventsBetween(
          game.today, game.today.add(const Duration(days: 120)));
      final next =
          ahead.firstWhere((e) => e.kind.isMatch && e.match?.played != true);
      // その月まで送る。
      for (var i = 0;
          i < 12 &&
              find
                  .byKey(ValueKey('cal-opp-${key(next.date)}'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.tap(find.byTooltip(en ? 'Next month' : '次の月'));
        await settleShell(tester);
      }
      final opp = find.byKey(ValueKey('cal-opp-${key(next.date)}'));
      expect(opp, findsOneWidget);
      expect(tester.widget<Text>(opp).data, next.match!.opponentShort);
      final side = find.descendant(
          of: find.byKey(ValueKey('cal-side-${key(next.date)}')),
          matching: find.byType(Text));
      expect(tester.widget<Text>(side).data,
          next.match!.home == null ? 'N' : (next.match!.home! ? 'H' : 'A'));
      // マスの字ははみ出さない(切れても「…」で収まる)。
      final para = tester.renderObject<RenderParagraph>(
          find.descendant(of: opp, matching: find.byType(RichText)));
      expect(
          para.size.width,
          lessThanOrEqualTo(tester
              .getSize(find.byKey(ValueKey('cal-day-${key(next.date)}')))
              .width));
      expect(tester.takeException(), isNull);

      // 終わった試合: 第1節の日のマスに「勝 2-1」/「W 2-1」。
      final first = game
          .calendarEventsBetween(game.today.subtract(const Duration(days: 60)),
              game.today.add(const Duration(days: 200)))
          .firstWhere((e) => e.match?.played == true);
      final played = first.date;
      expect(first.match!.goalsFor, 2);
      expect(first.match!.goalsAgainst, 1);
      expect(first.match!.opponent, isNotEmpty);
      // その月へ(前後どちらにもありうるので、今日へ戻してから送る)。
      await tester.tap(find.widgetWithText(TextButton, en ? 'Today' : '今日へ'));
      await settleShell(tester);
      for (var i = 0;
          i < 12 &&
              find
                  .byKey(ValueKey('cal-note-${key(played)}'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.tap(find.byTooltip(en ? 'Next month' : '次の月'));
        await settleShell(tester);
      }
      final note = find.byKey(ValueKey('cal-note-${key(played)}'));
      expect(tester.widget<Text>(note).data, en ? 'W 2-1' : '勝 2-1');
      // マスを押すと、その日の予定に相手と結果が出る。
      await tester.tap(find.byKey(ValueKey('cal-day-${key(played)}')));
      await settleShell(tester);
      expect(find.textContaining(first.match!.opponent), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('カップ戦の日の一覧から、カップ戦の画面へ移れる(重ねない)', (tester) async {
    final game = await pumpShell(tester);
    // 開幕前から、国内カップの最初の試合が予定に入っている。
    final cup = _firstCup(game)!;
    final nav = shellNavOf(tester);
    nav.go(TodoPlaces.calendar);
    await settleShell(tester);
    for (var i = 0;
        i < 12 &&
            find.byKey(ValueKey('cal-day-${key(cup.date)}')).evaluate().isEmpty;
        i++) {
      await tester.tap(find.byTooltip('次の月'));
      await settleShell(tester);
    }
    await tester.tap(find.byKey(ValueKey('cal-day-${key(cup.date)}')));
    await settleShell(tester);
    final link = find.byKey(ValueKey('calendar-to-cups-${key(cup.date)}'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settleShell(tester);
    expect(nav.menu, TodoMenu.league);
    expect(nav.tabOf(TodoMenu.league), TodoPlaces.leagueCups.tab);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}

DayEvent? _firstCup(GameState game) {
  final ev = game.calendarEventsBetween(
      game.today, game.today.add(const Duration(days: 300)));
  for (final e in ev) {
    if (e.kind == DayEventKind.cupMatch) return e;
  }
  return null;
}
