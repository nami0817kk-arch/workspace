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
AtBatResult simulateAtBat(Pitcher p, Batter b, Random rng) {
  double d(int v) => (v - 50) / 100.0; // -0.5〜+0.5

  final walkP = (0.08 + d(b.eye) * 0.10 - d(p.control) * 0.10).clamp(0.01, 0.25);
  final kP = (0.22 + d(p.stuff) * 0.20 - d(b.contact) * 0.15).clamp(0.05, 0.45);
  final hitP = (0.24 + d(b.contact) * 0.20 - d(p.stuff) * 0.10).clamp(0.08, 0.45);

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
