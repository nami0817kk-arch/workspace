import '../l10n/tr.dart';
import 'division_strength.dart';

/// 評価の言葉。総合力を部ごとの強さの幅と比べて、どの部で通用するかを
/// 言葉で表す(数字だけだと、5部の70が強いのか分かりにくい)。
class RatingWords {
  /// [overall]の選手が、何部のどの立場か。
  static String forOverall(int overall) {
    if (overall >= 92) return Tr.pick('世界的な選手', 'World class');
    for (var tier = 1; tier <= 5; tier++) {
      final (lo, hi) = divisionStrengthRange(tier);
      final mid = (lo + hi) ~/ 2;
      if (overall >= mid) {
        return Tr.pick('$tier部の主力級', 'Key player in tier $tier');
      }
      if (overall >= lo) {
        return Tr.pick('$tier部で通用する', 'Good enough for tier $tier');
      }
    }
    return Tr.pick('5部でも控え', 'Squad player even in tier 5');
  }
}
