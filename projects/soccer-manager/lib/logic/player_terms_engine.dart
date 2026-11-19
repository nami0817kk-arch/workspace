import 'dart:math';

import '../l10n/tr.dart';
import 'economy_scale.dart';

/// 選手(代理人)の返事の種類。
enum TermsReplyKind { accept, counter, walkAway }

/// 移籍する選手との条件(年俸・年数・サイン料)の交渉の決まり。
///
/// クラブ同士で移籍金がまとまっても、選手が条件をのまなければ移籍は
/// 成り立たない。選手は「今より上がるか」「下の部へ落ちないか」
/// 「試合に出られるか」で望む年俸を決める。
class PlayerTermsEngine {
  const PlayerTermsEngine._();

  /// 条件を出せる回数。3回目でも届かなければ決裂する。
  static const int maxRounds = 3;

  /// 望む額のこれより下は、話にならないとして席を立つ。
  static const double walkAwayRatio = 0.7;

  /// 選手が望む週俸(万円)。
  ///
  /// - 移籍する選手は、今の週俸と価値に見合う週俸の高いほうに1割を上乗せ
  ///   して望む(フリーエージェントは今の週俸のまま)
  /// - 下の部へ移るなら1部下がるごとに2割増し。上の部へなら少し下げてよい
  /// - 今のクラブで先発なのに、こちらでは控えになりそうなら2割増し
  static int demand({
    required int currentWage,
    required int marketValue,
    required int? fromTier,
    required int toTier,
    required bool wasStarter,
    required bool wouldStart,
  }) {
    var base = currentWage.toDouble();
    if (fromTier != null) {
      base = max(currentWage, weeklyWageForValue(marketValue)) * 1.1;
      final diff = toTier - fromTier;
      if (diff > 0) {
        base *= 1 + 0.2 * diff;
      } else if (diff < 0) {
        base *= 0.95;
      }
    }
    if (wasStarter && !wouldStart) base *= 1.2;
    return max(minWeeklyWage, base.round());
  }

  /// 条件に関係なく断る理由(無ければ null)。30歳までの選手は、3部以上
  /// 下のクラブへは行かない。
  static String? refusal({
    required int? fromTier,
    required int toTier,
    required int age,
  }) {
    if (fromTier == null || age >= 31) return null;
    final diff = toTier - fromTier;
    if (diff < 3) return null;
    return Tr.pick('$diff部も下のクラブへは行かない、と断られました。',
        'He will not drop $diff divisions to join you.');
  }

  /// サイン料を契約の年数でならした、1週あたりの実質の週俸。
  static int effectiveWeekly({
    required int weeklyWage,
    required int years,
    required int signingBonus,
  }) =>
      weeklyWage + (signingBonus / (52 * max(1, years))).round();

  /// 条件への返事。[round]は何回目の条件か。
  static TermsReplyKind judge({
    required int effective,
    required int demand,
    required int round,
  }) {
    if (effective >= demand) return TermsReplyKind.accept;
    if (effective < demand * walkAwayRatio) return TermsReplyKind.walkAway;
    if (round >= maxRounds) return TermsReplyKind.walkAway;
    return TermsReplyKind.counter;
  }
}
