import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/world.dart';
import 'package:flutter_test/flutter_test.dart';

Game _life(int seed, {int potential = 100}) {
  final g = Game.newGame(
      name: 'テスト', role: Role.batter, rng: Random(seed), potential: potential);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 4000) {
    g.autoSpend();
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
  return g;
}

void main() {
  group('世界大会が開かれる年', () {
    WorldEvent? at(Stage s, int age, {bool route = false}) =>
        worldEventFor(stage: s, age: age, hasRoute: route);

    test('U-12・U-15・U-18・U-23・プロ(22歳から4年おき)', () {
      expect(at(Stage.youth, 12)?.id, 'u12');
      expect(at(Stage.youth, 11), isNull);
      expect(at(Stage.juniorHigh, 15)?.id, 'u15');
      expect(at(Stage.juniorHigh, 14), isNull);
      expect(at(Stage.highSchool, 18)?.id, 'u18');
      expect(at(Stage.highSchool, 17), isNull);
      expect(at(Stage.pathChoice, 21, route: true)?.id, 'u23');
      expect(at(Stage.pathChoice, 21), isNull); // 進路が決まっていない
      for (final age in [22, 26, 30, 34, 38, 42]) {
        expect(at(Stage.pro, age)?.id, 'pro', reason: '$age');
      }
      for (final age in [23, 24, 25, 27]) {
        expect(at(Stage.pro, age), isNull, reason: '$age');
      }
    });

    test('国名は実在の国で、大会名は「世界大会」(固有の大会名を使わない)', () {
      for (final e in worldEvents) {
        expect(e.name, endsWith('世界大会'));
        expect(e.countries.length, e.opponents.length);
        expect(e.countries.toSet().length, e.countries.length);
        // 相手は弱い順
        final o = e.opponents;
        for (var i = 1; i < o.length; i++) {
          expect(o[i], greaterThan(o[i - 1]));
        }
      }
    });
  });

  group('結果', () {
    WorldRecord rec(int won) => WorldRecord(
        age: 12,
        eventId: 'u12',
        eventName: 'U-12世界大会',
        roundsWon: won,
        rounds: 4,
        line: const Line());

    test('勝ち上がりの数で表記が決まる', () {
      expect(rec(4).resultText, '優勝');
      expect(rec(3).resultText, '準優勝');
      expect(rec(2).resultText, 'ベスト4');
      expect(rec(1).resultText, 'ベスト8');
      expect(rec(0).resultText, '1次ラウンド敗退');
      expect(rec(4).champion, isTrue);
      expect(rec(3).champion, isFalse);
    });

    test('保存して読み直せる。古いデータ(項目なし)は既定値', () {
      final r = WorldRecord(
          age: 15,
          eventId: 'u15',
          eventName: 'U-15世界大会',
          roundsWon: 2,
          rounds: 4,
          line: const Line(games: 3, atBats: 12, hits: 5),
          lostTo: '韓国');
      final back = WorldRecord.fromJson(r.toJson());
      expect(back.eventId, 'u15');
      expect(back.lostTo, '韓国');
      expect(back.line.hits, 5);
      final empty = WorldRecord.fromJson({});
      expect(empty.rounds, 4);
      expect(empty.eventName, isNotEmpty);
    });
  });

  group('ゲームの中', () {
    test('強い選手は何度か代表に選ばれ、ログと記録と年表に残る', () {
      var found = 0;
      for (var seed = 0; seed < 40 && found < 3; seed++) {
        final g = _life(seed);
        if (g.worldRecords.isEmpty) continue;
        found++;
        for (final r in g.worldRecords) {
          expect(
              g.log.any((l) => l.contains('${r.eventName}の日本代表に選ばれた')), isTrue);
          expect(g.lifeLog.any((e) => e.kind == 'world'), isTrue);
          expect(r.rounds, 4);
          if (!r.champion) expect(r.lostTo, isNotNull);
        }
        // 同じ大会に2回出ることは無い
        final ids = [for (final r in g.worldRecords) r.eventId];
        expect(ids.where((i) => i != 'pro').toSet().length,
            ids.where((i) => i != 'pro').length);
      }
      expect(found, greaterThan(0));
    });

    test('弱い選手は選ばれにくい(U-12の選出率は強い選手より低い)', () {
      int u12(int potential) {
        var c = 0;
        for (var seed = 0; seed < 40; seed++) {
          final g = _life(seed, potential: potential);
          if (g.worldRecords.any((r) => r.eventId == 'u12')) c++;
        }
        return c;
      }

      expect(u12(100), greaterThan(u12(20)));
    });

    test('保存して読み直しても世界大会の記録が残る', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = _life(seed);
        if (g.worldRecords.isEmpty) continue;
        final back = Game.fromJson(g.toJson(), Random(1));
        expect(back.worldRecords.length, g.worldRecords.length);
        expect(back.worldRecords.first.eventId, g.worldRecords.first.eventId);
        final snap = PlayerSnapshot.fromGame(g);
        final snap2 = PlayerSnapshot.fromJson(snap.toJson());
        expect(snap2.worldRecords.length, g.worldRecords.length);
        // 古いセーブ(worldRecordsなし)は空
        final old = g.toJson()..remove('worldRecords');
        expect(Game.fromJson(old, Random(1)).worldRecords, isEmpty);
        return;
      }
      fail('世界大会に出た選手がいない');
    });

    test('優勝すると、ログに「世界一」が出る', () {
      var champs = 0;
      for (var seed = 0; seed < 80 && champs == 0; seed++) {
        final g = _life(seed);
        if (g.worldRecords.any((r) => r.champion)) {
          champs++;
          expect(g.log.any((l) => l.contains('世界一になった')), isTrue);
        }
      }
      expect(champs, greaterThan(0));
    });
  });

  group('実績', () {
    PlayerSnapshot snap(List<WorldRecord> w) => PlayerSnapshot(
          name: 't',
          role: Role.batter,
          age: 30,
          stage: Stage.retired,
          potential: 50,
          abilities: const {Ability.contact: 50},
          traits: const {},
          records: const [],
          events: const [],
          overallHistory: const [10, 20],
          worldRecords: w,
        );
    WorldRecord r(String id, int won) => WorldRecord(
        age: 20,
        eventId: id,
        eventName: id,
        roundsWon: won,
        rounds: 4,
        line: const Line());

    test('代表に選ばれる・世界一・全世代', () {
      expect(earnedBy(snap(const [])), isNot(contains('national-team')));
      expect(earnedBy(snap([r('u12', 1)])), contains('national-team'));
      expect(earnedBy(snap([r('u12', 1)])), isNot(contains('world-champion')));
      expect(earnedBy(snap([r('u12', 4)])), contains('world-champion'));
      expect(earnedBy(snap([r('u12', 1), r('u15', 1), r('u18', 1)])),
          isNot(contains('all-ages')));
      expect(
          earnedBy(snap([r('u12', 1), r('u15', 1), r('u18', 1), r('pro', 0)])),
          contains('all-ages'));
    });
  });
}
