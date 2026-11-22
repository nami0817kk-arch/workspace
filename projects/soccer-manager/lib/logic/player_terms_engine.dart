import 'dart:math';

import '../l10n/tr.dart';
import 'economy_scale.dart';
import '../models/player.dart';

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
  /// - 移籍する選手は、今の週俸と見合う週俸[fairWage]の高いほうに1割を
  ///   上乗せして望む(フリーエージェントは今の週俸のまま)。見合う週俸は
  ///   能力と経験から([Player.fairWeeklyWage])、行き先の国の水準
  ///   ([currentWageLevel])。国をまたぐときは、今の週俸も
  ///   [currentWageScale]で行き先の国の水準に直す([wageScaleToHome])
  /// - 下の部へ移るなら1部下がるごとに2割増し。上の部へなら少し下げてよい
  /// - 今のクラブで先発なのに、こちらでは控えになりそうなら2割増し
  static int demand({
    required int currentWage,
    required int fairWage,
    required int? fromTier,
    required int toTier,
    required bool wasStarter,
    required bool wouldStart,
    double stepDownFactor = 1.0,
    SquadStatus promise = SquadStatus.regular,
    double agentFactor = 1.0,
    double currentWageScale = 1.0,
  }) {
    final current = currentWage * currentWageScale;
    var base = current;
    if (fromTier != null) {
      base = max(current, fairWage.toDouble()) * 1.1;
      final diff = toTier - fromTier;
      if (diff > 0) {
        // 野心の強い選手ほど、下の部へ移ることを嫌う。
        base *= 1 + 0.2 * diff * stepDownFactor;
      } else if (diff < 0) {
        base *= 0.95;
      }
    }
    if (wasStarter && !wouldStart) base *= 1.2;
    base *= promiseFactor(promise);
    // 代理人の個性(強気なら高く、穏やかなら少し安く)。
    base *= agentFactor;
    return max(minWeeklyWage, base.round());
  }

  /// 約束する序列で、望む年俸がどれだけ変わるか。出番を保証される立場ほど
  /// 高い年俸を求める(キープレイヤー +15%、ローテーション -8%、
  /// 育成枠 -15%)。
  ///
  /// 以前は逆向き(キープレイヤーで -15%)で、更新の交渉
  /// ([SquadStatus.wageFactor]: 立場が上ほど高い)と食い違っていた。
  /// 移籍と更新で同じ倍率を使う。
  static double promiseFactor(SquadStatus s) => s.wageFactor;

  /// 約束を破ったことになる、続けて先発から外れた節の数。
  static int promiseTolerance(SquadStatus s) =>
      s == SquadStatus.keyPlayer ? 3 : 5;

  /// 他のクラブが動き始めてから、選手が行き先を決めるまでの日数。
  static const int rivalDecisionDays = 5;

  /// 1日あたり、他のクラブが同じ選手を狙い始める確率(主力は高い)。
  static double rivalDailyChance({required bool keyPlayer}) =>
      keyPlayer ? 0.06 : 0.03;

  /// 他のクラブがいるとき、選手がこちらに求める週俸。他のクラブの額に、
  /// 部の差(こちらが下なら1部ごとに +1割、上なら -5%)を掛ける。選手は
  /// 年俸とクラブの格を比べて行き先を選ぶ。
  static int rivalPull({
    required int rivalWage,
    required int rivalTier,
    required int toTier,
  }) {
    final diff = toTier - rivalTier;
    final f = diff > 0 ? 1 + 0.1 * diff : (diff < 0 ? 0.95 : 1.0);
    return (rivalWage * f).round();
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
    double walkAway = walkAwayRatio,
  }) {
    if (effective >= demand) return TermsReplyKind.accept;
    if (effective < demand * walkAway) return TermsReplyKind.walkAway;
    if (round >= maxRounds) return TermsReplyKind.walkAway;
    return TermsReplyKind.counter;
  }
}
