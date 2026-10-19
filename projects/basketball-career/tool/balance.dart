// ignore_for_file: avoid_print
// バランスの目安を出す: dart run tool/balance.dart
// 練習中心(疲れたら休養)で 1000 人を最後まで進め、進路と結末の割合を数える。
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';

void main() {
  const n = 1000;
  var pro = 0, direct = 0, abroad = 0, titles = 0;
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
          g.choose(rest ? Action.rest : Action.practice,
              Ability.values[guard % Ability.values.length]);
          if (g.canGoAbroad) {
            g.goAbroad();
            abroad++;
          }
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
  }
  String pct(int v) => '${(v / n * 100).toStringAsFixed(1)}%';
  print('プロ入り: ${pct(pro)}(高校から直接 ${pct(direct)})');
  print('海外挑戦: ${pct(abroad)}');
  print('平均タイトル数: ${(titles / n).toStringAsFixed(2)}');
  print('18歳の平均 総合 ${(ovrAt18 / n).toStringAsFixed(1)} / 身長 ${(heightAt18 / n).toStringAsFixed(1)}cm');
}
