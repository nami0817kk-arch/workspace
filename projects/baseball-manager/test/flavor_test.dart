import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Player _bat(String name, Map<Ability, int> a) => Player(
      name: name,
      role: Role.batter,
      age: 17,
      potential: 50,
      abilities: {for (final x in batterAbilities) x: a[x] ?? 40},
    );

void main() {
  test('練習メニューは、能力ごとに違う具体的な名前', () {
    final names = {for (final a in Ability.values) trainingMenu(a)};
    expect(names.length, Ability.values.length);
    for (final n in names) {
      expect(n, isNotEmpty);
      expect(RegExp(r'[a-z]{3,}').hasMatch(n), isFalse);
    }
  });

  test('所属は段階ごとに変わり、同じ名前なら毎回同じ', () {
    expect(affiliationOf(Stage.youth, 'ユウタ'), contains('ジュニアーズ'));
    expect(affiliationOf(Stage.juniorHigh, 'ユウタ'), contains('中学'));
    expect(affiliationOf(Stage.highSchool, 'ユウタ'), contains('高校'));
    expect(affiliationOf(Stage.pro, 'ユウタ', proTeam: '青波ホークス'), '青波ホークス');
    expect(affiliationOf(Stage.highSchool, 'ユウタ'),
        affiliationOf(Stage.highSchool, 'ユウタ'));
  });

  test('投打は4通りのどれか。名前でばらける', () {
    const ok = {'右投右打', '右投左打', '左投左打', '左投右打'};
    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      final h = handednessOf('選手$i');
      expect(ok, contains(h));
      seen.add(h);
    }
    expect(seen.length, greaterThanOrEqualTo(3));
  });

  test('守備位置: 投手は投手。野手は能力の特徴に合う位置', () {
    final pitcher = Player(
        name: 'p',
        role: Role.pitcher,
        age: 17,
        potential: 50,
        abilities: {for (final x in pitcherAbilities) x: 50});
    expect(['先発', '中継ぎ', '抑え'], contains(positionOf(pitcher)));
    final shortstop = _bat('a', {Ability.fielding: 80, Ability.speed: 75});
    expect(positionOf(shortstop), '遊撃手');
    final slugger = _bat('b', {Ability.power: 90, Ability.contact: 70});
    expect(positionOf(slugger), '一塁手');
    final center =
        _bat('c', {Ability.speed: 90, Ability.fielding: 55, Ability.power: 30});
    expect(positionOf(center), '中堅手');
  });

  test('背番号: 少年野球は無し、アマは1〜18、プロの投手は11〜29', () {
    final b = _bat('たろう', {});
    expect(uniformNumberOf(Stage.youth, b), isNull);
    expect(uniformNumberOf(Stage.highSchool, b), inInclusiveRange(2, 18));
    expect(uniformNumberOf(Stage.pro, b), inInclusiveRange(2, 99));
    final p = Player(
        name: 'ぴ',
        role: Role.pitcher,
        age: 20,
        potential: 50,
        abilities: {for (final x in pitcherAbilities) x: 50});
    expect(uniformNumberOf(Stage.pro, p), inInclusiveRange(11, 29));
    expect(uniformNumberOf(Stage.highSchool, p), inInclusiveRange(1, 11));
  });

  test('選手カードの1行', () {
    final b = _bat('たろう', {});
    expect(playerCardLine(Stage.youth, b), isNot(contains('背番号')));
    expect(playerCardLine(Stage.highSchool, b), contains('背番号'));
    expect(playerCardLine(Stage.highSchool, b), contains('投'));
  });
}
