import '../engine/puzzle.dart';
import '../engine/rules.dart';

/// 画面上の1人（手錠の2人は1人として扱う）。エンジンは人数だけを見るが、
/// 画面は誰がどこにいるかを追う必要があるのでここで個人に分ける。
class Person {
  Person(this.id, this.role, this.order);
  final int id;
  final Role role;

  /// 同じ役の中での番号（並び順と見分け用）。
  final int order;
  Place place = Place.left;

  /// 舟の上の席順。乗っていなければ -1。
  int seat = -1;
  bool get aboard => seat >= 0;
}

enum TapResult { boarded, left, boatElsewhere, full, locked }

/// 1面ぶんの進行。画面はこれを読み書きするだけにする。
class Session {
  Session(this.level) {
    var id = 0;
    for (final r in Role.values) {
      for (var i = 0; i < level.count(r); i++) {
        people.add(Person(id++, r, i));
      }
    }
  }

  final Level level;
  final List<Person> people = [];
  Place boat = Place.left;
  int trips = 0;
  bool usedHint = false;

  /// 逃げられて止まっている間の、逃げた人たち。
  List<Person> escaped = const [];
  Escaped? failure;
  bool get failed => failure != null;
  bool get cleared => people.every((p) => p.place == Place.right && !p.aboard) && boat == Place.right;

  final List<_Snap> _history = [];
  bool get canUndo => _history.isNotEmpty;

  List<Person> get aboard => people.where((p) => p.aboard).toList()..sort((a, b) => a.seat.compareTo(b.seat));
  int get seatsUsed => aboard.fold(0, (s, p) => s + p.role.seats);
  List<Person> at(Place p) => people.where((x) => x.place == p && !x.aboard).toList();

  /// エンジンに渡す盤面（舟に乗っている人は、舟のいる場所に数える）。
  Board get board {
    final counts = List<int>.filled(Place.values.length * Role.values.length, 0);
    for (final p in people) {
      counts[p.place.index * Role.values.length + p.role.index]++;
    }
    return Board.fromCounts(counts, boat);
  }

  List<Place> get destinations => neighbors(boat, island: level.island);

  TapResult tap(Person p) {
    if (failed || cleared) return TapResult.locked;
    if (p.aboard) {
      p.seat = -1;
      _compactSeats();
      return TapResult.left;
    }
    if (p.place != boat) return TapResult.boatElsewhere;
    if (seatsUsed + p.role.seats > level.capacity) return TapResult.full;
    p.seat = aboard.length;
    return TapResult.boarded;
  }

  void _compactSeats() {
    final a = aboard;
    for (var i = 0; i < a.length; i++) {
      a[i].seat = i;
    }
  }

  Move _moveTo(Place to) {
    final load = <Role, int>{};
    for (final p in aboard) {
      load[p.role] = (load[p.role] ?? 0) + 1;
    }
    return Move(boat, to, load);
  }

  /// 出したらどうなるかを、盤面を変えずに調べる（画面の演出を先に決めるため）。
  Outcome check(Place to) =>
      cross(board, _moveTo(to), capacity: level.capacity, island: level.island);

  /// 舟を出す。渡れたら人と舟を動かし、逃げられたら止める。
  Outcome depart(Place to) {
    if (failed || cleared) return const Refused(RefuseReason.empty);
    final m = _moveTo(to);
    final r = cross(board, m, capacity: level.capacity, island: level.island);
    if (r is Refused) return r;
    _history.add(_snap());
    final riders = aboard;
    switch (r) {
      case Crossed():
        for (final p in riders) {
          p.place = to;
          p.seat = -1;
        }
        boat = to;
        trips++;
      case Escaped(:final where):
        failure = r;
        // 着いた岸で逃げることは起きない（test/session_test.dart で確かめている）。
        // 逃げるのは舟の上か、出発した岸に残した囚人。
        escaped = where == null
            ? riders.where((p) => p.role.weight > 0).toList()
            : at(where).where((p) => p.role.weight > 0).toList();
      case Refused():
        break;
    }
    return r;
  }

  void undo() {
    if (_history.isEmpty) return;
    _restore(_history.removeLast());
  }

  void reset() {
    _history.clear();
    for (final p in people) {
      p.place = Place.left;
      p.seat = -1;
    }
    boat = Place.left;
    trips = 0;
    usedHint = false;
    failure = null;
    escaped = const [];
  }

  /// 次の一手を舟に乗せて返す。今の盤面から解けなければ null。
  Move? hint() {
    if (failed || cleared) return null;
    final path = solveFrom(board, level);
    if (path == null || path.isEmpty) return null;
    usedHint = true;
    final m = path.first;
    for (final p in people) {
      p.seat = -1;
    }
    var seat = 0;
    m.load.forEach((role, n) {
      for (final p in at(boat).where((p) => p.role == role).take(n)) {
        p.seat = seat++;
      }
    });
    return m;
  }

  /// 星の数。最短で3、少し回り道で2、それ以外は1。ヒントを使うと2まで。
  int get stars {
    final slack = level.island ? 6 : 4;
    var s = trips <= level.par ? 3 : trips <= level.par + slack ? 2 : 1;
    if (usedHint && s > 2) s = 2;
    return s;
  }

  _Snap _snap() => _Snap(
        [for (final p in people) (p.place, p.seat)],
        boat,
        trips,
      );

  void _restore(_Snap s) {
    for (var i = 0; i < people.length; i++) {
      people[i].place = s.people[i].$1;
      people[i].seat = s.people[i].$2;
    }
    boat = s.boat;
    trips = s.trips;
    failure = null;
    escaped = const [];
  }
}

class _Snap {
  _Snap(this.people, this.boat, this.trips);
  final List<(Place, int)> people;
  final Place boat;
  final int trips;
}
