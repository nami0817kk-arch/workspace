import '../models/season.dart';

/// **自分が出た試合と、出なかった試合の成績。**
///
/// 自分が出る試合はそのぶんクラブが強い（`MatchEngine.starLift`）のに、
/// それが見える場所がどこにも無かった。順位表は全試合の合計で、
/// 怪我やベンチで抜けた試合の負けも混ざる。**居ないと勝てない**が、
/// 数字で見えると「引っ張っている」ことが分かる。
///
/// 判定には使わない。リーグ戦の結果を分けて数えるだけ。
class Impact {
  const Impact({required this.with_, required this.without});

  final Record3 with_;
  final Record3 without;

  /// 出なかった試合がこれより少ないと、比べても意味が無い。
  static const int minWithout = 2;

  bool get comparable => with_.played > 0 && without.played >= minWithout;

  static Impact of(List<MatchResult> league) {
    var w = const Record3();
    var wo = const Record3();
    for (final r in league) {
      if (r.appearance.played) {
        w = w.add(r);
      } else {
        wo = wo.add(r);
      }
    }
    return Impact(with_: w, without: wo);
  }
}

/// 勝ち・引き分け・負け。
class Record3 {
  const Record3({this.won = 0, this.drawn = 0, this.lost = 0});

  final int won;
  final int drawn;
  final int lost;

  int get played => won + drawn + lost;

  /// 1試合あたりの勝ち点（0〜3）。勝率より引き分けを拾える。
  double get pointsPerGame => played == 0 ? 0 : (won * 3 + drawn) / played;

  Record3 add(MatchResult r) => Record3(
    won: won + (r.won ? 1 : 0),
    drawn: drawn + (r.drawn ? 1 : 0),
    lost: lost + (!r.won && !r.drawn ? 1 : 0),
  );

  String get label => '$won勝$drawn分$lost敗';
}
