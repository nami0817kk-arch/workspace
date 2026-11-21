// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';

/// 大陸カップの成績。
enum ContinentalStage {
  none(Say('不出場', 'Did not take part')),
  group(Say('グループ敗退', 'Out in the group')),
  round16(Say('ベスト16', 'Round of 16')),
  quarter(Say('ベスト8', 'Quarter-finals')),
  semi(Say('ベスト4', 'Semi-finals')),
  runnerUp(Say('準優勝', 'Runners-up')),
  winner(Say('優勝', 'Winners'));

  const ContinentalStage(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

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
  none(Say('不出場', 'Did not take part')),
  early(Say('初戦敗退', 'Out in the first round')),
  round16(Say('ベスト16', 'Round of 16')),
  quarter(Say('ベスト8', 'Quarter-finals')),
  semi(Say('ベスト4', 'Semi-finals')),
  runnerUp(Say('準優勝', 'Runners-up')),
  winner(Say('優勝', 'Winners'));

  const CupStage(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

  int get points => index;

  bool get participated => this != CupStage.none;

  /// 優勝すれば翌季の大陸カップに出られる。
  bool get qualifiesContinental => this == CupStage.winner;
}

/// 世界大会の成績。4年に1度だけ動く。
enum WorldCupStage {
  none(Say('不出場', 'Did not take part')),
  group(Say('グループ敗退', 'Out in the group')),
  round16(Say('ベスト16', 'Round of 16')),
  quarter(Say('ベスト8', 'Quarter-finals')),
  semi(Say('ベスト4', 'Semi-finals')),
  runnerUp(Say('準優勝', 'Runners-up')),
  winner(Say('優勝', 'Winners'));

  const WorldCupStage(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

  int get points => index;

  bool get participated => this != WorldCupStage.none;
}

/// 移籍市場が開いている期間。
///
/// 現実の移籍は年中できるわけではない。窓の外ではオファーが届かず、
/// 冬の窓は選択肢が少なく条件も悪い。
enum TransferWindow {
  summer(Say('夏の移籍市場', 'Summer window'), 1.0),
  winter(Say('冬の移籍市場', 'Winter window'), 0.6),
  closed(Say('移籍市場は閉じている', 'The window is shut'), 0.0);

  const TransferWindow(Say label, this.strength) : _label = label;

  final Say _label;

  String get label => _label.t;

  /// 届くオファーの量と質の係数。
  final double strength;

  bool get isOpen => this != TransferWindow.closed;
}

/// 登録メンバー（25人枠）に入れたか。
///
/// 外国人枠が埋まっている、序列が低い、自国育ちの頭数が足りない、
/// といった理由で登録から外れると1試合も出られない。
enum SquadStatus {
  registered(Say('登録済み', 'Registered')),
  outOfSquad(Say('登録外', 'Not registered'));

  const SquadStatus(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

  bool get canPlay => this == SquadStatus.registered;
}
