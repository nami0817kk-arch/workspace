import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Player _bat(Map<Ability, int> a, {String name = 't'}) => Player(
      name: name,
      role: Role.batter,
      age: 17,
      potential: 50,
      abilities: {for (final x in batterAbilities) x: a[x] ?? 40},
    );

Player _pit(Map<Ability, int> a) => Player(
      name: 'p',
      role: Role.pitcher,
      age: 17,
      potential: 50,
      abilities: {for (final x in pitcherAbilities) x: a[x] ?? 40},
    );

void main() {
  group('適性', () {
    test('各ポジションの重みは合計1', () {
      for (final p in Pos.values) {
        final sum = p.weights.values.fold<double>(0, (a, b) => a + b);
        expect(sum, closeTo(1.0, 1e-9), reason: p.label);
      }
    });

    test('適性は能力の重み付き平均(0〜99)', () {
      final all50 = _bat({
        for (final a in batterAbilities) a: 50,
      });
      for (final pos in positionsFor(Role.batter)) {
        expect(aptitudeOf(all50, pos), 50, reason: pos.label);
      }
      final top = _bat({for (final a in batterAbilities) a: 99});
      expect(aptitudeOf(top, Pos.shortstop), 99);
    });

    test('能力の特徴に合うポジションがいちばん高い', () {
      expect(bestPosition(_bat({Ability.fielding: 80, Ability.speed: 75})),
          Pos.shortstop);
      expect(bestPosition(_bat({Ability.power: 90, Ability.contact: 70})),
          Pos.first);
      expect(
          bestPosition(_bat(
              {Ability.speed: 90, Ability.fielding: 55, Ability.power: 30})),
          Pos.center);
      expect(bestPosition(_bat({Ability.catching: 85, Ability.arm: 70, Ability.fielding: 60})),
          Pos.catcher);
      expect(bestPosition(_pit({Ability.stamina: 80, Ability.control: 60})),
          Pos.starter);
      expect(
          bestPosition(_pit({
            Ability.stuff: 90,
            Ability.control: 70,
            Ability.stamina: 30,
          })),
          Pos.closer);
    });

    test('選べるポジションは役割で決まる(二刀流は先発と野手全部)', () {
      expect(
          positionsFor(Role.pitcher), [Pos.starter, Pos.reliever, Pos.closer]);
      expect(positionsFor(Role.batter).any((p) => p.isPitching), isFalse);
      final two = positionsFor(Role.twoWay);
      expect(two, contains(Pos.starter));
      expect(two, contains(Pos.dh));
      expect(two, isNot(contains(Pos.closer)));
    });

    test('決めていなければ、適性がいちばん高い所。役割に合わない指定は無視', () {
      final b = _bat({Ability.fielding: 80, Ability.speed: 75});
      expect(effectivePosition(b, null), Pos.shortstop);
      expect(effectivePosition(b, Pos.catcher), Pos.catcher);
      expect(effectivePosition(b, Pos.closer), Pos.shortstop); // 打者は抑えにならない
    });

    test('チーム力の補正: いちばん高い所なら0、低い所を選ぶと下がる(下限-6)', () {
      final b = _bat({Ability.fielding: 80, Ability.speed: 75});
      expect(positionTeamAdjust(b, bestPosition(b)), 0);
      expect(positionTeamAdjust(b, Pos.first), lessThan(0));
      expect(positionTeamAdjust(b, Pos.first), greaterThanOrEqualTo(-6));
      // 適性は同じくらいの2つなら、ほとんど下がらない
      expect(positionTeamAdjust(b, Pos.second), greaterThanOrEqualTo(-1));
    });
  });

  group('ゲームの中', () {
    Game start(int seed, {Role role = Role.batter}) =>
        Game.newGame(name: 't', role: role, rng: Random(seed), potential: 80);

    void playUntil(Game g, bool Function(Game) stop) {
      var n = 0;
      while (g.phase != Phase.retired && !stop(g) && n++ < 4000) {
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                abilitiesOf(g.player.role).first);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
    }

    test('決められるのは、中学・高校・進路の最初の年と、プロの毎年の最初だけ', () {
      final g = start(3);
      expect(g.canChoosePosition, isFalse); // 少年野球
      playUntil(g, (g) => g.stage == Stage.juniorHigh && g.slot == 0);
      expect(g.stage, Stage.juniorHigh);
      expect(g.canChoosePosition, isTrue); // 中学1年(13歳)の最初
      g.choose(Plan.rest, Ability.contact);
      expect(g.canChoosePosition, isFalse); // 同じ年の途中
      playUntil(g, (g) => g.stage == Stage.juniorHigh && g.player.age == 14);
      expect(g.canChoosePosition, isFalse); // 中学2年
      playUntil(g, (g) => g.stage == Stage.highSchool && g.slot == 0);
      expect(g.canChoosePosition, isTrue); // 高校1年(16歳)
    });

    test('プロは毎年の最初に決められる', () {
      for (var s = 0; s < 40; s++) {
        final g = start(s);
        playUntil(g, (g) => g.stage == Stage.pro);
        if (g.stage != Stage.pro) continue;
        expect(g.canChoosePosition, isTrue);
        g.choose(Plan.rest, Ability.contact);
        expect(g.canChoosePosition, isFalse);
        return;
      }
      fail('プロになれなかった');
    });

    test('決めると反映され、ログと年表に残る。保存して読み直しても残る', () {
      final g = start(3);
      playUntil(g, (g) => g.stage == Stage.juniorHigh && g.slot == 0);
      g.choosePosition(Pos.catcher);
      expect(g.position, Pos.catcher);
      expect(g.effectivePos, Pos.catcher);
      expect(g.log.any((l) => l.startsWith('ポジションを捕手に決めた')), isTrue);
      expect(g.lifeLog.any((e) => e.kind == 'position'), isTrue);
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.position, Pos.catcher);
      final snap = PlayerSnapshot.fromJson(PlayerSnapshot.fromGame(g).toJson());
      expect(snap.position, Pos.catcher);
      // 古いセーブ(positionなし)は決めていない扱い
      final old = g.toJson()..remove('position');
      expect(Game.fromJson(old, Random(1)).position, isNull);
    });

    test('決められない時・役割に合わないポジションは拒否される', () {
      final g = start(3);
      expect(() => g.choosePosition(Pos.catcher), throwsStateError); // 少年野球
      playUntil(g, (g) => g.stage == Stage.juniorHigh && g.slot == 0);
      expect(() => g.choosePosition(Pos.closer), throwsArgumentError); // 打者
      g.choose(Plan.rest, Ability.contact);
      expect(() => g.choosePosition(Pos.catcher), throwsStateError); // 年の途中
    });

    test('決めなければ補正は0(これまでのバランスを変えない)', () {
      final g = start(3);
      expect(positionTeamAdjust(g.player, g.effectivePos), 0);
    });

    test('投手は先発・中継ぎ・抑えから選べる', () {
      final g = start(4, role: Role.pitcher);
      playUntil(g, (g) => g.stage == Stage.juniorHigh && g.slot == 0);
      g.choosePosition(Pos.closer);
      expect(g.effectivePos, Pos.closer);
      expect(() => g.choosePosition(Pos.catcher), throwsArgumentError);
    });
  });
}
