// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';
import '../models/attributes.dart';

/// 怪我の重さ。
enum InjurySeverity {
  light(Say('軽傷', 'Minor')),
  moderate(Say('中程度', 'Moderate')),
  severe(Say('重傷', 'Serious'));

  const InjurySeverity(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;
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

  /// **中身が欠けていても投げない。**
  ///
  /// 投げると `SaveRepository.load` が握り潰して新規扱いになる——
  /// つまり**黙ってキャリアが消える**。名前の無いものは怪我として
  /// 扱えないので、怪我をしていない状態として読む。残り試合数が
  /// 欠けているときも 0（＝治っている）に倒す。**閉じ込める側に倒さない。**
  static Injury? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name'] as String?;
    if (name == null) return null;
    return Injury(
      name: name,
      severity:
          InjurySeverity.values.asNameMap()[json['severity'] as String?] ??
          InjurySeverity.light,
      matchesOut: json['matchesOut'] as int? ?? 0,
    );
  }
}

/// 怪我の種類。どの能力に後遺症が出るかまで決めてある。
class InjuryKind {
  const InjuryKind({
    required Say name,
    required this.severity,
    required this.minMatches,
    required this.maxMatches,
    required this.affects,
  }) : _name = name;

  final Say _name;

  String get name => _name.t;
  final InjurySeverity severity;
  final int minMatches;
  final int maxMatches;

  /// 重傷のときに落ちる能力。
  final AttributeKey affects;

  static const List<InjuryKind> all = [
    InjuryKind(
      name: Say('打撲', 'A knock'),
      severity: InjurySeverity.light,
      minMatches: 1,
      maxMatches: 2,
      affects: AttributeKey.physical,
    ),
    InjuryKind(
      name: Say('軽い肉離れ', 'A slight strain'),
      severity: InjurySeverity.light,
      minMatches: 2,
      maxMatches: 3,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: Say('足首の捻挫', 'A sprained ankle'),
      severity: InjurySeverity.moderate,
      minMatches: 4,
      maxMatches: 7,
      affects: AttributeKey.dribbling,
    ),
    InjuryKind(
      name: Say('ハムストリングの肉離れ', 'A hamstring strain'),
      severity: InjurySeverity.moderate,
      minMatches: 5,
      maxMatches: 9,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: Say('疲労骨折', 'A stress fracture'),
      severity: InjurySeverity.moderate,
      minMatches: 6,
      maxMatches: 10,
      affects: AttributeKey.physical,
    ),
    InjuryKind(
      name: Say('膝の靭帯損傷', 'Knee ligament damage'),
      severity: InjurySeverity.severe,
      minMatches: 12,
      maxMatches: 22,
      affects: AttributeKey.pace,
    ),
    InjuryKind(
      name: Say('アキレス腱断裂', 'A ruptured achilles'),
      severity: InjurySeverity.severe,
      minMatches: 16,
      maxMatches: 26,
      affects: AttributeKey.pace,
    ),
  ];
}
