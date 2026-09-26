// 面を選んで assets/levels.json を書き出す。
//   dart run tool/gen_levels.dart            … 書き出し＋一覧表示
//   dart run tool/gen_levels.dart --dry-run  … 一覧表示だけ
//
// 選び方:
//   1. 舞台ごとに、その舞台の要素を含む組み合わせを総当たりで解く
//   2. 難しさ = ランダムに動かしたときに解けるまでの平均手数（迷いやすさ）と、
//      「戻し」の回数（右岸から囚人を連れ戻す・2人以上で戻る、の直感に反する手）
//   3. 舞台の1面目はいちばん易しい導入面、残りは難しさが単調に上がるように等間隔で拾う
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';

class World {
  const World(this.no, this.name, this.accepts, {this.island = false, this.maxPar = 21});
  final int no;
  final String name;
  final bool Function(Map<Role, int>) accepts;
  final bool island;
  final int maxPar;
}

int n(Map<Role, int> c, Role r) => c[r] ?? 0;
bool none(Map<Role, int> c, List<Role> rs) => rs.every((r) => n(c, r) == 0);

final worlds = [
  World(1, '川べり', (c) => none(c, [Role.chief, Role.dog, Role.boss, Role.cuffed])),
  World(2, '看守長', (c) => n(c, Role.chief) > 0 && none(c, [Role.dog, Role.boss, Role.cuffed])),
  World(3, '手錠', (c) => n(c, Role.cuffed) > 0 && none(c, [Role.dog, Role.boss])),
  World(4, 'ボス', (c) => n(c, Role.boss) > 0 && none(c, [Role.dog, Role.cuffed])),
  World(5, '警察犬', (c) => n(c, Role.dog) > 0),
  World(6, '中州', (c) => true, island: true, maxPar: 26),
];

class Cand {
  Cand(this.cast, this.cap, this.island, this.a, this.walk, this.reversals);
  final Map<Role, int> cast;
  final int cap;
  final bool island;
  final Analysis a;
  final double walk;
  final int reversals;
  int get people => cast.entries.fold(0, (s, e) => s + e.value * e.key.seats);
  int get roles => cast.values.where((x) => x > 0).length;
  // 最短手順が何通りもある面は、長くても迷わない（ただ長いだけ）ので下げる
  double get score => log(walk) / ln2 + reversals * 1.5 - log(a.optimalCount) / ln2 * 0.4;
  String get castText => Role.values.where((r) => n(cast, r) > 0).map((r) => '${r.label}${n(cast, r)}').join(' ');
}

Iterable<Map<Role, int>> casts() sync* {
  for (var p = 0; p <= 6; p++) {
    for (var k = 0; k <= 2; k++) {
      for (var d = 0; d <= 2; d++) {
        if (p + k == 0 || p + k + d > 6) continue;
        for (var c = 0; c <= 5; c++) {
          for (var bo = 0; bo <= 2; bo++) {
            for (var h = 0; h <= 2; h++) {
              if (c + bo + h == 0 || c + bo + h > 5) continue;
              if ([k, d, bo, h].where((x) => x > 0).length > 2) continue;
              yield {Role.police: p, Role.chief: k, Role.dog: d, Role.prisoner: c, Role.boss: bo, Role.cuffed: h};
            }
          }
        }
      }
    }
  }
}

/// 川を渡る向きで並べた位置（左岸0・中州1・右岸2）。
int pos(Place p) => switch (p) { Place.left => 0, Place.island => 1, Place.right => 2 };

/// 「戻し」: 左向きの横断で、囚人を連れているか2人以上乗っているもの（直感に反する手）。
int reversals(List<Move> path) => path.where((m) {
      if (pos(m.to) > pos(m.from)) return false;
      final ppl = m.load.values.fold(0, (s, x) => s + x);
      return ppl >= 2 || m.load.keys.any((r) => r.weight > 0);
    }).length;

double randomWalk(Map<Role, int> cast, int cap, bool island, Random rng) {
  const runs = 200, limit = 20000;
  var total = 0;
  for (var i = 0; i < runs; i++) {
    var b = Board.start(cast);
    var steps = 0;
    while (!b.solved && steps < limit) {
      final ms = legalMoves(b, capacity: cap, island: island).toList();
      b = b.apply(ms[rng.nextInt(ms.length)]);
      steps++;
    }
    total += steps;
  }
  return total / runs;
}

void main(List<String> args) {
  final dry = args.contains('--dry-run');
  final rng = Random(20260926);
  final levels = <Level>[];
  for (final w in worlds) {
    final cands = <Cand>[];
    for (final cast in casts()) {
      if (!w.accepts(cast)) continue;
      for (var cap = 2; cap <= 4; cap++) {
        if (n(cast, Role.cuffed) > 0 && cap < 3) continue;
        final a = analyze(Board.start(cast), capacity: cap, island: w.island);
        final par = a.par;
        if (par == null || par < 3 || par > w.maxPar) continue;
        final rev = reversals(a.path!);
        // 直感に反する手が1つも無いのに長い面は、作業になるだけなので外す
        if (rev == 0 && par > 11) continue;
        cands.add(Cand(cast, cap, w.island, a, 0, rev));
      }
    }
    // 同じ最短回数・同じ定員なら人数の少ない方だけ残す（見た目がすっきりする）
    final best = <String, Cand>{};
    for (final c in cands) {
      final key = '${c.a.par}|${c.cap}|${c.reversals}';
      final cur = best[key];
      if (cur == null || c.people < cur.people) best[key] = c;
    }
    final pool = best.values
        .map((c) => Cand(c.cast, c.cap, c.island, c.a, randomWalk(c.cast, c.cap, c.island, rng), c.reversals))
        .toList()
      ..sort((x, y) => x.score.compareTo(y.score));
    // 導入面: 最短回数が最小のもののうち、役の種類と人数が最も少ないもの
    final minPar = pool.map((c) => c.a.par!).reduce(min);
    final intro = (pool.where((c) => c.a.par == minPar).toList()
          ..sort((x, y) => x.roles != y.roles ? x.roles.compareTo(y.roles) : x.people.compareTo(y.people)))
        .first;
    final picked = <Cand>[intro];
    final rest = pool.where((c) => c != intro).toList(); // 残り9面は難しさの順に等間隔で拾う
    for (var i = 1; i <= 9 && rest.isNotEmpty; i++) {
      final idx = ((rest.length - 1) * i / 9).round();
      final c = rest[idx];
      if (!picked.contains(c)) picked.add(c);
    }
    stdout.writeln('\n== ${w.no} ${w.name}  候補${cands.length} → 絞り込み${pool.length}');
    for (var i = 0; i < picked.length; i++) {
      final c = picked[i];
      final id = '${w.no}-${i + 1}';
      levels.add(Level(id: id, world: w.no, cast: c.cast, capacity: c.cap, island: c.island, par: c.a.par!));
      stdout.writeln('${id.padRight(5)} ${c.castText.padRight(22)} 定員${c.cap}  最短${c.a.par.toString().padLeft(2)}'
          '  戻し${c.reversals}  迷い${c.walk.toStringAsFixed(0).padLeft(5)}  解${c.a.optimalCount}  盤面${c.a.reachable}');
    }
  }
  if (!dry) {
    const enc = JsonEncoder.withIndent('  ');
    File('assets/levels.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('${enc.convert({'version': 1, 'levels': levels.map((l) => l.toJson()).toList()})}\n');
    stdout.writeln('\nassets/levels.json に ${levels.length} 面を書いた');
  }
}
