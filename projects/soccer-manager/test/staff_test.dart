import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/staff_market.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/state/game_state.dart';

/// スタッフを「人」として雇う仕組み。
///
/// 以前は役職ごとのレベル数値で、金を払えば誰でも同じだけ上がった。誰を
/// 雇うかという判断が無く、資金があるかどうかだけの話だった。いまは能力の
/// 偏った人物を選んで雇う形になっている。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  StaffMember make(
    StaffRole role, {
    int coaching = 10,
    int judging = 10,
    int medical = 10,
    int motivating = 10,
    int wage = 50,
  }) =>
      StaffMember(
        id: 'x-${role.name}',
        name: 'テスト',
        age: 45,
        role: role,
        attributes: {
          StaffAttribute.coaching: coaching,
          StaffAttribute.judging: judging,
          StaffAttribute.medical: medical,
          StaffAttribute.motivating: motivating,
        },
        wage: wage,
      );

  group('能力と役職の対応', () {
    test('役職に効かない能力は水準に影響しない', () {
      // フィジオに効くのは医療。指導が最高でも医療が低ければ働かない。
      final good = make(StaffRole.physio, medical: 20, coaching: 1);
      final bad = make(StaffRole.physio, medical: 1, coaching: 20);
      expect(good.effectiveLevel, greaterThan(bad.effectiveLevel));
    });

    test('水準は 1〜8 の範囲に収まる', () {
      for (final role in StaffRole.values) {
        final worst = make(role,
            coaching: 1, judging: 1, medical: 1, motivating: 1);
        final best = make(role,
            coaching: 20, judging: 20, medical: 20, motivating: 20);
        expect(worst.effectiveLevel, 1);
        expect(best.effectiveLevel, ClubInfrastructure.maxLevel);
      }
    });

    test('能力が高いほど週俸の相場も高い', () {
      expect(StaffMember.askingWage(18),
          greaterThan(StaffMember.askingWage(8)));
    });
  });

  group('クラブの規模によって来る人が変わる', () {
    test('下部リーグには最高水準のスタッフは来ない', () {
      expect(
        StaffMember.willJoin(roleAbility: 20, divisionTier: 5, confidence: 50),
        isFalse,
        reason: '5部に能力20は来ないはず',
      );
      expect(
        StaffMember.willJoin(roleAbility: 20, divisionTier: 1, confidence: 90),
        isTrue,
        reason: '1部で信頼も厚ければ来るはず',
      );
    });

    test('候補は全役職ぶん作られ、そのクラブに来る範囲に収まる', () {
      const tier = 4;
      final list = StaffMarket.generate(
          divisionTier: tier, confidence: 50, seed: 1);
      expect(list.length,
          StaffRole.values.length * StaffMarket.candidatesPerRole);
      for (final s in list) {
        expect(
          StaffMember.willJoin(
              roleAbility: s.roleAbility, divisionTier: tier, confidence: 50),
          isTrue,
          reason: '来ないはずの人が候補に出ている: ${s.roleAbility}',
        );
      }
    });
  });

  group('雇用と解任', () {
    test('雇うと水準が上がり、解任すると空席に戻る', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      game.save!.wageBudget = 100000;

      expect(game.staffFor(StaffRole.headCoach), isNull,
          reason: '開始時は空席のはず');
      expect(game.save!.infrastructure.staffLevel(StaffRole.headCoach), 1);

      final best = game
          .staffCandidatesFor(StaffRole.headCoach)
          .reduce((a, b) => a.roleAbility >= b.roleAbility ? a : b);
      expect(await game.hireStaff(best.id), isTrue);

      expect(game.staffFor(StaffRole.headCoach)!.id, best.id);
      expect(game.save!.infrastructure.totalStaffWeeklyWage, best.wage,
          reason: '雇った人の週俸が人件費に乗るはず');

      expect(await game.dismissStaff(StaffRole.headCoach), isTrue);
      expect(game.staffFor(StaffRole.headCoach), isNull);
      expect(game.save!.infrastructure.totalStaffWeeklyWage, 0);
    });

    test('雇った候補は候補一覧から消える', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      game.save!.wageBudget = 100000;

      final target = game.staffCandidatesFor(StaffRole.scout).first;
      await game.hireStaff(target.id);

      expect(
        game.staffCandidatesFor(StaffRole.scout).any((s) => s.id == target.id),
        isFalse,
      );
    });
  });

  group('保存と読み込み', () {
    test('雇っているスタッフが保存され、読み直しても水準が変わらない', () async {
      final game = GameState();
      await game.startNewGame('テストFC');
      game.save!.wageBudget = 100000;
      final best = game
          .staffCandidatesFor(StaffRole.physio)
          .reduce((a, b) => a.roleAbility >= b.roleAbility ? a : b);
      await game.hireStaff(best.id);
      final before = game.save!.infrastructure.staffLevel(StaffRole.physio);

      final restored = SaveGame.fromJson(game.save!.toJson());

      expect(restored.infrastructure.staffFor(StaffRole.physio)?.name,
          best.name);
      expect(restored.infrastructure.staffLevel(StaffRole.physio), before);
    });

    test('レベルだけを持つ旧セーブは、同じ働きの人物に置き換わる', () {
      // 旧セーブをそのまま読むと全役職が空席になり、トレーニング効率も
      // 負傷率も一斉に最低へ落ちる。続きから遊べなくなるため移行する。
      final legacy = {
        'staffLevels': {
          for (final r in StaffRole.values) r.name: 5,
        },
        'facilityLevels': const <String, int>{},
      };

      final infra = ClubInfrastructure.fromJson(legacy);

      for (final r in StaffRole.values) {
        expect(infra.staffFor(r), isNotNull, reason: '${r.name} が空席になっている');
        expect(infra.staffLevel(r), 5,
            reason: '${r.name} の働きが旧レベルと変わってしまっている');
      }
    });

    test('レベル1(=未強化)の旧セーブは空席のままにする', () {
      final legacy = {
        'staffLevels': {for (final r in StaffRole.values) r.name: 1},
        'facilityLevels': const <String, int>{},
      };

      final infra = ClubInfrastructure.fromJson(legacy);

      expect(infra.staffFor(StaffRole.headCoach), isNull);
      expect(infra.staffLevel(StaffRole.headCoach), 1);
    });
  });
}
