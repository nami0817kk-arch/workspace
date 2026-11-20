import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/club_calendar_engine.dart';
import 'package:soccer_manager/logic/contract_board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/money_calendar.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/logic/summer_tournament.dart';
import 'package:soccer_manager/logic/transfer_window.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 現実のクラブ運営に寄せた2つの画面の中身: 年間予定と、登録・契約。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('クラブの年間予定', () {
    List<ClubEvent> build({LeagueTheme theme = LeagueTheme.england}) =>
        ClubCalendarEngine.build(
          season: 1,
          theme: theme,
          calendar: SeasonCalendar.build(
              season: 1, theme: theme, totalMatchdays: 38),
        );

    test('7月1日から6月30日まで、日付の順に並ぶ', () {
      final events = build();
      for (var i = 1; i < events.length; i++) {
        expect(events[i].date.isBefore(events[i - 1].date), isFalse);
      }
      expect(events.first.date, DateTime(2026, 7, 1));
      expect(events.last.date, DateTime(2027, 6, 30));
    });

    test('事件の節は6・18・30節で、ゲームの規則と同じ式', () {
      final incidentDays = build()
          .where((e) => e.kind == ClubEventKind.incident)
          .map((e) => e.matchday)
          .toList();
      expect(incidentDays, [6, 18, 30]);
      for (final md in List.generate(38, (i) => i + 1)) {
        expect(ClubCalendarEngine.isIncidentMatchday(md),
            GameStateFinance.isOwnerEventMatchday(md));
      }
    });

    test('締切と期限は、ゲームの規則と同じ日付', () {
      for (final theme in LeagueTheme.values) {
        final dates = build(theme: theme).map((e) => e.date).toSet();
        expect(dates, contains(TransferWindowCalendar.summerOf(2026, theme).closes));
        expect(dates, contains(TransferWindowCalendar.winterOf(2027, theme).opens));
        expect(dates, contains(TransferWindowCalendar.winterOf(2027, theme).closes));
        expect(dates, contains(ContractEngine.optionDeadline(2027)));
        expect(dates, contains(DateTime(2027, 1, 1)), reason: '仮契約の解禁');
        for (final d in MoneyCalendar.broadcastDates(1)) {
          expect(dates, contains(d));
        }
      }
    });

    test('大会のある夏だけ、合流の日が載る', () {
      final withCup = build();
      expect(
          withCup.where((e) => e.kind == ClubEventKind.tournament).single.date,
          SummerTournament.of(2026)!.returnDate);
      final noCup = ClubCalendarEngine.build(
        season: 2,
        theme: LeagueTheme.england,
        calendar: SeasonCalendar.build(
            season: 2, theme: LeagueTheme.england, totalMatchdays: 38),
      );
      expect(noCup.where((e) => e.kind == ClubEventKind.tournament), isEmpty);
    });

    test('決算・総会・契約満了が、年度末(6月30日)にまとまる', () {
      expect(build().where((e) => e.date == DateTime(2027, 6, 30)).length, 3);
    });
  });

  group('登録と契約', () {
    test('更新の時期の選手は、残りが短い順で、ローン中は含まない', () async {
      final game = GameState();
      await game.startNewGame('契約FC');
      final team = game.userTeam;
      team.players[0].contractYearsRemaining = 0;
      team.players[1].contractYearsRemaining = 1;
      team.players[2].contractYearsRemaining = 3;
      final list = ContractBoardEngine.expiring(team);
      expect(list.every((p) => p.contractYearsRemaining <= 1), isTrue);
      expect(list.contains(team.players[2]), isFalse);
      for (var i = 1; i < list.length; i++) {
        expect(list[i].contractYearsRemaining,
            greaterThanOrEqualTo(list[i - 1].contractYearsRemaining));
      }
    });

    test('契約年数別の人数の合計は、登録人数と一致する', () async {
      final game = GameState();
      await game.startNewGame('契約FC');
      final team = game.userTeam;
      final by = ContractBoardEngine.byYearsRemaining(team);
      expect(by.values.fold<int>(0, (s, v) => s + v), team.players.length);
    });

    test('登録の余裕は、上限との差', () async {
      final game = GameState();
      await game.startNewGame('契約FC');
      final team = game.userTeam;
      expect(ContractBoardEngine.registrationRoom(team, team.players.length + 3), 3);
      expect(ContractBoardEngine.registrationRoom(team, team.players.length - 2), -2);
    });

    test('週給の合計は、全選手の週給の和', () async {
      final game = GameState();
      await game.startNewGame('契約FC');
      final team = game.userTeam;
      expect(ContractBoardEngine.weeklyWages(team),
          team.players.fold<int>(0, (s, p) => s + p.wage));
    });
  });
}
