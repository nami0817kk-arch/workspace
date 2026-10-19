/// 難しさ。成長の速さと、対戦相手の強さが変わる。
enum Difficulty {
  easy('やさしい', 'よく伸びて、相手が少し弱い。', 1.25, -3),
  normal('ふつう', '標準。', 1.0, 0),
  hard('むずかしい', '伸びが遅く、相手が強い。', 0.85, 3);

  const Difficulty(this.label, this.description, this.growth, this.opponent);
  final String label;
  final String description;

  /// 伸びる量にかける倍率(衰えには効かない)。
  final double growth;

  /// 対戦相手の強さに足す値。
  final double opponent;

  static Difficulty parse(String? s) => Difficulty.values
      .firstWhere((d) => d.name == s, orElse: () => Difficulty.normal);
}
