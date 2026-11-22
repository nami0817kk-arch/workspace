/// シーズン終了時に確定する、ユーザークラブの成績アーカイブ。
class SeasonRecord {
  final int season;
  final String clubName;
  final String leagueName;

  /// そのシーズンにプレーしたディビジョン(1部/2部)。
  final int divisionTier;

  final int finalRank;
  final int teamCount;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  final bool wonLeague;
  final bool promoted;
  final bool relegated;

  /// このシーズンに優勝したカップ戦名の一覧。
  final List<String> cupsWon;

  /// このシーズンに国内カップ(リーグカップ・大陸大会ではない方)で
  /// 優勝したか。オーナーの目標「国内カップ優勝」はこれだけを見る。
  /// 名前の一覧([cupsWon])では大会の種類が分からず、リーグカップや大陸
  /// 大会の優勝でも目標が達成になっていた。
  final bool wonDomesticCup;

  SeasonRecord({
    required this.season,
    required this.clubName,
    required this.leagueName,
    required this.divisionTier,
    required this.finalRank,
    required this.teamCount,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    this.wonLeague = false,
    this.promoted = false,
    this.relegated = false,
    List<String>? cupsWon,
    bool? wonDomesticCup,
  })  : cupsWon = cupsWon ?? [],
        // 渡されなければ、優勝した大会の名前から見分ける(古い記録と同じ)。
        wonDomesticCup =
            wonDomesticCup ?? legacyWonDomesticCup(cupsWon ?? const []);

  int get points => won * 3 + draw;
  int get goalDiff => goalsFor - goalsAgainst;

  Map<String, dynamic> toJson() => {
        'season': season,
        'clubName': clubName,
        'leagueName': leagueName,
        'divisionTier': divisionTier,
        'finalRank': finalRank,
        'teamCount': teamCount,
        'played': played,
        'won': won,
        'draw': draw,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'wonLeague': wonLeague,
        'promoted': promoted,
        'relegated': relegated,
        'cupsWon': cupsWon,
        'wonDomesticCup': wonDomesticCup,
      };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        season: json['season'] as int,
        clubName: json['clubName'] as String,
        leagueName: json['leagueName'] as String,
        divisionTier: json['divisionTier'] as int,
        finalRank: json['finalRank'] as int,
        teamCount: json['teamCount'] as int,
        played: json['played'] as int,
        won: json['won'] as int,
        draw: json['draw'] as int,
        lost: json['lost'] as int,
        goalsFor: json['goalsFor'] as int,
        goalsAgainst: json['goalsAgainst'] as int,
        wonLeague: json['wonLeague'] as bool? ?? false,
        promoted: json['promoted'] as bool? ?? false,
        relegated: json['relegated'] as bool? ?? false,
        cupsWon:
            (json['cupsWon'] as List?)?.map((e) => e as String).toList() ?? [],
        wonDomesticCup: json['wonDomesticCup'] as bool? ??
            legacyWonDomesticCup(
              (json['cupsWon'] as List?)?.map((e) => e as String) ?? const [],
            ),
      );

  /// 印の無い古い記録では、優勝した大会の名前から国内カップを見分ける。
  /// リーグカップと大陸大会の名前(日英・前の名前)でないものを国内カップと
  /// みなす(国内カップの名前は国ごとに違い、名前も変わってきたため)。
  static bool legacyWonDomesticCup(Iterable<String> cupsWon) =>
      cupsWon.any((name) => !_otherCupNames.contains(name));

  // i18n-ignore: 古いセーブの大会名を見分けるためのデータ(画面には出さない)。
  static const Set<String> _otherCupNames = {
    'リーグカップ',
    'League Cup',
    'ヨーロピアン・チャンピオンズカップ',
    'European Champions Cup',
    '大陸チャンピオンズカップ',
    'Continental Champions Cup',
  };
}
