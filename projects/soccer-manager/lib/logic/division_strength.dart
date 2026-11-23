import 'dart:math';

/// 部ごとのクラブの強さ(選手を作るときの目安の総合力)の幅。
///
/// 以前はどの部も「基準 + 0〜34」で、幅が35あった。3部に1部並みの
/// クラブが混じり、価値と年俸は能力に対して指数で伸びるため、2部・3部の
/// 真ん中のクラブでも人件費が年収を大きく超えていた(人件費率 115〜176%)。
///
/// 実在の下の部は、上の部よりクラブの差が小さい。1部だけは強豪から
/// 残留争いまでの差が大きいので、幅を広めに残す。5部は自クラブの
/// 出発点(強さ60)が真ん中より少し上になるようにしてある(以前の 40〜74
/// と平均は同じ 57)。
(int, int) divisionStrengthRange(int tier) => switch (tier.clamp(1, 5)) {
      1 => (82, 96),
      2 => (72, 86),
      3 => (65, 79),
      4 => (57, 71),
      _ => (48, 66),
    };

/// [tier] 部の真ん中くらいのクラブの、選手全員の総合力の平均の目安。
///
/// [divisionStrengthRange] は選手を作るときの目安で、出来上がるクラブの
/// 平均(控えと若手を含む)はその真ん中より7ほど低い(1部 82・2部 72・
/// 3部 65。2026-11-23 の実測)。CPU のクラブが選手を補充するとき、
/// 部の水準へ少し寄せるのに使う(RetirementEngine.cpuRecruitStrength)。
int divisionTypicalSquadLevel(int tier) {
  final (lo, hi) = divisionStrengthRange(tier);
  return (lo + hi) ~/ 2 - 7;
}

/// [tier] 部のクラブの強さを1つ引く。
int rollDivisionStrength(int tier, Random rng) {
  final (lo, hi) = divisionStrengthRange(tier);
  return lo + rng.nextInt(hi - lo + 1);
}
