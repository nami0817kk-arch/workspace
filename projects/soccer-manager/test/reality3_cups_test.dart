import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/day_events.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/promotion_engine.dart';
import 'package:soccer_manager/models/continental_cup.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// カップ・昇格まわりの残り(2026-11-22): 4クラブのスーパーカップを遊べる
/// ようにする、2部と3部の入れ替えを国ごとの形に、フランスの入れ替え戦を
/// 2試合合計に、延長の得点を選手の成績に数える。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 自クラブを入れた4クラブのスーパーカップを、今すぐ戦える形で置く
  /// (準決勝は第1節、決勝は第2節)。
  Future<(GameState, Cup)> spainWithSuperCup() async {
    final gs = GameState();
    await gs.startNewGame('杯FC', theme: LeagueTheme.spain);
    final s = gs.save!;
    s.cups.removeWhere((c) => c.type == CupType.superCup);
    final others =
        s.league.teams.where((t) => t.id != s.userTeamId).take(3).toList();
    final cup = Cup(
      type: CupType.superCup,
      name: 'スーパーカップ',
      rounds: [
        [
          CupMatch(
              round: 1, homeTeamId: others[0].id, awayTeamId: others[1].id),
          CupMatch(
              round: 1, homeTeamId: s.userTeamId, awayTeamId: others[2].id),
        ],
      ],
      plannedRounds: 2,
      roundDue: [1, 2],
    );
    s.cups.add(cup);
    return (gs, cup);
  }

  group('4クラブのスーパーカップを遊べる', () {
    test('日が来ても自クラブの試合は勝手に決まらず、もう1つの準決勝だけ裏で決まる', () async {
      final (gs, cup) = await spainWithSuperCup();
      final u = gs.userTeam.id;
      expect(gs.fourClubSuperCup, same(cup));
      gs.debugPlayDueCpuCupMatches();
      final mine = cup.rounds.first
          .firstWhere((m) => m.homeTeamId == u || m.awayTeamId == u);
      final other = cup.rounds.first.firstWhere((m) => !identical(m, mine));
      expect(mine.result, isNull, reason: '自クラブの試合は自分で戦う');
      expect(other.result, isNotNull);
      expect(gs.canPlayNextFourClubSuperCupMatch, isTrue);
      expect(cup.nextUnplayedMatch, same(mine), reason: '自クラブの試合が次');
      // カレンダーに自クラブのカップ戦として出る(進むボタンがその日に
      // 止まる)。
      final events = gs.calendarEventsBetween(
          gs.today, gs.dateOfMatchday(1).add(const Duration(days: 1)));
      expect(
          events.any((e) =>
              e.kind == DayEventKind.cupMatch && e.label.contains(cup.name)),
          isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('自動で戦える。延長は無く、並べばPK戦。勝てば決勝、終われば優勝が決まる', () async {
      final (gs, cup) = await spainWithSuperCup();
      final u = gs.userTeam.id;
      final appsBefore =
          gs.userTeam.players.fold<int>(0, (a, p) => a + p.careerAppearances);
      final r = await gs.playNextFourClubSuperCupMatch();
      expect(r, isNotNull);
      final semi = cup.rounds.first
          .firstWhere((m) => m.homeTeamId == u || m.awayTeamId == u);
      expect(semi.result, isNotNull);
      expect(semi.extraTime, isFalse, reason: 'スーパーカップに延長は無い');
      if (r!.homeGoals == r.awayGoals) {
        expect(semi.penaltyWinnerId, isNotNull);
      }
      // 試合後の効果(出場の記録)がリーグ戦と同じように付く。
      final appsAfter =
          gs.userTeam.players.fold<int>(0, (a, p) => a + p.careerAppearances);
      expect(appsAfter, greaterThan(appsBefore));
      expect(cup.rounds.length, 2, reason: '準決勝2つが終わって決勝が組まれた');
      // 決勝の日(第2節)まで進めると、自クラブが出ていれば自分で戦い、
      // 出ていなければ裏で決まる。
      await gs.simulateAheadMatchdays(2);
      expect(cup.isComplete, isTrue);
      expect(cup.rounds.last.single.extraTime, isFalse);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('ライブ観戦でも戦える(LiveCupKind.superCup)', () async {
      final (gs, cup) = await spainWithSuperCup();
      final u = gs.userTeam.id;
      expect(gs.canPlayNextFourClubSuperCupMatchLive, isTrue);
      expect(await gs.startCupMatchLive(LiveCupKind.superCup), isTrue);
      expect(gs.liveCupDescriptor, isNotNull);
      // 始める前に、もう1つの準決勝は裏で決まっている。
      final other = cup.rounds.first
          .firstWhere((m) => m.homeTeamId != u && m.awayTeamId != u);
      expect(other.result, isNotNull);
      while (gs.pendingChanceDecision != null) {
        await gs.resolveChanceDecision(ChanceDecision.shoot);
      }
      MatchResult? merged = await gs.playSecondHalf(interactive: true);
      while (merged == null && gs.pendingChanceDecision != null) {
        merged = (await gs.resolveChanceDecision(ChanceDecision.shoot)).merged;
      }
      expect(merged, isNotNull);
      final semi = cup.rounds.first
          .firstWhere((m) => m.homeTeamId == u || m.awayTeamId == u);
      expect(semi.result!.homeGoals, merged!.homeGoals);
      expect(semi.result!.awayGoals, merged.awayGoals);
      expect(semi.extraTime, isFalse);
      if (merged.homeGoals == merged.awayGoals) {
        expect(semi.penaltyWinnerId, isNotNull, reason: '延長なしでPK戦');
      }
      expect(cup.rounds.length, 2, reason: '決勝が組まれた');
      expect(gs.liveCupDescriptor, isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('2部と3部の入れ替えを国ごとの形に', () {
    List<Team> squads(String p, int n) => [
          for (var i = 0; i < n; i++)
            PlayerGenerator.generateSquad(
                id: '$p$i', name: '$p$i', strengthTier: 70),
        ];

    PromotionResult run(LeagueTheme theme, int upperTier,
        {int upper = 8, int lower = 12}) {
      final up = squads('u', upper);
      final low = squads('l', lower);
      return PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: theme.rulesBelow(upperTier),
      );
    }

    test('イングランド: リーグ1は自動2+プレーオフ1(準決勝2試合合計・決勝1試合)', () {
      final rules = LeagueTheme.england.rulesBelow(2);
      expect(rules.autoUp, 2);
      expect(rules.playoffPool, 4);
      expect(rules.playoffSpots, 1);
      expect(rules.playoffFormat, PlayoffFormat.englishTwoLegSemis);
      final r = run(LeagueTheme.england, 2);
      expect(r.promotionPlayoff.length, 5);
      expect(r.promotedTeamNames.length, 3);
      expect(r.promotedTeamNames.take(2), ['l0', 'l1']);
    });

    test('スペイン: 1部RFEFは自動2+3〜6位のプレーオフで2枠(2試合合計、PK戦なし)', () {
      final rules = LeagueTheme.spain.rulesBelow(2);
      expect(rules.autoDown, 4);
      expect(rules.autoUp, 2);
      expect(rules.playoffSpots, 2);
      expect(rules.promotionPlaces, 4, reason: '2部から4降格と釣り合う');
      for (var i = 0; i < 6; i++) {
        final r = run(LeagueTheme.spain, 2);
        expect(r.promotionPlayoff.length, 4, reason: '2つの対戦×2試合、決勝なし');
        expect(r.promotionPlayoff.where((m) => m.decidedByPenalties), isEmpty,
            reason: '並べば延長、それでも並べば順位が上');
        expect(r.promotedTeamNames.length, 4);
        expect(r.relegatedTeamNames.length, 4);
        expect(r.promotedTeamNames.take(2), ['l0', 'l1']);
        // 3位対6位、4位対5位の勝者が上がる。
        final viaPlayoff = r.promotedTeamNames.skip(2).toSet();
        expect(viaPlayoff.intersection({'l2', 'l5'}).length, 1);
        expect(viaPlayoff.intersection({'l3', 'l4'}).length, 1);
        expect(r.tier1.length, 8);
        expect(r.tier2.length, 12);
      }
      expect(LeagueTheme.spain.describeRules(2), contains('2'));
    });

    test('イタリア: セリエCは自動3+4〜9位のプレーオフで1枠(1回戦は延長なし、決勝は2試合合計)', () {
      final rules = LeagueTheme.italy.rulesBelow(2);
      // 2部から落ちるのは自動3+プレーアウトの負け1(2026-11-22)。
      expect(rules.autoDown, 3);
      expect(rules.relegationPlayout, isTrue);
      expect(rules.relegationPlaces, 4);
      expect(rules.autoUp, 3);
      expect(rules.playoffPool, 6);
      expect(rules.playoffFormat, PlayoffFormat.serieC);
      for (var i = 0; i < 6; i++) {
        final r = run(LeagueTheme.italy, 2);
        expect(r.promotionPlayoff.length, 2 + 4 + 2 + 2,
            reason: '1回戦2試合+準決勝2×2試合+決勝2試合+プレーアウト2試合');
        expect(r.promotedTeamNames.take(3), ['l0', 'l1', 'l2']);
        expect(r.promotedTeamNames.length, 4);
        expect(r.relegatedTeamNames.length, 4);
        // 1回戦と準決勝は、並べば順位が上(PK戦は無い)。
        expect(r.promotionPlayoff.take(6).where((m) => m.decidedByPenalties),
            isEmpty);
        // 1回戦は延長なし(1試合の得点は90分の分だけ。引き分けなら順位が上)。
        for (final m in r.promotionPlayoff.take(2)) {
          if (m.homeGoals == m.awayGoals) expect(m.winnerId, m.homeId);
        }
      }
    });

    test('ドイツ: 3部→2部は自動2+入れ替え戦(2試合合計)', () {
      final r = run(LeagueTheme.germany, 2);
      expect(
          LeagueTheme.germany.rulesBelow(2).relegationPlayoffTwoLegs, isTrue);
      expect(r.promotionPlayoff.length, 2);
      expect(r.promotedTeamNames.take(2), ['l0', 'l1']);
    });
  });

  group('フランスの入れ替え戦は2試合合計', () {
    test('1部と2部の間も、2部と3部の間も', () {
      // 1部と2部の間は、2部の3〜5位のプレーオフ(1試合ずつ)が前に付く
      // (2026-11-22)。ここでは入れ替え戦の2試合だけを見る。
      for (final upper in [1, 2]) {
        final rules = LeagueTheme.france.rulesBelow(upper);
        expect(rules.relegationPlayoff, isTrue);
        expect(rules.relegationPlayoffTwoLegs, isTrue, reason: '$upper部');
        final up = [
          for (var i = 0; i < 6; i++)
            PlayerGenerator.generateSquad(
                id: 'u$i', name: 'u$i', strengthTier: 70),
        ];
        final low = [
          for (var i = 0; i < 6; i++)
            PlayerGenerator.generateSquad(
                id: 'l$i', name: 'l$i', strengthTier: 70),
        ];
        final r = PromotionEngine.resolve(
          tier1Teams: up,
          tier2Teams: low,
          tier1PlayedOrder: up,
          tier2PlayedOrder: low,
          rules: rules,
        );
        expect(r.promotionPlayoff.length, upper == 1 ? 4 : 2);
        final barrage = r.promotionPlayoff.skip(r.promotionPlayoff.length - 2);
        final lowerSide = upper == 1 ? r.promotionPlayoff[1].winnerId : 'l2';
        expect(barrage.first.homeId, lowerSide, reason: '第1戦は下の部のホーム');
        expect(barrage.last.homeId, 'u3', reason: '第2戦は上の部のホーム');
        expect(barrage.first.winnerId, barrage.last.winnerId);
      }
    });

    test('1部と2部の間: 2部の3〜5位のプレーオフ(4位対5位→勝者対3位)の勝者が1部16位と戦う', () {
      final rules = LeagueTheme.france.rulesBelow(1);
      expect(rules.relegationPlayoffQualifiers, 3);
      expect(LeagueTheme.france.rulesBelow(2).relegationPlayoffQualifiers, 1);
      final up = [
        for (var i = 0; i < 18; i++)
          PlayerGenerator.generateSquad(
              id: 'u$i', name: 'u$i', strengthTier: 70),
      ];
      final low = [
        for (var i = 0; i < 18; i++)
          PlayerGenerator.generateSquad(
              id: 'l$i', name: 'l$i', strengthTier: 70),
      ];
      for (var k = 0; k < 6; k++) {
        final r = PromotionEngine.resolve(
          tier1Teams: up,
          tier2Teams: low,
          tier1PlayedOrder: up,
          tier2PlayedOrder: low,
          rules: rules,
        );
        final ms = r.promotionPlayoff;
        expect(ms.length, 4, reason: '1回戦1+2回戦1+入れ替え戦2');
        // 1回戦: 4位(ホーム)対5位。
        expect(ms[0].homeId, 'l3');
        expect(ms[0].awayId, 'l4');
        // 2回戦: 3位(ホーム)対1回戦の勝者。
        expect(ms[1].homeId, 'l2');
        expect(ms[1].awayId, ms[0].winnerId);
        // 入れ替え戦: 2回戦の勝者対1部16位(2試合合計)。
        expect(ms[2].homeId, ms[1].winnerId);
        expect(ms[2].awayId, 'u15');
        expect(ms[3].homeId, 'u15');
        // 上位2つは自動昇格。下位2つは自動降格。
        expect(r.promotedTeamNames.take(2), ['l0', 'l1']);
        expect(r.relegatedTeamNames.take(2), ['u16', 'u17']);
        // 入れ替え戦の勝者が1部に入り、部の大きさは変わらない。
        expect(r.tier1.any((t) => t.id == ms[3].winnerId), isTrue);
        expect(r.tier1.length, 18);
        expect(r.tier2.length, 18);
        // 3〜5位のうち入れ替え戦に出なかったクラブは上がらない。
        for (final id in ['l2', 'l3', 'l4']) {
          if (id == ms[1].winnerId) continue;
          expect(r.tier1.any((t) => t.id == id), isFalse);
        }
      }
      expect(LeagueTheme.france.describeRules(1), contains('3'));
    });
  });

  group('イタリアの2部の降格プレーアウト', () {
    List<Team> squads(String p, int n) => [
          for (var i = 0; i < n; i++)
            PlayerGenerator.generateSquad(
                id: '$p$i', name: '$p$i', strengthTier: 70),
        ];

    test('16位対17位を2試合合計で行い、負けた方が落ちる(18〜20位は自動)', () {
      final up = squads('u', 20);
      final low = squads('l', 20);
      for (var k = 0; k < 6; k++) {
        final r = PromotionEngine.resolve(
          tier1Teams: up,
          tier2Teams: low,
          tier1PlayedOrder: up,
          tier2PlayedOrder: low,
          rules: LeagueTheme.italy.rulesBelow(2),
          // 16位と17位の差は3点(行う)。
          tier1Points: {for (var i = 0; i < 20; i++) 'u$i': 60 - i * 3},
        );
        final playout = r.promotionPlayoff
            .where((m) => m.homeId == 'u15' || m.homeId == 'u16')
            .toList();
        expect(playout.length, 2);
        expect(playout.first.homeId, 'u16', reason: '第1戦は17位のホーム');
        expect(playout.last.homeId, 'u15', reason: '第2戦は16位のホーム');
        expect(playout.where((m) => m.decidedByPenalties), isEmpty,
            reason: '並べば順位が上が残る');
        final stays = playout.last.winnerId;
        final goes = stays == 'u15' ? 'u16' : 'u15';
        expect(r.relegatedTeamNames, containsAll(['u17', 'u18', 'u19', goes]));
        expect(r.relegatedTeamNames.length, 4);
        expect(r.tier1.any((t) => t.id == stays), isTrue);
        expect(r.tier1.length, 20);
        expect(r.tier2.length, 20);
      }
    });

    test('16位と17位の勝ち点差が4以上なら行わずに17位が落ちる', () {
      final up = squads('u', 20);
      final low = squads('l', 20);
      final r = PromotionEngine.resolve(
        tier1Teams: up,
        tier2Teams: low,
        tier1PlayedOrder: up,
        tier2PlayedOrder: low,
        rules: LeagueTheme.italy.rulesBelow(2),
        tier1Points: {for (var i = 0; i < 20; i++) 'u$i': 80 - i * 4},
      );
      expect(
          r.promotionPlayoff
              .where((m) => m.homeId == 'u15' || m.homeId == 'u16'),
          isEmpty);
      expect(r.relegatedTeamNames, containsAll(['u16', 'u17', 'u18', 'u19']));
      expect(r.relegatedTeamNames.length, 4);
      expect(r.tier1.any((t) => t.id == 'u15'), isTrue);
    });

    test('1部と2部の間(セリエA→B)にはプレーアウトは無い', () {
      expect(LeagueTheme.italy.rulesBelow(1).relegationPlayout, isFalse);
      expect(LeagueTheme.italy.describeRules(2), contains('4'));
    });
  });

  group('延長の得点を選手の成績に数える', () {
    test('延長の得点者とアシストは出ている選手から選ばれ、通算得点に足せる', () {
      final a =
          PlayerGenerator.generateSquad(id: 'a', name: 'a', strengthTier: 80);
      final b =
          PlayerGenerator.generateSquad(id: 'b', name: 'b', strengthTier: 60);
      final base = MatchResult(
          matchday: 0,
          homeTeamId: 'a',
          awayTeamId: 'b',
          homeGoals: 1,
          awayGoals: 1,
          events: []);
      final rng = Random(4);
      var sawGoal = false;
      var sawAssist = false;
      for (var i = 0; i < 60; i++) {
        final after = CupEngine.extraTime(base, a, b, random: rng);
        final goals = CupEngine.extraTimeGoals(base, after);
        expect(goals.length, after.homeGoals + after.awayGoals - 2,
            reason: '延長で足した得点');
        if (goals.isEmpty) continue;
        sawGoal = true;
        final before = {
          for (final p in [...a.players, ...b.players]) p.id: p.careerGoals,
        };
        CupEngine.creditExtraTimeGoals(base, after, [a, b]);
        for (final e in goals) {
          final team = e.teamId == 'a' ? a : b;
          final lineup = MatchEngine.lineupOf(team).map((p) => p.id).toSet();
          expect(lineup, contains(e.scorerId));
          expect(e.minute, inInclusiveRange(91, 120));
          if (e.assistId != null) {
            sawAssist = true;
            expect(e.assistId, isNot(e.scorerId));
            expect(lineup, contains(e.assistId));
          }
        }
        var added = 0;
        for (final p in [...a.players, ...b.players]) {
          added += p.careerGoals - before[p.id]!;
        }
        expect(added, goals.length, reason: '延長の得点の数だけ通算得点が増える');
      }
      expect(sawGoal, isTrue);
      expect(sawAssist, isTrue);
    });

    test('大陸大会の自動の試合は、延長の得点を含めた結果を返す(呼び出し側が成績に数える)', () {
      final a =
          PlayerGenerator.generateSquad(id: 'a', name: 'a', strengthTier: 70);
      final b =
          PlayerGenerator.generateSquad(id: 'b', name: 'b', strengthTier: 70);
      var sawExtraTime = false;
      for (var i = 0; i < 40 && !sawExtraTime; i++) {
        final cup = ContinentalCupEngine.create(name: 'x', teamIds: ['a', 'b']);
        final tie =
            CupTie(round: 1, teamAId: 'a', teamBId: 'b', singleLeg: true);
        cup.knockoutRounds.add([tie]);
        final r = ContinentalCupEngine.playNextKnockoutLeg(cup, [a, b]);
        expect(r, same(tie.legs.last));
        if (tie.extraTime) sawExtraTime = true;
      }
      expect(sawExtraTime, isTrue, reason: '40試合のうち1つは延長になる');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('ライブ観戦の延長の得点が、両クラブの選手の通算得点に入る', () async {
      final gs = GameState();
      await gs.startNewGame('延長FC');
      final s = gs.save!;
      final u = s.userTeamId;
      final opp = s.league.teams.firstWhere((t) => t.id != u);
      int goalsOf(Team t) =>
          t.players.fold<int>(0, (a, p) => a + p.careerGoals);
      var sawExtraTimeGoal = false;
      for (var i = 0; i < 40 && !sawExtraTimeGoal; i++) {
        // 自クラブと相手だけの国内カップに差し替える(すぐ戦える)。
        s.cups.removeWhere((c) => c.type == CupType.domestic);
        s.cups.add(CupEngine.createTiered(
          type: CupType.domestic,
          name: 'cup',
          byTier: {
            3: [u, opp.id]
          },
          focusTeamId: u,
        ));
        expect(gs.canPlayNextDomesticCupMatchLive, isTrue);
        final before = goalsOf(gs.userTeam) + goalsOf(opp);
        expect(await gs.startCupMatchLive(LiveCupKind.domestic), isTrue);
        while (gs.pendingChanceDecision != null) {
          await gs.resolveChanceDecision(ChanceDecision.shoot);
        }
        MatchResult? merged = await gs.playSecondHalf(interactive: true);
        while (merged == null && gs.pendingChanceDecision != null) {
          merged =
              (await gs.resolveChanceDecision(ChanceDecision.shoot)).merged;
        }
        final ids = {
          for (final p in [...gs.userTeam.players, ...opp.players]) p.id,
        };
        final goals = merged!.events
            .where((e) =>
                e.type == MatchEventType.goal && ids.contains(e.scorerId))
            .toList();
        final after = goalsOf(gs.userTeam) + goalsOf(opp);
        expect(after - before, goals.length,
            reason: '延長の得点も含めて、得点の数だけ通算得点が増える');
        if (goals.any((e) => e.minute > 90)) sawExtraTimeGoal = true;
      }
      expect(sawExtraTimeGoal, isTrue, reason: '40試合のうち1つは延長で点が入る');
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}
