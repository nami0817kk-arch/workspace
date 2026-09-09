/// 大陸カップの成績。
enum ContinentalStage {
  none('不出場'),
  group('グループ敗退'),
  round16('ベスト16'),
  quarter('ベスト8'),
  semi('ベスト4'),
  runnerUp('準優勝'),
  winner('優勝');

  const ContinentalStage(this.label);

  final String label;

  /// 勝ち上がるほど労働許可と評判に効く。
  int get points => index;

  bool get participated => this != ContinentalStage.none;
}

/// 国内カップ戦の成績。
///
/// リーグと違って一発勝負なので、格下でも決勝まで行くことがある。
/// 優勝すれば翌季の大陸カップ出場権が付く。弱いクラブに居ても
/// 上の舞台に届く道を1本残しておくための仕組み。
enum CupStage {
  none('不出場'),
  early('初戦敗退'),
  round16('ベスト16'),
  quarter('ベスト8'),
  semi('ベスト4'),
  runnerUp('準優勝'),
  winner('優勝');

  const CupStage(this.label);

  final String label;

  int get points => index;

  bool get participated => this != CupStage.none;

  /// 優勝すれば翌季の大陸カップに出られる。
  bool get qualifiesContinental => this == CupStage.winner;
}

/// 世界大会の成績。4年に1度だけ動く。
enum WorldCupStage {
  none('不出場'),
  group('グループ敗退'),
  round16('ベスト16'),
  quarter('ベスト8'),
  semi('ベスト4'),
  runnerUp('準優勝'),
  winner('優勝');

  const WorldCupStage(this.label);

  final String label;

  int get points => index;

  bool get participated => this != WorldCupStage.none;
}

/// 移籍市場が開いている期間。
///
/// 現実の移籍は年中できるわけではない。窓の外ではオファーが届かず、
/// 冬の窓は選択肢が少なく条件も悪い。
enum TransferWindow {
  summer('夏の移籍市場', 1.0),
  winter('冬の移籍市場', 0.6),
  closed('移籍市場は閉じている', 0.0);

  const TransferWindow(this.label, this.strength);

  final String label;

  /// 届くオファーの量と質の係数。
  final double strength;

  bool get isOpen => this != TransferWindow.closed;
}

/// 登録メンバー（25人枠）に入れたか。
///
/// 外国人枠が埋まっている、序列が低い、自国育ちの頭数が足りない、
/// といった理由で登録から外れると1試合も出られない。
enum SquadStatus {
  registered('登録済み'),
  outOfSquad('登録外');

  const SquadStatus(this.label);

  final String label;

  bool get canPlay => this == SquadStatus.registered;
}
