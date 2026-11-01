import 'dart:math';

import 'flavor.dart' show Pos;
import 'player.dart';

/// 守備の記録(守備機会・失策・守備率)。実際の野球にある指標。
///
/// **乱数は使わない**: 守備力・ポジション・試合数から決まる値に、名前と年齢から決めた小さなばらつきを足す
/// (同じ選手の同じ年なら毎回同じ。これまでの乱数の並びや勝敗には影響しない)。投手(役割)は数えない。

/// 1試合あたりの守備機会(ポジションごとの目安)。
double chancesPerGame(Pos p) => switch (p) {
      Pos.catcher => 8.0, // 捕手は捕球が多い
      Pos.first => 8.5,
      Pos.second => 3.8,
      Pos.third => 2.6,
      Pos.shortstop => 4.2,
      Pos.left => 1.8,
      Pos.center => 2.6,
      Pos.right => 1.8,
      Pos.dh => 0.0, // 指名打者は守らない
      _ => 0.0,
    };

/// 守備力 `fielding`(0〜99)での失策率。守備力50で約1.9%、99で約0.2%、10で約3.2%。
double errorRate(int fielding) =>
    (0.035 - 0.00033 * fielding).clamp(0.002, 0.04);

/// 守備の記録。`chances` が0なら守っていない(指名打者・投手)。
class FieldingLine {
  const FieldingLine(this.chances, this.errors);
  final int chances;
  final int errors;

  /// 守備率(1 - 失策/守備機会)。守備機会が無ければ null。
  double? get pct => chances == 0 ? null : 1 - errors / chances;
}

/// その年の守備の記録。`games` は出場試合数。
FieldingLine fieldingOf({
  required Player player,
  required Pos pos,
  required int games,
  required int age,
}) {
  if (player.role == Role.pitcher) return const FieldingLine(0, 0);
  final chances = (chancesPerGame(pos) * games).round();
  if (chances == 0) return const FieldingLine(0, 0);
  final expected = chances * errorRate(player.defense);
  // 名前と年齢から決める、±約25%のばらつき(0〜1)。
  final h = (player.name.codeUnits
          .fold<int>(age * 31, (a, c) => (a * 131 + c) & 0x7fffffff)) %
      1000 /
      1000.0;
  final errors = max(0, (expected * (0.75 + 0.5 * h)).round());
  return FieldingLine(chances, min(errors, chances));
}
