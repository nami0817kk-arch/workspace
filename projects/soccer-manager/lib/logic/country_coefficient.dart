/// 国の係数。大陸大会での各国のクラブの成績を5季ぶん足し、上位の国ほど
/// 大陸大会に出られるクラブが多い(実在の UEFA の係数と同じ考え方)。
class CountryCoefficientEngine {
  /// 足し合わせる季の数。
  static const int seasons = 5;

  /// 係数の順位(1位から)ごとの出場枠。
  static int spotsForRank(int rank) => switch (rank) {
        1 || 2 => 4,
        3 => 3,
        _ => 2,
      };

  /// 大陸大会の1季ぶんの点: 勝ち2・引き分け1、勝ち抜くごとに1。
  static double seasonPoints(
          {required int wins, required int draws, required int roundsWon}) =>
      wins * 2.0 + draws + roundsWon;

  /// 履歴に今季を足し、古いものを落とす。
  static List<double> push(List<double> history, double points) {
    final out = [...history, points];
    return out.length > seasons ? out.sublist(out.length - seasons) : out;
  }

  /// 係数(5季の合計)。
  static double total(List<double>? history) =>
      (history ?? const []).fold(0.0, (a, b) => a + b);
}
