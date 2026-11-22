import '../l10n/tr.dart';
import '../models/player.dart';

/// 怪我の部位。
enum InjuryPart { knee, ankle, thigh, calf, hamstring, shoulder, foot }

extension InjuryPartInfo on InjuryPart {
  String get label => switch (this) {
        InjuryPart.knee => Tr.pick('膝', 'knee'),
        InjuryPart.ankle => Tr.pick('足首', 'ankle'),
        InjuryPart.thigh => Tr.pick('太もも', 'thigh'),
        InjuryPart.calf => Tr.pick('ふくらはぎ', 'calf'),
        InjuryPart.hamstring => Tr.pick('もも裏', 'hamstring'),
        InjuryPart.shoulder => Tr.pick('肩', 'shoulder'),
        InjuryPart.foot => Tr.pick('足', 'foot'),
      };
}

/// 怪我の部位と、大きな怪我の手術の判断の決まり。
class InjuryCare {
  const InjuryCare._();

  /// 手術か保存療法かを選ばせる、靭帯の怪我の長さ(週)。
  static const int decisionWeeks = 6;

  /// 手術か保存療法かを選ばせる怪我か。長い靭帯の怪我と、長期の怪我
  /// (骨折・前十字靭帯・アキレス腱)は長さによらず選ばせる。
  static bool needsDecision(Player p) {
    final type = p.injuryType;
    if (type == null || p.injuryWeeks <= 0) return false;
    if (type.isLongTerm) return true;
    return type == InjuryType.ligament && p.injuryWeeks >= decisionWeeks;
  }

  /// 手術の費用(5部の物差しの万円)。
  static const int surgeryCostTier5 = 300;

  /// 手術: 離脱は2週延びるが、再発しない。
  static const int surgeryExtraWeeks = 2;

  /// 保存療法: 離脱は2週縮むが、治ったときに3割で再発し、4週休む。
  static const int restSavedWeeks = 2;
  static const double setbackChance = 0.3;
  static const int setbackWeeks = 4;

  /// 怪我の部位。種類と選手(と、これまでの怪我の数)から決まる。
  static InjuryPart partOf(Player p) {
    final type = p.injuryType;
    final n = p.injuryHistoryCounts.values.fold<int>(0, (a, b) => a + b);
    final h = '${p.id}#$n'
        .codeUnits
        .fold<int>(31, (a, c) => (a * 31 + c) % 1000003);
    final pool = switch (type) {
      InjuryType.ligament => const [InjuryPart.knee, InjuryPart.ankle],
      InjuryType.acl => const [InjuryPart.knee],
      InjuryType.achilles => const [InjuryPart.ankle],
      InjuryType.fracture => const [
          InjuryPart.foot,
          InjuryPart.ankle,
          InjuryPart.shoulder
        ],
      InjuryType.muscle => const [
          InjuryPart.thigh,
          InjuryPart.calf,
          InjuryPart.hamstring
        ],
      _ => const [
          InjuryPart.foot,
          InjuryPart.shoulder,
          InjuryPart.ankle,
          InjuryPart.thigh
        ],
    };
    return pool[h % pool.length];
  }

  /// 「膝の靭帯損傷」のような説明。前十字靭帯・アキレス腱は名前に部位が
  /// 入っているので、名前だけ。
  static String describe(Player p) {
    final type = p.injuryType;
    if (type == null) return '';
    if (type == InjuryType.acl || type == InjuryType.achilles) {
      return type.label;
    }
    return Tr.pick('${partOf(p).label}の${type.label}',
        '${type.label} (${partOf(p).label})');
  }
}
