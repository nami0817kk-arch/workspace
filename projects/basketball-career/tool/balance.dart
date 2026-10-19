// ignore_for_file: avoid_print
// バランスの目安を出す: dart run tool/balance.dart
// 練習中心(疲れたら休養)で 1000 人を最後まで進め、進路と結末の割合を数える。
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';

void main(List<String> args) {
  const n = 1000;
  final smart = args.contains('--smart');
  final spec = args.contains('--spec');
  var pro = 0, direct = 0, abroad = 0, titles = 0, rw = 0, rl = 0;
  var ovrAt18 = 0.0, heightAt18 = 0.0;
  for (var seed = 0; seed < n; seed++) {
    final g = Game.start('x', rng: Random(seed));
    var guard = 0;
    var seen18 = false;
    while (g.phase != Phase.retired && guard++ < 500) {
      if (!seen18 && g.player.age == 18) {
        seen18 = true;
        ovrAt18 += g.player.overall;
        heightAt18 += g.player.heightCm;
      }
      switch (g.phase) {
        case Phase.season:
          final rest = g.condition.fatigue >= 60 || g.condition.injured;
          // 重点は今いちばん低い能力ではなく、ポジションに効く能力を順に回す。
          if (spec) {
            // ポジションに効く能力のうち、重み×(100-今の値)がいちばん大きいものを重点にする。
            final w = weightsOf(g.player.position);
            final focus = w.keys.reduce((a, b) =>
                w[a]! * (100 - g.player.of(a)) >= w[b]! * (100 - g.player.of(b))
                    ? a
                    : b);
            final act = rest
                ? Action.rest
                : (g.condition.fatigue < 25 ? Action.intense : Action.practice);
            g.choose(act, focus);
          } else if (smart) {
            // 一番低い能力を重点にし、疲れが軽いうちは特訓を混ぜる。
            final low = Ability.values.reduce(
                (a, b) => g.player.of(a) <= g.player.of(b) ? a : b);
            final act = rest
                ? Action.rest
                : (g.condition.fatigue < 25 ? Action.intense : Action.practice);
            g.choose(act, low);
          } else {
            g.choose(rest ? Action.rest : Action.practice,
                Ability.values[guard % Ability.values.length]);
          }
          if (g.canGoAbroad) {
            g.goAbroad();
            abroad++;
          }
        case Phase.clutch:
          g.resolveClutch(bestClutch(g.player, g.run!.pending!.oppStrength, g.run!.pending!.form));
        case Phase.event:
          g.resolveEvent(0);
        case Phase.path:
          final first = !g.secondChance;
          final ok = g.chooseRoute(Route.pro);
          if (ok && first) direct++;
          if (!ok && !g.retired) g.chooseRoute(Route.university);
        case Phase.retired:
          break;
      }
    }
    if (g.records.any((r) => r.league.name.startsWith('pro'))) pro++;
    titles += g.titles;
    rw += g.rival.wins;
    rl += g.rival.losses;
  }
  String pct(int v) => '${(v / n * 100).toStringAsFixed(1)}%';
  print('プロ入り: ${pct(pro)}(高校から直接 ${pct(direct)})');
  print('海外挑戦: ${pct(abroad)}');
  print('ライバルとの通算: ${(rw / n).toStringAsFixed(1)}勝 ${(rl / n).toStringAsFixed(1)}敗(1人あたり)');
  print('平均タイトル数: ${(titles / n).toStringAsFixed(2)}');
  print('18歳の平均 総合 ${(ovrAt18 / n).toStringAsFixed(1)} / 身長 ${(heightAt18 / n).toStringAsFixed(1)}cm');
}
