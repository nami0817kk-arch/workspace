import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/staff_member.dart';

/// ユースコーチの「見極め」と「指導」が、別の仕事をしているかの検査。
///
/// 能力の説明は「見極め=実力と伸びしろを見抜く精度」「指導=どれだけ
/// 伸ばせるか」と書いてある。しかし実際は役職の総合力(見極めと指導の
/// 平均)だけを見ていたため、指導しか無いコーチでも見立てが鋭くなり、
/// 見極めしか無いコーチでも同じだけ育った。どちらを雇っても同じなら、
/// スタッフを選ぶ意味が無い。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  StaffMember youthCoach({required int coaching, required int judging}) =>
      StaffMember(
        id: 'yc',
        name: 'テストコーチ',
        age: 45,
        role: StaffRole.youthCoach,
        attributes: {
          StaffAttribute.coaching: coaching,
          StaffAttribute.judging: judging,
          StaffAttribute.medical: 10,
          StaffAttribute.motivating: 10,
        },
        wage: 50,
      );

  ClubInfrastructure withCoach(StaffMember coach) =>
      ClubInfrastructure(staff: {
        for (final r in StaffRole.values) r: r == StaffRole.youthCoach ? coach : null,
      });

  group('能力1つぶんのレベル', () {
    test('1〜20 が 1〜8 に収まる', () {
      expect(youthCoach(coaching: 1, judging: 1).levelOf(StaffAttribute.coaching), 1);
      expect(youthCoach(coaching: 20, judging: 1).levelOf(StaffAttribute.coaching),
          ClubInfrastructure.maxLevel);
    });

    test('役職の総合力とは別物(混ざらない)', () {
      final sharpEye = youthCoach(coaching: 1, judging: 20);
      final greatTeacher = youthCoach(coaching: 20, judging: 1);

      // 総合力は同じ。ここで判断していたので、両者の区別が付かなかった。
      expect(sharpEye.effectiveLevel, greatTeacher.effectiveLevel);

      expect(sharpEye.levelOf(StaffAttribute.judging),
          greaterThan(greatTeacher.levelOf(StaffAttribute.judging)));
      expect(greatTeacher.levelOf(StaffAttribute.coaching),
          greaterThan(sharpEye.levelOf(StaffAttribute.coaching)));
    });

    test('空席なら最低の1', () {
      final empty = ClubInfrastructure();
      expect(
          empty.staffAttributeLevel(StaffRole.youthCoach, StaffAttribute.judging),
          1);
    });
  });

  group('見極めは見立ての精度に効く', () {
    int width(int judgingLevel) {
      final p = PlayerGenerator.generate(
          position: Position.st, ageOverride: 16, strengthTier: 40)
        ..potential = 80;
      final r = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: judgingLevel);
      return r.$2 - r.$1;
    }

    test('見極めが高いほど推定の幅が狭い', () {
      final sharp = withCoach(youthCoach(coaching: 1, judging: 20));
      final dull = withCoach(youthCoach(coaching: 1, judging: 1));

      final sharpWidth = width(sharp.staffAttributeLevel(
          StaffRole.youthCoach, StaffAttribute.judging));
      final dullWidth = width(
          dull.staffAttributeLevel(StaffRole.youthCoach, StaffAttribute.judging));

      expect(sharpWidth, lessThan(dullWidth));
    });

    test('指導だけが高くても、見立ては鋭くならない', () {
      // ここが以前の食い違い。総合力で判定していたため、指導20/見極め1の
      // コーチでも見極め20と同じ幅になっていた。
      final teacher = withCoach(youthCoach(coaching: 20, judging: 1));
      final none = ClubInfrastructure();

      expect(
          width(teacher.staffAttributeLevel(
              StaffRole.youthCoach, StaffAttribute.judging)),
          width(none.staffAttributeLevel(
              StaffRole.youthCoach, StaffAttribute.judging)),
          reason: '指導の高さで見立てが鋭くなっている');
    });
  });

  group('指導は育成の伸びに効く', () {
    int total(Player p) => p.attributes.values.fold<int>(0, (s, v) => s + v);

    /// 1シーズン(38週)育てたときの能力値合計の伸び。乱数なので複数回の平均。
    double grownOverSeason(int coachLevel) {
      var sum = 0;
      const trials = 30;
      for (var t = 0; t < trials; t++) {
        final p = PlayerGenerator.generate(
            position: Position.st, ageOverride: 16, strengthTier: 40)
          ..potential = 95;
        final start = total(p);
        for (var w = 0; w < 38; w++) {
          TrainingEngine.applyYouthAcademyGrowth([p], 3, coachLevel: coachLevel);
        }
        sum += total(p) - start;
      }
      return sum / trials;
    }

    test('指導が高いほど速く伸びる', () {
      // 実測(施設3・1シーズン): 指導1で約73、指導8で約140。施設1→8の
      // 46→130より効き幅は小さい。施設が主、コーチが従の関係を保つ。
      expect(grownOverSeason(8), greaterThan(grownOverSeason(1) * 1.3),
          reason: '指導を上げても伸びが変わらない');
    });

    test('伸びるのは「手が回る項目が増える」形', () {
      // 倍率を上げるだけでは効かない(1週1項目につき最大+1で飽和する)。
      // 指導のレベルぶんだけ、追加で伸ばす項目が増えることを直接見る。
      final p = PlayerGenerator.generate(
          position: Position.st, ageOverride: 16, strengthTier: 40);
      expect(TrainingEngine.coachTeachingKeys(1, p), isEmpty);
      expect(TrainingEngine.coachTeachingKeys(8, p).length,
          greaterThan(TrainingEngine.coachTeachingKeys(3, p).length));
    });
  });
}
