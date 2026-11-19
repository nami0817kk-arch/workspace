import '../l10n/tr.dart';
import 'formation.dart';
import 'team.dart';

/// 監督の考え方。試合の構えと、選手の扱いに出る。
enum ManagerStyle { attacking, pragmatic, defensive, youth }

extension ManagerStyleInfo on ManagerStyle {
  String get label => switch (this) {
        ManagerStyle.attacking => Tr.pick('攻撃的', 'Attacking'),
        ManagerStyle.pragmatic => Tr.pick('現実的', 'Pragmatic'),
        ManagerStyle.defensive => Tr.pick('堅守', 'Defensive'),
        ManagerStyle.youth => Tr.pick('若手を使う', 'Gives youth a chance'),
      };

  String get description => switch (this) {
        ManagerStyle.attacking => Tr.pick('相手に合わせた構えより、一段前がかりに戦う。',
            'Plays one notch more aggressively than the match-up suggests.'),
        ManagerStyle.pragmatic => Tr.pick('相手との力関係に合わせて構えを選ぶ。',
            'Picks the approach to suit the opponent.'),
        ManagerStyle.defensive => Tr.pick('相手に合わせた構えより、一段守りを固める。',
            'Sits one notch deeper than the match-up suggests.'),
        ManagerStyle.youth => Tr.pick('21歳以下の選手の不満が溜まりにくい(出番を約束する)。',
            'Players aged 21 and under stay happier (he promises them minutes).'),
      };

  /// 監督が選ぶ構え。相手に合わせた構え[base]を、考え方の分だけずらす。
  TeamMentality shift(TeamMentality base) {
    final i = base.index +
        switch (this) {
          ManagerStyle.attacking => 1,
          ManagerStyle.defensive => -1,
          _ => 0,
        };
    return TeamMentality.values[i.clamp(0, TeamMentality.values.length - 1)];
  }
}

/// 監督の経歴の1季分(どのクラブで何位だったか)。
class ManagerSpell {
  final String club;

  /// 季が終わった年(2027 なら 2026/27 の季)。
  final int season;
  final int rank;
  final int teams;

  /// 何部のリーグか(他の国は 1)。
  final int tier;

  const ManagerSpell({
    required this.club,
    required this.season,
    required this.rank,
    required this.teams,
    required this.tier,
  });

  Map<String, dynamic> toJson() => {
        'club': club,
        'season': season,
        'rank': rank,
        'teams': teams,
        'tier': tier,
      };

  factory ManagerSpell.fromJson(Map<String, dynamic> j) => ManagerSpell(
        club: j['club'] as String? ?? '',
        season: j['season'] as int? ?? 1,
        rank: j['rank'] as int? ?? 1,
        teams: j['teams'] as int? ?? 20,
        tier: j['tier'] as int? ?? 1,
      );
}

/// 監督だけが持つもの(考え方・好みの布陣・経歴・今の所属)。
class ManagerProfile {
  final ManagerStyle style;
  final Formation formation;

  /// 経歴(古い順)。
  final List<ManagerSpell> career;

  /// 候補のうち、他のクラブで今まさに指揮している人の所属。引き抜くには
  /// そのクラブへ補償金([compensation]、5部の物差しの万円)を払う。
  final String? employerClubId;
  final String? employerClubName;
  final int compensation;

  ManagerProfile({
    required this.style,
    required this.formation,
    List<ManagerSpell>? career,
    this.employerClubId,
    this.employerClubName,
    this.compensation = 0,
  }) : career = career ?? [];

  /// 雇ったあと(所属は自クラブになる)。
  ManagerProfile hiredCopy() =>
      ManagerProfile(style: style, formation: formation, career: career);

  Map<String, dynamic> toJson() => {
        'style': style.name,
        'formation': formation.name,
        if (career.isNotEmpty) 'career': career.map((c) => c.toJson()).toList(),
        if (employerClubId != null) 'employerClubId': employerClubId,
        if (employerClubName != null) 'employerClubName': employerClubName,
        if (compensation > 0) 'compensation': compensation,
      };

  factory ManagerProfile.fromJson(Map<String, dynamic> j) => ManagerProfile(
        style: ManagerStyle.values.firstWhere((s) => s.name == j['style'],
            orElse: () => ManagerStyle.pragmatic),
        formation: Formation.values.firstWhere((f) => f.name == j['formation'],
            orElse: () => Formation.f442),
        career: (j['career'] as List?)
                ?.map((e) =>
                    ManagerSpell.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        employerClubId: j['employerClubId'] as String?,
        employerClubName: j['employerClubName'] as String?,
        compensation: j['compensation'] as int? ?? 0,
      );
}
