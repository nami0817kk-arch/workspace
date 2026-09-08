import '../models/club.dart';
import 'formulas.dart';
import 'world.dart';

/// リーグ1つぶんの格付け。
///
/// クラブの強さから機械的に出す。世界の全リーグを同じ物差しに並べないと、
/// 「自分のリーグがどのレベルなのか」がどこにも書いていないことになる。
class LeagueRank {
  const LeagueRank({
    required this.countryId,
    required this.tier,
    required this.average,
    required this.top,
    required this.clubs,
    required this.rank,
    required this.total,
  });

  final String countryId;
  final int tier;

  /// そのリーグのクラブの強さの平均。難易度はここで決まる。
  final double average;

  /// 首位級クラブの強さ。上を目指すときの目安。
  final int top;

  /// クラブ数。
  final int clubs;

  /// 世界順位（1 が最上位）。平均が同じリーグは同着になる。
  final int rank;

  /// 並べた総数。
  final int total;

  String get countryName => World.byId(countryId).name;

  String get name => '$countryName $tier部';

  /// 上から何割の位置か（0 が最上位）。
  double get percentile => total <= 1 ? 0 : (rank - 1) / (total - 1);

  /// 見出しに出す格。クラブの強さの平均で決める。
  ///
  /// 順位で切ると、リーグを1つ足しただけで全部の格が動く。
  /// 難易度そのもの（相手の強さ）で切れば、意味が変わらない。
  String get grade => switch (average) {
        >= 70 => 'S',
        >= 63 => 'A',
        >= 54 => 'B',
        >= 44 => 'C',
        _ => 'D',
      };

  /// 格の説明。文字だけだと何を意味するのか分からない。
  String get gradeLabel => switch (grade) {
        'S' => '世界最高峰',
        'A' => 'トップリーグ級',
        'B' => '中堅リーグ',
        'C' => '下部・地方リーグ',
        _ => '最下層',
      };
}

/// 選手の水準。総合力が世界のどのあたりに当たるのかを言葉にする。
class PlayerGrade {
  const PlayerGrade({
    required this.overall,
    required this.label,
    required this.description,
    required this.percentile,
    required this.starterClubs,
    required this.totalClubs,
    required this.bestLeague,
  });

  final int overall;

  /// 「一流」のような一言。
  final String label;

  /// その水準が何を意味するか。
  final String description;

  /// 世界のクラブのうち、この総合力が上回っている割合（0〜1）。
  final double percentile;

  /// 主力を張れるクラブ数と、世界のクラブ総数。
  final int starterClubs;
  final int totalClubs;

  /// 今の力で平均以上でいられる、一番上のリーグ。届かなければ null。
  final LeagueRank? bestLeague;
}

/// 世界の格付け。リーグの序列と、選手の水準を出す。
///
/// クラブの強さは [World.buildLeague] が決めているので、ここは数えるだけ。
/// 別に定義を持つと、リーグを1つ増やすたびに2か所を直すことになる。
class Ranking {
  const Ranking._();

  static List<LeagueRank>? _cache;

  /// 世界の全リーグを、強い順に並べたもの。
  static List<LeagueRank> leagues() {
    final cached = _cache;
    if (cached != null) return cached;

    final rows = <({String countryId, int tier, double average, int top, int clubs})>[];
    for (final country in World.countries) {
      for (var tier = 1; tier <= country.tiers; tier++) {
        final clubs = World.buildLeague(country.id, tier);
        final sum = clubs.fold<int>(0, (a, c) => a + c.strength);
        rows.add((
          countryId: country.id,
          tier: tier,
          average: sum / clubs.length,
          top: clubs.map((c) => c.strength).reduce((a, b) => a > b ? a : b),
          clubs: clubs.length,
        ));
      }
    }
    rows.sort((a, b) => b.average.compareTo(a.average));

    final result = [
      for (var i = 0; i < rows.length; i++)
        LeagueRank(
          countryId: rows[i].countryId,
          tier: rows[i].tier,
          average: rows[i].average,
          top: rows[i].top,
          clubs: rows[i].clubs,
          // 自分より強いリーグの数 + 1。平均が同じなら同着になる。
          rank: rows.where((r) => r.average > rows[i].average).length + 1,
          total: rows.length,
        ),
    ];
    return _cache = result;
  }

