import 'season.dart';

/// プロの1シーズンの表彰(タイトルとは別。保存は `SeasonRecord.awards`)。
/// 成績と前年の出場から決めるだけで、勝敗や成長には影響しない。
List<String> awardsOf(
  Line l, {
  required int games,
  required bool firstYear,
  required int? prevGames,
  required int fielding,
  required bool isBatter,
  List<String> titles = const [],
}) {
  final a = <String>[];
  final qualBat = l.plateAppearances >= games * 3.1;
  final qualPitch = l.inningsPitched >= games * 0.7;
  final strongBat = qualBat && (l.ops ?? 0) >= 0.880;
  final strongPitch = qualPitch && (l.era ?? 99) <= 2.60;
  final goodBat = l.plateAppearances >= games * 2.0 && (l.ops ?? 0) >= 0.800;
  final goodPitch = l.inningsPitched >= games * 0.5 && (l.era ?? 99) <= 3.20;

  if (firstYear &&
      ((l.plateAppearances >= 250 && (l.ops ?? 0) >= 0.760) ||
          (l.inningsPitched >= 70 && (l.era ?? 99) <= 3.20))) {
    a.add('新人王');
  }
  if (strongBat || strongPitch) a.add('ベストナイン');
  if (isBatter && fielding >= 70 && l.games >= games * 0.7) {
    a.add('ゴールデングラブ');
  }
  if (prevGames != null &&
      prevGames <= games - 50 &&
      (goodBat || goodPitch) &&
      l.games >= games * 0.6) {
    a.add('カムバック賞');
  }
  if (qualBat && l.stolenBases >= 40) a.add('盗塁王');
  if (qualBat && l.hits >= 180) a.add('最多安打');
  if (qualBat && (l.onBase ?? 0) >= 0.420) a.add('最高出塁率');
  if (l.rbi >= 110) a.add('打点王');
  if (l.wins >= 15 && qualPitch && !a.contains('ベストナイン')) {
    a.add('二桁勝利の柱');
  }

  // ── 実際の野球にある大記録・表彰(名前は一般的な呼び名。団体名・商標は使わない) ──
  // 三冠王: 打率・本塁打・打点の3部門で1位(ここでは首位打者・本塁打王・打点王の水準)。
  if (titles.contains('首位打者') && titles.contains('本塁打王') && l.rbi >= 110) {
    a.add('三冠王');
  }
  // 投手三冠: 防御率・勝利・奪三振の3部門で1位の水準。
  if (titles.contains('最優秀防御率') &&
      titles.contains('最多勝') &&
      titles.contains('最多奪三振')) {
    a.add('投手三冠');
  }
  // エース賞(先発投手の最高の栄誉。勝利・防御率・奪三振・勝率・投球回の基準を満たす)。
  if (qualPitch &&
      l.inningsPitched >= 150 &&
      l.wins >= 15 &&
      (l.era ?? 99) <= 2.50 &&
      l.strikeouts >= 150 &&
      (l.winRate ?? 0) >= 0.60) {
    a.add('エース賞');
  }
  if (l.wins >= 20) a.add('20勝投手');
  if (qualBat && (l.battingAverage ?? 0) >= 0.400) a.add('4割打者');
  if (qualBat &&
      (l.battingAverage ?? 0) >= 0.300 &&
      l.homeRuns >= 30 &&
      l.stolenBases >= 30) {
    a.add('トリプルスリー');
  }
  if (l.homeRuns >= 50) a.add('50本塁打');
  return a;
}

/// アマチュアの大会(夏の大会・世界大会のU-12〜U-23)の表彰。個人の出来(`rating`、50が普通)と勝ち上がりから決める。
/// 優勝して個人の出来が高ければ「大会最優秀選手」、2回戦以上に進んで出来が良ければ「大会優秀選手」。
List<String> tournamentAwardsOf({
  required int roundsWon,
  required int rounds,
  required double rating,
}) {
  final champion = rounds > 0 && roundsWon == rounds;
  if (champion && rating >= 68) return ['大会最優秀選手'];
  if (roundsWon >= 2 && rating >= 58) return ['大会優秀選手'];
  return const [];
}
