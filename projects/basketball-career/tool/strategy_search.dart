// ignore_for_file: avoid_print
// 方針をランダムに探して、突出して強い(=偏った)遊び方が無いかを見る。
// dart run tool/strategy_search.dart [試行数]
//
// 方針 = 各ターンで6つの過ごし方を選ぶ確率(疲れが低い/高いで別)＋重点の選び方。
// 評価 = 100人ぶんのプロ入り率・海外挑戦率・平均タイトル数。
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';

class Policy {
  Policy(this.low, this.high, this.recommended);
  final List<double> low; // 疲れ < 50 のときの6つの重み
  final List<double> high; // 疲れ >= 50
  final bool recommended; // 重点をおすすめにするか(false なら固定ローテ)

  static Policy random(Random r) => Policy(
        List.generate(6, (_) => r.nextDouble()),
        List.generate(6, (_) => r.nextDouble()),
        r.nextBool(),
      );

  Action pick(Game g, Random r) {
    final w = g.condition.fatigue < 50 ? low : high;
    var total = 0.0;
    final ok = <int>[];
    for (var i = 0; i < 6; i++) {
      if (canChoose(Action.values[i], g.condition)) {
        ok.add(i);
        total += w[i];
      }
    }
    var x = r.nextDouble() * total;
    for (final i in ok) {
      x -= w[i];
      if (x <= 0) return Action.values[i];
    }
    return Action.rest;
  }

  String describe() {
    String f(List<double> w) {
      final t = w.reduce((a, b) => a + b);
      return [
        for (var i = 0; i < 6; i++)
          '${Action.values[i].label}${(w[i] / t * 100).round()}%'
      ].join(' ');
    }

    return '低疲労[${f(low)}] 高疲労[${f(high)}] 重点${recommended ? 'おすすめ' : '固定'}';
  }
}

({double pro, double abroad, double titles}) evaluate(Policy p, int n, int seed0) {
  var pro = 0, abroad = 0, titles = 0;
  for (var k = 0; k < n; k++) {
    final r = Random(seed0 + k);
    final g = Game.start('x', rng: r);
    var guard = 0;
    var wentAbroad = false;
    while (g.phase != Phase.retired && guard++ < 500) {
      switch (g.phase) {
        case Phase.season:
          final focus = p.recommended
              ? recommendedFocus(g.player)
              : Ability.values[guard % Ability.values.length];
          g.choose(p.pick(g, r), focus);
          if (g.canGoAbroad) {
            g.goAbroad();
            wentAbroad = true;
          }
        case Phase.halftime:
          g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
        case Phase.clutch:
          g.resolveClutch(bestClutch(g.player, g.run!.pending!.oppStrength, g.run!.pending!.form));
        case Phase.event:
          g.resolveEvent(0);
        case Phase.path:
          final ok = g.chooseRoute(Route.pro);
          if (!ok && !g.retired) g.chooseRoute(Route.university);
        case Phase.retired:
          break;
      }
    }
    if (g.records.any((x) => x.league.name.startsWith('pro'))) pro++;
    if (wentAbroad) abroad++;
    titles += g.titles;
  }
  return (pro: pro / n * 100, abroad: abroad / n * 100, titles: titles / n);
}

void main(List<String> args) {
  final trials = args.isEmpty ? 40 : int.parse(args.first);
  final rng = Random(2026);
  final results = <(Policy, ({double pro, double abroad, double titles}))>[];
  for (var i = 0; i < trials; i++) {
    final p = Policy.random(rng);
    results.add((p, evaluate(p, 100, 1000)));
  }
  results.sort((a, b) => b.$2.abroad.compareTo(a.$2.abroad));
  String line((Policy, ({double pro, double abroad, double titles})) r) =>
      'プロ${r.$2.pro.round()}% 海外${r.$2.abroad.round()}% タイトル${r.$2.titles.toStringAsFixed(2)}  ${r.$1.describe()}';
  print('--- 海外挑戦率の上位5 ---');
  for (final r in results.take(5)) {
    print(line(r));
  }
  print('--- 下位3 ---');
  for (final r in results.reversed.take(3)) {
    print(line(r));
  }
  final best = results.first.$2.abroad, worst = results.last.$2.abroad;
  print('海外挑戦率の幅: ${worst.round()}% 〜 ${best.round()}%');
}
