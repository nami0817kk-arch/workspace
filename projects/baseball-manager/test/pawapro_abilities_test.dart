import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('打者の能力はパワプロと同じ7つ(選球眼はない)', () {
    expect(batterAbilities, [
      Ability.contact,
      Ability.power,
      Ability.trajectory,
      Ability.speed,
      Ability.arm,
      Ability.fielding,
      Ability.catching,
    ]);
    expect(Ability.parse('eye'), isNull);
    expect(pitcherAbilities.length, 3);
    // 二刀流は打者7＋投手3
    expect(abilitiesOf(Role.twoWay).length, 10);
  });

  test('経験点の種類: 弾道は打撃、肩力・捕球は守備走塁', () {
    expect(categoryOf(Ability.trajectory), Category.batting);
    expect(categoryOf(Ability.arm), Category.running);
    expect(categoryOf(Ability.catching), Category.running);
  });

  test('能力が5つだった頃のセーブは、足りない能力を補って読める(選球眼は捨てる)', () {
    final p = Player.fromJson({
      'name': 'x',
      'role': 'batter',
      'age': 20,
      'potential': 60,
      'abilities': {
        'contact': 60,
        'power': 40,
        'speed': 50,
        'fielding': 70,
        'eye': 55,
      },
    });
    expect(p.of(Ability.contact), 60);
    expect(p.of(Ability.trajectory), 50); // ミートとパワーの平均
    expect(p.of(Ability.arm), 70);
    expect(p.of(Ability.catching), 70);
    expect(p.abilities.length, 7);
  });

  test('投手のセーブには打者の能力を足さない', () {
    final p = Player.fromJson({
      'name': 'x',
      'role': 'pitcher',
      'abilities': {'stuff': 60, 'control': 50, 'stamina': 40},
    });
    expect(p.abilities.length, 3);
  });

  test('弾道は長打に、捕球は守備力に効く', () {
    Player bat(int trajectory, int catching) => Player(
          name: 't',
          role: Role.batter,
          age: 20,
          potential: 50,
          abilities: {
            for (final a in batterAbilities) a: 50,
            Ability.trajectory: trajectory,
            Ability.catching: catching,
          },
        );
    expect(bat(90, 50).toBatter().power, greaterThan(bat(10, 50).toBatter().power));
    expect(bat(50, 90).defense, greaterThan(bat(50, 10).defense));
    expect(bat(50, 50).defense, 50);
  });
}
