/// 引退した選手の記録。
///
/// これまで**引退した選手は消えていた**。引退画面に「この選手の記録は
/// 消えます」と書いてあって、新しいキャリアを始めた瞬間に本当に消えた。
/// 20年ぶんの選択の結果が、次の選手を作るために捨てられる。
///
/// キャリアの状態（`CareerState`）をそのまま残すと重いし、形式を変えるたびに
/// 読めなくなる。**引退した時点で必要なぶんだけを写し取って**、以後は
/// このかたちのまま持つ。
library;

import 'career.dart';
import 'competition.dart';
import 'life.dart';
import 'look.dart';
import 'reputation.dart';
import 'traits.dart';

/// クラブでの1区切り。何年そこに居たか。
class LegendSpell {
  const LegendSpell({
    required this.clubName,
    required this.seasons,
    required this.tier,
  });

  final String clubName;
  final int seasons;

  /// 一番上でプレーした部。
  final int tier;

  Map<String, dynamic> toJson() =>
      {'clubName': clubName, 'seasons': seasons, 'tier': tier};

  factory LegendSpell.fromJson(Map<String, dynamic> json) => LegendSpell(
        clubName: json['clubName'] as String? ?? '',
        seasons: json['seasons'] as int? ?? 0,
        tier: json['tier'] as int? ?? 1,
      );
}

/// 引退した選手1人ぶんの記録。
class Legend {
  const Legend({
    required this.name,
    required this.positionLabel,
    required this.retiredYear,
    required this.retiredAge,
    required this.seasons,
    required this.appearances,
    required this.goals,
    required this.assists,
    required this.averageRating,
    required this.caps,
    required this.internationalGoals,
    required this.peakOverall,
    required this.potential,
    required this.spells,
    required this.awards,
    required this.traits,
    required this.leagueTitles,
    required this.cupTitles,
    required this.continentalTitles,
    required this.worldCupBest,
    required this.bestTier,
    required this.look,
    required this.squadNumber,
    required this.secondCareer,
    required this.tampered,
    required this.recordedAt,
  });

  final String name;
  final String positionLabel;

  /// 引退した年と、そのときの年齢。
  final int retiredYear;
  final int retiredAge;

  final int seasons;
  final int appearances;
  final int goals;
  final int assists;
  final double averageRating;
  final int caps;
  final int internationalGoals;

  /// キャリアで一番高かった総合力と、そのときのポテンシャル。
  final int peakOverall;
  final int potential;

  /// 渡り歩いたクラブ。新しい順ではなく、歩いた順。
  final List<LegendSpell> spells;

  final List<Award> awards;
  final List<Trait> traits;

  final int leagueTitles;
  final int cupTitles;
  final int continentalTitles;
  final WorldCupStage worldCupBest;

  /// 到達した一番上の部。
  final int bestTier;

  final PlayerLook look;
  final int squadNumber;
  final SecondCareer secondCareer;

  /// 管理画面で書き換えたキャリアか。
  ///
  /// **印は殿堂にも持ち込む。** ここで落とすと、改変済みの記録が
  /// 普通の記録に紛れる（引き継ぎコードで持ち出せてしまうので）。
  final bool tampered;

  /// 記録した時刻。並べ替えと、同じ選手の重複を弾くのに使う。
  final int recordedAt;

  /// 一覧に出す一言。
  String get summary =>
      '$seasons季 ・ $appearances試合 ${goals}G ${assists}A ・ '
      '平均 ${averageRating.toStringAsFixed(2)}';

  /// 手にしたタイトルの数。0 なら出さない。
  int get titles => leagueTitles + cupTitles + continentalTitles;

