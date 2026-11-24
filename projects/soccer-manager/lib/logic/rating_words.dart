import '../l10n/tr.dart';
import '../models/league.dart';
import 'division_strength.dart';

/// 評価の言葉。総合力を部ごとの強さの幅と比べて、どの部で通用するかを
/// 言葉で表す(数字だけだと、3部の70が強いのか分かりにくい)。
class RatingWords {
  /// [overall]の選手が、何部のどの立場か。
  static String forOverall(int overall) {
    if (overall >= 92) return Tr.pick('世界的な選手', 'World class');
    for (var tier = 1; tier <= totalDivisionTiers; tier++) {
      final (lo, hi) = divisionStrengthRange(tier);
      final mid = (lo + hi) ~/ 2;
      if (overall >= mid) {
        return Tr.pick('$tier部の主力級', 'Key player in Tier $tier');
      }
      if (overall >= lo) {
        return Tr.pick('$tier部で通用する', 'Good enough for Tier $tier');
      }
    }
    return Tr.pick('$totalDivisionTiers部でも控え',
        'Squad player even in Tier $totalDivisionTiers');
  }

  /// 伸びしろの段(0〜3)。総合力が潜在能力のどこまで来ているかで決める
  /// (数字の潜在能力は見せない。FM の星と同じく、言葉で見立てを出す)。
  static int growthRoomLevel(int overall, int potential) {
    if (potential <= 0) return 0;
    final reached = overall / potential * 100;
    if (reached >= 95) return 0;
    if (reached >= 85) return 1;
    if (reached >= 70) return 2;
    return 3;
  }

  /// 伸びしろの言葉(長い形。詳しい画面で使う)。
  static String growthRoom(int overall, int potential) =>
      switch (growthRoomLevel(overall, potential)) {
        0 => Tr.pick('ほぼ上限', 'Almost none'),
        1 => Tr.pick('少しある', 'A little'),
        2 => Tr.pick('まだ伸びる', 'Still improving'),
        _ => Tr.pick('大きい', 'Plenty'),
      };

  /// 伸びしろの言葉(表の1マス用の短い形)。
  static String growthRoomShort(int overall, int potential) =>
      switch (growthRoomLevel(overall, potential)) {
        0 => Tr.pick('なし', 'None'),
        1 => Tr.pick('小', 'Low'),
        2 => Tr.pick('中', 'Some'),
        _ => Tr.pick('大', 'High'),
      };

  /// 調子の段(0〜3)。直近の採点の平均から。出ていなければ null。
  /// 採点は 6.0 が基準で、勝ち負けで ±0.4、得点で +1(MatchEngine)。
  static int? formLevel(double? avg) {
    if (avg == null) return null;
    if (avg >= 7.0) return 3;
    if (avg >= 6.4) return 2;
    if (avg >= 5.8) return 1;
    return 0;
  }

  /// 調子の言葉。出ていなければ「—」。
  static String form(double? avg) => switch (formLevel(avg)) {
        null => '—',
        3 => Tr.pick('絶好調', 'Superb'),
        2 => Tr.pick('好調', 'Good'),
        1 => Tr.pick('ふつう', 'Okay'),
        _ => Tr.pick('不調', 'Poor'),
      };
}
