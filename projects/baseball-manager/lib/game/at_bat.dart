import 'dart:math';

/// 打席の結果。
enum AtBatResult { strikeout, walk, out, single, double, triple, homeRun }

/// 能力値は 0〜100。50 が平均。
class Pitcher {
  const Pitcher({required this.control, required this.stuff});
  final int control; // 制球
  final int stuff; // 球威
}

class Batter {
  const Batter({required this.contact, required this.power, required this.eye});
  final int contact; // ミート
  final int power; // パワー
  final int eye; // 選球眼
}

/// 1打席を決める。乱数は注入できる（テストで再現するため）。
///
/// [ownBatter] は育てている選手が打席に立つとき。ふつうの一流(能力60〜80)の打率を
/// 現実に寄せるため、ヒットの土台を少し下げ、ミート90台の上乗せを増やして
/// 能力99の打率(約.45)は変えない。相手の打者(投手の成績の基準)は従来のまま。
AtBatResult simulateAtBat(Pitcher p, Batter b, Random rng,
    {bool ownBatter = false}) {
  double d(int v) => (v - 50) / 100.0; // -0.5〜+0.5

  // 力の差(-1〜+1)が大きく開いたぶんだけ、結果にさらに上乗せする。
  // 差が小さいうちは従来どおり。小学生の相手(30前後)に90台の投手が打たれ続けないように。
  double over(double v) {
    const knee = 0.32;
    if (v.abs() <= knee) return 0;
    return v.sign * (v.abs() - knee) * 2.0;
  }

  final edge = d(p.stuff) - d(b.contact);
  final ctl = d(p.control) - d(b.eye);
  final eo = over(edge);

  var walkP = (0.08 + d(b.eye) * 0.10 - d(p.control) * 0.10 - over(ctl) * 0.08)
      .clamp(0.0, 0.25);
  var kP = (0.22 + d(p.stuff) * 0.20 - d(b.contact) * 0.15 + eo * 0.20)
      .clamp(0.0, 0.55);
  // 打者が投手を大きく上回るとき(S級の打者と小学生の投手)は、ヒットが大きく増える。
  // 逆に投手が上回るときの減り方より強め。同レベル同士は従来どおり。
  // ミートがずば抜けた打者は、プロの相手にも4割に届くよう、上のほうを上乗せする
  // (能力70未満は0、99で+.045。2乗でなだらかに増える。相手の打者に使う80未満ではほぼ0)。
  final topContact = pow(((b.contact - 70) / 29).clamp(0.0, 1.0), 2) *
      (ownBatter ? 0.060 : 0.045);
  var hitP = ((ownBatter ? 0.225 : 0.24) +
          topContact +
          d(b.contact) * 0.20 -
          d(p.stuff) * 0.10 -
          eo * (eo < 0 ? 0.40 : 0.16))
      .clamp(0.0, 1.0);

  // 99と10のように力が桁違いに離れているときは、必ず強いほうが勝つ。
  // 差(球威-ミート)が0.6を超えたら少しずつ、0.85で完全に決まる。
  //  打者が圧倒: 凡退も三振もなく、必ず出塁(四球かヒット)。
  //  投手が圧倒: 四球もヒットもなく、必ず打ち取る。
  final t = ((edge.abs() - 0.6) / 0.25).clamp(0.0, 1.0);
  if (t > 0) {
    if (edge < 0) {
      kP *= 1 - t;
      hitP += (1 - walkP - hitP).clamp(0.0, 1.0) * t;
    } else {
      walkP *= 1 - t;
      hitP *= 1 - t;
      kP += (0.95 - kP).clamp(0.0, 1.0) * t;
    }
  }

  final r = rng.nextDouble();
  if (r < walkP) return AtBatResult.walk;
  if (r < walkP + kP) return AtBatResult.strikeout;
  if (r < walkP + kP + hitP) {
    final x = rng.nextDouble();
    final hrP = (0.10 + d(b.power) * 0.20).clamp(0.02, 0.30);
    if (x < hrP) return AtBatResult.homeRun;
    if (x < hrP + 0.02) return AtBatResult.triple;
    if (x < hrP + 0.02 + 0.22 + d(b.power) * 0.10) return AtBatResult.double;
    return AtBatResult.single;
  }
  return AtBatResult.out;
}
