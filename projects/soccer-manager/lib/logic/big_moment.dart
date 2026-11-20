import '../l10n/tr.dart';

/// 画面いっぱいに見せる、大事な場面。
enum BigMomentKind {
  champion,
  promoted,
  relegated,
  cupWon,
  cupLost,
  recordSigning,
  recordSale,
  clubRecord,
  deadlineDay,
}

extension BigMomentInfo on BigMomentKind {
  /// 絵(assets/art)。
  String get asset => switch (this) {
        BigMomentKind.champion => 'assets/art/championship.jpg',
        BigMomentKind.promoted => 'assets/art/promotion.jpg',
        BigMomentKind.relegated => 'assets/art/relegation.jpg',
        BigMomentKind.cupWon => 'assets/art/championship.jpg',
        BigMomentKind.cupLost => 'assets/art/cup_final.jpg',
        BigMomentKind.recordSigning => 'assets/art/record_signing.jpg',
        BigMomentKind.recordSale => 'assets/art/forced_sale.jpg',
        BigMomentKind.clubRecord => 'assets/art/club_record.jpg',
        BigMomentKind.deadlineDay => 'assets/art/record_signing.jpg',
      };

  /// 大きな見出し。
  String get headline => switch (this) {
        BigMomentKind.champion => Tr.pick('優勝決定', 'Champions'),
        BigMomentKind.promoted => Tr.pick('昇格決定', 'Promoted'),
        BigMomentKind.relegated => Tr.pick('降格決定', 'Relegated'),
        BigMomentKind.cupWon => Tr.pick('カップ優勝', 'Cup winners'),
        BigMomentKind.cupLost => Tr.pick('決勝で敗れる', 'Beaten in the final'),
        BigMomentKind.recordSigning =>
          Tr.pick('クラブ史上最高額の獲得', 'Club record signing'),
        BigMomentKind.recordSale =>
          Tr.pick('クラブ史上最高額の売却', 'Club record sale'),
        BigMomentKind.clubRecord => Tr.pick('クラブ記録を更新', 'A new club record'),
        BigMomentKind.deadlineDay => Tr.pick('移籍の締切日', 'Deadline day'),
      };
}

/// 優勝・昇格・降格が数字の上で決まったかを見る。
class ClinchEngine {
  /// [rows]は(クラブ id, 今の勝ち点, 残り試合数)。自クラブ[userId]が、
  /// 上から[n]位以内を確実にしたか(残りを全部勝っても、自クラブに
  /// 届くクラブが n-1 以下)。
  static bool clinchedTop(
      List<(String, int, int)> rows, String userId, int n) {
    final me = rows.where((r) => r.$1 == userId).firstOrNull;
    if (me == null || n <= 0) return false;
    final threats = rows
        .where((r) => r.$1 != userId && r.$2 + 3 * r.$3 >= me.$2)
        .length;
    return threats < n;
  }

  /// 自クラブが下から[n]位以内(降格)を避けられなくなったか(残りを全部
  /// 勝っても、上にいるクラブが「全体 − n」以上ある)。
  static bool doomedBottom(
      List<(String, int, int)> rows, String userId, int n) {
    final me = rows.where((r) => r.$1 == userId).firstOrNull;
    if (me == null || n <= 0) return false;
    final best = me.$2 + 3 * me.$3;
    final above = rows.where((r) => r.$1 != userId && r.$2 > best).length;
    return above >= rows.length - n;
  }
}
