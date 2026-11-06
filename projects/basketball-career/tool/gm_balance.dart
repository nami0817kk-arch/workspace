// ignore_for_file: avoid_print
// 自動で遊ぶGMで、始め方ごとの優勝・解任の割合を測る。
//   dart run tool/gm_balance.dart [回数]
import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';

void main(List<String> args) {
  final n = args.isEmpty ? 200 : int.parse(args[0]);
  for (final trades in [false, true]) {
    for (final sc in Scenario.values) {
      var titles = 0, anyTitle = 0, fired = 0, seasons = 0, wins = 0, finals = 0;
      final firstSeasonWins = <int>[];
      for (var i = 0; i < n; i++) {
        final c = botPlayCareer(1000 + i, sc, trades: trades);
        titles += c.titles;
        if (c.titles > 0) anyTitle++;
        if (c.fired) fired++;
        seasons += c.history.length;
        wins += c.history.fold(0, (s, h) => s + h.wins);
        finals += c.history.where((h) => h.result >= 2).length;
        if (c.history.isNotEmpty) firstSeasonWins.add(c.history.first.wins);
      }
      firstSeasonWins.sort();
      print('${trades ? "申し込みを受ける" : "素朴"} ${sc.label}: 1回でも優勝 ${(anyTitle * 100 / n).toStringAsFixed(0)}%'
          ' 優勝/任期 ${(titles / n).toStringAsFixed(2)} 決勝/任期 ${(finals / n).toStringAsFixed(2)}'
          ' 解任 ${(fired * 100 / n).toStringAsFixed(0)}% 平均年数 ${(seasons / n).toStringAsFixed(1)}'
          ' 平均勝ち ${(wins / seasons).toStringAsFixed(1)} 1年目の勝ち(中央) ${firstSeasonWins[firstSeasonWins.length ~/ 2]}');
    }
  }
}
