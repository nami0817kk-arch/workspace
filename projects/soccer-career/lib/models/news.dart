// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';

/// 見出しの種類。色分けと並べ替えに使う。
enum NewsKind {
  match(Say('試合', 'Match')),
  milestone(Say('節目', 'Milestone')),
  transfer(Say('移籍', 'Transfer')),
  club(Say('クラブ', 'Club')),
  national(Say('代表', 'International')),
  life(Say('ピッチ外', 'Off the pitch')),

  /// 関わった人の続き（移籍・引退・加入）。2026-11-22。
  people(Say('知り合い', 'People you know'));

  const NewsKind(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;
}

/// 世の中に出た1本の記事。
///
/// 数字は積み上がっても、それが「誰かに見られている」感覚は別に要る。
/// 実際の選手のキャリアは、他人が書いた見出しの連なりとして残っていく。
class NewsItem {
  const NewsItem({
    required this.year,
    required this.matchday,
    required this.kind,
    required this.headline,
    this.body = '',
  });

  final int year;

  /// そのシーズンの何節ごろの話か。0 はシーズンの外。
  final int matchday;

  final NewsKind kind;

  /// 見出し。これだけで意味が通るようにする。
  final String headline;

  /// 補足。無くてもよい。
  final String body;

  String get dateLabel => matchday > 0 ? tr('$year 第$matchday節', '$year matchday $matchday') : '$year';

  Map<String, dynamic> toJson() => {
        'year': year,
        'matchday': matchday,
        'kind': kind.name,
        'headline': headline,
        'body': body,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        year: json['year'] as int? ?? 0,
        matchday: json['matchday'] as int? ?? 0,
        kind: NewsKind.values.any((k) => k.name == json['kind'])
            ? NewsKind.values.byName(json['kind'] as String)
            : NewsKind.match,
        headline: json['headline'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

/// その試合が持つ意味。
///
/// 同じ「第20節」でも、ダービーと消化試合では立ち上がりの空気が違う。
/// 順位表とクラブの関係から決まるので、保存はしない。
enum FixtureStake {
  derby(Say('ダービー', 'Derby'), Say('街がひとつになる日。負けたら顔を上げて歩けない', 'The day the city is one. Lose and you cannot hold your head up')),
  titleRace(Say('首位攻防', 'Top of the table'), Say('ここで勝てば、優勝が現実になる', 'Win this and the title becomes real')),
  survival(Say('残留争い', 'Relegation six-pointer'), Say('負ければ、来季は下の部で戦うことになる', 'Lose and next season is in the tier below')),
  promotion(Say('昇格争い', 'Promotion race'), Say('上に行けるかどうかが、この90分で決まる', 'Ninety minutes decide whether you go up')),
  formerClub(Say('古巣との対戦', 'Against your old club'), Say('かつての仲間と、かつてのサポーターの前で', 'In front of former teammates and former supporters')),
  none(Say('', ''), Say('', ''));

  const FixtureStake(Say label, Say description)
    : _label = label,
      _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  bool get isSpecial => this != FixtureStake.none;
}
