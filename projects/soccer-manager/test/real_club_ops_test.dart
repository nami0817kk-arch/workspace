import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/club_calendar_engine.dart';
import 'package:soccer_manager/logic/contract_board_engine.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 現実のクラブ運営に寄せた2つの画面の中身: 年間予定と、登録・契約。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('クラブの年間予定', () {
    test('開幕前から終了時まで、節の順に並ぶ', () {
      final events = ClubCalendarEngine.build(totalMatchdays: 38);
      for (var i = 1; i < events.length; i++) {
        expect(events[i].matchday, greaterThanOrEqualTo(events[i - 1].matchday));
      }
      expect(events.first.matchday, 0);
      expect(events.last.matchday, 39);
    });

    test('事件の節は6・18・30節で、ゲームの規則と同じ式', () {
      final events = ClubCalendarEngine.build(totalMatchdays: 38);
      final incidentDays = events
          .where((e) => e.kind == ClubEventKind.incident)
          .map((e) => e.matchday)
          .toList();
      expect(incidentDays, [6, 18, 30]);
      for (final md in List.generate(38, (i) => i + 1)) {
        expect(ClubCalendarEngine.isIncidentMatchday(md),
            GameStateFinance.isOwnerEventMatchday(md));
      }
    });

    test('冬の移籍期間は、ゲームの移籍ウィンドウと同じ節から始まる', () {
      final events = ClubCalendarEngine.build(totalMatchdays: 38);
      final winter = events.firstWhere((e) =>
          e.kind == ClubEventKind.window && e.matchday > 0);
      expect(winter.matchday, 19);
    });

    test('決算・総会・契約満了が、終了時にまとまる', () {
      final events = ClubCalendarEngine.build(totalMatchdays: 20);
      expect(events.where((e) => e.matchday == 21).length, 3);
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
