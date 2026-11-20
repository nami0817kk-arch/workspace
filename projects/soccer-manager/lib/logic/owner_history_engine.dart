import '../l10n/tr.dart';
import '../models/owner_legacy.dart';

/// 5か年計画の野心の度合い。
enum PlanAmbition { steady, standard, bold }

extension PlanAmbitionInfo on PlanAmbition {
  String get label => switch (this) {
        PlanAmbition.steady => Tr.pick('堅実', 'Steady'),
        PlanAmbition.standard => Tr.pick('標準', 'Standard'),
        PlanAmbition.bold => Tr.pick('野心的', 'Bold'),
      };

  /// 何部上がるか。
  int get tiersUp => switch (this) {
        PlanAmbition.steady => 1,
        PlanAmbition.standard => 2,
        PlanAmbition.bold => 3,
      };

  /// クラブ価値を何倍にするか。
  double get valueMultiple => switch (this) {
        PlanAmbition.steady => 1.3,
        PlanAmbition.standard => 1.6,
        PlanAmbition.bold => 2.0,
      };

  /// スタジアムを何段上げるか。
  int get stadiumUp => switch (this) {
        PlanAmbition.steady => 1,
        PlanAmbition.standard => 2,
        PlanAmbition.bold => 3,
      };
}

/// 歴代のオーナーの1人(順位表の1行)。
class OwnerRankRow {
  final String name;
  final int score;
  final bool isYou;
  const OwnerRankRow(this.name, this.score, {this.isYou = false});
}

/// 5か年計画とオーナーの順位の決まり。
class OwnerHistoryEngine {
  const OwnerHistoryEngine._();

  /// 計画の年数。
  static const int planSeasons = 5;

  /// 計画の結果(果たした目標の数 0〜3)による、株主の期待の増減。
  static int planResultDelta(int met) => switch (met) {
        3 => 15,
        2 => 5,
        1 => -5,
        _ => -12,
      };

  /// オーナーとしての点。リーグ優勝30・カップ10・1季2、最高順位が
  /// 1位なら+10、3位以内なら+5。
  static int score(OwnerLegacy l) =>
      l.leagueTitles * 30 +
      l.cupTitles * 10 +
      l.seasons * 2 +
      (l.bestRank == 1 ? 10 : (l.bestRank > 0 && l.bestRank <= 3 ? 5 : 0));

  /// 歴代の名オーナー(作り物。実在しない)。点の高い順。
  static List<OwnerRankRow> get legends => [
        OwnerRankRow(Tr.pick('鉄鋼王 ガルシア', 'Steel baron Garcia'), 320),
        OwnerRankRow(Tr.pick('海運のロッシ', 'Shipping magnate Rossi'), 250),
        OwnerRankRow(Tr.pick('石油のハミルトン', 'Oilman Hamilton'), 190),
        OwnerRankRow(Tr.pick('醸造家ミュラー', 'Brewer Muller'), 140),
        OwnerRankRow(Tr.pick('不動産のデュボワ', 'Property king Dubois'), 100),
        OwnerRankRow(Tr.pick('地元の名士 サントス', 'Local worthy Santos'), 70),
        OwnerRankRow(Tr.pick('IT長者 ノヴァク', 'Tech founder Novak'), 45),
        OwnerRankRow(Tr.pick('市民クラブの組合', 'The supporters\' trust'), 25),
      ];

  /// あなたを入れた順位表(点の高い順)。
  static List<OwnerRankRow> table(int yourScore) {
    final rows = [
      ...legends,
      OwnerRankRow(Tr.pick('あなた', 'You'), yourScore, isYou: true),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }
}
