import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_instruction.dart';

/// 選手ごとの個別指示。
///
/// 一律の強化にしないことが要点。全員に付ければ強くなる作りだと、
/// 「付けるか付けないか」の作業になって選ぶ意味が無い。攻守の引き換えか、
/// その選手に向いているかどうかで、得にも損にもなるようにしてある。
void main() {
  Player make({
    int longShots = 50,
    int dribbling = 50,
    int crossing = 50,
  }) {
    final p = Player(
      id: 'p',
      name: 'p',
      age: 26,
      position: Position.amr,
      potential: 80,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.setAttributeValue(AttributeKeys.longShots, longShots);
    p.setAttributeValue(AttributeKeys.dribbling, dribbling);
    p.setAttributeValue(AttributeKeys.crossing, crossing);
    return p;
  }

  double attack(Player p) => MatchEngine.instructionAttackMultiplier(p);
  double defense(Player p) => MatchEngine.instructionDefenseMultiplier(p);

  test('指示なしなら何も変わらない', () {
    final p = make();
    expect(attack(p), 1.0);
    expect(defense(p), 1.0);
  });

  group('攻守の引き換えになる指示', () {
    test('持ち上がれ: 攻撃が上がり、守備が下がる', () {
      final p = make()..instruction = PlayerInstruction.getForward;
      expect(attack(p), greaterThan(1.0));
      expect(defense(p), lessThan(1.0));
    });

    test('守備に残れ: 守備が上がり、攻撃が下がる', () {
      final p = make()..instruction = PlayerInstruction.stayBack;
      expect(defense(p), greaterThan(1.0));
      expect(attack(p), lessThan(1.0));
    });

    test('引き換えの量は同じ(どちらかが一方的に得にならない)', () {
      final forward = make()..instruction = PlayerInstruction.getForward;
      final back = make()..instruction = PlayerInstruction.stayBack;
      expect(attack(forward) - 1.0, closeTo(1.0 - attack(back), 0.001));
      expect(defense(back) - 1.0, closeTo(1.0 - defense(forward), 0.001));
    });
  });

  group('向き不向きで決まる指示', () {
    test('シュートを狙え: ミドルが上手ければ得、下手なら損', () {
      final good = make(longShots: 90)
        ..instruction = PlayerInstruction.shootOnSight;
      final poor = make(longShots: 20)
        ..instruction = PlayerInstruction.shootOnSight;

      expect(attack(good), greaterThan(1.0), reason: '上手い選手には得のはず');
      expect(attack(poor), lessThan(1.0), reason: '下手な選手には損のはず');
    });

    test('内側へ切れ込め: ドリブラーなら得、クロスが持ち味なら損', () {
      final dribbler = make(dribbling: 90, crossing: 40)
        ..instruction = PlayerInstruction.cutInside;
      final crosser = make(dribbling: 40, crossing: 90)
        ..instruction = PlayerInstruction.cutInside;

      expect(attack(dribbler), greaterThan(1.0));
      expect(attack(crosser), lessThan(1.0));
    });

    test('向き不向きの指示は守備に影響しない', () {
      for (final ins in [
        PlayerInstruction.shootOnSight,
        PlayerInstruction.cutInside,
      ]) {
        final p = make()..instruction = ins;
        expect(defense(p), 1.0, reason: '${ins.name} が守備を動かしている');
      }
    });
  });

  test('平均的な選手には、向き不向きの指示は効きも損もしない', () {
    // 能力50(平均)ちょうどなら増減なし。ここがずれていると、指示を付ける
    // だけで得をする形になり、全員に付けるのが最適になってしまう。
    for (final ins in [
      PlayerInstruction.shootOnSight,
      PlayerInstruction.cutInside,
    ]) {
      final p = make()..instruction = ins;
      expect(attack(p), closeTo(1.0, 0.0001), reason: ins.name);
    }
  });

  test('保存され、読み直しても残る', () {
    final p = make()..instruction = PlayerInstruction.cutInside;
    final restored = Player.fromJson(p.toJson());
    expect(restored.instruction, PlayerInstruction.cutInside);
  });

  test('指示を持たない旧セーブは「指示なし」として読む', () {
    final json = make().toJson();
    json.remove('instruction');
    expect(Player.fromJson(json).instruction, isNull);
  });
}
