// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

/// 指定の段階まで進めた保存データ(JSON)を出す。画面確認用。
/// 使い方: dart run tool/dump_save.dart [stage名: youth, juniorHigh, highSchool, pro, retired] [seed]
void main(List<String> a) {
  final stage = a.isEmpty ? 'pro' : a[0];
  final seed = a.length > 1 ? int.parse(a[1]) : 5;
  final g = Game.newGame(
      name: 'ユウタ', role: Role.pitcher, rng: Random(seed), potential: 90);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 4000) {
    if (stage == 'pathChoice' && g.phase == Phase.pathChoice) {
      break;
    }
    if (stage != 'retired' &&
        g.phase == Phase.term &&
        g.stage.name == stage &&
        g.slot == 5) {
      break;
    }
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(
            g.condition.fatigue >= 60 ? Plan.rest : Plan.train, Ability.stuff);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  print(jsonEncode(g.toJson()));
}
