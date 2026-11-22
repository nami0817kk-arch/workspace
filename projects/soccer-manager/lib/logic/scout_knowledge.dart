import '../l10n/tr.dart';
import 'economy_scale.dart';

/// 他のクラブの選手が「どれだけ見えているか」(0〜100%)の決まり。
///
/// - 自クラブの選手は全部見える(100%)。
/// - 同じ部のクラブの選手は、試合で見ているので最初から[sameLeagueBase]%。
/// - それ以外は0%から。スカウトを送った地域(国と部)の選手は、毎週
///   [weeklyGain]ずつ見えてくる。注目リストの選手は、どこにいても毎週
///   [watchWeeklyGain]ずつ見えてくる。
/// - 見えているほど、総合力・伸びしろの幅が狭い。0%なら数字は出ない
///   (年齢・ポジション・所属・市場価値の目安だけ)。
class ScoutKnowledge {
  const ScoutKnowledge._();

  static const int sameLeagueBase = 30;

  /// 監督が補強の案に挙げるのに要る見え方。
  static const int proposalMinimum = 30;

  static const int watchWeeklyGain = 5;

  /// 送れる地域の数。スカウトの見極めの力(1〜8)で1〜3か所。
  static int slotsFor(int judgingLevel) =>
      1 + (judgingLevel >= 4 ? 1 : 0) + (judgingLevel >= 7 ? 1 : 0);

  /// 送った地域で、1週に見えてくる量(%)。見極めの力1で10、8で24。
  static int weeklyGain(int judgingLevel) => 8 + 2 * judgingLevel;

  /// 1か所あたりの1週の出張費(万円)。上の部ほど高い(5部で3万円)。
  static int weeklyTripCost(int tier) => scaleMoneyForTier(tier, 3);

  /// 見立ての振れ幅(±いくつ)。0%は数字を出さないので使わない。
  static int uncertainty(int knowledge) =>
      knowledge >= 100 ? 0 : ((100 - knowledge) * 12 / 100).ceil();

  /// [trueValue]の見立ての幅。見えていなければ null。
  ///
  /// 幅の真ん中は本当の値から少しずれる(ずれは選手ごとに決まっていて、
  /// 本当の値は必ず幅の中に入る)。真ん中が本当の値だと、幅を見ただけで
  /// 答えが分かってしまう。
  static (int, int)? range(int trueValue, int knowledge, String id, int salt) {
    if (knowledge <= 0) return null;
    final u = uncertainty(knowledge);
    if (u == 0) return (trueValue, trueValue);
    final c = trueValue + centerOffset(id, salt, u);
    return ((c - u).clamp(1, 99), (c + u).clamp(1, 99));
  }

  /// 幅±[u]の見立ての、真ん中のずれ(-u/2〜+u/2)。選手の[id]と[salt]で
  /// 決まるので、見るたびに変わらない。ずれが幅の半分以下なので、本当の値は
  /// 必ず幅の中に入る。ユースの見立て(ScoutingEngine
  /// .estimatedPotentialRange)も同じずらし方を使う。
  static int centerOffset(String id, int salt, int u) =>
      _seed(id, salt) % (u + 1) - u ~/ 2;

  /// 幅の真ん中(並べ替えに使う)。見えていなければ -1。
  static int center((int, int)? r) => r == null ? -1 : (r.$1 + r.$2) ~/ 2;

  /// 幅の表示。「76〜79」/ "76-79"。見えていなければ「?」。
  static String label((int, int)? r) {
    if (r == null) return '?';
    if (r.$1 == r.$2) return '${r.$1}';
    return Tr.pick('${r.$1}〜${r.$2}', '${r.$1}-${r.$2}');
  }

  static int _seed(String id, int salt) {
    var h = 41 + salt * 977;
    for (final c in id.codeUnits) {
      h = (h * 53 + c) & 0x3fffffff;
    }
    return h;
  }
}
