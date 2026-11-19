import '../l10n/tr.dart';

/// ファンの層。満足の度合いはそれぞれ別のものを見る(保存はしない)。
enum FanSegment {
  /// 昔からのサポーター。サポーターの期待そのもの。
  core,

  /// 地元と家族連れ。生え抜きが先発にいるか・入場券が手ごろか。
  local,

  /// 新しく来たファン。最近の勝ち負けと、人気の選手。
  casual,
}

extension FanSegmentInfo on FanSegment {
  String get label => switch (this) {
        FanSegment.core => Tr.pick('昔からのサポーター', 'Core supporters'),
        FanSegment.local => Tr.pick('地元・家族', 'Locals and families'),
        FanSegment.casual => Tr.pick('新しいファン', 'New fans'),
      };

  /// スタンドに占める割合。
  double get share => switch (this) {
        FanSegment.core => 0.40,
        FanSegment.local => 0.35,
        FanSegment.casual => 0.25,
      };

  String get hint => switch (this) {
        FanSegment.core => Tr.pick('成績と、クラブらしさを見ている',
            'They judge results and the club\'s identity'),
        FanSegment.local => Tr.pick('生え抜きの先発と、手ごろな入場券を喜ぶ',
            'They like homegrown starters and fair ticket prices'),
        FanSegment.casual => Tr.pick('最近の勝ちと、人気の選手に集まる',
            'They follow recent wins and star players'),
      };
}

class FanSegmentEngine {
  /// 地元・家族の満足: 先発の生え抜きの数と、入場券の値段の倍率。
  static int localMood(
          {required int homegrownStarters, required double ticketAttendance}) =>
      (35 + homegrownStarters * 6 + (ticketAttendance - 1) * 60)
          .round()
          .clamp(0, 100);

  /// 新しいファンの満足: 直近5試合の勝ち点(0〜15)と、看板選手の人気。
  static int casualMood({required int recentPoints, required int topPopularity}) =>
      (20 + recentPoints * 3 + topPopularity * 0.3).round().clamp(0, 100);

  /// 層ごとの満足を、割合で重みを付けて平均する。
  static double weighted(Map<FanSegment, int> moods) => moods.entries
      .fold(0.0, (s, e) => s + e.key.share * e.value);

  /// 観客の入りに掛ける倍率(満足55で1倍、上下5%まで)。
  static double attendanceModifier(double weightedMood) =>
      (1 + (weightedMood - 55) / 45 * 0.05).clamp(0.95, 1.05);
}
