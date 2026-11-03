import 'package:baseball_manager/game/characters.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/ui/labels.dart';
import 'package:baseball_manager/ui/player_screen.dart';
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
    expect(pitcherAbilities, [
      Ability.stuff,
      Ability.control,
      Ability.stamina,
      Ability.breaking,
    ]);
    // 投手も打撃・守備の能力を持つ(投球が先)。二刀流は打者7＋投手4
    expect(abilitiesOf(Role.pitcher).length, 11);
    expect(abilitiesOf(Role.pitcher).first, Ability.stuff);
    expect(mainAbilitiesOf(Role.pitcher), pitcherAbilities);
    expect(abilitiesOf(Role.twoWay).length, 11);
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

  test('投球だけだった頃の投手のセーブは、変化球と打撃・守備を補って読む', () {
    final p = Player.fromJson({
      'name': 'x',
      'role': 'pitcher',
      'abilities': {'stuff': 60, 'control': 50, 'stamina': 40},
    });
    expect(p.abilities.length, 11);
    expect(p.of(Ability.breaking), 55); // 球威と制球の平均
    expect(p.of(Ability.contact), 20);
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

  test('投手の生まれの知らせは、投球の能力の天賦だけを言う(打撃・守備の不得手は言わない)', () {
    final p = Player(
        name: 't',
        role: Role.pitcher,
        age: 6,
        potential: 50,
        gifts: {Ability.stuff: 2, Ability.catching: -2});
    final notes = birthTalentNotes(p).join('/');
    expect(notes, contains('球速'));
    expect(notes, isNot(contains('捕球')));
  });

  test('能力が5つだった頃に引退した殿堂の選手も、弾道・肩力・捕球を補って読む(0にならない)', () {
    final s = PlayerSnapshot.fromJson({
      'name': 'むかし',
      'role': 'batter',
      'abilities': {
        'contact': 80,
        'power': 60,
        'speed': 50,
        'fielding': 70,
        'eye': 65,
      },
    });
    expect(s.of(Ability.trajectory), 70);
    expect(s.of(Ability.arm), 70);
    expect(s.of(Ability.catching), 70);
    final p = PlayerSnapshot.fromJson({
      'role': 'pitcher',
      'abilities': {'stuff': 80, 'control': 60, 'stamina': 70},
    });
    expect(p.of(Ability.breaking), 70);
  });

  test('選球眼が得意だった仲間は、ミートが得意として読む', () {
    final m = Character.fromJson(
        {'id': 'm', 'name': '仲間', 'kind': 'teammate', 'specialty': 'eye'});
    expect(m.specialty, Ability.contact);
    final n = Character.fromJson(
        {'id': 'n', 'name': '仲間', 'kind': 'teammate', 'specialty': 'speed'});
    expect(n.specialty, Ability.speed);
  });

  test('コピーする選手カードに、本業の能力がランクと数字で入る', () {
    final s = PlayerSnapshot.fromJson({
      'name': 'カード',
      'role': 'pitcher',
      'age': 25,
      'abilities': {
        'stuff': 75,
        'control': 62,
        'stamina': 55,
        'breaking': 48,
        'contact': 30,
      },
    });
    final t = profileCardText(s);
    expect(t, contains('能力: 球速B75・コントロールC62・スタミナD55・変化球E48'));
    expect(t, isNot(contains('ミート'))); // 投手の打撃は入れない
  });
}
