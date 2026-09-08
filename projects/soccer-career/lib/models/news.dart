/// 見出しの種類。色分けと並べ替えに使う。
enum NewsKind {
  match('試合'),
  milestone('節目'),
  transfer('移籍'),
  club('クラブ'),
  national('代表'),
  life('ピッチ外');

  const NewsKind(this.label);

  final String label;
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

  String get dateLabel => matchday > 0 ? '$year 第$matchday節' : '$year';

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
  derby('ダービー', '街がひとつになる日。負けたら顔を上げて歩けない'),
  titleRace('首位攻防', 'ここで勝てば、優勝が現実になる'),
  survival('残留争い', '負ければ、来季は下の部で戦うことになる'),
  promotion('昇格争い', '上に行けるかどうかが、この90分で決まる'),
  formerClub('古巣との対戦', 'かつての仲間と、かつてのサポーターの前で'),
  none('', '');

  const FixtureStake(this.label, this.description);

  final String label;
  final String description;

  bool get isSpecial => this != FixtureStake.none;
}
