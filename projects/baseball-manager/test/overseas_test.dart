import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

/// プロの、年の最初まで進める。`strong` なら能力を上げて、移籍の条件を満たす。
Game _proAt(int seed, {bool strong = true}) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 100);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 4000) {
    g.autoSpend();
    if (g.stage == Stage.pro &&
        g.phase == Phase.term &&
        g.slot == 0 &&
        g.player.age >= 24) {
      break;
    }
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  if (strong && g.stage == Stage.pro) {
    for (final a in batterAbilities) {
      g.adminSetAbility(a, 80);
    }
  }
  return g;
}

Game _strongPro() {
  for (var s = 0; s < 60; s++) {
    final g = _proAt(s);
    if (g.stage == Stage.pro && g.phase == Phase.term) return g;
  }
  fail('プロの24歳以上まで進めない');
}

void main() {
  group('移籍の条件', () {
    test('プロ・24歳以上・総合評価70以上・年の最初だけ。海外にいる間は不可', () {
      final g = _strongPro();
      expect(g.canMoveOverseas, isTrue);
      g.moveOverseas();
      expect(g.overseas, isTrue);
      expect(overseasTeams, contains(g.overseasTeam));
      expect(g.canMoveOverseas, isFalse);
      expect(g.canReturnHome, isTrue);
      expect(() => g.moveOverseas(), throwsStateError);
    });

    test('弱い選手・年の途中・アマチュアは移籍できない', () {
      final weak = _proAt(1, strong: false);
      if (weak.stage == Stage.pro) {
        for (final a in batterAbilities) {
          weak.adminSetAbility(a, 40);
        }
        expect(weak.canMoveOverseas, isFalse);
        expect(() => weak.moveOverseas(), throwsStateError);
      }
      final g = _strongPro();
      g.choose(Plan.rest, Ability.contact);
      expect(g.canMoveOverseas, isFalse);
      final young = Game.newGame(
          name: 't', role: Role.batter, rng: Random(1), potential: 90);
      expect(young.canMoveOverseas, isFalse);
    });

    test('移籍すると気持ちが下がり、目標が立て直され、日本には戻れる', () {
      final g = _strongPro();
      final morale = g.condition.morale;
      g.moveOverseas();
      expect(g.condition.morale, lessThan(morale));
      expect(g.log.any((l) => l.contains('海を渡った')), isTrue);
      expect(g.lifeLog.any((e) => e.kind == 'overseas'), isTrue);
      expect(g.goal, isNotNull);
      g.returnHome();
      expect(g.overseas, isFalse);
      expect(g.canMoveOverseas, isTrue); // また行ける
      expect(() => g.returnHome(), throwsStateError);
    });
  });

  group('海外のシーズン', () {
    Line seasonOf(Game g, int n) {
      var t = const Line();
      for (var s = 0; s < n; s++) {
        final copy = Game.fromJson(g.toJson(), Random(s));
        var k = 0;
        while (copy.records.where((r) => r.stage == Stage.pro).length <=
                g.records.where((r) => r.stage == Stage.pro).length &&
            copy.phase != Phase.retired &&
            k++ < 40) {
          copy.phase == Phase.event
              ? copy.resolveEvent(0)
              : copy.choose(Plan.rest, Ability.contact);
        }
        t += copy.records.lastWhere((r) => r.stage == Stage.pro).line;
      }
      return t;
    }

    test('記録に海外の印が付き、年俸は2.5倍になる', () {
      final g = _strongPro();
      g.moveOverseas();
      var k = 0;
      final n = g.records.length;
      while (g.records.length == n && g.phase != Phase.retired && k++ < 40) {
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(Plan.rest, Ability.contact);
      }
      final rec = g.records.last;
      expect(rec.overseas, isTrue);
      final home = SeasonRecord(
          age: rec.age,
          stage: Stage.pro,
          line: rec.line,
          rank: rec.rank,
          titles: rec.titles);
      expect(salaryOf(rec), greaterThan((salaryOf(home) * 2.4).floor()));
      expect(salaryOf(rec), lessThanOrEqualTo((salaryOf(home) * 2.6).ceil()));
    });

    test('相手が強いので、同じ選手でも日本より成績が落ちる(平均)', () {
      final home = _strongPro();
      final abroad = Game.fromJson(home.toJson(), Random(1))..moveOverseas();
      final h = seasonOf(home, 30);
      final a = seasonOf(abroad, 30);
      expect(a.opsPlus!, lessThan(h.opsPlus!));
    });
  });

  group('保存・実績', () {
    test('保存して読み直しても海外の状態が残る。古いセーブは日本のまま', () {
      final g = _strongPro();
      g.moveOverseas();
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.overseas, isTrue);
      expect(back.overseasTeam, g.overseasTeam);
      final snap = PlayerSnapshot.fromJson(PlayerSnapshot.fromGame(g).toJson());
      expect(snap.overseasTeam, g.overseasTeam);
      final old = g.toJson()
        ..remove('overseas')
        ..remove('overseasTeam');
      final o = Game.fromJson(old, Random(1));
      expect(o.overseas, isFalse);
      expect(o.overseasTeam, isNull);
      // 古い記録(overseasなし)は日本
      expect(
          SeasonRecord.fromJson({'age': 25, 'stage': 'pro'}).overseas, isFalse);
    });

    test('実績: 海を渡る・アメリカの頂点', () {
      PlayerSnapshot snap(List<SeasonRecord> r) => PlayerSnapshot(
            name: 't',
            role: Role.batter,
            age: 30,
            stage: Stage.retired,
            potential: 50,
            abilities: const {Ability.contact: 50},
            traits: const {},
            records: r,
            events: const [],
            overallHistory: const [10, 20],
          );
      SeasonRecord rec(bool o, int rank) => SeasonRecord(
          age: 28,
          stage: Stage.pro,
          line: const Line(),
          rank: rank,
          overseas: o);
      expect(earnedBy(snap([rec(false, 1)])), isNot(contains('overseas')));
      expect(earnedBy(snap([rec(true, 4)])), contains('overseas'));
      expect(
          earnedBy(snap([rec(true, 4)])), isNot(contains('overseas-champion')));
      expect(earnedBy(snap([rec(true, 1)])), contains('overseas-champion'));
    });

    test('何度遊んでも落ちない: 海外に行って戻って、最後まで', () {
      for (var seed = 0; seed < 15; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.pitcher, rng: Random(seed), potential: 100);
        var n = 0;
        while (g.phase != Phase.retired && n++ < 4000) {
          g.autoSpend();
          if (g.phase == Phase.term && g.slot == 0) {
            if (g.canMoveOverseas) {
              g.moveOverseas();
            } else if (g.canReturnHome && g.player.age % 3 == 0) {
              g.returnHome();
            }
          }
          switch (g.phase) {
            case Phase.term:
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  abilitiesOf(g.player.role).first);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.corporate);
            case Phase.retired:
              break;
          }
        }
        expect(g.phase, Phase.retired);
        Game.fromJson(g.toJson(), Random(1));
      }
    });
  });
}
