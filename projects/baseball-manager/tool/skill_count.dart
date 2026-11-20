// 少年・中学・高校の終わりまでに、特殊能力をいくつ取れるかを数える。
//
//   dart run tool/skill_count.dart 300
//
// 方針A「特殊能力も使う」: balance.dart と同じ(4回に1回研究、コツ3以上で取る、残りは能力へ)。
// 方針B「特殊能力に全部」: 経験点はすべて特殊能力に使う(安いものから)。能力には振らない。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/skills.dart';

import 'balance.dart' show skillUser;

int _owned(Game g) => g.player.skills.where((k) => !k.negative).length;

void _buyA(Game g) {
  for (final s in weaknessesFor(g.player.role)) {
    if (g.player.skills.contains(s)) g.buySkill(s);
  }
  for (final s in skillsFor(g.player.role)) {
    // 割に合う値段のときだけ(持つほど・年をとるほど高くなるので、高すぎるものは見送る)
    if (((g.skillTips[s] ?? 0) >= 3 || s.gold) && g.skillPrice(s) <= s.baseCost) {
      g.buySkill(s);
    }
  }
  g.autoSpend();
}

void _buyB(Game g) {
  var bought = true;
  while (bought) {
    bought = false;
    final cands = [...skillsFor(g.player.role)]
      ..sort((a, b) => g.skillPrice(a).compareTo(g.skillPrice(b)));
    for (final s in cands) {
      if (g.buySkill(s) == null) {
        bought = true;
        break;
      }
    }
  }
}

void main(List<String> args) {
  final n = args.isEmpty ? 300 : int.parse(args.first);
  for (final mode in ['A 特殊能力も使う', 'B 特殊能力に全部']) {
    for (final role in [Role.batter, Role.pitcher]) {
      final at = <int, List<int>>{12: [], 15: [], 18: []};
      for (var s = 0; s < n; s++) {
        final g = Game.newGame(name: 't', role: role, rng: Random(s));
        var steps = 0;
        while (g.phase != Phase.retired && g.player.age <= 18 && ++steps < 3000) {
          if (mode.startsWith('A')) {
            _buyA(g);
          } else {
            _buyB(g);
          }
          final age = g.player.age;
          switch (g.phase) {
            case Phase.term:
              skillUser(g);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
          if (g.player.age != age && at.containsKey(age)) {
            at[age]!.add(_owned(g));
          }
        }
      }
      String stat(List<int> l) {
        if (l.isEmpty) return '-';
        l.sort();
        final avg = l.reduce((a, b) => a + b) / l.length;
        return '平均${avg.toStringAsFixed(1)} (少ない人${l[l.length ~/ 10]}〜多い人${l[l.length * 9 ~/ 10]})';
      }

      print('$mode / ${role.name}: 12歳の終わり ${stat(at[12]!)} / 15歳 ${stat(at[15]!)} / 18歳 ${stat(at[18]!)}');
    }
  }
}
