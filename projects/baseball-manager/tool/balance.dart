// バランス調整用: 方針を決めて何人も遊ばせ、結果の分布を見る。
//
//   dart run tool/balance.dart            # 全方針
//   dart run tool/balance.dart 3000       # 人数を指定
//
// 「平凡」は練習と休養だけ、「上手い」は特訓・コーチ・交流・弱い能力の底上げを使う。
// 実際の遊び方は両者の間〜上のはず。数字を変えたら、ここで分布を確かめる。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/characters.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

typedef Policy = void Function(Game g);

void plain(Game g) {
  g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
      abilitiesOf(g.player.role).first);
}

void skilled(Game g) {
  final abilities = abilitiesOf(g.player.role);
  // いちばん低い能力を重点にする(総合評価は平均なので、底上げが効率的)。
  final focus = ([...abilities]
        ..sort((a, b) => g.player.of(a).compareTo(g.player.of(b))))
      .first;
  final c = g.condition;
  final Plan plan;
  if (c.fatigue >= 70) {
    plan = Plan.rest;
  } else if (c.morale < 35) {
    plan = Plan.social;
  } else if (g.cast.coach != null &&
      g.cast.coach!.tips < tipsNeeded &&
      g.slot % 3 == 0) {
    plan = Plan.lesson;
  } else if (c.fatigue < 30) {
    plan = Plan.special;
  } else {
    plan = Plan.train;
  }
  g.choose(plan, focus);
}

class Result {
  Result(this.madePro, this.proYears, this.peak, this.title, this.twoWay);
  final bool madePro;
  final int proYears;
  final int peak;
  final String title;
  final bool twoWay;
}

Result play(int seed, Policy policy, Role role) {
  final g = Game.newGame(name: 't', role: role, rng: Random(seed));
  var steps = 0;
  while (g.phase != Phase.retired) {
    if (++steps > 6000) throw StateError('終わらない seed=$seed');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        if (g.stage == Stage.pro && g.player.age >= 36) {
          g.retire();
        } else {
          policy(g);
        }
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  final e = g.ending!;
  return Result(e.madePro, e.proYears, e.peakOverall, e.title, e.wasTwoWay);
}

void main(List<String> args) {
  final n = args.isEmpty ? 1500 : int.parse(args.first);
  for (final entry in {'平凡': plain, '上手い': skilled}.entries) {
    for (final role in [Role.batter, Role.pitcher]) {
      final rs = [for (var s = 0; s < n; s++) play(s, entry.value, role)];
      final pro = rs.where((r) => r.madePro).toList();
      final titles = <String, int>{};
      for (final r in rs) {
        titles.update(r.title, (v) => v + 1, ifAbsent: () => 1);
      }
      String pct(int x) => (100 * x / n).toStringAsFixed(1);
      print('${entry.key} / ${role.name}: プロ入り ${pct(pro.length)}%  '
          '平均プロ年数 ${pro.isEmpty ? '-' : (pro.map((r) => r.proYears).reduce((a, b) => a + b) / pro.length).toStringAsFixed(1)}  '
          '最高評価平均 ${pro.isEmpty ? '-' : (pro.map((r) => r.peak).reduce((a, b) => a + b) / pro.length).toStringAsFixed(1)}');
      print(
          '   ${titles.entries.map((e) => '${e.key} ${pct(e.value)}%').join('  ')}');
    }
  }
}
