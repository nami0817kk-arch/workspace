import 'dart:math';

import '../data/name_pool.dart';
import '../models/club_infrastructure.dart';
import '../models/staff_member.dart';

/// 雇えるスタッフの候補を作る。
///
/// 候補はシーズンごとに入れ替わる。良いスタッフはクラブの規模を見て断るので
/// (StaffMember.willJoin)、下部リーグでは粒の揃わない顔ぶれになる。
class StaffMarket {
  static final Random _rng = Random();

  /// 1役職あたりの候補数。多すぎると選ぶのが作業になるので絞る。
  static const int candidatesPerRole = 3;

  /// 役職に効く能力に乗せるばらつきの幅。「見極め16・指導9のスカウト」の
  /// ような偏りを出して、比べる意味を作る。
  static const double _spread = 2;

  /// [tier]のクラブに来る候補を、全役職ぶん作る。
  static List<StaffMember> generate({
    required int divisionTier,
    required int confidence,
    required int seed,
    Set<String> avoidNames = const {},
  }) {
    final out = <StaffMember>[];
    final used = {...avoidNames};
    for (final role in StaffRole.values) {
      for (int i = 0; i < candidatesPerRole; i++) {
        final s = _generateOne(
          role: role,
          divisionTier: divisionTier,
          confidence: confidence,
          id: 'staff-$seed-${role.name}-$i',
          avoid: used,
        );
        used.add(s.name);
        out.add(s);
      }
    }
    return out;
  }

  static StaffMember _generateOne({
    required StaffRole role,
    required int divisionTier,
    required int confidence,
    required String id,
    required Set<String> avoid,
  }) {
    // そのクラブに来てくれる上限を求め、その範囲で振る。上限ぎりぎりの
    // 人材が毎回出ると選ぶ意味が薄れるので、下にも散らす。
    var ceiling = 6.0;
    for (double a = 20; a >= 4; a -= 0.5) {
      if (StaffMember.willJoin(
        roleAbility: a,
        divisionTier: divisionTier,
        confidence: confidence,
      )) {
        ceiling = a;
        break;
      }
    }
    // 能力にばらつき(±2)を付けるので、その分だけ天井を下げて狙う。
    // 下げないと、来ないはずの水準の人物が候補に出てしまう。
    final aimHigh = max(3.0, ceiling - _spread);
    final floor = max(3.0, aimHigh - 5);
    final target = floor + _rng.nextDouble() * (aimHigh - floor);

    // 役職に効く能力を target 付近に、効かない能力は自由に振る。
    // 「見極めは高いが指導は並」といった偏りが出て、配置の判断が生まれる。
    final weights = staffRoleWeights(role);
    final attrs = <StaffAttribute, int>{};
    for (final a in StaffAttribute.values) {
      if (weights.containsKey(a)) {
        final spread = _rng.nextDouble() * (_spread * 2) - _spread;
        attrs[a] = (target + spread).round().clamp(1, 20);
      } else {
        attrs[a] = (3 + _rng.nextInt(15)).clamp(1, 20);
      }
    }

    final tmp = StaffMember(
      id: id,
      name: NamePool.randomPlayerName(avoid: avoid),
      age: 32 + _rng.nextInt(30),
      role: role,
      attributes: attrs,
      wage: 0,
    );
    return StaffMember(
      id: tmp.id,
      name: tmp.name,
      age: tmp.age,
      role: role,
      attributes: attrs,
      wage: StaffMember.askingWage(tmp.roleAbility),
      contractYears: 2 + _rng.nextInt(2),
    );
  }

  /// 既存のセーブにある「スタッフレベル」を、そのレベル相当の人物へ移す。
  ///
  /// レベルだけで持っていたセーブを読み込んだとき、雇っている人がいない
  /// 状態になると、トレーニング効率も負傷率も一斉に最低値へ落ちてしまう。
  /// 同じ働きをする人物を置いて、続きから遊べるようにする。
  static StaffMember fromLegacyLevel(StaffRole role, int level) {
    // effectiveLevel が元のレベルに戻る能力値を逆算する。
    final ability =
        1 + (level - 1) / (ClubInfrastructure.maxLevel - 1) * 19;
    final weights = staffRoleWeights(role);
    final attrs = <StaffAttribute, int>{
      for (final a in StaffAttribute.values)
        a: weights.containsKey(a) ? ability.round().clamp(1, 20) : 8,
    };
    return StaffMember(
      id: 'staff-legacy-${role.name}',
      name: NamePool.randomPlayerName(),
      age: 45,
      role: role,
      attributes: attrs,
      wage: ClubInfrastructure.staffWeeklyWage(level),
      contractYears: 3,
    );
  }
}
