import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/mastery.dart';
import 'package:basketball_career/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('段は累計で決まり、次の段までの量が分かる', () {
    expect(masteryLevel(0), 0);
    expect(masteryLevel(9), 0);
    expect(masteryLevel(10), 1);
    expect(masteryLevel(100), masteryMax);
    expect(masteryProgress(15), (have: 5, need: 15));
    expect(masteryProgress(500), isNull);
  });

  test('練習は第1の重点に、特訓はもっと。休養・交流・怪我ではたまらない', () {
    expect(masteryGain(Action.practice, injured: false), (first: 3, second: 1));
    expect(masteryGain(Action.intense, injured: false).first, greaterThan(3));
    expect(masteryGain(Action.rest, injured: false), (first: 0, second: 0));
    expect(masteryGain(Action.social, injured: false), (first: 0, second: 0));
    expect(masteryGain(Action.practice, injured: true), (first: 0, second: 0));
  });

  test('大人(伸びが小さい年)でも、練習を重ねると段が上がり、能力とポイントが増える。保存で残る', () {
    final g = Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: 31, potential: 60, heightCm: 190, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 60}),
      rng: Random(3),
      slot: 0,
      track: Track.pro,
      mastery: {Ability.threePoint: 20}, // 基礎(Lv1)の途中から
    );
    final ups = <(Ability, int)>[];
    final sp0 = g.sp;
    var guard = 0;
    while (g.masteryOf(Ability.threePoint) < 3 && guard++ < 40) {
      expect(g.phase, Phase.season, reason: 'guard $guard');
      if (g.slot == 1 || g.slot == 3) {
        g.choose(Action.rest, Ability.threePoint); // 大会の季節は避ける(試合の結果に左右されない)
        continue;
      }
      g.choose(Action.practice, Ability.threePoint);
      ups.addAll(g.lastMasteryUps);
    }
    expect(g.masteryOf(Ability.threePoint), 3);
    expect(ups.map((u) => u.$2), [2, 3]);
    expect(g.sp, greaterThanOrEqualTo(sp0 + 1), reason: '武器(Lv3)でポイント +1');
    final back = Game.fromJson(g.toJson());
    expect(back.mastery[Ability.threePoint], g.mastery[Ability.threePoint]);
    // 古いセーブ・壊れた値でも落ちない。
    final old = Game.fromJson(g.toJson()..remove('mastery'));
    expect(old.masteryOf(Ability.threePoint), 0);
    final bad = Game.fromJson(g.toJson()..['mastery'] = 'こわれた');
    expect(bad.mastery, isEmpty);
  });

  test('ごほうびの能力は上限99を超えない', () {
    final g = Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: 31, potential: 60, heightCm: 190, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: abilityCap}),
      rng: Random(1),
      slot: 0,
      mastery: {Ability.pass: 99},
    );
    g.choose(Action.practice, Ability.pass);
    expect(g.lastMasteryUps, [(Ability.pass, masteryMax)]);
    expect(g.player.of(Ability.pass), lessThanOrEqualTo(abilityCap));
  });

  test('ごほうびの一言', () {
    expect(masteryRewardText(Ability.pass, 1), '');
    expect(masteryRewardText(Ability.pass, 2), '  パス +1');
    expect(masteryRewardText(Ability.pass, 3), '  特殊能力ポイント +1');
    expect(masteryRewardText(Ability.pass, 5), '  パス +1・特殊能力ポイント +1');
  });
}
