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
  return a;
}
