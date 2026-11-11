/// 難しさ。任期を始めるときに選び、途中では変えられない(2026-11-11 仕様)。
///
/// 今ここで効くのは、けが・オーナーの厳しさ・トレードの通りやすさ。
/// 要求年俸・新人の見立ての幅・GM の格の点は、それぞれの仕組みを作るときに足す。
enum Difficulty {
  easy('やさしい', 'けがが少なく、オーナーが寛大で、トレードが通りやすい。'),
  normal('ふつう', '基準の難しさ。'),
  hard('きびしい', 'けがが多く、オーナーが厳しく、トレードが通りにくい。');

  const Difficulty(this.label, this.text);
  final String label;
  final String text;

  /// 自分のチームのけがの起きやすさ。
  double get injury => const [0.7, 1.0, 1.3][index];

  /// オーナーの信頼が減るときの倍率(増えるときは変えない)。
  double get ownerStrict => const [0.75, 1.0, 1.3][index];

  /// 相手がトレードを受けるのに要る釣り合いの倍率(大きいほど通りにくい)。
  double get tradeHardness => const [0.92, 1.0, 1.1][index];

  static Difficulty fromIndex(Object? i) => i is int && i >= 0 && i < values.length ? values[i] : normal;
}
