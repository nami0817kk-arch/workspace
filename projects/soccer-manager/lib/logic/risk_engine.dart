import 'dart:math';

import '../l10n/tr.dart';
import 'sponsor_engine.dart';

/// 突発の出来事の種類。
enum IncidentKind {
  /// 選手の不祥事。信頼も落ちる。
  scandal,

  /// スタジアムの設備故障。
  repair,

  /// 災害・悪天候での試合中止。
  disaster;

  String get label => switch (this) {
        scandal => Tr.pick('選手の不祥事', 'Player scandal'),
        repair => Tr.pick('スタジアムの設備故障', 'Stadium breakdown'),
        disaster => Tr.pick('災害による試合中止', 'Disaster cancellation'),
      };
}

/// 起きた出来事。[loss]は損失(万円)、[trustLoss]はサポーターの期待の低下。
class Incident {
  const Incident({
    required this.kind,
    required this.loss,
    required this.trustLoss,
  });

  final IncidentKind kind;
  final int loss;
  final int trustLoss;
}

/// 損失を、保険・基金・クラブの順に払った結果。
class IncidentCover {
  const IncidentCover({
    required this.byInsurance,
    required this.byFund,
    required this.byClub,
    required this.fundAfter,
  });

  final int byInsurance;
  final int byFund;
  final int byClub;
  final int fundAfter;
}

/// 突発イベントと、保険・災害基金・地域貢献。備えるほど傷が浅くなる。
class RiskEngine {
  const RiskEngine._();

  /// シーズンに1つ起きる確率。
  static const double incidentChance = 0.35;

  /// 地域貢献の最大レベル。
  static const int maxCommunityLevel = 5;

  /// 保険料(万円/季)。
  static int premium(int tier) => (120 * sqrt(SponsorEngine.tierFactor(tier))).round();

  /// 地域貢献を1段上げる費用。
  static int communityCost(int nextLevel) => 300 * nextLevel;

  /// 地域貢献の効果: シーズン末にサポーターの期待が上がる量。
  static int communityTrustGain(int level) => level * 2;

  /// 出来事を引く。[chanceRoll]が確率に入らなければ null。
  /// [kindRoll]と[sizeRoll]は 0〜1。
  static Incident? roll({
    required double chanceRoll,
    required double kindRoll,
    required double sizeRoll,
    required int tier,
    required int communityLevel,
  }) {
    if (chanceRoll >= incidentChance) return null;
    final kind = IncidentKind.values[
        (kindRoll * IncidentKind.values.length)
            .floor()
            .clamp(0, IncidentKind.values.length - 1)];
    // 地域貢献が厚いと、不祥事の評判被害が小さい。
    final scale = sqrt(SponsorEngine.tierFactor(tier));
    final loss = ((200 + sizeRoll * 500) * scale).round();
    final trust = kind == IncidentKind.scandal
        ? max(0, 6 - communityLevel)
        : (kind == IncidentKind.disaster ? 2 : 0);
    return Incident(kind: kind, loss: loss, trustLoss: trust);
  }

  /// 損失の払い方。保険は損失の半分、残りを基金、まだ残ればクラブの資金。
  static IncidentCover cover({
    required int loss,
    required bool insured,
    required int fund,
  }) {
    final insurance = insured ? (loss / 2).round() : 0;
    var rest = loss - insurance;
    final fromFund = min(fund, rest);
    rest -= fromFund;
    return IncidentCover(
      byInsurance: insurance,
      byFund: fromFund,
      byClub: rest,
      fundAfter: fund - fromFund,
    );
  }
}
