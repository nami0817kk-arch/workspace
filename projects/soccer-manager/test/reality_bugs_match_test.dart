import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/owner_goal.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/models/weather.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 試合・選手まわりの「ゲームの中でつじつまが合わない」不具合(2026-11-22)の
/// 挙動を固定する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Team squad(String id, {int tier = 60}) {
    final t = PlayerGenerator.generateSquad(
      id: id,
      name: id,
      strengthTier: tier,
    );
    LineupUtils.autoFill(t);
    return t;
  }

  bool canPlay(Player p) =>
      !p.isInjured &&
      !p.isSuspended &&
      !p.isOnInternationalDuty &&
      !p.isLoanedOut &&
      !p.notRegistered;

  /// [team]の控えの1人を、[like]と同じポジションの、疲れていない強い選手に
  /// 作り替える(自動の交代で必ず選ばれる控え)。
  Player strongBenchFor(Team team, Player like) {
    final onPitch = MatchEngine.lineupOf(team).map((p) => p.id).toSet();
    final b = team.players
        .firstWhere((p) => !onPitch.contains(p.id) && canPlay(p));
    b.position = like.position;
    b.secondaryPositions = [];
    b.attributes = {for (final k in AttributeKeys.all) k: 99};
    b.potential = 99;
    b.fatigue = 0;
    return b;
  }

  group('1. 2枚目の警告は、前半・後半をまたいでも退場', () {
    test('後半の始まり(46分)では、前半の警告の印を消さない', () {
      final home = squad('h');
      final away = squad('a');
      final p = MatchEngine.lineupOf(home).first;
      p.yellowCardedThisMatch = true;
      MatchEngine.simulateMinutes(
        home: home,
        away: away,
        startMinute: 46,
        endMinute: 90,
      );
      expect(p.yellowCardedThisMatch, isTrue,
          reason: 'ハーフタイムで前半の警告が消えている');
    });

    test('試合の始まり(1分)では、前の試合の印を消す', () {
      final home = squad('h');
      final away = squad('a');
      for (final p in home.players) {
        p.yellowCardedThisMatch = true;
      }
      MatchEngine.simulateMinutes(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 1,
      );
      final carded = {
        for (final p in home.players)
          if (p.yellowCardedThisMatch) p.id,
      };
      // 1分間で警告が出ても1枚まで。前の試合の印は残らない。
      expect(carded.length, lessThanOrEqualTo(1));
    });

    test('前半に警告を受けた選手が後半にもう一度カードを受けたら退場', () {
      final home = squad('h');
      final away = squad('a');
      final booked = {
        for (final p in [
          ...MatchEngine.lineupOf(home),
          ...MatchEngine.lineupOf(away),
        ])
          p.id: p,
      };
      var secondCards = 0;
      for (var i = 0; i < 400 && secondCards < 5; i++) {
        for (final p in booked.values) {
          p.yellowCardedThisMatch = true; // 前半に1枚ずつ受けた
        }
        final half = MatchEngine.simulateMinutes(
          home: home,
          away: away,
          startMinute: 46,
          endMinute: 90,
        );
        for (final e in half.events) {
          if (e.type != MatchEventType.yellowCard &&
              e.type != MatchEventType.redCard) {
            continue;
          }
          if (!booked.containsKey(e.scorerId)) continue;
          secondCards++;
          expect(e.type, MatchEventType.redCard,
              reason: '前半に警告を受けた選手の後半の2枚目が警告のまま');
        }
      }
      expect(secondCards, greaterThan(0), reason: '後半にカードが1枚も出なかった');
    });

    test('再起動で印が消えても、イベントから警告を戻せる', () {
      final home = squad('h');
      final away = squad('a');
      final p = home.players.first;
      final q = away.players.first;
      MatchEngine.markYellowCardsFromEvents(home, away, [
        MatchEvent(
          minute: 30,
          teamId: home.id,
          scorerName: p.name,
          scorerId: p.id,
          type: MatchEventType.yellowCard,
        ),
        MatchEvent(
          minute: 40,
          teamId: away.id,
          scorerName: q.name,
          scorerId: q.id,
        ),
      ]);
      expect(p.yellowCardedThisMatch, isTrue);
      expect(q.yellowCardedThisMatch, isFalse, reason: '得点を警告として数えた');
    });
  });

  group('2. 結果だけ見る試合・CPU 同士の試合にも交代がある', () {
    test('疲れた選手は、ハーフタイムに同じポジションの控えと替わる', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      for (final p in lineup) {
        p.fatigue = 0;
      }
      final tired = lineup.firstWhere((p) => p.position != Position.gk);
      tired.fatigue = 95;
      final bench = strongBenchFor(t, tired);
      final swaps =
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: 0);
      expect(swaps, hasLength(1));
      expect(swaps.single.out.id, tired.id);
      expect(swaps.single.incoming.id, bench.id);
    });

    test('疲れていなくて勝ち・引き分けなら替えない', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      for (final p in lineup) {
        p.fatigue = 0;
      }
      expect(
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: 0),
          isEmpty);
      expect(
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: 2),
          isEmpty);
    });

    test('負けていれば、中盤・前線の1人を同じくらいの控えと替える', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      for (final p in lineup) {
        p.fatigue = 0;
      }
      final attacker = lineup.firstWhere((p) =>
          p.position.group == PositionGroup.mid ||
          p.position.group == PositionGroup.att);
      strongBenchFor(t, attacker);
      final swaps =
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup, goalDiff: -1);
      expect(swaps, hasLength(1));
      expect(
          [PositionGroup.mid, PositionGroup.att]
              .contains(swaps.single.out.position.group),
          isTrue);
    });

    test('交代枠を超えない・GK と退場した選手は替えない', () {
      final t = squad('h');
      final lineup = MatchEngine.lineupOf(t);
      final onPitch = lineup.map((p) => p.id).toSet();
      final bench = t.players.where((p) => !onPitch.contains(p.id)).toList();
      // 全員疲れていて、控えは全員とても強い。
      for (final p in lineup) {
        p.fatigue = 100;
      }
      for (final b in bench) {
        b.attributes = {for (final k in AttributeKeys.all) k: 99};
        b.fatigue = 0;
      }
      final sentOff = lineup.firstWhere((p) => p.position != Position.gk);
      final swaps = MatchEngine.chooseHalfTimeSubstitutions(
        t,
        lineup,
        goalDiff: -3,
        excludedIds: {sentOff.id},
      );
      expect(swaps.length, lessThanOrEqualTo(substitutionsPerMatch));
      expect(swaps.length, greaterThan(0));
      expect(swaps.any((s) => s.out.position == Position.gk), isFalse);
      expect(swaps.any((s) => s.out.id == sentOff.id), isFalse);
      expect(
          MatchEngine.chooseHalfTimeSubstitutions(t, lineup,
              goalDiff: -3, maxSubs: 0),
          isEmpty);
      expect(GameState.maxSubstitutionsPerMatch, substitutionsPerMatch,
          reason: '手動と自動で交代枠の数がずれた');
    });

    test('CPU 同士の試合(simulate)で交代が起き、試合後は先発の指定が元に戻る', () {
      final home = squad('h');
      final away = squad('a');
      final lineup = MatchEngine.lineupOf(home);
      final tired = lineup.firstWhere((p) => p.position != Position.gk);
      tired.fatigue = 95;
      final bench = strongBenchFor(home, tired);
      final xiBefore = List<String>.of(home.startingXI);
      final tiredApps = tired.careerAppearances;
      final benchApps = bench.careerAppearances;

      final result =
          MatchEngine.simulate(home: home, away: away, matchday: 1);

      expect(home.startingXI, xiBefore, reason: '交代が先発の指定に残った');
      expect(bench.careerAppearances, benchApps + 1, reason: '入った控えが出場に数えられていない');
      expect(tired.careerAppearances, tiredApps + 1,
          reason: '下がった選手の前半の出場が数えられていない');
      expect(result.playerRatings.containsKey(tired.id), isTrue);
      expect(result.playerRatings.containsKey(bench.id), isTrue);
    });

    test('自クラブのクイック試合でも、ハーフタイムに自動で交代する', () async {
      final game = GameState();
      await game.startNewGame('交代FC');
      final half = await game.playNextMatchday();
      expect(half, isNotNull);
      expect(game.isHalfTime, isTrue);
      final team = game.userTeam;
      final tired = MatchEngine.lineupOf(team)
          .firstWhere((p) => p.position != Position.gk);
      tired.fatigue = 95;
      final bench = strongBenchFor(team, tired);
      final xiBefore = List<String>.of(team.startingXI);
      final benchApps = bench.careerAppearances;
      final tiredApps = tired.careerAppearances;

      final result = await game.playSecondHalf();

      expect(result, isNotNull);
      expect(bench.careerAppearances, benchApps + 1, reason: '控えが入っていない');
      expect(tired.careerAppearances, tiredApps + 1);
      expect(team.startingXI, xiBefore, reason: '自動の交代が先発の指定に残った');
    });

    test('ライブ観戦の試合では自動で交代しない(利用者が替える)', () async {
      final game = GameState();
      await game.startNewGame('交代FC');
      await game.playNextMatchday(interactive: true);
      while (game.pendingChanceDecision != null) {
        await game.resolveChanceDecision(ChanceDecision.shoot);
      }
      expect(game.isHalfTime, isTrue);
      final team = game.userTeam;
      final tired = MatchEngine.lineupOf(team)
          .firstWhere((p) => p.position != Position.gk);
      tired.fatigue = 95;
      final bench = strongBenchFor(team, tired);
      final benchApps = bench.careerAppearances;

      var result = await game.playSecondHalf(interactive: true);
      while (result == null && game.pendingChanceDecision != null) {
        result =
            (await game.resolveChanceDecision(ChanceDecision.shoot)).merged;
      }
      expect(result, isNotNull);
      expect(bench.careerAppearances, benchApps,
          reason: 'ライブ観戦なのに自動で交代した');
      expect(game.substitutionsUsed, 0);
    });
  });

  group('3. 国内育成の印は国籍を見て付ける', () {
    test('他国籍になる選手には付きにくく、自国籍には付きやすい', () {
      var national = 0, nationalHg = 0, foreign = 0, foreignHg = 0;
      for (var i = 0; i < 3000; i++) {
        final p = PlayerGenerator.generate(
            position: Position.mc, strengthTier: 55);
        if (Player.foreignNationalFromId(p.id)) {
          foreign++;
          if (p.homegrown) foreignHg++;
        } else {
          national++;
          if (p.homegrown) nationalHg++;
        }
      }
      expect(foreign, greaterThan(100));
      expect(foreignHg / foreign, lessThan(0.25));
      expect(nationalHg / national, greaterThan(0.55));
      // 全体の割合は以前(6割)から大きく動かさない。
      final all = (nationalHg + foreignHg) / (national + foreign);
      expect(all, inInclusiveRange(0.5, 0.7));
    });

    test('決まりそのもの: 自国籍は2/3、他国籍は1/10', () {
      final nationalId = List.generate(100, (i) => 'p$i')
          .firstWhere((id) => !Player.foreignNationalFromId(id));
      final foreignId = List.generate(500, (i) => 'p$i')
          .firstWhere(Player.foreignNationalFromId);
      expect(PlayerGenerator.homegrownRoll(nationalId, 0.6), isTrue);
      expect(PlayerGenerator.homegrownRoll(nationalId, 0.7), isFalse);
      expect(PlayerGenerator.homegrownRoll(foreignId, 0.05), isTrue);
      expect(PlayerGenerator.homegrownRoll(foreignId, 0.2), isFalse);
    });

    test('ゲームの中でも、他国籍の選手は国内育成が少ない', () async {
      final game = GameState();
      await game.startNewGame('国籍FC');
      final home = game.currentLeagueTheme;
      final players = game.save!.league.teams
          .where((t) => t.id != game.save!.userTeamId)
          .expand((t) => t.players)
          .where((p) => !p.academyGraduate)
          .toList();
      final foreign =
          players.where((p) => game.nationalityOf(p) != home).toList();
      final national =
          players.where((p) => game.nationalityOf(p) == home).toList();
      expect(foreign, isNotEmpty);
      double rate(List<Player> ps) =>
          ps.where((p) => p.homegrown).length / ps.length;
      expect(rate(foreign), lessThan(rate(national)));
      expect(rate(foreign), lessThan(0.3));
    });

    test('印の無い古いデータの読み込みは今までどおり(id から決まる)', () {
      final p =
          PlayerGenerator.generate(position: Position.st, strengthTier: 50);
      final json = p.toJson()..remove('homegrown');
      expect(Player.fromJson(json).homegrown, Player.homegrownFromId(p.id));
      final saved = p.toJson();
      expect(Player.fromJson(saved).homegrown, p.homegrown);
    });
  });

  group('4. ユースの伸びしろの見立ては、真ん中が答えにならない', () {
    test('幅の真ん中は選手ごとにずれ、本当の値は必ず幅の中', () {
      var offCenter = 0;
      for (var i = 0; i < 60; i++) {
        final p = PlayerGenerator.generate(
            position: Position.mc, strengthTier: 55, ageOverride: 16)
          ..potential = 70;
        final r = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: 1);
        expect(p.potential, inInclusiveRange(r.$1, r.$2));
        if ((r.$1 + r.$2) / 2 != p.potential) offCenter++;
        // 同じ選手は何度見ても同じ幅(見直して答えを絞れない)。
        expect(ScoutingEngine.estimatedPotentialRange(p, scoutLevel: 1), r);
      }
      expect(offCenter, greaterThan(30), reason: '幅の真ん中がほぼ本当の値のまま');
    });

    test('見極めが高いほど幅は狭いまま', () {
      final p = PlayerGenerator.generate(
          position: Position.mc, strengthTier: 55, ageOverride: 16)
        ..potential = 70;
      int width(int level) {
        final r = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: level);
        return r.$2 - r.$1;
      }

      expect(width(8), lessThan(width(1)));
    });
  });

  group('5. 「国内カップ優勝」は国内カップの優勝だけ', () {
    SeasonRecord record({List<String> cups = const [], bool? domestic}) {
      // domestic が null なら、印の無い古い記録として読み込む。
      final json = SeasonRecord(
        season: 1,
        clubName: 'c',
        leagueName: 'l',
        divisionTier: 1,
        finalRank: 3,
        teamCount: 20,
        played: 38,
        won: 20,
        draw: 10,
        lost: 8,
        goalsFor: 60,
        goalsAgainst: 40,
        cupsWon: cups,
        wonDomesticCup: domestic,
      ).toJson();
      if (domestic == null) json.remove('wonDomesticCup');
      return SeasonRecord.fromJson(json);
    }

    test('印は保存して読み戻せる', () {
      expect(record(cups: ['X'], domestic: true).wonDomesticCup, isTrue);
      expect(record(cups: ['X'], domestic: false).wonDomesticCup, isFalse);
    });

    test('古い記録では、リーグカップ・大陸大会の優勝を国内カップとみなさない', () {
      expect(record(cups: ['League Cup']).wonDomesticCup, isFalse);
      expect(record(cups: ['European Champions Cup']).wonDomesticCup, isFalse);
      expect(
          record(cups: ['League Cup', 'Coppa Nazionale']).wonDomesticCup,
          isTrue);
      expect(record().wonDomesticCup, isFalse);
    });

    Future<GameState> withCupGoal(SeasonRecord Function(int season) r) async {
      final gs = GameState();
      await gs.startNewGame('目標FC');
      await gs.setOwnerGoal(OwnerGoal.winCup);
      final save = gs.save!;
      save.seasonHistory.add(r(save.league.season));
      gs.debugEvaluateOwnerGoal(season: save.league.season);
      return gs;
    }

    SeasonRecord seasonWith(int season, List<String> cups, {bool? domestic}) =>
        SeasonRecord(
          season: season,
          clubName: 'c',
          leagueName: 'l',
          divisionTier: 1,
          finalRank: 3,
          teamCount: 20,
          played: 38,
          won: 20,
          draw: 10,
          lost: 8,
          goalsFor: 60,
          goalsAgainst: 40,
          cupsWon: cups,
          wonDomesticCup: domestic,
        );

    test('リーグカップ・大陸大会だけの優勝では目標は達成にならない', () async {
      final gs = await withCupGoal(
          (s) => seasonWith(s, ['League Cup', 'X'], domestic: false));
      expect(gs.save!.ownerGoal, OwnerGoal.winCup);
      expect(gs.save!.achievedGoals, isEmpty);
    });

    test('国内カップの優勝なら達成', () async {
      final gs =
          await withCupGoal((s) => seasonWith(s, ['X'], domestic: true));
      expect(gs.save!.ownerGoal, isNull);
      expect(gs.save!.achievedGoals, hasLength(1));
    });
  });

  group('6. 天候は試合の日の月に合わせる', () {
    test('12月のカップ戦に猛暑は出ない', () {
      final teams = [for (var i = 0; i < 8; i++) squad('t$i', tier: 50)];
      for (var round = 0; round < 6; round++) {
        final cup = CupEngine.createKnockout(
          type: CupType.domestic,
          name: 'cup',
          teamIds: teams.map((t) => t.id).toList(),
        );
        while (cup.nextUnplayedMatch != null) {
          final r = CupEngine.playNextMatch(cup, teams, month: 12);
          if (r == null) break;
          expect(r.weather, isNot(Weather.heatwave));
        }
      }
    });

    test('大陸大会でも、7月に雪は出ない', () {
      final teams = [for (var i = 0; i < 8; i++) squad('c$i', tier: 50)];
      final cup = ContinentalCupEngine.create(
        name: 'cc',
        teamIds: teams.map((t) => t.id).toList(),
      );
      for (var i = 0; i < 12; i++) {
        final r =
            ContinentalCupEngine.playNextGroupMatch(cup, teams, month: 7);
        if (r == null) break;
        expect(r.weather, isNot(Weather.snow));
      }
    });
  });

  group('7. 引退は32歳から', () {
    test('31歳は引退しない、32歳からは引退しうる', () {
      final p = PlayerGenerator.generate(
          position: Position.mc, strengthTier: 40, ageOverride: 31);
      expect(RetirementEngine.retirementChance(p), 0.0);
      p.age = 32;
      p.attributes = {for (final k in AttributeKeys.all) k: 40};
      expect(RetirementEngine.retirementChance(p), greaterThan(0.0));
      final source =
          File('lib/logic/retirement_engine.dart').readAsStringSync();
      expect(source, isNot(contains('31歳未満は引退しない')));
    });
  });
}
