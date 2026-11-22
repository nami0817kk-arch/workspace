/// 国の係数。大陸大会での各国のクラブの成績を5季ぶん足し、上位の国ほど
/// 大陸大会に出られるクラブが多い(実在の UEFA の係数と同じ考え方)。
class CountryCoefficientEngine {
  /// 足し合わせる季の数。
  static const int seasons = 5;

  /// 係数の順位(1位から)ごとのチャンピオンズカップの出場枠。実在の数に
  /// 合わせた(2026-11-22。それまでは 4/4/3/2/2): 1・2位 5枠(イングランド・
  /// スペインにあたる)、3・4位 4枠(ドイツ・イタリア)、5位 3枠(フランス)。
  /// 係数の順位が入れ替われば枠も入れ替わる。
  static int spotsForRank(int rank) => switch (rank) {
        1 || 2 => 5,
        3 || 4 => 4,
        _ => 3,
      };

  /// ヨーロッパカップ(EL にあたる)の出場枠。どの国も2: リーグで CL の
  /// 枠のすぐ下の1クラブと、国内カップの優勝クラブ(すでに CL に出るなら、
  /// リーグの次の順位のクラブ)。
  static const int europaSpots = 2;

  /// 季の記録が無い国の係数の元(5季ぶんのうち4季)。ゲームを始めた時点で
  /// 実在の順位(イングランド > スペイン > ドイツ > イタリア > フランス)に
  /// なるように置く。数えた季が増えると古いものから落ちる。
  static List<double> seedHistory(String themeName) {
    final v = switch (themeName) {
      'england' => 9.0,
      'spain' => 8.5,
      'germany' => 7.5,
      'italy' => 7.0,
      _ => 6.0,
    };
    return List.filled(seasons - 1, v);
  }

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
