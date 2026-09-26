import 'dart:collection';

import 'rules.dart';

/// 1面の定義。
class Level {
  const Level({
    required this.id,
    required this.world,
    required this.cast,
    required this.capacity,
    this.island = false,
    required this.par,
  });

  /// 「3-7」のような表示用の番号。
  final String id;
  final int world;
  final Map<Role, int> cast;

  /// 舟の席の数。手錠の2人は2席使う。
  final int capacity;

  /// 川の中ほどに中州があるか。ある面では舟は 左岸↔中州↔右岸 を1区間ずつ進む。
  final bool island;

  /// 最短の往復回数（舟が1回渡るごとに1）。
  final int par;

  int count(Role r) => cast[r] ?? 0;

  Map<String, Object?> toJson() => {
        'id': id,
        'world': world,
        'cast': {for (final e in cast.entries) if (e.value > 0) e.key.name: e.value},
        'capacity': capacity,
        if (island) 'island': true,
        'par': par,
      };

  factory Level.fromJson(Map<String, Object?> j) => Level(
        id: j['id']! as String,
        world: j['world']! as int,
        cast: {
          for (final e in (j['cast']! as Map<String, Object?>).entries)
            Role.values.byName(e.key): e.value! as int,
        },
        capacity: j['capacity']! as int,
        island: (j['island'] as bool?) ?? false,
        par: j['par']! as int,
      );
}

/// 盤面。場所ごとの各役の人数と、舟のいる場所。
class Board {
  Board._(this.counts, this.boat);

  /// 全員が左岸・舟も左岸の初期盤面。
  factory Board.start(Map<Role, int> cast) {
    final c = List<int>.filled(Place.values.length * Role.values.length, 0);
    for (final r in Role.values) {
      c[_i(Place.left, r)] = cast[r] ?? 0;
    }
    return Board._(c, Place.left);
  }

  /// 場所×役の人数（`place.index * Role.values.length + role.index`）から作る。
  factory Board.fromCounts(List<int> counts, Place boat) => Board._(List.unmodifiable(counts), boat);

  /// [place] 行の [role] 列。
  final List<int> counts;
  final Place boat;

  static int _i(Place p, Role r) => p.index * Role.values.length + r.index;

  int at(Place p, Role r) => counts[_i(p, r)];

  int guardAt(Place p) =>
      Role.values.fold(0, (s, r) => s + at(p, r) * r.guard);
  int weightAt(Place p) =>
      Role.values.fold(0, (s, r) => s + at(p, r) * r.weight);

  bool safeAt(Place p) => isSafe(guardAt(p), weightAt(p));

  bool get solved =>
      Place.values.every((p) => p == Place.right ||
          Role.values.every((r) => at(p, r) == 0)) &&
      boat == Place.right;

  String get key => '${counts.join(',')}|${boat.index}';

  Board apply(Move m) {
    final c = List<int>.of(counts);
    m.load.forEach((r, n) {
      c[_i(m.from, r)] -= n;
      c[_i(m.to, r)] += n;
    });
    return Board._(c, m.to);
  }
}

/// 舟の1回の横断。
class Move {
  const Move(this.from, this.to, this.load);
  final Place from;
  final Place to;
  final Map<Role, int> load;

  int get seats => load.entries.fold(0, (s, e) => s + e.key.seats * e.value);

  @override
  String toString() =>
      '${from.name}->${to.name} ${load.entries.where((e) => e.value > 0).map((e) => '${e.key.label}${e.value}').join('+')}';
}

/// 1回の横断の結果。逃げた場合はどこで逃げたかを返す。
sealed class Outcome {
  const Outcome();
}

class Crossed extends Outcome {
  const Crossed(this.board);
  final Board board;
}

/// 横断そのものができない（漕ぎ手がいない・定員超過など）。盤面は変わらない。
class Refused extends Outcome {
  const Refused(this.reason);
  final RefuseReason reason;
}

enum RefuseReason { empty, overCapacity, noRower, notAdjacent }

/// 見張りが足りず逃げられた。[where] が null なら舟の上。
class Escaped extends Outcome {
  const Escaped(this.where, this.guard, this.weight);
  final Place? where;
  final int guard;
  final int weight;
}

List<Place> neighbors(Place p, {required bool island}) {
  if (!island) return [p == Place.left ? Place.right : Place.left];
  return switch (p) {
    Place.left => [Place.island],
    Place.island => [Place.left, Place.right],
    Place.right => [Place.island],
  };
}

