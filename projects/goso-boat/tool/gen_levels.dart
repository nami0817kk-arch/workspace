// 面を選んで assets/levels.json を書き出す。
//   dart run tool/gen_levels.dart            … 書き出し＋一覧表示
//   dart run tool/gen_levels.dart --dry-run  … 一覧表示だけ
//
// 選び方:
//   1. 舞台ごとに、その舞台の要素を含む組み合わせを総当たりで解く
//   2. 難しさ = ランダムに動かしたときに解けるまでの平均手数（迷いやすさ）と、
//      「戻し」の回数（右岸から囚人を連れ戻す・2人以上で戻る、の直感に反する手）
//      −最短手順の通り数（多いほど迷わない）
//   3. 舞台の1面目は易しい導入面。残りは難しい側に寄せて拾う
//      （2026-09-26 ユーザー指示「全体的に難易度とステージを増やしたい」で、
//       6舞台×10面 → 8舞台・120面にし、易しい側の4分の1を使わないようにした）
//   4. 舞台8「鬼門」は、他の舞台で使っていない組み合わせから最難関だけを集める
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';

class World {
  const World(this.no, this.name, this.count, this.accepts,
      {this.island = false, this.maxPar = 23, this.maxExtras = 2, this.intro = true});
  final int no;
  final String name;
  final int count;
  final bool Function(Map<Role, int>) accepts;
  final bool island;
  final int maxPar;

  /// 警官・囚人以外の役を何種類まで混ぜてよいか。
  final int maxExtras;

  /// 1面目を易しい導入面にするか。
  final bool intro;
}

int n(Map<Role, int> c, Role r) => c[r] ?? 0;
bool none(Map<Role, int> c, List<Role> rs) => rs.every((r) => n(c, r) == 0);

final worlds = [
  World(1, '川べり', 12, (c) => none(c, [Role.chief, Role.dog, Role.boss, Role.cuffed])),
  World(2, '看守長', 15, (c) => n(c, Role.chief) > 0 && none(c, [Role.dog, Role.boss, Role.cuffed])),
  World(3, '手錠', 15, (c) => n(c, Role.cuffed) > 0 && none(c, [Role.dog, Role.boss])),
  World(4, 'ボス', 15, (c) => n(c, Role.boss) > 0 && none(c, [Role.dog, Role.cuffed])),
  World(5, '警察犬', 15, (c) => n(c, Role.dog) > 0, maxExtras: 3),
  World(6, '中州', 15, (c) => none(c, [Role.dog, Role.boss]), island: true, maxPar: 26),
  World(7, '総力戦', 15, (c) => [Role.chief, Role.dog, Role.boss, Role.cuffed].where((r) => n(c, r) > 0).length >= 2,
      island: true, maxPar: 30, maxExtras: 3),
];
const extremeCount = 18; // 舞台8「鬼門」

class Cand {
  Cand(this.cast, this.cap, this.island, this.a, this.reversals);
  final Map<Role, int> cast;
  final int cap;
  final bool island;
  final Analysis a;
  final int reversals;
  double walk = 0;
  int get people => cast.entries.fold(0, (s, e) => s + e.value * e.key.seats);
  int get roles => cast.values.where((x) => x > 0).length;
  String get key => '${Role.values.map((r) => n(cast, r)).join(',')}|$cap|$island';

  /// ランダム歩きを回す前の、安い見積もり（盤面の数と戻しの回数）。
  double get proxy => log(a.reachable) / ln2 + reversals * 1.5 - log(a.optimalCount) / ln2 * 0.4 + a.par! * 0.15;
  // 長い面は（解が何通りあっても）疲れるので、最短回数も少し足して後ろ寄りにする
  double get score => log(walk) / ln2 + reversals * 1.5 - log(a.optimalCount) / ln2 * 0.4 + a.par! * 0.15;
  String get castText => Role.values.where((r) => n(cast, r) > 0).map((r) => '${r.label}${n(cast, r)}').join(' ');
}

