import '../models/player.dart';
import '../models/team.dart';
import 'contract_engine.dart';

/// ユースから一軍へ上げるときの条件。画面に出してから決めさせるため、
/// 実行前に計算できるようにしてある。
class YouthPromotionTerms {
  /// プロ契約の週俸(万円)。
  final int weeklyWage;

  /// 契約時に一括で支払う契約金(万円)。
  final int signingBonus;

  /// 契約年数。
  final int years;

  /// 割り当てられる背番号。
  final int squadNumber;

  const YouthPromotionTerms({
    required this.weeklyWage,
    required this.signingBonus,
    required this.years,
    required this.squadNumber,
  });
}

/// ユースからの昇格を「手続き」にする。
///
/// これまでは押した瞬間に名簿へ移るだけで、費用も契約も無かった。上げ得
/// だったため、枠さえ空いていれば全員上げるのが最善になっていた。プロ契約
/// (週俸と契約金)を結ばせ、一軍の速さに慣れるまで時間がかかるようにする。
class YouthPromotionEngine {
  /// 背番号として割り当てる範囲。
  static const int maxSquadNumber = 40;

  /// 昇格直後の実戦感覚。一軍の試合に慣れるまで数週かかる。
  /// 40未満は成長に不利が付く水準で、これがあるため「とりあえず上げる」
  /// ではなく、出番を作れる時期に上げる判断になる。
  static const int adaptationSharpness = 25;

  /// 昇格が決まった選手の士気の上乗せ。
  static const int promotionHappinessBonus = 8;

  /// [team]で空いている背番号のうち最小のもの。GKは1番を優先する
  /// (空いていれば)。
  static int nextSquadNumber(Team team, Player player) {
    final used = {
      for (final p in team.players)
        if (p.squadNumber != null) p.squadNumber!,
    };
    if (player.position.group == PositionGroup.gk && !used.contains(1)) {
      return 1;
    }
    for (var n = 1; n <= maxSquadNumber; n++) {
      if (n == 1 && player.position.group != PositionGroup.gk) continue;
      if (!used.contains(n)) return n;
    }
    return maxSquadNumber;
  }

  static YouthPromotionTerms termsFor(Team team, Player player) =>
      YouthPromotionTerms(
        // 週俸は市場価値に連動する(生成時と同じ式)。ユースの給与のまま
        // 一軍に置けると、安い戦力を作る抜け道になる。
        weeklyWage: (player.marketValue / 40).round().clamp(5, 500),
        signingBonus: ContractEngine.signingBonusFor(player),
        years: ContractEngine.negotiatedYears(player),
        squadNumber: nextSquadNumber(team, player),
      );

  /// 昇格した選手に契約と適応の状態を書き込む。名簿の移動は呼び出し側が行う。
  static void applyPromotion(Player player, YouthPromotionTerms terms) {
    player.wage = terms.weeklyWage;
    player.contractYearsRemaining = terms.years;
    player.squadNumber = terms.squadNumber;
    player.appearanceFee = ContractEngine.appearanceFeeFor(player);
    // 一軍の強度に慣れるまでの期間。出番が無ければ上がらないので、
    // 上げたあとに使う必要がある。
    player.matchSharpness = adaptationSharpness;
    player.happiness =
        (player.happiness + promotionHappinessBonus).clamp(0, 100);
    // ユース時代の記録は持ち越さない(一軍の記録と混ざる)。
    player.youthMatchApps = 0;
    player.youthMatchGoals = 0;
    player.lastYouthMatchRating = 0;
    player.mentorId = null;
  }
}
