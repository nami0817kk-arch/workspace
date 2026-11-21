import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/day_events.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 日付で進む(2026-11-22)。進むボタンは次の予定がある日まで進み、
/// 何もない日は飛ばす。カップ戦はその日に、給料・放映権・移籍の窓は
/// その日に処理される。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('試合以外の出来事: 月末の給料日・放映権・窓の締切が日付順に出る', () {
    final ev = DayEvents.calendarEvents(
        DateTime(2026, 8, 10), DateTime(2026, 11, 2), LeagueTheme.england);
    final kinds = [for (final e in ev) (e.date, e.kind)];
    expect(kinds, contains((DateTime(2026, 8, 31), DayEventKind.wages)));
    expect(kinds,
        contains((DateTime(2026, 9, 1), DayEventKind.windowDeadline)));
    expect(kinds, contains((DateTime(2026, 11, 1), DayEventKind.broadcast)));
    // 範囲の外(8/1 の放映権・8/10 以前)は入らない。
    expect(ev.any((e) => e.date.isBefore(DateTime(2026, 8, 11))), isFalse);
    for (var i = 1; i < ev.length; i++) {
      expect(ev[i].date.isBefore(ev[i - 1].date), isFalse);
    }
  });

  test('進むボタンだけで1季を進められ、日付は戻らず、予定の日に止まる', () async {
    final game = GameState();
    await game.startNewGame('暦FC');
    final kinds = <DayEventKind>[];
    var last = game.today;
    var guard = 0;
    while (game.save!.league.nextUnplayedFixture != null && guard++ < 400) {
      final first = game.nextStop;
      expect(first, isNotNull, reason: 'リーグ戦が残っているのに止まる日が無い');
      // 次のリーグ戦の日より後には止まらない。
      expect(first!.date.isAfter(game.nextMatchDate!), isFalse);
      await game.playBackgroundCupMatchesBefore(first);
      final stop = game.nextStop!;
      kinds.add(stop.kind);
      switch (stop.kind) {
        case DayEventKind.leagueMatch:
          expect(await game.playNextMatchdayQuickSim(), isNotNull);
        case DayEventKind.cupMatch:
          final dom = game.domesticCup?.nextUnplayedMatch;
          final uid = game.userTeam.id;
          final domestic = dom != null &&
              game.canPlayNextDomesticCupMatch &&
              (dom.homeTeamId == uid || dom.awayTeamId == uid);
          if (domestic) {
            await game.playNextCupMatch();
          } else if (game.continentalCup!.isGroupStageComplete) {
            await game.playNextContinentalKnockoutLeg();
          } else {
            await game.playNextContinentalGroupMatch();
          }
        default:
          await game.advanceToDateStop(stop);
          expect(game.today, stop.date, reason: '${stop.label} の日に止まっていない');
      }
      expect(game.today.isBefore(last), isFalse, reason: '日付が戻った');
      last = game.today;
    }
    expect(game.save!.league.isSeasonComplete, isTrue);
    expect(kinds.where((k) => k == DayEventKind.leagueMatch).length,
        game.save!.league.fixtures.map((f) => f.matchday).toSet().length);
    expect(kinds, contains(DayEventKind.wages));
    expect(kinds, contains(DayEventKind.windowDeadline));
    expect(kinds, contains(DayEventKind.broadcast));
    // 季の途中の自クラブのカップ戦も、進むボタンが止まって行った。
    final uid = game.userTeam.id;
    final playedUserCup = game.domesticCup!.rounds.expand((r) => r).any((m) =>
        !m.isBye &&
        m.result != null &&
        (m.homeTeamId == uid || m.awayTeamId == uid));
    if (playedUserCup) expect(kinds, contains(DayEventKind.cupMatch));
    // リーグ戦を終えたら、季の終わりの流れに入る(進むボタンは出さない)。
    expect(game.nextStop, isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('カレンダーの1か月に、自クラブのリーグ戦と給料日が載る', () async {
    final game = GameState();
    await game.startNewGame('暦FC');
    final d = game.nextMatchDate!;
    final first = DateTime(d.year, d.month, 1);
    final last = DateTime(d.year, d.month + 1, 0);
    final ev = game.calendarEventsBetween(first, last);
    expect(ev.any((e) => e.kind == DayEventKind.leagueMatch && e.date == d),
        isTrue);
    expect(ev.any((e) => e.kind == DayEventKind.wages && e.date == last),
        isTrue);
  });
}