Iterable<Map<Role, int>> casts(int maxExtras) sync* {
  for (var p = 0; p <= 6; p++) {
    for (var k = 0; k <= 2; k++) {
      for (var d = 0; d <= 2; d++) {
        if (p + k == 0 || p + k + d > 6) continue;
        for (var c = 0; c <= 6; c++) {
          for (var bo = 0; bo <= 2; bo++) {
            for (var h = 0; h <= 2; h++) {
              // 囚人側の列は6人分まで（手錠の2人は2人分の幅）
              if (c + bo + h == 0 || c + bo + 2 * h > 6) continue;
              if ([k, d, bo, h].where((x) => x > 0).length > maxExtras) continue;
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

double randomWalk(Cand c, Random rng) {
  const runs = 80, limit = 30000;
  var total = 0;
  for (var i = 0; i < runs; i++) {
    var b = Board.start(c.cast);
    var steps = 0;
    while (!b.solved && steps < limit) {
      final ms = legalMoves(b, capacity: c.cap, island: c.island).toList();
      b = b.apply(ms[rng.nextInt(ms.length)]);
      steps++;
    }
    total += steps;
  }
  return total / runs;
}

List<Cand> solveAll({required bool island, required int maxExtras, required int maxPar, bool Function(Map<Role, int>)? accepts}) {
  final out = <Cand>[];
  for (final cast in casts(maxExtras)) {
    if (accepts != null && !accepts(cast)) continue;
    for (var cap = 2; cap <= 4; cap++) {
      if (n(cast, Role.cuffed) > 0 && cap < 3) continue;
      final a = analyze(Board.start(cast), capacity: cap, island: island);
      final par = a.par;
      if (par == null || par < 3 || par > maxPar) continue;
      final rev = reversals(a.path!);
      // 直感に反する手が1つも無いのに長い面は、作業になるだけなので外す
      if (rev == 0 && par > 11) continue;
      out.add(Cand(cast, cap, island, a, rev));
    }
  }
  return out;
}

/// 同じ最短回数・定員・戻しの回数・役の組なら、人数の少ない方だけ残す。
List<Cand> dedupe(List<Cand> cs) {
  final best = <String, Cand>{};
  for (final c in cs) {
    final k = '${c.a.par}|${c.cap}|${c.reversals}|${Role.values.map((r) => n(c.cast, r) > 0 ? 1 : 0).join()}';
    final cur = best[k];
    if (cur == null || c.people < cur.people) best[k] = c;
  }
  return best.values.toList();
}

void main(List<String> args) {
  final dry = args.contains('--dry-run');
  final rng = Random(20260926);
  final levels = <Level>[];
  final used = <String>{};

  void emit(int world, String name, List<Cand> picked, int poolSize) {
    print('\n== $world $name  候補$poolSize → ${picked.length}面');
    for (var i = 0; i < picked.length; i++) {
      final c = picked[i];
      final id = '$world-${i + 1}';
      used.add(c.key);
      levels.add(Level(id: id, world: world, cast: c.cast, capacity: c.cap, island: c.island, par: c.a.par!));
      print('${id.padRight(5)} ${c.castText.padRight(26)} 定員${c.cap}${c.island ? ' 中州' : '    '}  最短${c.a.par.toString().padLeft(2)}'
          '  戻し${c.reversals.toString().padLeft(2)}  迷い${c.walk.toStringAsFixed(0).padLeft(5)}  解${c.a.optimalCount}  盤面${c.a.reachable}');
    }
  }

  for (final w in worlds) {
    // 迷いやすさの計測は重いので、安い見積もりで上位だけに絞ってから回す
    final all = dedupe(solveAll(island: w.island, maxExtras: w.maxExtras, maxPar: w.maxPar, accepts: w.accepts))
        .where((c) => !used.contains(c.key)) // 前の舞台で使った組み合わせは使わない
        .toList()
      ..sort((x, y) => x.proxy.compareTo(y.proxy));
    final keep = all.length <= 70 ? all : [...all.take(8), ...all.skip(all.length - 62)];
    for (final c in keep) {
      c.walk = randomWalk(c, rng);
    }
    keep.sort((x, y) => x.score.compareTo(y.score));
    final picked = <Cand>[];
    if (w.intro) {
      final minPar = keep.map((c) => c.a.par!).reduce(min);
      picked.add((keep.where((c) => c.a.par == minPar).toList()
            ..sort((x, y) => x.roles != y.roles ? x.roles.compareTo(y.roles) : x.people.compareTo(y.people)))
          .first);
    }
    // 残りは難しい側の4分の3から、難しさの順に間を空けて拾う（易しい4分の1は使わない）
    final rest = keep.where((c) => !picked.contains(c)).toList();
    final need = w.count - picked.length;
    final from = (rest.length * 0.25).floor();
    for (var i = 0; i < need; i++) {
      var idx = from + ((rest.length - 1 - from) * (need == 1 ? 1 : i / (need - 1))).round();
      while (idx < rest.length && picked.contains(rest[idx])) {
        idx++;
      }
      if (idx >= rest.length) idx = rest.lastIndexWhere((c) => !picked.contains(c));
      if (idx < 0) break;
      picked.add(rest[idx]);
    }
    // 導入面は先頭のまま、残りを易しい順に並べる
    final head = w.intro ? picked.take(1).toList() : <Cand>[];
    final tail = picked.skip(head.length).toList()..sort((x, y) => x.score.compareTo(y.score));
    picked
      ..clear()
      ..addAll([...head, ...tail]);
    emit(w.no, w.name, picked, all.length);
  }

  // 舞台8「鬼門」: まだ使っていない組み合わせから、中州なし・中州ありの最難関を半分ずつ
  final extreme = <Cand>[];
  for (final island in [false, true]) {
    final all = dedupe(solveAll(island: island, maxExtras: 3, maxPar: island ? 30 : 23))
        .where((c) => !used.contains(c.key))
        .toList()
      ..sort((x, y) => y.proxy.compareTo(x.proxy));
    final top = all.take(40).toList();
    for (final c in top) {
      c.walk = randomWalk(c, rng);
    }
    top.sort((x, y) => y.score.compareTo(x.score));
    extreme.addAll(top.take(extremeCount ~/ 2));
  }
  extreme.sort((x, y) => x.score.compareTo(y.score));
  emit(8, '鬼門', extreme, extreme.length);

  if (!dry) {
    const enc = JsonEncoder.withIndent('  ');
    File('assets/levels.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('${enc.convert({'version': 2, 'levels': levels.map((l) => l.toJson()).toList()})}\n');
    print('\nassets/levels.json に ${levels.length} 面を書いた');
  }
}
