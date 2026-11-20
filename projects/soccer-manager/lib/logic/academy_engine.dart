import '../l10n/tr.dart';
import '../models/attributes.dart';
import '../models/player.dart';

/// 育成の方針。入ってくる子の伸ばし方が変わる。
enum YouthPolicy { balanced, technical, physical, quantity }

extension YouthPolicyInfo on YouthPolicy {
  String get label => switch (this) {
        YouthPolicy.balanced => Tr.pick('万能', 'Balanced'),
        YouthPolicy.technical => Tr.pick('技術重視', 'Technique first'),
        YouthPolicy.physical => Tr.pick('フィジカル重視', 'Physical first'),
        YouthPolicy.quantity => Tr.pick('数を取る', 'Numbers game'),
      };

  String get description => switch (this) {
        YouthPolicy.balanced =>
          Tr.pick('偏りなく育てる。', 'No particular emphasis.'),
        YouthPolicy.technical => Tr.pick('入ってくる子の技術の能力が+5。',
            'New intakes get +5 on technical attributes.'),
        YouthPolicy.physical => Tr.pick('入ってくる子のフィジカルの能力が+5。',
            'New intakes get +5 on physical attributes.'),
        YouthPolicy.quantity => Tr.pick('入ってくる子が2人多いが、質は少し下がる。',
            'Two more youngsters each intake, but slightly lower quality.'),
      };
}

/// アカデミーの等級(カテゴリー1〜4。1が最上)と、育成の方針の効き目。
class AcademyEngine {
  const AcademyEngine._();

  /// 等級の点: ユース施設(1〜8)とユースコーチの水準(1〜8)に、育成予算の
  /// 蓄積(0.5〜2.0)を2倍して足す。
  static double score({
    required int facilityLevel,
    required int coachLevel,
    required double momentum,
  }) =>
      facilityLevel + coachLevel + momentum * 2;

  /// カテゴリー(1〜4)。点が高いほど上。
  static int category(double score) {
    if (score >= 15) return 1;
    if (score >= 11) return 2;
    if (score >= 7) return 3;
    return 4;
  }

  /// 等級で入ってくる子の数が増える(カテゴリー1で+2、2で+1)。
  static int extraIntake(int category) => switch (category) {
        1 => 2,
        2 => 1,
        _ => 0,
      };

  /// 等級で入ってくる子の質が上がる(見立ての下限と上限に足す)。
  static int qualityBonus(int category) => switch (category) {
        1 => 4,
        2 => 2,
        3 => 0,
        _ => -2,
      };

  /// 方針の数の効き目。
  static int policyExtraIntake(YouthPolicy p) =>
      p == YouthPolicy.quantity ? 2 : 0;

  /// 方針の質の効き目。
  static int policyQualityBonus(YouthPolicy p) =>
      p == YouthPolicy.quantity ? -3 : 0;

  /// 方針に合わせて、入ってきた子の能力を伸ばす。
  static void applyPolicy(Player p, YouthPolicy policy) {
    final cat = switch (policy) {
      YouthPolicy.technical => AttributeCategory.technical,
      YouthPolicy.physical => AttributeCategory.physical,
      _ => null,
    };
    if (cat == null) return;
    for (final k in cat.keys) {
      p.setAttributeValue(k, (p.attributeValue(k) + 5).clamp(1, 100));
    }
  }
}
