// ignore_for_file: avoid_print
import 'dart:math';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';

void main() {
  final rng = Random(3);
  for (final role in [Role.batter, Role.pitcher]) {
    for (final v in [40, 60, 80, 95]) {
      for (final (opp, label) in [
        (30, '小学'),
        (45, '中学'),
        (60, '高校'),
        (70, 'プロ')
      ]) {
        final p =
            Player(name: 't', role: role, age: 11, potential: 80, abilities: {
          for (final a in Ability.values) a: v,
        });
        var l = const Line();
        for (var i = 0; i < 1500; i++) {
          l += playGame(p, opp, rng);
        }
        final g = l.games;
        if (role == Role.batter) {
          print(
              '打者 全$v vs $label($opp): 打率 ${(l.hits / l.atBats).toStringAsFixed(3)} HR/試合 ${(l.homeRuns / g).toStringAsFixed(2)} 四球/試合 ${(l.walks / g).toStringAsFixed(2)}');
        } else {
          print(
              '投手 全$v vs $label($opp): 被安打/試合 ${(l.hitsAllowed / g).toStringAsFixed(1)} 奪三振/試合 ${(l.strikeouts / g).toStringAsFixed(1)} 防御率 ${(l.runsAllowed * 27 / l.outs).toStringAsFixed(2)}');
        }
      }
    }
  }
}
