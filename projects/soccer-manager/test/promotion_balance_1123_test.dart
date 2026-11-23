// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/academy_engine.dart';
import 'package:soccer_manager/logic/division_strength.dart';
import 'package:soccer_manager/logic/offscreen_development.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 3部から抜け出しやすくする作り直し(2026-11-23)。
///
/// 自クラブのいる部の CPU だけが若手の倍率で膨らみ、上手に経営しても
/// 3部の上位が季ごとに強くなって抜け出せなかった。CPU の練習を自クラブの
/// 標準にそろえ、アカデミーの子とスカウト網を戦力に届くようにした。
/// 長い測定は tool/balance/promotion_balance_test.dart(CI では回さない)。
void main() {
  double avg(Team t) =>
      t.players.map((p) => p.overall).reduce((a, b) => a + b) /
      t.players.length;

  group('1 CPU の練習は自クラブの標準と同じ', () {
    test('部の倍率は 3部 1.0・2部 1.15・1部 1.3、不明は 1.0', () {
      expect(TrainingEngine.cpuStandardGrowthMultiplier(3), 1.0);
      expect(TrainingEngine.cpuStandardGrowthMultiplier(2), 1.15);
      expect(TrainingEngine.cpuStandardGrowthMultiplier(1), 1.3);
      expect(TrainingEngine.cpuStandardGrowthMultiplier(null), 1.0);
    });

    test('自クラブ Lv1 の全体練習と CPU の3部の1季の伸びの差は1割以内、1部は1.1〜1.4倍', () {
      var user = 0.0, cpu3 = 0.0, cpu1 = 0.0;
      const n = 12;
      for (var i = 0; i < n; i++) {
        Team mk(String id) {
          final t =
              PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 72);
          for (final p in t.players) {
            p.age = 21 + i % 6;
            p.matchSharpness = 85;
          }
          return t;
        }

        final a = mk('u$i'), b = mk('c$i'), c = mk('d$i');
        final a0 = avg(a), b0 = avg(b), c0 = avg(c);
        for (var w = 0; w < 40; w++) {
          for (final p in a.players) {
            p.fatigue = 20;
            p.matchSharpness = 85;
            p.injuryWeeks = 0;
          }
          TrainingEngine.applyWeeklyTraining(a);
          TrainingEngine.applyPassiveCpuGrowth(b, tier: 3);
          TrainingEngine.applyPassiveCpuGrowth(c, tier: 1);
        }
        user += avg(a) - a0;
        cpu3 += avg(b) - b0;
        cpu1 += avg(c) - c0;
      }
      expect(user, greaterThan(0));
      expect((cpu3 - user).abs() / user, lessThan(0.1),
          reason: '自クラブ ${user / n} と CPU 3部 ${cpu3 / n}');
      expect(cpu1 / cpu3, inInclusiveRange(1.1, 1.4),
          reason: '1部 ${cpu1 / n} と 3部 ${cpu3 / n}');
    });

    test('画面外の若手の1年の伸びは、CPU の1年の練習と ±0.8 以内', () {
      final rng = Random(7);
      for (final age in [17, 20, 23]) {
        var on = 0.0, off = 0.0;
        const n = 150;
        for (var i = 0; i < n; i++) {
          final pos = Position.values[i % Position.values.length];
          final p = PlayerGenerator.generate(
              position: pos, strengthTier: 72, ageOverride: age)
            ..matchSharpness = 85;
          final q = PlayerGenerator.generate(
              position: pos, strengthTier: 72, ageOverride: age);
          final t = Team(id: 't', name: 'T', players: [p]);
          final before = p.overall;
          for (var w = 0; w < 40; w++) {
            TrainingEngine.applyPassiveCpuGrowth(t, tier: 3);
          }
          on += p.overall - before;
          off += OffscreenDevelopment.yearlyChange(q, rng, tier: 3);
        }
        expect((on - off).abs() / n, lessThan(0.8),
            reason: '$age歳: 画面の中 ${on / n} / 外 ${off / n}');
      }
    });

    test('CPU には練習の疲れを付けない', () {
      final t =
          PlayerGenerator.generateSquad(id: 'f', name: 'F', strengthTier: 70);
      for (final p in t.players) {
        p.fatigue = 10;
      }
      for (var w = 0; w < 10; w++) {
        TrainingEngine.applyPassiveCpuGrowth(t, tier: 3);
      }
      for (final p in t.players) {
        expect(p.fatigue, 10, reason: p.name);
      }
    });
  });

  group('2 アカデミーの子', () {
    test('ユース施設 Lv5 の子は Lv1 より総合力がはっきり伸びる', () {
      double gain(int level) {
        var sum = 0.0;
        const n = 60;
        for (var i = 0; i < n; i++) {
          final p = PlayerGenerator.generate(
              position: Position.values[i % Position.values.length],
              strengthTier: 75,
              ageOverride: 17)
            ..matchSharpness = 85;
          final before = p.overall;
          for (var w = 0; w < 40; w++) {
            TrainingEngine.applyYouthAcademyGrowth([p], level);
          }
          sum += p.overall - before;
        }
        return sum / n;
      }

      final lv1 = gain(1);
      final lv5 = gain(5);
      expect(lv1, greaterThan(1.0), reason: 'Lv1 でも総合力が伸びる($lv1)');
      expect(lv5 - lv1, greaterThan(1.0), reason: 'Lv1 $lv1 / Lv5 $lv5');
    });

    test('等級の質は -2/+2/+6/+10', () {
      expect([
        for (final c in [4, 3, 2, 1]) AcademyEngine.qualityBonus(c)
      ], [
        -2,
        2,
        6,
        10
      ]);
    });

    test('上の部のクラブほど良い子が入る(部の水準へ寄せる)', () {
      expect(ScoutingEngine.academyTierShift(null), 0);
      expect(ScoutingEngine.academyTierShift(3), greaterThan(0));
      expect(ScoutingEngine.academyTierShift(1),
          greaterThan(ScoutingEngine.academyTierShift(3)));
      double meanPotential(int? tier) {
        var s = 0;
        for (var i = 0; i < 300; i++) {
          s += ScoutingEngine.generateAcademyGraduate(tier: tier).potential;
        }
        return s / 300;
      }

      expect(meanPotential(3) - meanPotential(null), greaterThan(2));
      // 3部の子でも、当たりは3部の水準に届く。
      expect(divisionTypicalSquadLevel(3),
          lessThan(70 + 10 + ScoutingEngine.academyTierShift(3)));
    });
  });

  group('3 スカウト網の埋もれた即戦力', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Tr.language = AppLanguage.japanese;
    });
    tearDown(() => Tr.language = AppLanguage.system);

    test('水準3から1人ずつ、上限3人。割引は2〜4割', () {
      expect(ScoutingEngine.hiddenGemCountFor(1), 0);
      expect(ScoutingEngine.hiddenGemCountFor(2), 0);
      expect(ScoutingEngine.hiddenGemCountFor(3), 1);
      expect(ScoutingEngine.hiddenGemCountFor(4), 2);
      expect(ScoutingEngine.hiddenGemCountFor(5), 3);
      expect(ScoutingEngine.hiddenGemCountFor(8), 3);
      expect(ScoutingEngine.hiddenGemDiscount(3), closeTo(0.2, 1e-9));
      expect(ScoutingEngine.hiddenGemDiscount(8), closeTo(0.4, 1e-9));
      for (var lv = 1; lv <= 8; lv++) {
        expect(
            ScoutingEngine.hiddenGemDiscount(lv), inInclusiveRange(0.2, 0.4));
      }
    });

    test('20〜23歳、総合力は狙いの並み、潜在は +5〜+12', () {
      for (var i = 0; i < 200; i++) {
        final p = ScoutingEngine.generateHiddenGem(targetOverall: 72);
        expect(p.age, inInclusiveRange(20, 23));
        expect(p.overall, inInclusiveRange(69, 72), reason: '${p.overall}');
        expect(p.potential - 72, inInclusiveRange(5, 12));
        for (final v in p.attributes.values) {
          expect(v, lessThanOrEqualTo(p.potential));
        }
      }
    });

    test('水準の高いスカウトの候補に所属先のあるプロが混ざり、移籍で一軍に入る', () async {
      final gs = GameState();
      await gs.startNewGame('スカウトFC');
      final s = gs.save!;
      s.infrastructure.staff[StaffRole.scout] = StaffMember(
        id: 'scout-test',
        name: 'テストスカウト',
        age: 45,
        role: StaffRole.scout,
        attributes: {for (final a in StaffAttribute.values) a: 15},
        wage: 10,
      );
      final level = gs.scoutLevel;
      expect(level, greaterThanOrEqualTo(3));
      s.budget = 1 << 30;
      s.wageBudget = 1 << 28;
      expect(await gs.refreshScoutCandidates(), isTrue);
      final pros = [
        for (final p in gs.scoutCandidates)
          if (gs.isScoutedPro(p)) p,
      ];
      expect(pros.length, ScoutingEngine.hiddenGemCountFor(level));
      expect(gs.scoutCandidates.length,
          ScoutingEngine.scoutCandidateCountFor(level));
      final youth = gs.scoutCandidates.where((p) => !gs.isScoutedPro(p));
      for (final p in youth) {
        expect(p.age, lessThan(20));
      }
      final gem = pros.first;
      expect(gs.scoutedProClubs[gem.id], isNotEmpty);
      final fee = gs.scoutedProFeeFor(gem);
      expect(fee, lessThan(gem.marketValue));
      expect(gs.isTransferWindowOpen, isTrue, reason: '新しいゲームは夏の窓から');
      final before = s.budget;
      final prospects = s.youthProspects.length;
      expect(await gs.scoutProspect(gem.id), isTrue,
          reason: gs.lastSigningBlockReason);
      expect(gs.userTeam.players.any((p) => p.id == gem.id), isTrue);
      expect(s.youthProspects.length, prospects, reason: 'ユースには入らない');
      expect(s.budget, lessThanOrEqualTo(before - fee));
      expect(gs.isScoutedPro(gem), isFalse);
    });
  });
}
