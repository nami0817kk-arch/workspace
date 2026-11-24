/// 選手の経歴の1行(1季・1クラブ分のリーグ戦の成績)。
///
/// 2026-11-25 から季の終わりに書き足す(それより前の季は記録が無い。
/// 経歴の表は、記録の無い季を出さず、今季の分は試合の結果からその場で作る)。
class PlayerCareerLine {
  const PlayerCareerLine({
    required this.seasonEndYear,
    required this.club,
    this.apps = 0,
    this.goals = 0,
    this.rating,
    this.loan = false,
  });

  /// 季の終わりの年(2027 なら 2026-27 の季)。
  final int seasonEndYear;
  final String club;
  final int apps;
  final int goals;

  /// 平均採点(出ていなければ null)。
  final double? rating;

  /// 借りられて(または貸し出されて)いた先での季か。
  final bool loan;

  /// 季の表記(2026-27)。
  String get seasonLabel =>
      '${seasonEndYear - 1}-${(seasonEndYear % 100).toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        's': seasonEndYear,
        'c': club,
        if (apps != 0) 'a': apps,
        if (goals != 0) 'g': goals,
        if (rating != null) 'r': (rating! * 100).round(),
        if (loan) 'l': true,
      };

  factory PlayerCareerLine.fromJson(Map<String, dynamic> j) => PlayerCareerLine(
        seasonEndYear: j['s'] as int? ?? 0,
        club: j['c'] as String? ?? '',
        apps: j['a'] as int? ?? 0,
        goals: j['g'] as int? ?? 0,
        rating: j['r'] == null ? null : (j['r'] as int) / 100,
        loan: j['l'] as bool? ?? false,
      );
}

/// 移籍の種類。
enum PlayerMoveKind { transfer, free, loan, loanReturn, preContract, release }

/// 選手の移籍の歴の1行。
class PlayerMoveLine {
  const PlayerMoveLine({
    required this.date,
    required this.from,
    required this.to,
    required this.kind,
    this.fee = 0,
  });

  final DateTime date;
  final String from;
  final String to;
  final PlayerMoveKind kind;

  /// 移籍金(万円)。
  final int fee;

  Map<String, dynamic> toJson() => {
        'd': '${date.year}-${date.month}-${date.day}',
        'f': from,
        't': to,
        'k': kind.name,
        if (fee != 0) 'fee': fee,
      };

  factory PlayerMoveLine.fromJson(Map<String, dynamic> j) {
    final parts = (j['d'] as String? ?? '2026-7-1').split('-');
    DateTime date;
    try {
      date = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      date = DateTime(2026, 7, 1);
    }
    return PlayerMoveLine(
      date: date,
      from: j['f'] as String? ?? '',
      to: j['t'] as String? ?? '',
      kind: PlayerMoveKind.values.firstWhere((k) => k.name == j['k'],
          orElse: () => PlayerMoveKind.transfer),
      fee: j['fee'] as int? ?? 0,
    );
  }
}