/// 判定の本体。画面もヒントの探索もこれを使う。
Outcome cross(Board b, Move m, {required int capacity, required bool island}) {
  if (m.from != b.boat || !neighbors(m.from, island: island).contains(m.to)) {
    return const Refused(RefuseReason.notAdjacent);
  }
  final total = m.load.values.fold(0, (s, n) => s + n);
  if (total == 0) return const Refused(RefuseReason.empty);
  if (m.seats > capacity) return const Refused(RefuseReason.overCapacity);
  if (!m.load.entries.any((e) => e.value > 0 && e.key.rows)) {
    return const Refused(RefuseReason.noRower);
  }
  // 出発した瞬間の岸 → 舟の上 → 着いた岸 の順に見る。
  final next = b.apply(m);
  if (!next.safeAt(m.from)) {
    return Escaped(m.from, next.guardAt(m.from), next.weightAt(m.from));
  }
  final g = m.load.entries.fold(0, (s, e) => s + e.key.guard * e.value);
  final w = m.load.entries.fold(0, (s, e) => s + e.key.weight * e.value);
  if (!isSafe(g, w)) return Escaped(null, g, w);
  if (!next.safeAt(m.to)) {
    return Escaped(m.to, next.guardAt(m.to), next.weightAt(m.to));
  }
  return Crossed(next);
}

/// [b] から出せる、逃げられない横断をすべて返す。
Iterable<Move> legalMoves(Board b, {required int capacity, required bool island}) sync* {
  for (final to in neighbors(b.boat, island: island)) {
    for (final load in _loads(b, capacity)) {
      final m = Move(b.boat, to, load);
      if (cross(b, m, capacity: capacity, island: island) is Crossed) yield m;
    }
  }
}

Iterable<Map<Role, int>> _loads(Board b, int capacity) sync* {
  final roles = Role.values;
  final pick = List<int>.filled(roles.length, 0);
  Iterable<Map<Role, int>> rec(int i, int seatsLeft) sync* {
    if (i == roles.length) {
      if (pick.any((n) => n > 0)) {
        yield {for (var k = 0; k < roles.length; k++) if (pick[k] > 0) roles[k]: pick[k]};
      }
      return;
    }
    final r = roles[i];
    final max = b.at(b.boat, r);
    for (var n = 0; n <= max && n * r.seats <= seatsLeft; n++) {
      pick[i] = n;
      yield* rec(i + 1, seatsLeft - n * r.seats);
    }
    pick[i] = 0;
  }

  yield* rec(0, capacity);
}

/// 探索の結果。
class Analysis {
  Analysis(this.path, this.reachable, this.optimalCount);

  /// 最短手順。解けなければ null。
  final List<Move>? path;

  /// 初期盤面から逃げられずに行ける盤面の数（探索の広さ＝迷いやすさの目安）。
  final int reachable;

  /// 最短手順が何通りあるか（少ないほど「これしかない」面になる）。
  final int optimalCount;

  int? get par => path?.length;
}

/// 幅優先探索で最短手順を求める。
Analysis analyze(Board start, {required int capacity, required bool island}) {
  final dist = <String, int>{start.key: 0};
  final ways = <String, int>{start.key: 1};
  final prev = <String, (String, Move)>{};
  final boards = <String, Board>{start.key: start};
  final q = Queue<Board>()..add(start);
  String? goal;
  while (q.isNotEmpty) {
    final b = q.removeFirst();
    final d = dist[b.key]!;
    if (b.solved) {
      goal ??= b.key;
      continue;
    }
    for (final m in legalMoves(b, capacity: capacity, island: island)) {
      final n = b.apply(m);
      final k = n.key;
      final nd = dist[k];
      if (nd == null) {
        dist[k] = d + 1;
        ways[k] = ways[b.key]!;
        prev[k] = (b.key, m);
        boards[k] = n;
        q.add(n);
      } else if (nd == d + 1) {
        ways[k] = ways[k]! + ways[b.key]!;
      }
    }
  }
  if (goal == null) return Analysis(null, dist.length, 0);
  final path = <Move>[];
  var k = goal;
  while (prev.containsKey(k)) {
    final (p, m) = prev[k]!;
    path.add(m);
    k = p;
  }
  return Analysis(path.reversed.toList(), dist.length, ways[goal]!);
}

/// 途中の盤面からの最短手順（ヒント用）。
List<Move>? solveFrom(Board b, Level level) =>
    analyze(b, capacity: level.capacity, island: level.island).path;
