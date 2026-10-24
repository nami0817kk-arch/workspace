import 'dart:math';

import 'package:basketball_career/game/career.dart';
import 'package:basketball_career/game/events.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(double h, {int a = 60, double genes = 0.5, int age = 15, int potential = 70}) => Player(
      name: 'a',
      age: age,
      potential: potential,
      heightCm: h,
      heightGenes: genes,
      abilities: {for (final x in Ability.values) x: a},
    );

/// 6歳から17歳まで、同じ乱数で毎年 `ageUp` した最終身長。
double _finalHeight(double habit, {double genes = 0.5}) {
  var p = newPlayer('x', 70, genes, const {});
  final rng = Random(3);
  while (p.age < 21) {
    p = ageUp(p, rng, habit: habit);
  }
  return p.heightCm;
}

void main() {
  group('身長は能力の1つ(総合評価に入る・ポテンシャルとは別)', () {
    test('身長の評価: 155cmで0、186cmでおよそ48、210cmでおよそ85、220cm以上で100', () {
      expect(heightRatingOf(150), 0);
      expect(heightRatingOf(155), 0);
      expect(heightRatingOf(186), closeTo(47.7, 0.1));
      expect(heightRatingOf(210), closeTo(84.6, 0.1));
      expect(heightRatingOf(225), 100);
      expect(_p(200).heightRating, heightRatingOf(200));
    });

    test('同じ能力なら、身長が高いほど総合評価が高い(同じポジション内)', () {
      expect(_p(215).position, _p(205).position, reason: '前提: どちらもセンター');
      expect(_p(215).overall, greaterThan(_p(205).overall));
      expect(_p(196, a: 60).overall, greaterThan(_p(190, a: 60).overall));
    });

    test('身長が総合に効く度合いは、大きいポジションほど大きい', () {
      expect(heightWeightOf(Position.pointGuard), lessThan(heightWeightOf(Position.smallForward)));
      expect(heightWeightOf(Position.smallForward), lessThan(heightWeightOf(Position.powerForward)));
      expect(heightWeightOf(Position.powerForward), lessThan(heightWeightOf(Position.center)));
    });

    test('身長はポテンシャル(potential)とは独立: 素質が高くても身長は変わらない', () {
      expect(_p(190, potential: 30).heightRating, _p(190, potential: 95).heightRating);
      expect(_p(190, potential: 30, genes: 0.9).heightCm, 190);
    });
  });

  group('幼少期の行い(生活習慣)が身長の伸びに効く', () {
    test('休養・交流で良くなり、疲れ切った特訓や疲れの溜まりすぎで乱れる', () {
      expect(habitDelta(Action.rest, 20), greaterThan(0));
      expect(habitDelta(Action.social, 20), greaterThan(0));
      expect(habitDelta(Action.practice, 20), 0);
      expect(habitDelta(Action.intense, 30), 0, reason: '疲れが軽い特訓は影響なし');
      expect(habitDelta(Action.intense, 65), lessThan(0));
      expect(habitDelta(Action.practice, 80), lessThan(0), reason: '疲れ70以上は睡眠不足');
    });

    test('ふつう(基準)なら身長の伸びは基準どおり、良いと伸び、乱れると鈍る', () {
      expect(habitHeightMultiplier(habitBaseline), 1.0);
      expect(habitHeightMultiplier(10), greaterThan(1.0));
      expect(habitHeightMultiplier(-10), lessThan(1.0));
      expect(habitHeightMultiplier(99), habitHeightMultiplier(10), reason: '上限で頭打ち');
    });

    test('最終身長: 良い習慣で数cm高く、乱れた習慣で数cm低い', () {
      final base = _finalHeight(habitBaseline);
      final good = _finalHeight(10);
      final bad = _finalHeight(-10);
      expect(good - base, inInclusiveRange(2.0, 5.0));
      expect(base - bad, inInclusiveRange(3.0, 6.5));
    });

    test('18歳以降は生活習慣で身長は変わらない', () {
      final a = ageUp(_p(185, age: 19), Random(1), habit: 10).heightCm;
      final b = ageUp(_p(185, age: 19), Random(1), habit: -10).heightCm;
      expect(a, b);
    });

    test('生活習慣は保存・復元で変わらず、古いセーブは0', () {
      final base = Game.start('x', rng: Random(1), events: false);
      final g = Game(eventsEnabled: false, player: base.player, rng: Random(2), habit: 7.5);
      expect(Game.fromJson(g.toJson()).habit, 7.5);
      final j = g.toJson()..remove('habit');
      expect(Game.fromJson(j).habit, 0);
    });

    test('幼少期は休養で生活習慣が上がり、18歳を過ぎると動かない', () {
      final g = Game.start('x', rng: Random(4), events: false);
      final before = g.habit;
      g.condition = g.condition.copyWith(fatigue: 20);
      g.choose(Action.rest, Ability.values.first);
      expect(g.habit, greaterThan(before));
      final adult = Game(
        eventsEnabled: false,
        player: g.player.copyWith(age: 20),
        rng: Random(5),
        track: Track.university,
        collegeYearsLeft: 4,
        habit: 5,
      );
      adult.choose(Action.rest, Ability.values.first);
      expect(adult.habit, 5);
    });

    test('幼少期の出来事(睡眠・食事・外遊び)があり、良い選択は習慣が上がり悪い選択は下がる', () {
      for (final id in ['sleep_habit', 'meal_habit', 'outdoor_play']) {
        final e = eventById(id)!;
        expect(e.options.length, 2, reason: id);
        expect(e.options[0].effect.habit, greaterThan(0), reason: id);
        expect(e.options[1].effect.habit, lessThan(0), reason: id);
        expect(e.maxAge, lessThanOrEqualTo(17), reason: '幼少期だけ');
        expect(events.map((x) => x.id), contains(id));
      }
    });

    test('出来事で生活習慣が動き、-10〜+10に収まる', () {
      final g = Game.start('x', rng: Random(6), events: true);
      g.pendingEventId = 'sleep_habit';
      final lines = g.resolveEvent(0);
      expect(g.habit, 3);
      expect(lines.any((l) => l.contains('生活習慣')), isTrue);
      g.habit = 9.5;
      g.pendingEventId = 'meal_habit';
      g.resolveEvent(0);
      expect(g.habit, 10);
      g.habit = -9;
      g.pendingEventId = 'sleep_habit';
      g.resolveEvent(1);
      expect(g.habit, -10);
    });
  });
}