  /// 今のキャリアから写し取る。引退した時点で1度だけ呼ぶ。
  factory Legend.from(CareerState state, {required SecondCareer secondCareer}) {
    final totals = state.careerTotals;
    // 歩いた順にクラブをまとめる。同じクラブに戻ってきたら別の区切りにする
    // （「古巣へのラストダンス」がキャリアの形として残る）。
    final spells = <LegendSpell>[];
    for (final record in [...state.history]) {
      if (spells.isNotEmpty && spells.last.clubName == record.clubName) {
        final last = spells.removeLast();
        spells.add(LegendSpell(
          clubName: last.clubName,
          seasons: last.seasons + 1,
          tier: last.tier < record.tier ? last.tier : record.tier,
        ));
      } else {
        spells.add(LegendSpell(
          clubName: record.clubName,
          seasons: 1,
          tier: record.tier,
        ));
      }
    }
    var worldCupBest = WorldCupStage.none;
    for (final record in state.history) {
      if (record.worldCupStage.points > worldCupBest.points) {
        worldCupBest = record.worldCupStage;
      }
    }
    return Legend(
      name: state.player.name,
      positionLabel: state.player.positionLabel,
      retiredYear: state.year,
      retiredAge: state.player.age,
      seasons: state.history.length,
      appearances: totals.appearances,
      goals: totals.goals,
      assists: totals.assists,
      averageRating: totals.averageRating,
      caps: state.caps,
      internationalGoals: state.internationalGoals,
      // 引退時の総合力ではなく、一番高かったところを残す。
      // 衰えた後の数字だけが残るのは、その選手の記録として正しくない。
      peakOverall: [
        state.player.overall,
        for (final h in state.history) h.overall,
      ].reduce((a, b) => a > b ? a : b),
      potential: state.player.potential,
      spells: spells,
      awards: state.reputation.awards,
      traits: state.player.traits,
      leagueTitles: state.history
          .where((h) => h.tier == 1 && h.leaguePosition == 1)
          .length,
      cupTitles:
          state.history.where((h) => h.cupStage == CupStage.winner).length,
      continentalTitles: state.history
          .where((h) => h.continentalStage == ContinentalStage.winner)
          .length,
      worldCupBest: worldCupBest,
      bestTier: state.history.isEmpty
          ? state.club.tier
          : state.history.map((h) => h.tier).reduce((a, b) => a < b ? a : b),
      look: state.player.look,
      squadNumber: state.squadNumber,
      secondCareer: secondCareer,
      tampered: state.tampered,
      recordedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'positionLabel': positionLabel,
        'retiredYear': retiredYear,
        'retiredAge': retiredAge,
        'seasons': seasons,
        'appearances': appearances,
        'goals': goals,
        'assists': assists,
        'averageRating': averageRating,
        'caps': caps,
        'internationalGoals': internationalGoals,
        'peakOverall': peakOverall,
        'potential': potential,
        'spells': [for (final s in spells) s.toJson()],
        'awards': [for (final a in awards) a.name],
        'traits': [for (final t in traits) t.name],
        'leagueTitles': leagueTitles,
        'cupTitles': cupTitles,
        'continentalTitles': continentalTitles,
        'worldCupBest': worldCupBest.name,
        'bestTier': bestTier,
        'look': look.toJson(),
        'squadNumber': squadNumber,
        'secondCareer': secondCareer.name,
        'tampered': tampered,
        'recordedAt': recordedAt,
      };

  factory Legend.fromJson(Map<String, dynamic> json) => Legend(
        name: json['name'] as String? ?? '名無し',
        positionLabel: json['positionLabel'] as String? ?? '',
        retiredYear: json['retiredYear'] as int? ?? 0,
        retiredAge: json['retiredAge'] as int? ?? 0,
        seasons: json['seasons'] as int? ?? 0,
        appearances: json['appearances'] as int? ?? 0,
        goals: json['goals'] as int? ?? 0,
        assists: json['assists'] as int? ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
        caps: json['caps'] as int? ?? 0,
        internationalGoals: json['internationalGoals'] as int? ?? 0,
        peakOverall: json['peakOverall'] as int? ?? 0,
        potential: json['potential'] as int? ?? 0,
        spells: [
          for (final s in (json['spells'] as List? ?? const []))
            LegendSpell.fromJson(s as Map<String, dynamic>),
        ],
        awards: [
          for (final a in (json['awards'] as List? ?? const []))
            if (Award.values.any((v) => v.name == a)) Award.values.byName(a as String),
        ],
        traits: [
          for (final t in (json['traits'] as List? ?? const []))
            if (Trait.values.any((v) => v.name == t)) Trait.values.byName(t as String),
        ],
        leagueTitles: json['leagueTitles'] as int? ?? 0,
        cupTitles: json['cupTitles'] as int? ?? 0,
        continentalTitles: json['continentalTitles'] as int? ?? 0,
        worldCupBest:
            WorldCupStage.values.any((v) => v.name == json['worldCupBest'])
                ? WorldCupStage.values.byName(json['worldCupBest'] as String)
                : WorldCupStage.none,
        bestTier: json['bestTier'] as int? ?? 1,
        look: PlayerLook.fromJson(json['look'] as Map<String, dynamic>?),
        squadNumber: json['squadNumber'] as int? ?? 0,
        secondCareer:
            SecondCareer.values.any((v) => v.name == json['secondCareer'])
                ? SecondCareer.values.byName(json['secondCareer'] as String)
                : SecondCareer.quiet,
        tampered: json['tampered'] as bool? ?? false,
        recordedAt: json['recordedAt'] as int? ?? 0,
      );
}

/// 引退した選手たち。新しい順に並ぶ。
class Hall {
  const Hall({this.legends = const []});

  final List<Legend> legends;

  /// 残しておく数。端末の保存領域を無限には使わない。
  static const int keep = 40;

  Hall add(Legend legend) => Hall(
        legends: [legend, ...legends].take(keep).toList(),
      );

  Hall removeAt(int index) => Hall(
        legends: [
          for (var i = 0; i < legends.length; i++)
            if (i != index) legends[i],
        ],
      );

  bool get isEmpty => legends.isEmpty;

  Map<String, dynamic> toJson() =>
      {'legends': [for (final l in legends) l.toJson()]};

  factory Hall.fromJson(Map<String, dynamic>? json) => Hall(
        legends: [
          for (final l in (json?['legends'] as List? ?? const []))
            Legend.fromJson(l as Map<String, dynamic>),
        ],
      );
}
