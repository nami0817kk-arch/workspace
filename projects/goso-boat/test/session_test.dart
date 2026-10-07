import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';
import 'package:goso_boat/game/session.dart';

Level lv(Map<Role, int> cast, {int cap = 2, bool island = false, int par = 5}) =>
    Level(id: 't', world: 1, cast: cast, capacity: cap, island: island, par: par);

List<Level> _levels() {
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

Person first(Session s, Role r) => s.people.firstWhere((p) => p.role == r && !p.aboard && p.place == s.boat);

void main() {
  test('乗せる・降ろす・定員', () {
    final s = Session(lv({Role.police: 3, Role.prisoner: 1}));
    expect(s.tap(first(s, Role.police)), TapResult.boarded);
    expect(s.tap(first(s, Role.police)), TapResult.boarded);
    expect(s.tap(first(s, Role.prisoner)), TapResult.full);
    final seated = s.aboard.first;
    expect(s.tap(seated), TapResult.left);
    expect(s.aboard, hasLength(1));
    expect(s.aboard.single.seat, 0, reason: '降ろしたら席を詰める');
  });

  test('手錠の2人は2席ぶんとして数える', () {
    final s = Session(lv({Role.police: 2, Role.cuffed: 1}, cap: 3));
    s.tap(first(s, Role.police));
    s.tap(first(s, Role.police));
    expect(s.tap(first(s, Role.cuffed)), TapResult.full);
  });

  test('渡ると人と舟が動き、回数が増える', () {
    final s = Session(lv({Role.police: 3, Role.prisoner: 1}));
    s.tap(first(s, Role.police));
    s.tap(first(s, Role.prisoner));
    expect(s.depart(Place.right), isA<Crossed>());
    expect(s.boat, Place.right);
    expect(s.trips, 1);
    expect(s.at(Place.right), hasLength(2));
    expect(s.tap(s.at(Place.left).first), TapResult.boatElsewhere);
  });

  test('逃げたら止まり、一手戻すと元に戻る', () {
    final s = Session(lv({Role.police: 2, Role.prisoner: 1}));
    s.tap(first(s, Role.police));
    s.tap(first(s, Role.police));
    final r = s.depart(Place.right);
    expect(r, isA<Escaped>());
    expect(s.failed, isTrue);
    expect(s.escaped.single.role, Role.prisoner);
    expect(s.tap(s.people.first), TapResult.locked);
    s.undo();
    expect(s.failed, isFalse);
    expect(s.aboard, hasLength(2), reason: '出発前の、乗せた状態に戻る');
    expect(s.trips, 0);
  });

  test('舟の上で逃げたときは乗っている囚人だけが逃げる', () {
    final s = Session(lv({Role.police: 2, Role.boss: 1, Role.prisoner: 1}, cap: 2));
    s.tap(first(s, Role.police));
    s.tap(first(s, Role.boss));
    expect(s.depart(Place.right), isA<Escaped>().having((e) => e.where, 'where', isNull));
    expect(s.escaped.single.role, Role.boss);
  });

  test('着いた岸で逃げることは起きない（岸も舟も見張れていれば合わせても見張れる）', () {
    // 岸 (g1,w1) と舟 (g2,w2) がそれぞれ安全なら合計も安全。だから逃げるのは
    // 「出発した岸」か「舟の上」だけで、画面もその2通りだけを演出すればよい。
    for (var g1 = 0; g1 <= 6; g1++) {
      for (var w1 = 0; w1 <= 6; w1++) {
        for (var g2 = 1; g2 <= 4; g2++) {
          for (var w2 = 0; w2 <= 4; w2++) {
            if (isSafe(g1, w1) && isSafe(g2, w2)) expect(isSafe(g1 + g2, w1 + w2), isTrue);
          }
        }
      }
    }
  });

  test('漕ぎ手がいなければ出せない（止まらない）', () {
    final s = Session(lv({Role.police: 3, Role.prisoner: 1}));
    s.tap(first(s, Role.prisoner));
    expect(s.depart(Place.right), isA<Refused>());
    expect(s.failed, isFalse);
    expect(s.canUndo, isFalse);
  });

  test('星2は最短+2回まで（中州なし）、+4回まで（中州あり）', () {
    int starsFor(Level l, int trips) => (Session(l)..trips = trips).stars;
    final plain = lv({Role.police: 3, Role.prisoner: 1}, par: 5);
    expect(starsFor(plain, 5), 3);
    expect(starsFor(plain, 7), 2);
    expect(starsFor(plain, 8), 1);
    final isl = lv({Role.police: 3, Role.prisoner: 1}, par: 6, island: true);
    expect(starsFor(isl, 10), 2);
    expect(starsFor(isl, 11), 1);
  });

  test('途中の盤面を保存して戻せる。合わない形は受け付けない', () {
    final l = lv({Role.police: 3, Role.prisoner: 1});
    final a = Session(l);
    a.tap(first(a, Role.police));
    a.tap(first(a, Role.prisoner));
    a.depart(Place.right);
    a.usedHint = true;
    final b = Session(l);
    expect(b.restore(a.toJson()), isTrue);
    expect(b.trips, 1);
    expect(b.boat, Place.right);
    expect(b.at(Place.right), hasLength(2));
    expect(b.usedHint, isTrue, reason: 'ヒントを使った印も戻す（星2までのまま）');
    expect(b.canUndo, isFalse, reason: '一手戻すの履歴は持たない');
    expect(Session(lv({Role.police: 2, Role.prisoner: 1})).restore(a.toJson()), isFalse, reason: '人数が違う面');
    expect(Session(l).restore({'places': 'x'}), isFalse);
  });

  test('一手戻すを使った印: 続きからでも残り、最初からで消える', () {
    final l = lv({Role.police: 3, Role.prisoner: 1});
    final a = Session(l);
    a.tap(first(a, Role.police));
    a.depart(Place.right);
    expect(a.usedUndo, isFalse);
    a.undo();
    expect(a.usedUndo, isTrue);
    a.tap(first(a, Role.police));
    a.depart(Place.right);
    final c = Session(l)..restore(a.toJson());
    expect(c.usedUndo, isTrue);
    a.reset();
    expect(a.usedUndo, isFalse);
  });

  test('星: 最短で3、ヒントを使うと2まで', () {
    final s = Session(lv({Role.police: 3, Role.prisoner: 1}, par: 5));
    while (!s.cleared) {
      s.hint();
      s.depart(s.destinations.first);
    }
    expect(s.trips, 5);
    expect(s.stars, 2);
  });

  group('全面をヒントだけで最短で解ける', () {
    for (final l in _levels()) {
      test(l.id, () {
        final s = Session(l);
        var guard = 0;
        while (!s.cleared && guard++ < 200) {
          final m = s.hint();
          expect(m, isNotNull, reason: '${s.trips}回目でヒントが出ない');
          final r = s.depart(m!.to);
          expect(r, isA<Crossed>(), reason: '${s.trips}回目 $m');
        }
        expect(s.cleared, isTrue);
        expect(s.trips, l.par);
      });
    }
  });
}
