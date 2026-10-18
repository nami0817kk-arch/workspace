/// 難しさ。はじめに選び、その選手の一生ずっと変わらない。
enum Difficulty {
  easy('やさしい', '経験点が1.15倍。ドラフトで指名されやすい。', 1.15, -3),
  normal('ふつう', 'ほどよい難しさ。', 1.0, 0),
  hard('むずかしい', '経験点が0.9倍。ドラフトで指名されにくい。', 0.9, 3);

  const Difficulty(
      this.label, this.description, this.expMultiplier, this.draftShift);
  final String label;
  final String description;

  /// 練習で貯まる経験点にかかる倍率。
  final double expMultiplier;

  /// ドラフトの合格ライン(点)に足す値。負なら指名されやすい。
  final double draftShift;

  static Difficulty parse(Object? name) =>
      Difficulty.values.where((d) => d.name == name).firstOrNull ??
      Difficulty.normal;
}
