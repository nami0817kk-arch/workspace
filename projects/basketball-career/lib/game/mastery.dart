import 'life.dart';
import 'player.dart';

/// 熟練度: 同じ能力を重点にして練習を重ねるほどたまり、段(Lv1〜5)が上がる。
///
/// 能力の伸びは年齢で小さくなる(プロの約18年はほとんど上がらない)が、熟練度は年齢によらずたまる。
/// 「練習しても手応えが無い」大人の時期にも、重ねた練習が形に残るようにするためのもの。
/// 段が上がると、得意(Lv2)・達人(Lv4)・極み(Lv5)でその能力 +1、武器(Lv3)と極み(Lv5)で特殊能力ポイント +1。

/// 段に上がるのに要る累計の熟練度。
const masteryThresholds = [10, 25, 45, 70, 100];
const masteryNames = ['', '基礎', '得意', '武器', '達人', '極み'];
const masteryMax = 5;

/// 累計の熟練度から段(0〜5)。
int masteryLevel(int points) {
  var lv = 0;
  for (final t in masteryThresholds) {
    if (points >= t) lv++;
  }
  return lv;
}

/// 次の段までの (今の段の中での量, その段の幅)。極みなら null。
({int have, int need})? masteryProgress(int points) {
  final lv = masteryLevel(points);
  if (lv >= masteryMax) return null;
  final from = lv == 0 ? 0 : masteryThresholds[lv - 1];
  return (have: points - from, need: masteryThresholds[lv] - from);
}

/// 1ターンでたまる量。第1の重点・第2の重点の順。怪我で休んだターンはたまらない。
({int first, int second}) masteryGain(Action a, {required bool injured}) {
  if (injured) return (first: 0, second: 0);
  return switch (a) {
    Action.practice => (first: 3, second: 1),
    Action.intense => (first: 5, second: 2),
    Action.scrimmage => (first: 1, second: 0),
    Action.study => (first: 1, second: 1),
    _ => (first: 0, second: 0),
  };
}

/// 段が上がったときのごほうび: 能力の上乗せ。
int masteryAbilityBonus(int level) => level == 2 || level >= 4 ? 1 : 0;

/// 段が上がったときのごほうび: 特殊能力ポイント。
int masterySp(int level) => level == 3 || level == masteryMax ? 1 : 0;

/// 「3Pシュート 熟練Lv3(武器)」の形。
String masteryLabel(Ability a, int level) =>
    '${a.label} 熟練Lv$level(${masteryNames[level]})';

/// ごほうびの一言(「  3Pシュート +1・特殊能力ポイント +1」)。何も無ければ空。
String masteryRewardText(Ability a, int level) {
  final parts = [
    if (masteryAbilityBonus(level) > 0) '${a.label} +${masteryAbilityBonus(level)}',
    if (masterySp(level) > 0) '特殊能力ポイント +${masterySp(level)}',
  ];
  return parts.isEmpty ? '' : '  ${parts.join('・')}';
}
