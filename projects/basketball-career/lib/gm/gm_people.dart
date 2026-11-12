import 'names.dart';
import 'rng.dart';

/// ほかのチームの GM の型。
enum GmStyle {
  aggressive('攻め型', '大物を取りに行く。話は早いが、釣り合いには厳しくない', 0.97),
  patient('我慢型', '若手を育てて待つ。年寄りの獲得には慎重', 1.02),
  analytic('分析型', '数字で見る。釣り合いを見抜かれやすい', 1.06),
  thrifty('倹約型', '年俸を減らしたい。高い年俸の選手には慎重', 1.03),
  gambler('勝負師', '賭けに出る。ときどき割に合わない話にも乗る', 0.94);

  const GmStyle(this.label, this.text, this.hardness);
  final String label;
  final String text;

  /// トレードの受けにくさに掛ける数(1より大きいほど厳しい)。
  final double hardness;
}

/// ほかのチームの GM(名前と型)。
class GmPerson {
  const GmPerson(this.name, this.style);
  final String name;
  final GmStyle style;
}

/// チームの GM。リーグの種・チームの番号・何代目かから決める(乱数の列を使わないので、リーグの続きを変えない)。
GmPerson gmOf(int seed, int team, {int era = 0}) {
  final rng = Rng(seed * 100003 + team * 7919 + era * 104729 + 17);
  return GmPerson(randomName(rng), GmStyle.values[rng.nextInt(GmStyle.values.length)]);
}
