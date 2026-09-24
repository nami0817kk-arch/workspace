import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/staff_market.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/staff_member.dart';

/// スタッフの「得意分野」の検査。
///
/// 能力値(1-20)は上手さしか表さないため、誰を雇っても育つ能力が同じだった。
/// 得意分野で伸びる先が変わること、担当が違う分野には効かないことを見る。
void main() {
  Player prospect(Position position) => PlayerGenerator.generate(
        position: position,
        ageOverride: 17,
        strengthTier: 45,
      )..potential = 95;

  int sumOf(Player p, List<String> keys) =>
      keys.fold<int>(0, (s, k) => s + p.attributeValue(k));

  test('攻撃が得意なコーチのもとでは、得点に関わる能力が余計に伸びる', () {
    const keys = [
      AttributeKeys.finishing,
      AttributeKeys.offTheBall,
      AttributeKeys.technique,
    ];
    var withCoach = 0;
    var without = 0;
    for (var run = 0; run < 8; run++) {
      final a = prospect(Position.st);
      final b = prospect(Position.st);
      b.attributes.addAll(Map<String, int>.from(a.attributes));
      final before = sumOf(a, keys);

      for (var week = 0; week < 30; week++) {
        TrainingEngine.applyYouthAcademyGrowth([a], 3,
            coachSpecialty: StaffSpecialty.attacking);
        TrainingEngine.applyYouthAcademyGrowth([b], 3);
      }
      withCoach += sumOf(a, keys) - before;
      without += sumOf(b, keys) - before;
    }
    expect(withCoach, greaterThan(without), reason: '得意分野が効いていない');
  });

  test('GK専門のコーチは、フィールドプレーヤーには効かない', () {
    final p = prospect(Position.st);
    expect(
      TrainingEngine.specialtyKeys(StaffSpecialty.goalkeeping, p),
      isEmpty,
      reason: 'GK専門がフィールドプレーヤーに効いている',
    );
    final gk = prospect(Position.gk);
    expect(
      TrainingEngine.specialtyKeys(StaffSpecialty.goalkeeping, gk),
      isNotEmpty,
    );
  });

  test('攻撃・守備はGKには効かないが、フィジカルは全員に効く', () {
    final gk = prospect(Position.gk);
    expect(TrainingEngine.specialtyKeys(StaffSpecialty.attacking, gk), isEmpty);
    expect(TrainingEngine.specialtyKeys(StaffSpecialty.defending, gk), isEmpty);
    expect(
        TrainingEngine.specialtyKeys(StaffSpecialty.physical, gk), isNotEmpty);
  });

  test('万能のコーチは、特定の分野を押し上げない', () {
    final p = prospect(Position.mc);
    expect(TrainingEngine.specialtyKeys(StaffSpecialty.balanced, p), isEmpty);
  });

  test('得意分野はセーブに残り、旧セーブは万能として読む', () {
    final staff = StaffMarket.generate(
      divisionTier: 3,
      confidence: 50,
      seed: 1,
    ).firstWhere((s) => s.role == StaffRole.youthCoach);
    final restored = StaffMember.fromJson(staff.toJson());
    expect(restored.specialty, staff.specialty);

    final legacy = Map<String, dynamic>.from(staff.toJson())
      ..remove('specialty');
    expect(StaffMember.fromJson(legacy).specialty, StaffSpecialty.balanced);
  });

  test('候補には万能も専門も混ざる', () {
    final specialties = <StaffSpecialty>{};
    for (var i = 0; i < 20; i++) {
      for (final s in StaffMarket.generate(
        divisionTier: 3,
        confidence: 50,
        seed: i,
      )) {
        specialties.add(s.specialty);
      }
    }
    expect(specialties, contains(StaffSpecialty.balanced));
    expect(specialties.length, greaterThan(1), reason: '全員が同じ得意分野になっている');
  });
}
