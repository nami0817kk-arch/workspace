import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';

const plain = {Role.police: 3, Role.prisoner: 1};

Outcome go(Board b, Map<Role, int> load, {int cap = 2, Place to = Place.right, bool island = false}) =>
    cross(b, Move(b.boat, to, load), capacity: cap, island: island);

void main() {
  group('逃げる条件', () {
    test('警官のいない岸に囚人を残すと逃げる', () {
      final b = Board.start({Role.police: 2, Role.prisoner: 1});
      final r = go(b, {Role.police: 2});
      expect(r, isA<Escaped>().having((e) => e.where, 'where', Place.left));
    });

    test('囚人が警官より多い岸は逃げる', () {
      final b = Board.start({Role.police: 3, Role.prisoner: 2});
      final r = go(b, {Role.police: 2});
      expect(r, isA<Escaped>().having((e) => e.weight, 'weight', 2));
    });

    test('漕ぎ手がいない舟は出せない（逃げる扱いではない）', () {
      final b = Board.start(plain);
      expect(go(b, {Role.prisoner: 1}), isA<Refused>().having((e) => e.reason, 'reason', RefuseReason.noRower));
    });

    test('警察犬は見張れるが漕げない', () {
      final b = Board.start({Role.police: 1, Role.dog: 1, Role.prisoner: 1});
      expect(go(b, {Role.dog: 1}), isA<Refused>());
      // 犬が残れば囚人1人は見張れる
      expect(go(b, {Role.police: 1}), isA<Crossed>());
    });

    test('看守長は1人で2人分を見張る', () {
      final b = Board.start({Role.chief: 1, Role.police: 1, Role.prisoner: 2});
      expect(go(b, {Role.police: 1}), isA<Crossed>(), reason: '看守長だけが残っても囚人2人までは見張れる');
      final b2 = Board.start({Role.chief: 1, Role.police: 1, Role.prisoner: 3});
      expect(go(b2, {Role.police: 1}, cap: 2), isA<Escaped>());
    });

    test('ボスは見張りが2要る', () {
      final b = Board.start({Role.police: 2, Role.boss: 1});
      expect(go(b, {Role.police: 1, Role.boss: 1}), isA<Escaped>().having((e) => e.where, 'where', isNull), reason: '舟の上で警官1人ではボスを抑えられない');
    });

    test('手錠の2人は席を2つ使う', () {
      final b = Board.start({Role.police: 2, Role.cuffed: 1});
      expect(go(b, {Role.police: 1, Role.cuffed: 1}, cap: 2), isA<Refused>().having((e) => e.reason, 'reason', RefuseReason.overCapacity));
    });

    test('中州のある面は1区間ずつしか進めない', () {
      final b = Board.start(plain);
      expect(go(b, {Role.police: 1}, island: true), isA<Refused>().having((e) => e.reason, 'reason', RefuseReason.notAdjacent));
      expect(go(b, {Role.police: 1}, to: Place.island, island: true), isA<Crossed>());
    });
  });

  group('探索', () {
    test('昔からの形（警官3・囚人1・定員2）は5回', () {
      expect(analyze(Board.start(plain), capacity: 2, island: false).par, 5);
    });

    test('解けない形は null を返す', () {
      final a = analyze(Board.start({Role.police: 2, Role.prisoner: 2}), capacity: 2, island: false);
      expect(a.path, isNull);
    });

    test('最短手順をそのまま実行すると全員渡りきる', () {
      final a = analyze(Board.start(plain), capacity: 2, island: false);
      var b = Board.start(plain);
      for (final m in a.path!) {
        b = (cross(b, m, capacity: 2, island: false) as Crossed).board;
      }
      expect(b.solved, isTrue);
    });
  });

  group('収録面', () {
    final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
    final levels = (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();

    test('8舞台・120面（2026-09-26 に60面から増やした）', () {
      expect(levels, hasLength(120));
      expect(levels.map((l) => l.id).toSet(), hasLength(120));
      final perWorld = {1: 12, 2: 15, 3: 15, 4: 15, 5: 15, 6: 15, 7: 15, 8: 18};
      perWorld.forEach((w, count) => expect(levels.where((l) => l.world == w), hasLength(count), reason: '舞台$w'));
    });

    test('同じ組み合わせの面が2つない', () {
      final keys = levels.map((l) => '${Role.values.map(l.count).join(',')}|${l.capacity}|${l.island}').toSet();
      expect(keys, hasLength(levels.length));
    });

    for (final l in levels) {
      test('${l.id} は最短${l.par}回で解ける', () {
        final a = analyze(Board.start(l.cast), capacity: l.capacity, island: l.island);
        expect(a.par, l.par);
      });
    }

    test('画面に収まる人数（片側の列が6人分まで）', () {
      for (final l in levels) {
        final guards = l.count(Role.police) + l.count(Role.chief) + l.count(Role.dog);
        final captives = l.count(Role.prisoner) + l.count(Role.boss) + l.count(Role.cuffed) * 2;
        expect(guards, lessThanOrEqualTo(6), reason: l.id);
        expect(captives, lessThanOrEqualTo(6), reason: '${l.id}（手錠の2人は2人分の幅）');
      }
    });
  });
}
