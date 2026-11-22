import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/country_coefficient.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/promotion_engine.dart';
import 'package:soccer_manager/models/continental_cup.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// カップ戦と大陸大会を実在の形に寄せた(2026-11-22)ことの検査。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<int, List<String>> tiers(int a, int b, int c) => {
        1: [for (var i = 0; i < a; i++) 't1_$i'],
        2: [for (var i = 0; i < b; i++) 't2_$i'],
        3: [for (var i = 0; i < c; i++) 't3_$i'],
      };

  group('国内カップ: 1〜3部の全クラブ', () {
    test('3部が1回戦、2部が2回戦、1部は後から入る。不戦勝の試合は作らない', () {
      final cup = CupEngine.createTiered(
        type: CupType.domestic,
        name: 'cup',
        byTier: tiers(20, 24, 24),
        random: Random(1),
      );
      final r1 = cup.rounds.single;
      expect(r1.length, 12, reason: '3部の24クラブが12試合');
      for (final m in r1) {
        expect(m.homeTeamId.startsWith('t3_'), isTrue);
        expect(m.awayTeamId.startsWith('t3_'), isTrue);
        expect(m.isBye, isFalse);
      }
      for (var i = 0; i < 20; i++) {
        expect(cup.involvesTeam('t1_$i'), isTrue, reason: '1部も出る');
      }
      expect(cup.plannedRounds, cup.totalRounds);
      expect(cup.totalRounds, greaterThanOrEqualTo(7));
    });

    test('最後まで進めると、2の累乗で決勝まで行き、優勝が1つ決まる', () {
      for (final sizes in [
        [20, 24, 24],
        [20, 22, 20],
        [18, 18, 20],
        [20, 20, 20],
        [18, 18, 18],
      ]) {
        final byTier = tiers(sizes[0], sizes[1], sizes[2]);
        final cup = CupEngine.createTiered(
            type: CupType.domestic,
            name: 'cup',
            byTier: byTier,
            random: Random(sizes.first));
        final teams = [
          for (final ids in byTier.values)
            for (final id in ids)
              Team(id: id, name: id, players: [], retainedOverall: 70),
        ];
        var guard = 0;
        while (!cup.isComplete && guard++ < 500) {
          final m = cup.nextUnplayedMatch!;
          CupEngine.playInBackground(cup, teams, m);
        }
        expect(cup.isComplete, isTrue, reason: '$sizes');
        expect(cup.rounds.length, cup.plannedRounds, reason: '$sizes');
        expect(cup.rounds.last.length, 1);
        // 決勝の2つ前からは2の累乗(8→4→2→1試合)。
        expect(cup.rounds[cup.rounds.length - 2].length, 2);
        expect(cup.rounds[cup.rounds.length - 3].length, 4);
        // 全クラブがどこかの回戦で試合をした(不戦勝で決勝まで行かない)。
        final played = {
          for (final r in cup.rounds)
            for (final m in r) ...[m.homeTeamId, m.awayTeamId],
        };
        expect(played.length, teams.length, reason: '$sizes');
      }
    });

    test('部の違うクラブが当たると、下の部のクラブのホーム', () {
      final cup = CupEngine.createTiered(
        type: CupType.domestic,
        name: 'cup',
        byTier: tiers(20, 24, 24),
        random: Random(3),
      );
      final teams = [
        for (final id in cup.tiers.keys)
          Team(id: id, name: id, players: [], retainedOverall: 70),
      ];
      var mixed = 0;
      while (!cup.isComplete) {
        for (final m in cup.rounds.last) {
          final th = cup.tiers[m.homeTeamId]!;
          final ta = cup.tiers[m.awayTeamId]!;
          if (th != ta) {
            mixed++;
            expect(th, greaterThan(ta), reason: '下の部(数字が大きい)がホーム');
          }
        }
        CupEngine.playInBackground(cup, teams, cup.nextUnplayedMatch!);
      }
      expect(mixed, greaterThan(0));
    });

    test('90分で並べば延長戦、それでも並べばPK戦で決着する', () {
      final cup = CupEngine.createTiered(
        type: CupType.domestic,
        name: 'cup',
        byTier: {
          3: ['a', 'b']
        },
      );
      final a = Team(id: 'a', name: 'a', players: [], retainedOverall: 70);
      final b = Team(id: 'b', name: 'b', players: [], retainedOverall: 70);
      final m = cup.rounds.single.single;
      CupEngine.applyMatchResult(
        cup,
        [a, b],
        m,
        MatchResult(
            matchday: 0,
            homeTeamId: m.homeTeamId,
            awayTeamId: m.awayTeamId,
            homeGoals: 1,
            awayGoals: 1,
            events: []),
      );
      expect(m.extraTime, isTrue);
      expect(m.winnerId, isNotNull);
      if (m.result!.homeGoals == m.result!.awayGoals) {
        expect(m.penaltyWinnerId, isNotNull);
      } else {
        expect(m.penaltyWinnerId, isNull);
      }
      expect(cup.isComplete, isTrue);
      // 保存して読み戻しても延長の印が残る。
      final back = Cup.fromJson(jsonDecode(jsonEncode(cup.toJson())));
      expect(back.rounds.single.single.extraTime, isTrue);
      expect(back.plannedRounds, 1);
    });

    test('新しいゲーム: 国内カップに1〜3部の全クラブ。決勝は最終節の前(5月)', () async {
      final gs = GameState();
      await gs.startNewGame('杯FC');
      final s = gs.save!;
      final cup = gs.domesticCup!;
      for (final t in s.allTeams) {
        expect(cup.involvesTeam(t.id), isTrue, reason: t.name);
      }
      final m = (s.league.teams.length - 1) * 2;
      expect(cup.roundDue!.last, m);
      for (var i = 1; i < cup.roundDue!.length; i++) {
        expect(cup.roundDue![i], greaterThan(cup.roundDue![i - 1]),
            reason: '回戦ごとに別の週');
      }
      final finalDate = gs.seasonCalendar.cupDateBefore(m);
      expect(finalDate.month, anyOf(4, 5, 6),
          reason: '決勝は季の終わり(5月ごろ): $finalDate');
    });

    test('回戦はまとめて同じ週に決まる(自クラブの出ない試合は裏で)', () async {
      final gs = GameState();
      await gs.startNewGame('杯FC');
      final cup = gs.domesticCup!;
      final firstRound = cup.rounds.first;
      await gs.simulateAheadMatchdays(cup.roundDue!.first);
      expect(firstRound.every((m) => m.result != null), isTrue,
          reason: '1回戦はすべて終わっている');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('リーグカップはイングランドだけ', () {
    test('イングランドは1〜3部のクラブで、ほかの国には無い', () async {
      final gs = GameState();
      await gs.startNewGame('杯FC');
      expect(gs.leagueCup, isNotNull);
      for (final t in gs.save!.allTeams) {
        expect(gs.leagueCup!.involvesTeam(t.id), isTrue);
      }
      for (final theme in [
        LeagueTheme.spain,
        LeagueTheme.germany,
        LeagueTheme.italy,
        LeagueTheme.france,
      ]) {
        final other = GameState();
        await other.startNewGame('杯FC', theme: theme);
        expect(other.leagueCup, isNull, reason: theme.name);
        expect(other.save!.cups.where((c) => c.type == CupType.leagueCup),
            isEmpty);
      }
    });

    test('古いセーブの他国のリーグカップは、読み込むと静かに消える', () async {
      final gs = GameState();
      await gs.startNewGame('杯FC', theme: LeagueTheme.spain);
      final s = gs.save!;
      s.cups.add(CupEngine.createKnockout(
        type: CupType.leagueCup,
        name: 'old',
        teamIds: s.league.teams.map((t) => t.id).toList(),
      ));
      final json = jsonEncode(s.toJson());
      final ok = await gs.importSaveJson(json);
      expect(ok, isTrue);
      expect(gs.save!.cups.where((c) => c.type == CupType.leagueCup), isEmpty);
      expect(gs.domesticCup, isNotNull);
    });
  });

  group('大陸大会: チャンピオンズカップとヨーロッパカップ', () {
    test('出場枠は実在の数(1・2位5、3・4位4、5位3)。EL は2', () {
      expect(CountryCoefficientEngine.spotsForRank(1), 5);
      expect(CountryCoefficientEngine.spotsForRank(2), 5);
      expect(CountryCoefficientEngine.spotsForRank(3), 4);
      expect(CountryCoefficientEngine.spotsForRank(4), 4);
      expect(CountryCoefficientEngine.spotsForRank(5), 3);
      expect(CountryCoefficientEngine.europaSpots, 2);
    });

    test('始めた時点の係数の順位は イングランド>スペイン>ドイツ>イタリア>フランス', () async {
      final gs = GameState();
      await gs.startNewGame('枠FC');
      expect(gs.countryCoefficientRanking.map((r) => r.$1).toList(), [
        LeagueTheme.england,
        LeagueTheme.spain,
        LeagueTheme.germany,
        LeagueTheme.italy,
        LeagueTheme.france,
      ]);
      expect(gs.championsSpotsFor(LeagueTheme.england), 5);
      expect(gs.championsSpotsFor(LeagueTheme.spain), 5);
      expect(gs.championsSpotsFor(LeagueTheme.germany), 4);
      expect(gs.championsSpotsFor(LeagueTheme.italy), 4);
      expect(gs.championsSpotsFor(LeagueTheme.france), 3);
      expect(gs.continentalSpots, 5);
    });

    test('第1季から2つの大会があり、自国の他のクラブも他国のクラブも出る', () async {
      final gs = GameState();
      await gs.startNewGame('大陸FC');
      final s = gs.save!;
      final cl = s.continentalCup!;
      final el = s.secondContinentalCup!;
      expect(cl.groups.expand((g) => g).length, 32);
      expect(el.groups.expand((g) => g).length, 16);
      expect(cl.groups.length, 8);
      expect(el.groups.length, 4);
      expect(cl.level, 1);
      expect(el.level, 2);
      // グループはホームとアウェイの総当たり(6節)。
      expect(cl.groupMatches.length, 8 * 12);
      expect(cl.groupMatches.map((m) => m.round).reduce(max), 6);
      // 国ごとの数: CL はイングランド5・スペイン5・ドイツ4・イタリア4・
      // フランス3、EL は各国2。
      int count(Map<String, String> c, String theme) =>
          c.values.where((v) => v == theme).length;
      expect(count(cl.countries, 'england'), 5);
      expect(count(cl.countries, 'spain'), 5);
      expect(count(cl.countries, 'germany'), 4);
      expect(count(cl.countries, 'italy'), 4);
      expect(count(cl.countries, 'france'), 3);
      for (final t in LeagueTheme.values) {
        expect(count(el.countries, t.name), 2, reason: t.name);
      }
      // 自国のクラブは自国の1部のクラブ(自クラブは3部なので出ない)。
      final tier1 = {
        for (final t in s.otherDivisionLeagues[0]!.teams) t.id,
      };
      for (final e in cl.countries.entries) {
        if (e.value == 'england') expect(tier1, contains(e.key));
      }
      expect(gs.continentalCup, isNull, reason: '自クラブは出ていない');
      expect(gs.continentalCups.length, 2);
      // 同じ国のクラブは、できるだけ同じ組にしない(国ごと最大5なので、
      // 8組なら必ず分けられる)。
      for (final g in cl.groups) {
        final cs = [
          for (final id in g)
            if (cl.countries[id] != null) cl.countries[id]!
        ];
        expect(cs.toSet().length, cs.length, reason: '$g');
      }
      // 保存して読み戻せる。
      final back = SaveGame.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.secondContinentalCup!.groups.length, 4);
      expect(back.continentalCup!.countries, cl.countries);
      expect(back.continentalTeams.length, s.continentalTeams.length);
    });

    test('段階ごとに日が決まっていて、日が来ると自クラブの出ない試合が進む', () async {
      final gs = GameState();
      await gs.startNewGame('大陸FC');
      final cl = gs.save!.continentalCup!;
      expect(cl.stepDue!.length, ContinentalCupEngine.stepCountFor(8));
      expect(ContinentalCupEngine.currentStep(cl), 0);
      await gs.simulateAheadMatchdays(cl.stepDue![1]);
      expect(
          cl.groupMatches
              .where((m) => m.round <= 2)
              .every((m) => m.result != null),
          isTrue);
      expect(
          cl.groupMatches
              .where((m) => m.round >= 4)
              .every((m) => m.result == null),
          isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('大会を最後まで進めると、決勝トーナメントは2試合合計・決勝は1試合', () {
      final ids = [for (var i = 0; i < 32; i++) 'c$i'];
      final teams = [
        for (var i = 0; i < 32; i++)
          Team(id: 'c$i', name: 'c$i', players: [], retainedOverall: 60 + i),
      ];
      final cup = ContinentalCupEngine.create(
        name: 'cl',
        teamIds: ids,
        homeAndAway: true,
        strength: {for (final t in teams) t.id: t.overallRating},
        stepDue: List.generate(13, (i) => i + 1),
      );
      var guard = 0;
      while (!cup.isComplete && guard++ < 50) {
        ContinentalCupEngine.playCpuStep(cup, teams, 'nobody');
      }
      expect(cup.isComplete, isTrue);
      expect(cup.knockoutRounds.length, 4, reason: 'ベスト16・準々決勝・準決勝・決勝');
      expect(cup.knockoutRounds.first.length, 8);
      for (final r in cup.knockoutRounds.take(3)) {
        for (final t in r) {
          expect(t.legs.length, 2);
        }
      }
      expect(cup.knockoutRounds.last.single.singleLeg, isTrue);
      // ポット分け: 強い8クラブは別々の組。
      final top = [for (var i = 24; i < 32; i++) 'c$i'];
      for (final g in cup.groups) {
        expect(g.where(top.contains).length, 1);
      }
    });

    test('2試合合計で並べば延長戦、それでも並べばPK戦', () {
      final a = Team(id: 'a', name: 'a', players: [], retainedOverall: 70);
      final b = Team(id: 'b', name: 'b', players: [], retainedOverall: 70);
      final cup = ContinentalCupEngine.create(name: 'x', teamIds: ['a', 'b']);
      for (final m in cup.groupMatches) {
        ContinentalCupEngine.applyGroupMatchResult(
            cup,
            [a, b],
            m,
            MatchResult(
                matchday: 1,
                homeTeamId: m.homeTeamId,
                awayTeamId: m.awayTeamId,
                homeGoals: 0,
                awayGoals: 0,
                events: []));
      }
      // 1組だけだと決勝トーナメントは組まれない。自分で1つ作る。
      final tie = CupTie(round: 1, teamAId: 'a', teamBId: 'b');
      cup.knockoutRounds.add([tie]);
      MatchResult r(String h, String w) => MatchResult(
          matchday: 0,
          homeTeamId: h,
          awayTeamId: w,
          homeGoals: 1,
          awayGoals: 1,
          events: []);
      ContinentalCupEngine.applyKnockoutLegResult(
          cup, [a, b], tie, r('a', 'b'));
      expect(tie.extraTime, isFalse);
      ContinentalCupEngine.applyKnockoutLegResult(
          cup, [a, b], tie, r('b', 'a'));
      expect(tie.extraTime, isTrue);
      expect(tie.winnerId, isNotNull);
    });
  });

  group('賞金', () {
    test('CL は出るだけで30億、優勝クラブの総額は150億以上。EL は3分の1', () {
      expect(championsCupParticipationPrize, 300000);
      final cl = continentalChampionTotal(1,
          groupWins: 4, groupDraws: 1, knockoutRounds: 4);
      expect(cl, greaterThanOrEqualTo(1500000));
      final el = continentalChampionTotal(2,
          groupWins: 4, groupDraws: 1, knockoutRounds: 3);
      expect(el / cl, closeTo(1 / 3, 0.08));
      expect(continentalPrize(2, championsCupParticipationPrize), 100000);
    });

    test('賞金は1部の真ん中のクラブの年収の目安に入れない(出場だけで約9%の上乗せ)', () {
      // 年収の目安は国で変わる(放映権の国差。イングランドの1部で約380億)。
      final share = championsCupParticipationPrize / typicalAnnualIncome(1);
      expect(share, inInclusiveRange(0.07, 0.12));
    });

    test('自クラブが出ていれば、出場給と勝ち上がりの賞金が年収に入る', () async {
      final gs = GameState();
      await gs.startNewGame('賞金FC');
      final s = gs.save!;
      // 自クラブを1部の1位として大会を組み直す。
      final tier1 = [s.league.teams.firstWhere((t) => t.id == s.userTeamId)];
      tier1.addAll(s.otherDivisionLeagues[0]!.teams);
      gs.debugSetUpContinentalCups(tier1);
      expect(gs.continentalCup, same(s.continentalCup));
      final before = s.budget;
      // 第1節(グループの第1節より前)からグループが終わるまで進める。
      await gs.simulateAheadMatchdays(s.continentalCup!.stepDue![5]);
      final cup = s.continentalCup!;
      expect(cup.participationPaid, isTrue);
      expect(s.careerCupPrize, greaterThanOrEqualTo(300000),
          reason: '出場給30億が入っている');
      expect(s.budget, isNot(before));
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  group('順位の決め方', () {
    League twoTied({required bool goalDiffFirst}) {
      Team t(String id) => Team(id: id, name: id, players: []);
      final teams = [t('a'), t('b'), t('c')];
      Fixture f(String h, String a, int hg, int ag) => Fixture(
          matchday: 1,
          homeTeamId: h,
          awayTeamId: a,
          result: MatchResult(
              matchday: 1,
              homeTeamId: h,
              awayTeamId: a,
              homeGoals: hg,
              awayGoals: ag,
              events: []));
      // a と b は勝ち点6で並ぶ。直接対決は a の勝ち、得失点差は b が上。
      return League(
        teams: teams,
        fixtures: [
          f('a', 'b', 1, 0),
          f('b', 'c', 5, 0),
          f('a', 'c', 1, 0),
          f('c', 'b', 0, 1),
        ],
        goalDiffFirst: goalDiffFirst,
      );
    }

    test('イングランド・ドイツ・フランスは得失点差が先、スペイン・イタリアは直接対決が先', () {
      expect(LeagueTheme.england.goalDifferenceFirst, isTrue);
      expect(LeagueTheme.germany.goalDifferenceFirst, isTrue);
      expect(LeagueTheme.france.goalDifferenceFirst, isTrue);
      expect(LeagueTheme.spain.goalDifferenceFirst, isFalse);
      expect(LeagueTheme.italy.goalDifferenceFirst, isFalse);
      final gd = twoTied(goalDiffFirst: true).sortedStandings;
      final h2h = twoTied(goalDiffFirst: false).sortedStandings;
      expect(gd.first.points, gd[1].points);
      expect(gd.first.teamId, 'b');
      expect(h2h.first.teamId, 'a');
      final back = League.fromJson(
          jsonDecode(jsonEncode(twoTied(goalDiffFirst: true).toJson())));
      expect(back.goalDiffFirst, isTrue);
    });

    test('ゲームのリーグにも国ごとの決め方が入る', () async {
      final gs = GameState();
      await gs.startNewGame('順位FC');
      expect(gs.save!.league.goalDiffFirst, isTrue);
      expect(gs.save!.foreignLeagues['spain']!.goalDiffFirst, isFalse);
      expect(gs.save!.foreignLeagues['germany']!.goalDiffFirst, isTrue);
      final es = GameState();
      await es.startNewGame('順位FC', theme: LeagueTheme.italy);
      expect(es.save!.league.goalDiffFirst, isFalse);
    });
  });

  group('昇格プレーオフ・入れ替え戦', () {
    List<Team> squads(String p, int n) => [
          for (var i = 0; i < n; i++)
            PlayerGenerator.generateSquad(
                id: '$p$i', name: '$p$i', strengthTier: 70),
        ];

    test('イングランド: 準決勝は2試合合計、決勝は1試合', () {
      final up = squads('u', 6);
      final low = squads('l', 8);
      final r = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: LeagueTheme.england.rulesBelow(1),
      );
      expect(r.promotionPlayoff.length, 5, reason: '準決勝2×2試合+決勝1試合');
      expect(r.promotedTeamNames.length, 3);
    });

    test('スペイン: すべて2試合合計(並べば順位が上)', () {
      final up = squads('u', 6);
      final low = squads('l', 8);
      final r = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: LeagueTheme.spain.rulesBelow(1),
      );
      expect(r.promotionPlayoff.length, 6);
      expect(r.promotionPlayoff.where((m) => m.decidedByPenalties), isEmpty);
    });

    test('イタリア: 3〜8位の6クラブ。3位が4位を14点以上離せば行わない', () {
      final up = squads('u', 6);
      final low = squads('l', 10);
      final rules = LeagueTheme.italy.rulesBelow(1);
      expect(rules.playoffPool, 6);
      final r = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: rules,
        tier2Points: {for (var i = 0; i < 10; i++) 'l$i': 80 - i},
      );
      expect(r.promotionPlayoff.length, 2 + 4 + 2, reason: '1回戦2+準決勝4+決勝2');
      final skip = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: rules,
        tier2Points: {
          for (var i = 0; i < 10; i++) 'l$i': i <= 2 ? 90 - i : 70 - i,
        },
      );
      expect(skip.promotionPlayoff, isEmpty);
      expect(skip.promotedTeamNames, ['l0', 'l1', 'l2']);
    });

    test('ドイツ: 入れ替え戦は2試合合計', () {
      final up = squads('u', 6);
      final low = squads('l', 6);
      final r = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: LeagueTheme.germany.rulesBelow(1),
      );
      expect(r.promotionPlayoff.length, 2);
      expect(r.promotionPlayoff.first.homeId, 'l2', reason: '第1戦は下の部のホーム');
      expect(r.promotionPlayoff.last.homeId, 'u3', reason: '第2戦は上の部のホーム');
    });
  });

  group('スーパーカップ', () {
    test('スペイン・イタリアは4クラブ。重なればリーグの次の順位', () {
      final ids = [for (var i = 0; i < 20; i++) 'c$i'];
      final cup = CupEngine.createKnockout(
          type: CupType.domestic, name: 'c', teamIds: ['c0', 'c5']);
      final m = cup.rounds.single.single;
      CupEngine.applyMatchResult(
        cup,
        [
          Team(id: 'c0', name: 'c0', players: [], retainedOverall: 70),
          Team(id: 'c5', name: 'c5', players: [], retainedOverall: 70),
        ],
        m,
        MatchResult(
            matchday: 0,
            homeTeamId: m.homeTeamId,
            awayTeamId: m.awayTeamId,
            homeGoals: m.homeTeamId == 'c5' ? 2 : 0,
            awayGoals: m.awayTeamId == 'c5' ? 2 : 0,
            events: []),
      );
      final field = GameStateCups.fourClubSuperCupField(ids, cup)!;
      // リーグ1位 c0 がカップ準優勝なので、代わりにリーグ3位 c2。
      expect(field, ['c0', 'c1', 'c5', 'c2']);
      expect(LeagueTheme.spain.fourClubSuperCup, isTrue);
      expect(LeagueTheme.italy.fourClubSuperCup, isTrue);
      expect(LeagueTheme.england.fourClubSuperCup, isFalse);
    });

    test('季をまたぐと、スペインは4クラブのスーパーカップが1月ごろに組まれ、'
        '大陸大会も組み直される', () async {
      final gs = GameState();
      await gs.startNewGame('季FC', theme: LeagueTheme.spain);
      await gs.simulateAheadMatchdays(60);
      // リーグの後に残ったカップ戦を済ませる。
      while (gs.domesticCup?.nextUnplayedMatch != null) {
        await gs.playNextCupMatch();
      }
      expect(gs.domesticCup!.isComplete, isTrue);
      for (final c in gs.continentalCups) {
        expect(c.isComplete, isTrue, reason: c.name);
      }
      await gs.startNextSeason();
      final s = gs.save!;
      final sc = gs.fourClubSuperCup;
      expect(sc, isNotNull);
      expect(sc!.rounds.single.length, 2, reason: '準決勝2試合');
      expect(sc.plannedRounds, 2);
      final janDate = gs.seasonCalendar.dateForMatchday(sc.roundDue!.first);
      expect(janDate.month, anyOf(1, 2), reason: '$janDate');
      expect(gs.pendingSuperCup, isNull, reason: '開幕前の1試合は無い');
      expect(s.cups.where((c) => c.type == CupType.leagueCup), isEmpty);
      expect(s.continentalCup!.groups.length, 8);
      expect(s.secondContinentalCup!.groups.length, 4);
      // 係数は、その国のクラブの実際の成績から足された。
      expect(s.countryCoefficients['spain']!.length,
          CountryCoefficientEngine.seasons);
      // スーパーカップの日が来ると決まる。
      await gs.simulateAheadMatchdays(sc.roundDue!.last + 1);
      expect(sc.isComplete, isTrue);
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
