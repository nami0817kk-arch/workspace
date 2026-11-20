import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/squad_registration_engine.dart';
import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/logic/transfer_window.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'support/legacy_market.dart';

/// 移籍の窓を日付で開け閉めする決まりの検査。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame({LeagueTheme theme = LeagueTheme.england}) async {
    final game = GameState();
    await game.startNewGame('窓FC', theme: theme);
    game.save!.budget = 99999999;
    game.save!.wageBudget = 999999; // 年俸の枠で止めない
    return game;
  }

  /// [day]より前に行われる節を、結果だけ入れて消化済みにする。
  void playFixturesBefore(GameState game, DateTime day) {
    final league = game.save!.league;
    while (game.nextMatchDate != null && game.nextMatchDate!.isBefore(day)) {
      final md = league.nextUnplayedFixture!.matchday;
      for (final f in league.fixturesForMatchday(md)) {
        f.result ??= MatchResult(
          matchday: md,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: const [],
        );
      }
    }
  }

  Future<void> playOne(GameState game) async {
    await game.playNextMatchday();
    if (game.isHalfTime) await game.playSecondHalf();
  }

  group('国ごとの開閉日', () {
    // (国, 夏の開く日, 冬の開く日, 冬の締切)。夏の締切はどの国も9月1日。
    final table = <LeagueTheme, (DateTime, DateTime, DateTime)>{
      LeagueTheme.england:
          (DateTime(2027, 6, 14), DateTime(2027, 1, 1), DateTime(2027, 2, 2)),
      LeagueTheme.spain:
          (DateTime(2027, 7, 1), DateTime(2027, 1, 2), DateTime(2027, 2, 3)),
      LeagueTheme.germany:
          (DateTime(2027, 7, 1), DateTime(2027, 1, 1), DateTime(2027, 2, 2)),
      LeagueTheme.italy:
          (DateTime(2027, 7, 1), DateTime(2027, 1, 2), DateTime(2027, 2, 3)),
      LeagueTheme.france:
          (DateTime(2027, 6, 16), DateTime(2027, 1, 1), DateTime(2027, 2, 3)),
    };
    DateTime prev(DateTime d) => DateTime(d.year, d.month, d.day - 1);
    DateTime next(DateTime d) => DateTime(d.year, d.month, d.day + 1);

    for (final e in table.entries) {
      test('${e.key.name}: 開く日・締切日の前後', () {
        final (summer, winterOpen, winterClose) = e.value;
        bool open(DateTime d) => TransferWindowCalendar.isOpen(d, e.key);
        expect(open(prev(summer)), isFalse);
        expect(open(summer), isTrue);
        expect(open(DateTime(2027, 9, 1)), isTrue, reason: '締切日は開いている');
        expect(open(DateTime(2027, 9, 2)), isFalse);
        expect(open(prev(winterOpen)), isFalse);
        expect(open(winterOpen), isTrue);
        expect(open(winterClose), isTrue);
        expect(open(next(winterClose)), isFalse);
        // シーズン中の秋と、リーグ戦を終えた5月末は閉じている。
        expect(open(DateTime(2026, 10, 15)), isFalse);
        expect(open(DateTime(2027, 5, 30)), isFalse);
        // 新しいシーズンは7月1日から始まる。その日はどの国も開いている。
        expect(open(DateTime(2027, 7, 1)), isTrue);
      });
    }
  });

  group('締切の残り日数と表示', () {
    test('7月1日から9月1日の締切まで62日。締切日は0日で札が付く', () async {
      final game = await newGame();
      expect(game.today, DateTime(2026, 7, 1));
      expect(game.isTransferWindowOpen, isTrue);
      expect(game.transferWindowDaysLeft, 62);
      expect(game.transferWindowStatusLabel, contains('締切まで残り62日'));
      expect(game.isTransferDeadlineDay, isFalse);

      game.save!.today = DateTime(2026, 9, 1);
      expect(game.transferWindowDaysLeft, 0);
      expect(game.isTransferDeadlineDay, isTrue);
      expect(game.transferWindowStatusLabel, contains('今日が締切'));
    });

    test('次の試合の前に閉まる節は締切日として扱う', () async {
      final game = await newGame();
      final deadline = DateTime(2026, 9, 1);
      // 締切より前で最後の試合の日に今日を置く。
      final dates = game.seasonCalendar.matchdayDates;
      final lastBefore = dates.lastWhere((d) => !d.isAfter(deadline));
      final firstAfter = dates.firstWhere((d) => d.isAfter(deadline));
      if (lastBefore == deadline) return; // 締切日ちょうどに試合がある暦
      game.save!.today = lastBefore;
      expect(firstAfter.isAfter(deadline), isTrue);
      expect(game.isTransferDeadlineDay, isTrue);
      expect(game.transferWindowStatusLabel, contains('次の試合の前に閉まります'));
    });

    test('閉じているときは次の窓が開く日を出す', () async {
      final game = await newGame();
      game.save!.today = DateTime(2026, 10, 15);
      expect(game.isTransferWindowOpen, isFalse);
      expect(game.transferWindowDaysLeft, isNull);
      expect(game.transferWindowStatusLabel, contains('次の窓は1月1日から'));

      game.save!.today = DateTime(2027, 5, 30);
      expect(game.transferWindowStatusLabel, contains('次の窓は6月14日から'));
    });

    test('オフに日付が進んでも窓は開く(リーグ戦の後→新しいシーズンの7月1日)',
        () async {
      final game = await newGame();
      final dates = game.seasonCalendar.matchdayDates;
      // 最終節の日は閉じている。新しいシーズンの始まりの日は開いている。
      expect(TransferWindowCalendar.isOpen(dates.last, LeagueTheme.england),
          isFalse);
      // 1シーズンのあいだに、試合の日として窓の中に入る日が夏・冬の両方にある。
      final summer = dates.where((d) => d.month == 8 || (d.month == 9 && d.day == 1));
      final winter = dates.where(
          (d) => TransferWindowCalendar.openOn(d, LeagueTheme.england)?.kind ==
              TransferWindowKind.winter);
      expect(summer, isNotEmpty);
      expect(winter, isNotEmpty, reason: '冬の窓が一度も開かない暦になっている');
      for (final theme in LeagueTheme.values) {
        final g = await newGame(theme: theme);
        final w = g.seasonCalendar.matchdayDates.where((d) =>
            TransferWindowCalendar.openOn(d, theme)?.kind ==
            TransferWindowKind.winter);
        expect(w, isNotEmpty, reason: '${theme.name} の冬の窓に試合の日が無い');
      }
    });
  });

  group('窓の外', () {
    test('移籍金のかかる獲得・売却はできないが、自由契約の選手は取れる', () async {
      final game = await newGame();
      game.save!.today = DateTime(2026, 10, 15);
      final target = legacyMarket(game).firstWhere((p) => p.age >= 18);
      expect(await game.buyPlayer(target.id), isFalse);
      expect(await game.signLoanPlayer(target.id), isFalse);

      final fa = game.freeAgents.first;
      fa.age = 20; // 登録の枠に当たらない年齢
      expect(await game.signFreeAgent(fa.id), isTrue);
      expect(game.userTeam.players.any((p) => p.id == fa.id), isTrue);
    });

    test('他のクラブ同士の移籍も窓の外では起きない', () async {
      final game = await newGame();
      final day = DateTime(2026, 10, 1);
      playFixturesBefore(game, day);
      game.save!.today = day;
      for (var i = 0; i < 4; i++) {
        await playOne(game);
        expect(game.isTransferWindowOpen, isFalse);
        expect(game.lastAiTransferNews, isNull);
      }
    });
  });

  group('GK の緊急獲得', () {
    test('登録中のGKが全員出られないときだけ、窓の外でもGKを1人ローンで取れる', () async {
      final game = await newGame();
      game.save!.today = DateTime(2026, 10, 15);
      final market = legacyMarket(game);
      final gk = market.firstWhere((p) => p.age >= 18);
      gk.position = Position.gk;
      final gk2 = market.firstWhere((p) => p.age >= 18 && p.id != gk.id);
      gk2.position = Position.gk;
      final outfield = market
          .firstWhere((p) => p.age >= 18 && p.id != gk.id && p.id != gk2.id);
      outfield.position = Position.st;
      // 21歳以下にして登録の枠で止まらないようにする。
      for (final p in [gk, gk2, outfield]) {
        p.age = 21;
      }

      expect(game.isGoalkeeperEmergency, isFalse);
      expect(await game.signLoanPlayer(gk.id), isFalse,
          reason: 'GKが出られるうちは特例にならない');

      for (final p in game.userTeam.players) {
        if (p.position == Position.gk) p.injuryWeeks = 6;
      }
      expect(game.isGoalkeeperEmergency, isTrue);
      expect(await game.signLoanPlayer(outfield.id), isFalse,
          reason: '特例で取れるのはGKだけ');
      expect(await game.buyPlayer(gk.id), isFalse,
          reason: '特例は期限付きだけ。完全移籍は次の窓まで待つ');
      expect(await game.signLoanPlayer(gk.id), isTrue);
      expect(game.isGoalkeeperEmergency, isFalse);
      expect(await game.signLoanPlayer(gk2.id), isFalse, reason: '取れるのは1人だけ');
    });
  });

  group('締切の登録名簿', () {
    Future<GameState> overLimitGame() async {
      final game = await newGame();
      final team = game.userTeam;
      for (final p in team.players) {
        p.age = 25;
        p.homegrown = true;
        p.injuryWeeks = 0;
      }
      while (team.players.length < 27) {
        final extra = PlayerGenerator.generate(
            position: Position.mc, strengthTier: 30)
          ..age = 25
          ..homegrown = true;
        team.players.add(extra);
      }
      while (team.players.length > 27) {
        team.players.removeLast();
      }
      LineupUtils.autoFill(team);
      return game;
    }

    test('枠を超えていなければ誰も外さない', () async {
      final game = await newGame();
      final team = game.userTeam;
      for (final p in team.players) {
        p.age = 25;
        p.homegrown = true;
      }
      while (team.players.length > 25) {
        team.players.removeLast();
      }
      expect(SquadRegistration.plannedExclusions(team), isEmpty);
      playFixturesBefore(game, DateTime(2026, 9, 2));
      game.save!.today = DateTime(2026, 8, 31);
      await playOne(game);
      expect(team.players.where((p) => p.notRegistered), isEmpty);
    });

    test('締切で25人を超える分が外れ、次の窓まで出られない', () async {
      final game = await overLimitGame();
      final team = game.userTeam;
      final chosen = team.players
          .where((p) => p.position != Position.gk)
          .reduce((a, b) => a.overall >= b.overall ? a : b);
      await game.setLeaveOffRegistration(chosen.id, true);

      final planned = game.plannedRegistrationExclusions;
      expect(planned.length, 2);
      expect(planned, contains(chosen), reason: 'オーナーが外すと決めた選手が先');

      playFixturesBefore(game, DateTime(2026, 9, 2));
      game.save!.today = DateTime(2026, 8, 31);
      await playOne(game);

      expect(game.isTransferWindowOpen, isFalse);
      final out = team.players.where((p) => p.notRegistered).toList();
      expect(out.map((p) => p.id).toSet(), planned.map((p) => p.id).toSet());
      expect(team.players.where(SquadRegistration.isSenior)
              .where((p) => !p.notRegistered)
              .length,
          SquadRegistration.seniorLimit);
      // 自動編成からも、試合のスタメンからも外れる。
      LineupUtils.autoFill(team);
      for (final p in out) {
        expect(team.startingXI, isNot(contains(p.id)));
      }

      // 冬の窓が開けば、また出られる。
      playFixturesBefore(game, DateTime(2027, 1, 1));
      await playOne(game);
      expect(game.isTransferWindowOpen, isTrue);
      expect(team.players.where((p) => p.notRegistered), isEmpty);
    });

    test('国外で育った選手は17人まで。超えた分は国外の選手から外す', () {
      final team = PlayerGenerator.generateSquad(
          id: 't', name: 'T', strengthTier: 60);
      for (final p in team.players) {
        p.age = 25;
        p.homegrown = false;
        p.academyGraduate = false;
      }
      while (team.players.length > 20) {
        team.players.removeLast();
      }
      final excluded = SquadRegistration.plannedExclusions(team);
      expect(excluded.length, team.players.length - 17);
      expect(excluded.where((p) => p.position == Position.gk).length,
          lessThanOrEqualTo(
              team.players.where((p) => p.position == Position.gk).length - 2),
          reason: 'GKは登録に2人残す');
    });
  });

  group('ローンの期間', () {
    test('半年は冬の窓が開く日まで、1年はシーズン末まで', () {
      const theme = LeagueTheme.england;
      final summer = DateTime(2026, 7, 20);
      expect(TransferWindowCalendar.loanEndDate(summer, theme, LoanLength.half),
          DateTime(2027, 1, 1));
      expect(TransferWindowCalendar.loanEndDate(summer, theme, LoanLength.full),
          DateTime(2027, 6, 30));
      // 冬の窓の最中に組む半年は、シーズン末まで。
      final winter = DateTime(2027, 1, 20);
      expect(TransferWindowCalendar.halfLoanAvailable(winter, theme), isFalse);
      expect(TransferWindowCalendar.loanEndDate(winter, theme, LoanLength.half),
          DateTime(2027, 6, 30));
      // スペインの冬の窓は1月2日に開く。
      expect(
          TransferWindowCalendar.loanEndDate(
              summer, LeagueTheme.spain, LoanLength.half),
          DateTime(2027, 1, 2));
    });

    test('借りた選手は終わりの日に戻る(半年)', () async {
      final game = await newGame();
      final target = legacyMarket(game).firstWhere((p) => p.age >= 18)
        ..age = 21;
      expect(await game.signLoanPlayer(target.id, length: LoanLength.half),
          isTrue);
      final p = game.userTeam.players.firstWhere((p) => p.id == target.id);
      expect(p.loanEndDate, DateTime(2027, 1, 1));

      expect(ContractEngine.advanceLoanWeek(game.userTeam,
              today: DateTime(2026, 12, 31)),
          isEmpty);
      final ended = ContractEngine.advanceLoanWeek(game.userTeam,
          today: DateTime(2027, 1, 1));
      expect(ended.map((e) => e.id), contains(target.id));
    });

    test('1年のローンはシーズンの切り替わり(7月1日)で終わる', () async {
      final game = await newGame();
      final target = legacyMarket(game).firstWhere((p) => p.age >= 18)
        ..age = 21;
      expect(await game.signLoanPlayer(target.id, length: LoanLength.full),
          isTrue);
      final league = game.save!.league;
      for (final f in league.fixtures) {
        f.result ??= MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: const [],
        );
      }
      await game.startNextSeason();
      expect(game.today, DateTime(2027, 7, 1));
      expect(game.userTeam.players.any((p) => p.id == target.id), isFalse);
    });

    test('貸した選手は、呼び戻しの条項があれば冬の窓で戻せる', () async {
      final game = await newGame();
      final team = game.userTeam;
      final a = team.players[team.players.length - 1];
      final b = team.players[team.players.length - 2];
      expect(await game.loanOutPlayer(a.id, length: LoanLength.full,
              recallClause: true),
          isTrue);
      expect(await game.loanOutPlayer(b.id, length: LoanLength.full), isTrue);
      expect(a.loanedOutUntil, DateTime(2027, 6, 30));

      // 窓の外・夏の窓では呼び戻せない。
      expect(game.canRecallLoanedOutPlayer(a), isFalse);
      game.save!.today = DateTime(2026, 11, 1);
      expect(await game.recallLoanedOutPlayer(a.id), isFalse);

      game.save!.today = DateTime(2027, 1, 10);
      expect(game.canRecallLoanedOutPlayer(b), isFalse, reason: '条項が無い');
      expect(await game.recallLoanedOutPlayer(a.id), isTrue);
      expect(a.isLoanedOut, isFalse);
      expect(b.isLoanedOut, isTrue);
    });

    test('旧セーブの週数は今日からの日付に直す', () async {
      final game = await newGame();
      final p = game.userTeam.players.first
        ..isLoan = true
        ..loanWeeksRemaining = 10
        ..loanEndDate = null;
      final q = game.userTeam.players[1]
        ..loanedOutWeeksRemaining = 4
        ..loanedOutToClubName = 'どこか'
        ..loanedOutUntil = null;
      final json = game.exportSaveJson()!;
      final loaded = GameState();
      expect(await loaded.importSaveJson(json), isTrue);
      final lp = loaded.userTeam.players.firstWhere((x) => x.id == p.id);
      final lq = loaded.userTeam.players.firstWhere((x) => x.id == q.id);
      expect(lp.loanEndDate, DateTime(2026, 7, 1 + 70));
      expect(lq.loanedOutUntil, DateTime(2026, 7, 1 + 28));
    });
  });

  group('18歳未満の国際移籍', () {
    test('市場の18歳未満は自国のクラブの選手だけ', () {
      final market =
          TransferMarket.generate(count: 300, home: LeagueTheme.italy);
      final minors = market.where((p) => p.age < 18).toList();
      expect(minors, isNotEmpty, reason: '検査の前提(17歳の候補が出る)');
      for (final p in minors) {
        expect(p.originLeague, LeagueTheme.italy.name);
      }
    });

    test('他の国の18歳未満は獲れない。自国の18歳未満は獲れる', () async {
      final game = await newGame();
      final foreign = legacyMarket(game)[0]
        ..age = 17
        ..originLeague = LeagueTheme.spain.name;
      final domestic = legacyMarket(game)[1]
        ..age = 17
        ..originLeague = LeagueTheme.england.name;
      expect(await game.buyPlayer(foreign.id), isFalse);
      expect(game.lastSigningBlockReason, contains('18歳未満'));
      expect(await game.signLoanPlayer(foreign.id), isFalse);
      expect(await game.buyPlayer(domestic.id), isTrue);
    });

    test('スカウトの候補は国内の子だけ', () async {
      final game = await newGame();
      for (final p in game.scoutCandidates) {
        expect(p.originLeague, LeagueTheme.england.name);
      }
    });

    test('自クラブの18歳未満を他の国のクラブへは売れない', () async {
      final game = await newGame();
      final team = game.userTeam;
      final young = team.players.last..age = 17;
      final foreignClub =
          game.save!.foreignLeagues.values.first.teams.first.name;
      game.save!.incomingOffers.add(IncomingOffer(
        id: 'f1',
        playerId: young.id,
        playerName: young.name,
        buyerClubName: foreignClub,
        amount: 1000,
      ));
      expect(await game.acceptIncomingOffer('f1'), isFalse);
      expect(team.players.any((p) => p.id == young.id), isTrue);

      young.age = 18;
      expect(await game.acceptIncomingOffer('f1'), isTrue);
    });
  });
}
