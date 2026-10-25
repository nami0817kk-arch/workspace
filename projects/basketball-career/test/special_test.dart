import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/special.dart';
import 'package:flutter_test/flutter_test.dart';

void _step(Game g) {
  switch (g.phase) {
    case Phase.season:
      g.choose(recommendedAction(g), recommendedFocus(g.player));
    case Phase.halftime:
      g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
    case Phase.clutch:
      g.resolveClutch(Clutch.drive);
    case Phase.event:
      g.resolveEvent(0);
    case Phase.path:
      if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
    case Phase.retired:
      break;
  }
}

Player _p({Set<Special> specials = const {}}) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: 20,
    heightCm: 190,
    abilities: {for (final a in Ability.values) a: 60},
    specials: specials,
  );
}

/// 勝負どころで止まっている試合(プロ・夏の大会)を探す。
Game? _clutchGame(Set<Special> specials) {
  for (var seed = 0; seed < 3000; seed++) {
    final base = Game.start('x', rng: Random(seed), events: false);
    final g = Game(
      eventsEnabled: false,
      player: base.player.copyWith(
        age: 24,
        heightCm: 192,
        abilities: {for (final a in Ability.values) a: 70},
        specials: specials,
      ),
      rng: Random(seed),
      track: Track.pro,
      salary: 2000,
      slot: 1,
    );
    g.choose(Action.rest, Ability.defense, askClutch: true);
    var guard = 0;
    while (g.phase == Phase.halftime && guard++ < 10) {
      g.resolveHalftime(Halftime.keep);
    }
    if (g.phase == Phase.clutch) return g;
  }
  return null;
}

void main() {
  group('習得の条件', () {
    test('ポイントが足りないと習得できず、理由が出る', () {
      expect(canLearn({}, 0, Special.calm), isFalse);
      expect(whyNot({}, 1, Special.calm), contains('あと'));
      expect(canLearn({}, Special.calm.cost, Special.calm), isTrue);
      expect(whyNot({}, Special.calm.cost, Special.calm), isNull);
    });

    test('前提のある能力は、前提を取るまで習得できない', () {
      expect(canLearn({}, 99, Special.clutchMaster), isFalse);
      expect(whyNot({}, 99, Special.zone), contains('冷静沈着'));
      expect(canLearn({Special.calm}, 99, Special.clutchMaster), isTrue);
      expect(canLearn({Special.calm}, 99, Special.zone), isTrue);
    });

    test('習得済みは重ねて習得できない', () {
      expect(canLearn({Special.calm}, 99, Special.calm), isFalse);
      expect(whyNot({Special.calm}, 99, Special.calm), '習得済み');
    });

    test('どの能力も名前から読み戻せ、優先順にすべて入っている', () {
      for (final s in Special.values) {
        expect(Special.parse(s.name), s);
        expect(s.cost, greaterThan(0));
        expect(learnPriority, contains(s));
      }
      expect(Special.parse('zzz'), isNull);
    });
  });

  group('効き方', () {
    test('冷静沈着・クラッチの申し子で勝負どころの成功率が上がる。ゾーンはさらに +12%', () {
      double c(Set<Special> s, {bool zone = false}) =>
          clutchChance(_p(specials: s), Clutch.drive, 60, 1.0, zone: zone);
      expect(c({Special.calm}), greaterThan(c({})));
      expect(c({Special.calm, Special.clutchMaster}), greaterThan(c({Special.calm})));
      expect(c({}, zone: true) - c({}), closeTo(zoneBonus, 1e-9));
    });

    test('鉄壁の守りでファウルが減る(平均)', () {
      double mean(Set<Special> s) {
        final p = _p(specials: s)
            .copyWith(abilities: {for (final a in Ability.values) a: 80});
        var sum = 0;
        for (var i = 0; i < 2000; i++) {
          sum += foulsOf(p, 4, 1.0, Random(i));
        }
        return sum / 2000;
      }

      expect(mean({Special.ironWall}), lessThan(mean({}) * 0.9));
    });

    test('努力の天才で伸びが増え、不屈で疲れの回復が増える', () {
      final young = _p().copyWith(age: 14);
      final youngGifted = _p(specials: {Special.prodigy}).copyWith(age: 14);
      expect(yearlyDelta(youngGifted, Ability.pass, Ability.pass),
          greaterThan(yearlyDelta(young, Ability.pass, Ability.pass)));
      expect(specialRecoveryMultiplier({Special.resilience}), greaterThan(1.0));
      expect(specialRecoveryMultiplier({}), 1.0);
    });

    test('ムードメーカーでチームワークが薄れる量が半分に、0未満にならない', () {
      expect(specialTeamworkDecay({Special.moodMaker}, 2), 1);
      expect(specialTeamworkDecay({Special.moodMaker}, 1), 1);
      expect(specialTeamworkDecay({}, 2), 2);
    });
  });

  group('ゲームの中の特殊能力', () {
    test('年末にポイントがたまる(毎年1以上)', () {
      final g = Game.start('x', rng: Random(3), events: false);
      expect(g.sp, 0);
      var guard = 0;
      while (g.sp == 0 && g.phase != Phase.retired && guard++ < 40) {
        _step(g);
      }
      expect(g.sp, greaterThanOrEqualTo(1));
      expect(g.lastSpGain, greaterThanOrEqualTo(1));
    });

    test('習得するとポイントが減り、能力が付く。足りないときは StateError', () {
      final g = Game.start('x', rng: Random(3), events: false);
      expect(() => g.learnSpecial(Special.calm), throwsStateError);
      g.sp = 20;
      g.learnSpecial(Special.calm);
      expect(g.sp, 20 - Special.calm.cost);
      expect(g.player.specials, {Special.calm});
      expect(() => g.learnSpecial(Special.calm), throwsStateError);
      expect(() => g.learnSpecial(Special.clutchMaster), returnsNormally);
    });

    test('ポイントと習得した能力が保存で残る。古いセーブは0・なしで読める', () {
      final g = Game.start('x', rng: Random(3), events: false);
      g.sp = 9;
      g.learnSpecial(Special.calm);
      final back = Game.fromJson(g.toJson());
      expect(back.sp, g.sp);
      expect(back.player.specials, {Special.calm});
      final j = g.toJson()..remove('sp');
      (j['player'] as Map<String, dynamic>).remove('specials');
      final old = Game.fromJson(j);
      expect(old.sp, 0);
      expect(old.player.specials, isEmpty);
    });

    test('ゾーンは大会ごとに1回。使うと勝負どころの成功率が上がり、2回目は使えない', () {
      final g = _clutchGame({Special.calm, Special.zone});
      expect(g, isNotNull, reason: '勝負どころで止まる試合が見つかる');
      final before = g!.clutchInfo!.chances[Clutch.drive]!;
      expect(g.run!.zones, 1);
      g.useZone();
      expect(g.run!.zones, 0);
      expect(g.clutchInfo!.chances[Clutch.drive]! - before, closeTo(zoneBonus, 1e-9));
      expect(() => g.useZone(), throwsStateError);
      // 保存しても、ゾーン中の状態が残る。
      final back = Game.fromJson(g.toJson());
      expect(back.run!.pending!.zone, isTrue);
      expect(back.run!.zones, 0);
    });

    test('ゾーンを習得していなければ、使えない', () {
      final g = _clutchGame({});
      expect(g, isNotNull);
      expect(g!.run!.zones, 0);
      expect(() => g.useZone(), throwsStateError);
    });
  });
}
