import '../models/attributes.dart';

/// 怪我の重さ。
enum InjurySeverity {
  light('軽傷'),
  moderate('中程度'),
  severe('重傷');

  const InjurySeverity(this.label);

  final String label;
}

/// 負傷。離脱している間は試合に出られない。
///
/// 重傷は能力とポテンシャルを削る。治って終わりにすると、
/// 怪我が「数試合休むだけの足踏み」になってしまう。
class Injury {
  const Injury({
    required this.name,
    required this.severity,
    required this.matchesOut,
  });

  final String name;
  final InjurySeverity severity;

  /// 残りの欠場試合数。
  final int matchesOut;

  Injury tick() => Injury(
        name: name,
        severity: severity,
        matchesOut: matchesOut - 1,
      );

  bool get healed => matchesOut <= 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'severity': severity.name,
        'matchesOut': matchesOut,
      };

  static Injury? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Injury(
      name: json['name'] as String,
      severity: InjurySeverity.values.byName(json['severity'] as String),
      matchesOut: json['matchesOut'] as int,
    );
  }
}

/// 怪我の種類。どの能力に後遺症が出るかまで決めてある。
class InjuryKind {
  const InjuryKind({
    required this.name,
    required this.severity,
    required this.minMatches,
    required this.maxMatches,
    required this.affects,
  });

  final String name;
  final InjurySeverity severity;
  final int minMatches;
  final int maxMatches;

  /// 重傷のときに落ちる能力。
  final AttributeKey affects;

  static const List<InjuryKind> all = [
    InjuryKind(
      name: '打撲',
      severity: InjurySeverity.light,
      minMatches: 1,
      maxMatches: 2,
      affects: AttributeKey.physical,
    ),
    InjuryKind(
      name: '軽い肉離れ',
      severity: InjurySeverity.light,
      minMatches: 2,
      maxMatches: 3,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: '足首の捻挫',
      severity: InjurySeverity.moderate,
      minMatches: 4,
      maxMatches: 7,
      affects: AttributeKey.dribbling,
    ),
    InjuryKind(
      name: 'ハムストリングの肉離れ',
      severity: InjurySeverity.moderate,
      minMatches: 5,
      maxMatches: 9,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: '疲労骨折',
      severity: InjurySeverity.moderate,
      minMatches: 6,
      maxMatches: 10,
      affects: AttributeKey.physical,
    ),
    InjuryKind(
      name: '膝の靭帯損傷',
      severity: InjurySeverity.severe,
      minMatches: 12,
      maxMatches: 22,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: 'アキレス腱断裂',
      severity: InjurySeverity.severe,
      minMatches: 16,
      maxMatches: 26,
      affects: AttributeKey.pace,
    ),
  ];
}
