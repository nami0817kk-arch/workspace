// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/day_events.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/state/game_state.dart';

import 'support/app_fonts.dart';
import 'support/shell_harness.dart';

/// 試合の始め方と見せ方を、全大会で揃えた(2026-11-24)。
/// - どの大会の試合も、進むボタンがその日に止まって行う
/// - 試合のあとは、どの大会も同じダイジェスト(大会名の見出し・期待の動き・
///   賞金。試合経過の画面は 2026-11-25 に外した)
/// - 状況の札・カップ戦の画面から試合をするボタンは無い
void main() {
  setUpAll(loadAppFonts);

  /// 進むボタンと同じ順に、[want] の日が次の止まる日になるまで進める
  /// (途中の試合はゲームの口から行う)。
  Future<DayEvent?> advanceUntil(
      GameState gs, bool Function(DayEvent stop) want) async {
    for (var guard = 0; guard < 400; guard++) {
      final first = gs.nextStop;
      if (first == null) return null;
      await gs.playBackgroundCupMatchesBefore(first);
      final stop = gs.nextStop!;
      if (want(stop)) return stop;
      switch (stop.kind) {
        case DayEventKind.leagueMatch:
          await gs.playNextMatchdayQuickSim();
        case DayEventKind.cupMatch:
          final dom = gs.domesticCup?.nextUnplayedMatch;
          final uid = gs.userTeam.id;
          if (dom != null &&
              gs.canPlayNextDomesticCupMatch &&
              (dom.homeTeamId == uid || dom.awayTeamId == uid)) {
            await gs.playNextCupMatch();
          } else if (gs.canPlayNextFourClubSuperCupMatch) {
            await gs.playNextFourClubSuperCupMatch();
          } else if (gs.continentalCup!.isGroupStageComplete) {
            await gs.playNextContinentalKnockoutLeg();
          } else {
            await gs.playNextContinentalGroupMatch();
          }
        case DayEventKind.superCup:
          await gs.playSuperCup();
        case DayEventKind.friendly:
          await gs.playFriendly(gs.friendlyIndexFor(stop)!);
        default:
          await gs.advanceToDateStop(stop);
      }
    }
    return null;
  }

  /// 上の帯の進むボタンを押し、出たダイアログの見出し(大会名)を返す。
  Future<String> pressAdvance(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('advance-button')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('match-digest')), findsOneWidget,
        reason: '試合のあとに結果のダイジェストが出ていない');
    // 期待の動き(どの大会も同じ部品)。試合経過の画面への入口は無い。
    expect(find.text('サポーター '), findsOneWidget);
    expect(find.byKey(const ValueKey('match-digest-watch')), findsNothing);
    expect(find.text('試合経過を見る'), findsNothing);
    final title = tester
        .widget<Text>(find.byKey(const ValueKey('match-digest-competition')))
        .data!;
    await tester.tap(find.byKey(const ValueKey('match-digest-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('match-digest')), findsNothing);
    // 画面は重ねていない(以前のカップ戦は試合経過の画面を開いていた)。
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    return title;
  }

  testWidgets('親善試合: 進むボタンが止まり、同じダイアログで結果を出す', (tester) async {
    late DayEvent stop;
    final gs = await pumpShell(tester, arrange: (gs) async {
      stop = (await advanceUntil(gs, (s) => s.kind == DayEventKind.friendly))!;
    });
    await tester.pump();
    final label = tester
        .widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('advance-button')),
            matching: find.byType(Text)))
        .data!;
    expect(label, startsWith('親善試合へ'));
    final i = gs.friendlyIndexFor(stop)!;
    final title = await pressAdvance(tester);
    expect(title, '親善試合');
    expect(gs.save!.friendlies[i].result, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('リーグ戦: 見出しは「リーグ戦 第N節」', (tester) async {
    late DayEvent stop;
    await pumpShell(tester, arrange: (gs) async {
      stop =
          (await advanceUntil(gs, (s) => s.kind == DayEventKind.leagueMatch))!;
    });
    await tester.pump();
    final title = await pressAdvance(tester);
    expect(title, 'リーグ戦 第${stop.matchday}節');
    expect(tester.takeException(), isNull);
  });

  testWidgets('国内カップ: 自クラブの出ない試合を先に済ませ、同じダイアログに大会名と回戦', (tester) async {
    final gs = await pumpShell(tester, arrange: (gs) async {
      await advanceUntil(gs, (s) => s.kind == DayEventKind.cupMatch);
    });
    await tester.pump();
    final cup = gs.domesticCup!;
    final mine = cup.nextUnplayedMatch!;
    final title = await pressAdvance(tester);
    expect(title, startsWith(cup.name));
    expect(mine.result ?? mine.firstLeg, isNotNull, reason: '自クラブの試合をした');
    // 同じ回戦の、自クラブの出ない試合は済んでいる(先に済ませる処理)。
    final round = cup.rounds.firstWhere((r) => r.contains(mine));
    for (final m in round) {
      if (identical(m, mine) || m.isBye || m.twoLegged) continue;
      expect(m.result, isNotNull, reason: '同じ回戦の他の試合が残っている');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('スーパーカップ: 開幕前の日に進むボタンが止まり、同じダイアログ', (tester) async {
    final gs = await pumpShell(tester, arrange: (gs) async {
      final u = gs.userTeam.id;
      final other = gs.save!.league.teams.firstWhere((t) => t.id != u).id;
      gs.save!.pendingSuperCup =
          CupMatch(round: 1, homeTeamId: u, awayTeamId: other);
      await advanceUntil(gs, (s) => s.kind == DayEventKind.superCup);
    });
    await tester.pump();
    expect(gs.nextStop!.kind, DayEventKind.superCup);
    // 状況の札は日付の案内だけ(「クイック消化」は無い)。
    shellNavOf(tester).go(TodoPlaces.status);
    await settleShell(tester);
    final card =
        find.byKey(const ValueKey('super-cup-card'), skipOffstage: false);
    // 状況のページは一覧が長いので、札が作られるところまで送る。
    final lists = find.descendant(
        of: find.byType(HomeScreen), matching: find.byType(Scrollable));
    for (final l in lists.evaluate().toList()) {
      if (card.evaluate().isNotEmpty) break;
      for (var i = 0; i < 12 && card.evaluate().isEmpty; i++) {
        await tester.drag(find.byWidget(l.widget), const Offset(0, -250),
            warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
        findsNothing);
    final title = await pressAdvance(tester);
    expect(title, 'スーパーカップ');
    expect(gs.pendingSuperCup, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('カップ戦の画面に、試合をするボタンは無い', (tester) async {
    await pumpShell(tester);
    shellNavOf(tester).go(TodoPlaces.leagueCups);
    await settleShell(tester);
    for (final t in [
      '次の試合をする',
      'グループステージの次の試合をする',
      '決勝トーナメントの次の試合をする',
      'クイック消化',
    ]) {
      expect(find.text(t, skipOffstage: false), findsNothing, reason: t);
    }
    expect(tester.takeException(), isNull);
  });
}
