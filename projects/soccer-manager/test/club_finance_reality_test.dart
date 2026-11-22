import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/fan_demand_engine.dart';
import 'package:soccer_manager/logic/relegation_clause.dart';
import 'package:soccer_manager/logic/running_cost_engine.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2026-11-23: 観客の需要・運営費・降格の条項・スポンサーの昇降格の条項・
/// 昇格の補強予算を、実際の欧州サッカーに近づけた。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ファンの需要と観客数', () {
    test('需要の目安は上の部ほど大きく、評判で0.8〜1.2倍', () {
      expect(FanDemandEngine.target(1, 50), 40000);
      expect(FanDemandEngine.target(2, 50), greaterThan(20000));
      expect(FanDemandEngine.target(3, 50),
          lessThan(FanDemandEngine.target(2, 50)));
      expect(FanDemandEngine.target(1, 0), 32000);
      expect(FanDemandEngine.target(1, 100), 48000);
    });

    test('席を増やしても、需要より多くは入らない', () async {
      final gs = GameState();
      await gs.startNewGame('需要FC');
      final s = gs.save!;
      s.fanDemand = 15000;
      s.infrastructure.facilityLevels[FacilityType.stadium] = 1;
      final small = gs.expectedAttendance;
      expect(small, lessThanOrEqualTo(gs.stadiumCapacity));
      s.infrastructure.facilityLevels[FacilityType.stadium] =
          ClubInfrastructure.maxLevel;
      final big = gs.expectedAttendance;
      expect(gs.stadiumCapacity, greaterThan(40000));
      expect(big, lessThanOrEqualTo((15000 * gs.userAttendanceRate).round()));
      expect(big, lessThan(20000));
      // 入場収入も、需要を超えた席のぶんは増えない。
      final gate = gs.weeklyIncomeParts(s.userTeamId).gate;
      s.infrastructure.facilityLevels[FacilityType.stadium] = 3; // 24,000席
      expect(gs.weeklyIncomeParts(s.userTeamId).gate, gate);
    });

    test('需要が収容人数を超えていれば、増築したぶん入る', () async {
      final gs = GameState();
      await gs.startNewGame('需要FC');
      final s = gs.save!;
      s.fanDemand = 60000;
      s.infrastructure.facilityLevels[FacilityType.stadium] = 1;
      final before = gs.expectedAttendance;
      final gateBefore = gs.weeklyIncomeParts(s.userTeamId).gate;
      s.infrastructure.facilityLevels[FacilityType.stadium] = 3;
      expect(gs.expectedAttendance, greaterThan(before));
      expect(gs.weeklyIncomeParts(s.userTeamId).gate, greaterThan(gateBefore));
    });

    test('順位で動く動員率は上下10%まで', () {
      expect(FanDemandEngine.rankSwing(1, 20), closeTo(0.1, 1e-9));
      expect(FanDemandEngine.rankSwing(20, 20), closeTo(-0.1, 1e-9));
      for (var r = 1; r <= 20; r++) {
        expect(FanDemandEngine.rankSwing(r, 20).abs(), lessThanOrEqualTo(0.1));
      }
    });

    test('需要は上位・昇格でゆっくり伸び、降格で減る', () {
      int next(int played, int now, int rank) => FanDemandEngine.nextSeason(
            demand: 20000,
            playedTier: played,
            newTier: now,
            finalRank: rank,
            teamCount: 20,
            reputation: 50,
          );
      // 2部の真ん中の需要(22,000)の近くで、優勝なら伸び、最下位なら減る。
      expect(next(2, 2, 1), greaterThan(next(2, 2, 20)));
      // 昇格すると伸びるが、一気に上の部の目安(4万)にはならない。
      final up = next(2, 1, 1);
      expect(up, greaterThan(next(2, 2, 1)));
      expect(up, lessThan(30000));
      // 降格すると減る。
      expect(next(2, 3, 20), lessThan(next(2, 2, 20)));
      expect(next(2, 3, 20), lessThan(20000));
    });

    test('季末に需要が動く(昇格すれば増える)', () async {
      final gs = GameState();
      await gs.startNewGame('需要FC');
      final s = gs.save!;
      s.fanDemand = 11000;
      gs.debugAdvanceFanDemand(
          playedTier: 3, newTier: 2, finalRank: 1, teamCount: 24);
      expect(s.fanDemand, greaterThan(11000));
    });

    test('需要は保存され、無い旧セーブは部と規模から作る', () async {
      final gs = GameState();
      await gs.startNewGame('需要FC');
      final s = gs.save!;
      expect(s.fanDemand, greaterThan(0), reason: '新しいゲームで作る');
      s.fanDemand = 23456;
      expect(SaveGame.fromJson(s.toJson()).fanDemand, 23456);

      s.infrastructure.facilityLevels[FacilityType.stadium] = 6; // 42,000席
      final json = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>;
      expect(json.remove('fanDemand'), 23456);
      final old = GameState();
      await old.importSaveJson(jsonEncode(json));
      final os = old.save!;
      // 増築していた旧セーブは、席の85%を下回らない(入りが急に減らない)。
      expect(
          os.fanDemand,
          FanDemandEngine.initial(
              tier: os.currentDivisionTier,
              reputation: os.managerReputation,
              capacity: ClubInfrastructure.stadiumCapacity(6)));
      expect(
          os.fanDemand,
          greaterThanOrEqualTo(
              (ClubInfrastructure.stadiumCapacity(6) * 0.85).round()));
    });
  });

  group('運営費', () {
    test('上の部ほど大きく、施設が大きいほど増える', () {
      const base = [1, 1, 1, 1, 1];
      int annual(int tier, [List<int> lv = base]) => RunningCostEngine.annual(
          tier: tier, theme: LeagueTheme.england, facilityLevels: lv);
      expect(annual(1), greaterThan(annual(2)));
      expect(annual(2), greaterThan(annual(3)));
      expect(annual(1, [5, 5, 5, 5, 5]), greaterThan(annual(1)));
      expect(annual(1),
          (typicalAnnualIncome(1) * RunningCostEngine.shareForTier(1)).round());
    });

    test('1部の真ん中のクラブは、人件費率70%で収支がほぼ釣り合う', () {
      for (final t in LeagueTheme.values) {
        final income = typicalAnnualIncome(1, t);
        final cost = RunningCostEngine.annual(
            tier: 1, theme: t, facilityLevels: const [3, 3, 3, 3, 3]);
        final margin = (income - income * 0.7 - cost) / income;
        expect(margin, inInclusiveRange(-0.05, 0.08), reason: t.name);
      }
    });

    test('毎月末に運営費の項目で記帳される', () async {
      final gs = GameState();
      await gs.startNewGame('運営FC');
      final d = gs.today;
      gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 3, 1));
      final l = gs.save!.ledgerFor(gs.save!.league.season);
      expect(-l.of(LedgerCategory.operations), gs.monthlyRunningCost * 3);
    });
  });

  group('降格の条項', () {
    test('年俸の倍率は0.6〜0.75で、イングランドが一番強い', () {
      for (final t in LeagueTheme.values) {
        expect(RelegationClause.wageFactor(t), inInclusiveRange(0.6, 0.75));
        expect(RelegationClause.wageFactor(LeagueTheme.england),
            lessThanOrEqualTo(RelegationClause.wageFactor(t)));
      }
    });

    test('降格したクラブの選手の年俸が下がる(自クラブも CPU も。貸し出しで来ている選手は除く)', () async {
      final gs = GameState();
      await gs.startNewGame('降格FC', theme: LeagueTheme.england);
      final s = gs.save!;
      final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      final mine = gs.userTeam;
      final before = {
        for (final p in [...mine.players, ...cpu.players]) p.id: p.wage
      };
      final loanee = mine.players.first..isLoan = true;
      gs.debugApplyRelegationWageClause([mine, cpu], fromTier: 1);
      final f = RelegationClause.wageFactorFor(LeagueTheme.england,
          fromTier: 1, toTier: 2);
      expect(f, lessThan(1.0));
      for (final p in [...mine.players, ...cpu.players]) {
        if (p.id == loanee.id) {
          expect(p.wage, before[p.id]);
        } else {
          expect(p.wage, max(minWeeklyWage, (before[p.id]! * f).round()),
              reason: p.name);
        }
      }
    });

    // 2026-11-23: 条項の倍率だけで下げると、部の水準が変わって見合う額が
    // 上がり、降格したクラブの全員が「年俸が安い」(見合う額の7割未満)に
    // なっていた。下げるのは新しい部の水準までにする。
    test('降格の条項で下げても、新しい部の見合う額の7割を割らない(全ての国・部)', () {
      for (final theme in LeagueTheme.values) {
        for (final from in [1, 2]) {
          final to = from + 1;
          final oldLevel = wageCountryFactor(theme, from);
          final newLevel = wageCountryFactor(theme, to);
          final f =
              RelegationClause.wageFactorFor(theme, fromTier: from, toTier: to);
          expect(f, lessThanOrEqualTo(1.0));
          expect(f, greaterThanOrEqualTo(RelegationClause.wageFactor(theme)));
          for (final age in [20, 27, 33]) {
            // 降格する前の部で見合う額をもらっていた選手。
            final wage = weeklyWageForAbility(75, age, oldLevel);
            final after = (wage * f).round();
            final fairNew = weeklyWageForAbility(75, age, newLevel);
            expect(after, greaterThanOrEqualTo((fairNew * 0.7).floor()),
                reason: '${theme.name} $from→$to age $age');
          }
        }
      }
    });

    // 2026-11-23: 国・部の水準が下の部ほど高い国(フランス・ドイツなど)では、
    // 降格しても年俸が下がらなかった。水準を部が下がるほど同じか低い形に
    // 直したので、どの国でも降格で下がり、条項の倍率より下がりすぎない。
    test('年俸の水準は、どの国も部が下がるほど同じか低い', () {
      for (final theme in LeagueTheme.values) {
        for (final tier in [1, 2]) {
          expect(wageCountryFactor(theme, tier + 1),
              lessThanOrEqualTo(wageCountryFactor(theme, tier)),
              reason: '${theme.name} $tier部→${tier + 1}部');
        }
        // 同じ選手は、1部より下の部で高くは求めない。
        expect(weeklyWageForAbility(75, 27, wageCountryFactor(theme, 2)),
            lessThanOrEqualTo(
                weeklyWageForAbility(75, 27, wageCountryFactor(theme, 1))),
            reason: theme.name);
      }
    });

    test('降格すると、どの国・部でも年俸が下がる(条項の倍率までで止まる)', () {
      for (final theme in LeagueTheme.values) {
        for (final from in [1, 2]) {
          final f = RelegationClause.wageFactorFor(theme,
              fromTier: from, toTier: from + 1);
          expect(f, lessThan(1.0), reason: '${theme.name} $from部');
          expect(f, greaterThanOrEqualTo(RelegationClause.wageFactor(theme)),
              reason: '${theme.name} $from部');
          // 水準の比のとおりに下がる(条項の倍率より下がるときだけ止める)。
          final ratio = wageCountryFactor(theme, from + 1) /
              wageCountryFactor(theme, from);
          expect(f,
              closeTo(max(RelegationClause.wageFactor(theme), ratio), 1e-9));
        }
      }
      // 1部から3部へ2つ下がるときも同じ形。
      expect(
          RelegationClause.wageFactorFor(LeagueTheme.france,
              fromTier: 1, toTier: 3),
          lessThan(1.0));
    });
  });

  group('スポンサー・命名権の昇格・降格の条項', () {
    test('昇格で上乗せ、降格で減額', () {
      expect(SponsorEngine.divisionChangeFactor(2, 1), closeTo(1.3, 1e-9));
      expect(SponsorEngine.divisionChangeFactor(2, 3), closeTo(0.7, 1e-9));
      expect(SponsorEngine.divisionChangeFactor(2, 2), 1.0);
    });

    test('結んでいる契約の額が動く', () async {
      final gs = GameState();
      await gs.startNewGame('条項FC');
      final s = gs.save!;
      s.sponsorDeal =
          SponsorDeal(name: 'A', weeklyIncome: 1000, yearsRemaining: 2);
      s.namingDeal =
          SponsorDeal(name: 'B', weeklyIncome: 500, yearsRemaining: 5);
      gs.debugApplySponsorDivisionClause(3, 2);
      expect(s.sponsorDeal!.weeklyIncome, 1300);
      expect(s.namingDeal!.weeklyIncome, 650);
      gs.debugApplySponsorDivisionClause(2, 3);
      expect(s.sponsorDeal!.weeklyIncome, 910);
    });
  });

  test('昇格の補強予算は、放映権の増加より小さい手付けだけ', () {
    for (final t in LeagueTheme.values) {
      for (var tier = 1; tier <= 2; tier++) {
        final bonus = BoardEngine.promotionBonusFor(tier, t);
        final tvGain = annualBroadcast(tier, t) - annualBroadcast(tier + 1, t);
        expect(bonus, lessThan(tvGain * 0.15), reason: '${t.name} $tier部');
        expect(bonus, greaterThan(0));
      }
    }
  });
}