  /// そのリーグの格付け。無ければ一番下を返す。
  static LeagueRank of(String countryId, int tier) => leagues().firstWhere(
        (l) => l.countryId == countryId && l.tier == tier,
        orElse: () => leagues().last,
      );

  static List<int>? _strengths;

  /// 世界の全クラブの強さ。選手の水準を測る物差しにする。
  ///
  /// クラブの強さは、そこで主力を張る選手の総合力とほぼ同じ意味を持つ
  /// （登録も移籍もこの数字で判定している）。だから「このクラブより上か」を
  /// 数えれば、そのまま「世界で何クラブの主力になれるか」になる。
  static List<int> _clubStrengths() {
    final cached = _strengths;
    if (cached != null) return cached;
    final all = <int>[
      for (final country in World.countries)
        for (var tier = 1; tier <= country.tiers; tier++)
          for (final club in World.buildLeague(country.id, tier)) club.strength,
    ]..sort();
    return _strengths = all;
  }

  /// 総合力から水準を出す。
  static PlayerGrade gradeFor(int overall) {
    final strengths = _clubStrengths();
    final starters = strengths.where((s) => s <= overall).length;
    final percentile = starters / strengths.length;
    final (label, description) = _band(overall);
    LeagueRank? best;
    for (final league in leagues()) {
      if (league.average <= overall) {
        best = league;
        break;
      }
    }
    return PlayerGrade(
      overall: overall,
      label: label,
      description: description,
      percentile: percentile,
      starterClubs: starters,
      totalClubs: strengths.length,
      bestLeague: best,
    );
  }

  /// 総合力を言葉にする。
  ///
  /// 割合で切ると、世界のクラブの大半が下部リーグなので、総合力70で
  /// 「上位13%」のような数字が出て実感と合わない。ゲームの中で実際に
  /// 意味を持つしきい値（代表招集・最高峰リーグの平均）で切る。
  static (String, String) _band(int overall) => switch (overall) {
        >= 88 => ('世界屈指', 'どのリーグでも中心になれる'),
        >= 82 => ('ワールドクラス', '最高峰のリーグで主力を張れる'),
        >= Formulas.callUpOverall => ('一流', '代表に呼ばれる水準'),
        >= 70 => ('主力級', '上位リーグで計算される'),
        >= 62 => ('戦力', '所属リーグで出場を積める'),
        >= 52 => ('控え', '出場機会を争う段階'),
        _ => ('育成中', 'まずは下の部で試合に出るところから'),
      };

  /// 代表招集の目安まで、あといくつか。届いていれば 0。
  static int toCallUp(int overall) =>
      overall >= Formulas.callUpOverall ? 0 : Formulas.callUpOverall - overall;

  /// クラブの中での立ち位置。総合力とクラブの強さの差で決まる。
  static String standingIn(int overall, Club club) {
    final gap = overall - club.strength;
    if (gap >= 8) return 'このクラブでは格上。もっと上でやれる';
    if (gap >= 2) return 'チームの中心';
    if (gap >= -4) return '主力の一角';
    if (gap >= -12) return '出場機会を争う立場';
    return 'このクラブでは力不足';
  }

  /// 能力値が1上がると、その局面の成功率が何%動くか。
  ///
  /// 練習の1回が試合の何に化けるのかを、推測ではなく式のまま出すための値。
  static const double chancePerPoint = 0.009;

  /// 能力の伸びを、成功率の増分（%）に直す。
  static double chanceGainPercent(int growth) => growth * chancePerPoint * 100;

  /// テスト用。定義を差し替えたときにキャッシュを捨てる。
  static void resetCache() {
    _cache = null;
    _strengths = null;
  }
}
