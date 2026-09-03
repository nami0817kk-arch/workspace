import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'training_engine.dart';
import '../l10n/tr.dart';

/// 育成アドバイスの種類。並び順がそのまま重要度(上ほど急ぎ)になる。
enum AdviceKind { highFatigue, lowSharpness, unusedPotential, noMentor }

extension AdviceKindInfo on AdviceKind {
  String get label => switch (this) {
        AdviceKind.highFatigue => Tr.pick('疲労', 'Fatigue'),
        AdviceKind.lowSharpness => Tr.pick('実戦感覚', 'Sharpness'),
        AdviceKind.unusedPotential => Tr.pick('伸びしろ', 'Potential'),
        AdviceKind.noMentor => Tr.pick('メンター', 'Mentor'),
      };
}

/// アドバイスに対して、その場で打てる手。
///
/// 助言を読んでから該当画面へ移動して設定する、という往復をなくすためのもの。
/// [label] は押す前に何が起きるか分かる文言にする(「メンターに田中を付ける」)。
sealed class AdviceFix {
  final String label;
  const AdviceFix(this.label);
}

/// 若手にベテランのメンターを付ける。
class AssignMentorFix extends AdviceFix {
  final String mentorId;
  const AssignMentorFix({required this.mentorId, required String label})
      : super(label);
}

/// 伸びしろのある選手に、伸ばす属性を決めて特訓ドリルを設定する。
class SetDrillFix extends AdviceFix {
  final String attributeKey;
  const SetDrillFix({required this.attributeKey, required String label})
      : super(label);
}

/// 疲れている選手の個別方針を休養にする。
class RestFix extends AdviceFix {
  const RestFix(super.label);
}

/// 育成アドバイス1件(対象選手+提案文+打てる手)。
class DevelopmentAdvice {
  final AdviceKind kind;
  final String playerId;
  final String playerName;
  final String message;

  /// その場で適用できる手。決め打ちできないものは null(実戦感覚の不足は、
  /// 出場機会を作るかローンに出すかの判断が要るので自動では決められない)。
  final AdviceFix? fix;

  const DevelopmentAdvice({
    required this.kind,
    required this.playerId,
    required this.playerName,
    required this.message,
    this.fix,
  });
}

/// コーチ陣がスカッドを見渡し、育成面で手を打つべき選手を挙げる
/// アドバイザー。トレーニング画面の提案カードに表示する。
/// 押しつけはせず、既にケアされている選手(ドリル設定済み等)は挙げない。
class DevelopmentAdvisor {
  /// この疲労以上で休養を勧める。
  static const int fatigueThreshold = 75;

  /// この実戦感覚未満で出場機会の確保を勧める(成長ペナルティと同じ閾値)。
  static const int sharpnessThreshold = 40;

  /// 「伸びしろ豊富」とみなす潜在能力と現在能力の差。
  static const int potentialGapThreshold = 10;

  /// 伸びしろ提案・メンター提案の対象になる年齢の上限。
  static const int youngAgeLimit = 21;
  static const int mentorAgeLimit = 23;

  /// 一度に表示するアドバイスの上限(多すぎると読まれないため)。
  static const int maxAdvices = 6;

  static List<DevelopmentAdvice> advise(Team team) {
    final advices = <DevelopmentAdvice>[];
    final hasMentorCandidate =
        team.players.any((p) => p.age >= TrainingEngine.minMentorAge);

    for (final p in team.players) {
      if (p.isLoanedOut) continue;
      if (p.fatigue >= fatigueThreshold) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.highFatigue,
            playerId: p.id,
            playerName: p.name,
            message: Tr.pick('疲労${p.fatigue}。休養方針やローテーションで回復を',
                'Fatigue ${p.fatigue}. Rest him or rotate him to bring it back'),
            fix: p.individualFocus == TrainingFocus.rest
                ? null
                : RestFix(Tr.pick('休養にする', 'Rest him')),
          ),
        );
      }
      if (!p.isInjured && p.matchSharpness < sharpnessThreshold) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.lowSharpness,
            playerId: p.id,
            playerName: p.name,
            message: Tr.pick('実戦感覚${p.matchSharpness}で成長が鈍っている。出場機会かローン武者修行を',
                'Sharpness ${p.matchSharpness} is holding his growth back. He needs minutes, or a loan'),
          ),
        );
      }
      if (p.age <= youngAgeLimit &&
          p.potential - p.overall >= potentialGapThreshold &&
          p.drillAttributeKey == null &&
          p.developmentTargetRole == null) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.unusedPotential,
            playerId: p.id,
            playerName: p.name,
            message: Tr.pick(
                '伸びしろ${p.potential - p.overall}が手つかず。特訓ドリルか育成プランで方向付けを',
                '${p.potential - p.overall} of room to grow, untouched. Point him somewhere with a focus drill or a development plan'),
            fix: _drillFixFor(p),
          ),
        );
      }
      if (p.age <= mentorAgeLimit && p.mentorId == null && hasMentorCandidate) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.noMentor,
            playerId: p.id,
            playerName: p.name,
            message: Tr.pick('メンター未設定。ベテランを付けると成長率が上がる',
                'No mentor. Pairing him with an older player would speed up his growth'),
            fix: _mentorFixFor(p, team),
          ),
        );
      }
    }

    advices.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return advices.length > maxAdvices
        ? advices.sublist(0, maxAdvices)
        : advices;
  }

  /// メンターに付ける相手を選ぶ。条件を満たすベテランのうち総合力が最も高い者。
  /// メンター役に人数制限は無いので、単純に一番良い手本を当てる。
  static AdviceFix? _mentorFixFor(Player mentee, Team team) {
    Player? best;
    for (final p in team.players) {
      if (p.id == mentee.id) continue;
      if (p.age < TrainingEngine.minMentorAge) continue;
      if (p.isLoanedOut) continue;
      if (best == null || p.overall > best.overall) best = p;
    }
    if (best == null) return null;
    return AssignMentorFix(
      mentorId: best.id,
      label: Tr.pick('${best.name}を付ける', 'Pair with ${best.name}'),
    );
  }

  /// 伸ばす属性を決める。総合力に効く属性のうち、その選手が最も低いもの。
  /// 一番弱いところを埋める形にすると、総合力への効きが分かりやすい。
  static AdviceFix? _drillFixFor(Player p) {
    final candidates = p.position == Position.gk
        ? const [
            AttributeKeys.reflexes,
            AttributeKeys.handling,
            AttributeKeys.oneOnOnes,
            AttributeKeys.aerialReach,
          ]
        : const [
            AttributeKeys.finishing,
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.passing,
            AttributeKeys.firstTouch,
            AttributeKeys.vision,
            AttributeKeys.stamina,
          ];
    String? lowest;
    int lowestValue = 1 << 30;
    for (final key in candidates) {
      final v = p.attributeValue(key);
      if (v < lowestValue) {
        lowestValue = v;
        lowest = key;
      }
    }
    if (lowest == null) return null;
    return SetDrillFix(
      attributeKey: lowest,
      label: Tr.pick('${AttributeKeys.labelOf(lowest)}の特訓を設定',
          'Set a ${AttributeKeys.labelOf(lowest)} drill'),
    );
  }
}
