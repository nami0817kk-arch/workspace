// ignore_for_file: avoid_print
// カードの試合の釣り合いを測る。自動で遊ぶ人(lib/deck/bot.dart)に何シーズンも遊ばせて数える。
// 使い方: dart run tool/deck_balance.dart [シーズン数] [難しさ]
import 'package:basketball_career/deck/bot.dart';
import 'package:basketball_career/deck/run.dart';

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 400;
  final dif = args.length > 1 ? int.parse(args[1]) : 0;
  var champs = 0;
  final reached = List.filled(3, 0);
  var games = 0, wins = 0, mineSum = 0, theirsSum = 0, deckSize = 0, mateSum = 0;
  final stageGames = List.filled(3, 0), stageWins = List.filled(3, 0);
  final bossGames = List.filled(3, 0), bossWins = List.filled(3, 0);
  for (var i = 0; i < n; i++) {
    final r = RunState(seed: 1000 + i * 7919, difficulty: dif);
    for (var steps = 0; steps < 500 && !r.over; steps++) {
      if (r.phase == Phase.battle) {
        final b = r.battle!;
        final boss = r.current == NodeType.boss;
        final st = r.stage;
        botPlayBattle(b);
        games++;
        stageGames[st]++;
        if (boss) bossGames[st]++;
        mineSum += b.mine;
        theirsSum += b.theirs;
        if (b.won) {
          wins++;
          stageWins[st]++;
          if (boss) bossWins[st]++;
        }
      }
      botStep(r);
    }
    reached[r.stage]++;
    if (r.champion) champs++;
    deckSize += r.deck.length;
    mateSum += r.mates.length;
  }
  String pct(int a, int b) => b == 0 ? '-' : '${(a * 100 / b).toStringAsFixed(0)}%';
  print('シーズン $n 回(難しさ $dif)');
  print('優勝 ${pct(champs, n)}  最後にいた大会: 地区予選 ${reached[0]} / 県大会 ${reached[1]} / 全国 ${reached[2]}');
  print('試合 $games  勝率 ${pct(wins, games)}  平均点 ${(mineSum / games).toStringAsFixed(1)} - ${(theirsSum / games).toStringAsFixed(1)}');
  for (var s = 0; s < 3; s++) {
    print('  ${['地区予選', '県大会', '全国大会'][s]}: 勝率 ${pct(stageWins[s], stageGames[s])}  決勝 ${pct(bossWins[s], bossGames[s])} (${bossGames[s]}試合)');
  }
  print('最後のデッキ平均 ${(deckSize / n).toStringAsFixed(1)} 枚・仲間 ${(mateSum / n).toStringAsFixed(1)} 人');
}
