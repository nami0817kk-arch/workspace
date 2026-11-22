import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 6月の代表ウィークと、アフリカネイションズカップ(2026-11-22)。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('暦', () {
    test('6月の代表ウィークは翌年6月上旬の9日間で、リーグ戦とぶつからない', () {
      for (var season = 1; season <= 8; season++) {
        final y = SeasonCalendar.startYear(season);
        final june = SeasonCalendar.juneWindowDays(season);
        expect(june.length, 9);
        final first = june.reduce((a, b) => a.isBefore(b) ? a : b);
        expect(first.weekday, DateTime.monday);
        expect(first.year, y + 1);
        expect(first.month, 6);
        expect(first.day, lessThanOrEqualTo(7), reason: '6月上旬に始まる');
        expect(
          SeasonCalendar.internationalWindowDays(season).containsAll(june),
          isTrue,
        );
        for (final theme in LeagueTheme.values) {
          for (final teams in theme.teamsByTier.toSet()) {
            final cal = SeasonCalendar.build(
              season: season,
              theme: theme,
              totalMatchdays: (teams - 1) * 2,
            );
            for (final d in cal.matchdayDates) {
              expect(
                june.contains(d),
                isFalse,
                reason: '${theme.name} $teams 第$season季 $d',
              );
            }
            expect(
              cal.lastMatchDate.isBefore(first),
              isTrue,
              reason: '${theme.name} $teams 第$season季はオフに入る前に終わる',
            );
            expect(cal.isInternationalWindow(first), isTrue);
          }
        }
      }
    });

    test('リーグ戦の後のカップ戦は6月の代表ウィークを避ける', () {
      final june = SeasonCalendar.juneWindowDays(1);
      final first = june.reduce((a, b) => a.isBefore(b) ? a : b);
      for (final continental in [false, true]) {
        final d = SeasonCalendar.nextCupWeekdayAfter(
          first.subtract(const Duration(days: 1)),
          continental: continental,
        );
        expect(june.contains(d), isFalse);
        expect(d.isAfter(first), isTrue);
      }
    });

    test('アフリカネイションズカップは奇数年の1月〜2月上旬の4週間', () {
      for (var season = 1; season <= 8; season++) {
        final year = SeasonCalendar.startYear(season) + 1;
        final r = SeasonCalendar.africaCupOfNations(season);
        if (year.isEven) {
          expect(r, isNull, reason: '$year年は無い');
          continue;
        }
        expect(r, isNotNull, reason: '$year年はある');
        final (start, end) = r!;
        expect(start.year, year);
        expect(start.month, 1);
        expect(end.difference(start).inDays, 27);
        expect(end.month, 2);
        expect(end.day, lessThanOrEqualTo(14), reason: '2月上旬に終わる');
        // リーグ戦は止まらない(期間中にも節がある)。
        final cal = SeasonCalendar.build(
          season: season,
          theme: LeagueTheme.france,
          totalMatchdays: 34,
        );
        expect(cal.matchdayDates.any(cal.isAfricaCupOfNations), isTrue);
      }
    });
  });

  group('代表の召集', () {
    Future<GameState> newGame() async {
      final game = GameState();
      await game.startNewGame('代表FC', theme: LeagueTheme.france);
      return game;
    }

    void makeStar(Player p) {
      p
        ..attributes = {for (final k in AttributeKeys.all) k: 95}
        ..onTournamentLeave = false
        ..injuryWeeks = 0
        ..injuryType = null
        ..internationalDutyWeeksRemaining = 0;
    }

    /// 他のクラブの選手から、アフリカの代表の選手と、そうでない選手を1人ずつ。
    (Player, Player) pickStars(GameState game) {
      final s = game.save!;
      Player? african;
      Player? other;
      for (final t in s.league.teams) {
        if (t.id == s.userTeamId) continue;
        for (final p in t.players) {
          if (p.isLoanedOut) continue;
          if (game.isAfricanInternational(p)) {
            african ??= p;
          } else {
            other ??= p;
          }
        }
      }
      expect(african, isNotNull, reason: 'アフリカの代表の選手がリーグにいない');
      makeStar(african!);
      makeStar(other!);
      return (african, other);
    }

    test('アフリカの代表の選手は国籍と id で決まり、フランス国籍に多い', () {
      var fr = 0, en = 0;
      for (var i = 0; i < 4000; i++) {
        if (GameStateNation.africanTeamFor('p$i', LeagueTheme.france) != null) {
          fr++;
        }
        if (GameStateNation.africanTeamFor('p$i', LeagueTheme.england) !=
            null) {
          en++;
        }
        // 同じ選手は何度聞いても同じ答え。
        expect(
          GameStateNation.africanTeamFor('p$i', LeagueTheme.france),
          GameStateNation.africanTeamFor('p$i', LeagueTheme.france),
        );
      }
      expect(fr / 4000, inInclusiveRange(0.08, 0.16));
      expect(en / 4000, inInclusiveRange(0.02, 0.06));
    });

    test('アフリカネイションズカップの間、アフリカの代表の選手だけが離れ、終われば戻る', () async {
      final game = await newGame();
      final (african, other) = pickStars(game);
      final (start, end) = SeasonCalendar.africaCupOfNations(
        game.save!.league.season,
      )!;
      game.save!.today = start;
      game.debugAdvanceInternationalDuty();
      expect(african.isOnInternationalDuty, isTrue, reason: '呼ばれていない');
      expect(other.isOnInternationalDuty, isFalse, reason: 'アフリカの代表でないのに呼ばれた');
      expect(game.save!.newsLog.first.text, contains('アフリカネイションズカップ'));
      // 大会の途中の週の処理では戻らない(残りの週は大会の終わりまで)。
      for (var d = 7; d < 28; d += 7) {
        game.save!.today = DateTime(start.year, start.month, start.day + d);
        expect(
          game.debugAdvanceInternationalDuty(),
          isEmpty,
          reason: '同じ大会で二度呼んだ',
        );
        game.debugReleaseInternationalDuty();
        expect(
          african.isOnInternationalDuty,
          isTrue,
          reason: '大会の途中で戻った(${game.today})',
        );
      }
      // 期間中もリーグ戦には出られない(出場できる選手から外れる)。
      // 大会が終われば戻る。
      game.save!.today = DateTime(end.year, end.month, end.day + 1);
      game.debugReleaseInternationalDuty();
      expect(african.isOnInternationalDuty, isFalse, reason: '大会の後も戻らない');
    });

    test('アフリカネイションズカップの間でも、アフリカの代表でない選手は戻る', () async {
      final game = await newGame();
      final (_, other) = pickStars(game);
      final (start, _) = SeasonCalendar.africaCupOfNations(
        game.save!.league.season,
      )!;
      game.save!.today = DateTime(start.year, start.month, start.day + 3);
      other.internationalDutyWeeksRemaining = 1;
      game.debugReleaseInternationalDuty();
      expect(other.isOnInternationalDuty, isFalse);
    });

    test('自クラブの選手が呼ばれると、通知とニュースに名前が出る', () async {
      final game = await newGame();
      final s = game.save!;
      // 自クラブにアフリカの代表の選手がいなければ、他のクラブから移す。
      final team = game.userTeam;
      var mine = team.players
          .where((p) => !p.isLoanedOut && game.isAfricanInternational(p))
          .firstOrNull;
      if (mine == null) {
        final (african, _) = pickStars(game);
        final from = s.league.teams.firstWhere(
          (t) => t.players.any((p) => p.id == african.id),
        );
        from.players.remove(african);
        african.nation = LeagueTheme.france.name;
        team.players.add(african);
        mine = african;
        expect(game.isAfricanInternational(mine), isTrue);
      }
      makeStar(mine);
      final (start, _) = SeasonCalendar.africaCupOfNations(s.league.season)!;
      s.today = start;
      final called = game.debugAdvanceInternationalDuty();
      expect(called, contains(mine.name));
      expect(s.newsLog.first.text, contains(mine.name));
      expect(team.startingXI, isNot(contains(mine.id)));
    });

    test('6月の代表ウィーク(オフ)にも呼ばれ、終われば疲れを持って戻る', () async {
      final game = await newGame();
      final s = game.save!;
      // リーグ戦を全部終えた形にする(オフ)。
      for (final f in s.league.fixtures) {
        f.result ??= MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: const [],
        );
      }
      expect(s.league.nextUnplayedFixture, isNull);
      final (_, other) = pickStars(game);
      final star = game.userTeam.players.first;
      makeStar(star);
      star.fatigue = 0;
      final june = SeasonCalendar.juneWindowDays(s.league.season);
      final first = june.reduce((a, b) => a.isBefore(b) ? a : b);
      final before = DateTime(first.year, 5, 31);
      s.today = DateTime(first.year, first.month, first.day + 2);
      game.lastInternationalCallUps = [];
      game.debugCallUpForJuneWindow(before, game.today);
      expect(star.isOnInternationalDuty, isTrue);
      expect(other.isOnInternationalDuty, isTrue);
      expect(game.lastInternationalCallUps, contains(star.name));
      // 代表ウィークの間は戻らない。
      game.debugReleaseInternationalDuty();
      expect(star.isOnInternationalDuty, isTrue);
      // 終わったら戻る(疲れが残る)。
      s.today = DateTime(first.year, 6, 30);
      game.debugReleaseInternationalDuty();
      expect(star.isOnInternationalDuty, isFalse);
      expect(star.fatigue, greaterThan(0));
    });

    test('リーグ戦の残っているうち(オフでない)は、6月の召集を走らせない', () async {
      final game = await newGame();
      final s = game.save!;
      final star = game.userTeam.players.first;
      makeStar(star);
      final june = SeasonCalendar.juneWindowDays(s.league.season);
      final first = june.reduce((a, b) => a.isBefore(b) ? a : b);
      game.debugCallUpForJuneWindow(DateTime(first.year, 5, 31), first);
      expect(star.isOnInternationalDuty, isFalse);
    });
  });
}
