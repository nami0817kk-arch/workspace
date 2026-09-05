import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/opposition_plan.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

/// 対戦相手への対策指示。
///
/// スカウティングレポートは相手の弱点を教えてくれるのに、読むだけで手が
/// 打てなかった。読んだ内容を試合へ持ち込めるようにしたぶん、
/// 「どれかが常に得」にならないことを確かめる。
void main() {
  Player make(Position position, {int defense = 50}) {
    final p = Player(
      id: '${position.name}$defense${identityHashCode(position)}',
      name: position.name,
      age: 26,
      position: position,
      potential: 80,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    // 守備力は tackling / marking / positioning などの加重平均。
    for (final k in [
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.anticipation,
    ]) {
      p.setAttributeValue(k, defense);
    }
    return p;
  }

  /// 左右の守備力を指定した相手の11人。
  List<Player> opponent({int rightDefense = 50, int leftDefense = 50}) => [
        make(Position.gk),
        make(Position.dr, defense: rightDefense),
        make(Position.dc),
        make(Position.dc),
        make(Position.dl, defense: leftDefense),
        make(Position.mr),
        make(Position.mc),
        make(Position.mc),
        make(Position.ml),
        make(Position.st),
        make(Position.st),
      ];

  Team teamWith(OppositionPlan plan) => Team(
        id: 't',
        name: 'T',
        players: const [],
        oppositionPlan: plan,
      );

  group('弱いサイドを突く', () {
    test('相手のサイドが手薄なほど効き目が大きい', () {
      final vsWeak = MatchEngine.planAttackFactor(
        teamWith(OppositionPlan.targetWeakFlank),
        opponent(leftDefense: 20),
      );
      final vsSolid = MatchEngine.planAttackFactor(
        teamWith(OppositionPlan.targetWeakFlank),
        opponent(leftDefense: 50),
      );

      expect(vsWeak, greaterThan(vsSolid));
      expect(vsWeak, greaterThan(1.0));
    });

    test('相手に手薄なサイドが無ければ、ほとんど得をしない(空振りする)', () {
      final factor = MatchEngine.planAttackFactor(
        teamWith(OppositionPlan.targetWeakFlank),
        opponent(rightDefense: 75, leftDefense: 75),
      );
      expect(factor, lessThanOrEqualTo(1.0),
          reason: '弱点が無いのに突いて得をするなら、相手を見る意味が無い');
    });

    test('効き目には上限がある', () {
      final factor = MatchEngine.planAttackFactor(
        teamWith(OppositionPlan.targetWeakFlank),
        opponent(leftDefense: 1),
      );
      expect(factor, lessThanOrEqualTo(1.08));
    });
  });

  group('引き換えがある', () {
    test('司令塔を潰すと相手の攻撃は鈍るが、こちらの攻撃も落ちる', () {
      const plan = OppositionPlan.pressPlaymaker;
      expect(plan.opponentAttackFactor, lessThan(1.0));
      expect(plan.ownAttackFactor, lessThan(1.0));
    });

    test('中央を固めると守備は上がるが、攻撃は落ちる', () {
      const plan = OppositionPlan.stayCompact;
      expect(plan.ownDefenseFactor, greaterThan(1.0));
      expect(plan.ownAttackFactor, lessThan(1.0));
    });

    test('弱いサイドを突くと、そのぶん守備が薄くなる', () {
      expect(OppositionPlan.targetWeakFlank.ownDefenseFactor, lessThan(1.0));
    });

    test('どの対策にも、必ず何らかの代償がある', () {
      // 代償の無い対策があると、それを選び続けるのが最適になり、
      // 相手を見る意味が消える。
      for (final plan in OppositionPlan.values) {
        if (plan == OppositionPlan.none) continue;
        final hasCost = plan.ownAttackFactor < 1.0 ||
            plan.ownDefenseFactor < 1.0;
        expect(hasCost, isTrue, reason: '${plan.name} に代償が無い');
      }
    });
  });

  test('対策なしなら、どこにも影響しない', () {
    const plan = OppositionPlan.none;
    expect(plan.ownAttackFactor, 1.0);
    expect(plan.ownDefenseFactor, 1.0);
    expect(plan.opponentAttackFactor, 1.0);
    expect(
      MatchEngine.planAttackFactor(teamWith(plan), opponent(leftDefense: 10)),
      1.0,
      reason: '対策を選んでいないのに、相手の弱点で勝手に強くなってはいけない',
    );
  });

  test('旧セーブは「対策なし」として読む(従来と挙動が変わらない)', () {
    final json = Team(id: 't', name: 'T', players: const []).toJson();
    json.remove('oppositionPlan');
    expect(Team.fromJson(json).oppositionPlan, OppositionPlan.none);
  });
}
