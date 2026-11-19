import 'dart:math';

/// 分析部門の計算。xG(期待得点)はシュートと枠内シュートから見積もる。
class AnalyticsEngine {
  /// 年会費(5部の物差しの万円)。
  static const int annualFee = 250;

  /// xG の見積もり: 枠外のシュート0.04点、枠内のシュート0.28点。
  static double xg({required int shots, required int onTarget}) {
    final off = max(0, shots - onTarget);
    return off * 0.04 + onTarget * 0.28;
  }
}

/// U21 の育成の計算。
class U21Engine {
  /// U21 の年齢。
  static const int maxAge = 21;

  /// 毎節、先発に入っていない U21 の選手が、U21 の試合で伸びる確率。
  static const double growChance = 0.06;
}
