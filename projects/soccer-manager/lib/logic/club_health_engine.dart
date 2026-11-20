/// クラブの経営診断。2つの期待・人件費率・資金から、100点満点の点数と
/// A〜E の評価を出す。状況ページの監督の報告に出す。
class ClubHealth {
  const ClubHealth({required this.score, required this.grade});

  /// 0〜100。
  final int score;

  /// A(良好)〜E(危険)。
  final String grade;
}

class ClubHealthEngine {
  const ClubHealthEngine._();

  /// 診断する。[wageRatio] は営業収入に対する人件費の割合(0.7で注意)。
  /// 内訳: サポーター30点・株主30点・人件費率20点・資金20点。
  static ClubHealth assess({
    required int supporter,
    required int shareholder,
    required double wageRatio,
    required int budget,
  }) {
    final s = supporter.clamp(0, 100) * 30 / 100;
    final h = shareholder.clamp(0, 100) * 30 / 100;
    // 人件費率: 0.5以下で満点、0.85以上で0点、その間は直線。
    final w = (1 - ((wageRatio - 0.5) / 0.35).clamp(0.0, 1.0)) * 20;
    // 資金: 0以下は0点、3000万円以上で満点、その間は直線。
    final f = (budget / 3000).clamp(0.0, 1.0) * 20;
    final score = (s + h + w + f).round().clamp(0, 100);
    return ClubHealth(score: score, grade: gradeFor(score));
  }

  static String gradeFor(int score) {
    if (score >= 80) return 'A';
    if (score >= 65) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'E';
  }
}
