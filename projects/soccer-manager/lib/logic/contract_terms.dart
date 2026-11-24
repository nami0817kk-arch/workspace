import 'dart:math';

import '../models/player.dart';

/// 契約の交渉で出す条件の一式(2026-11-25。FM の契約の画面に寄せた)。
///
/// 年俸・期間・延長オプションに加えて、序列の約束・サイン料・出来高・
/// 年ごとの昇給・リリース条項・降格/昇格の条項を交渉の項目にした。以前は
/// 序列とサイン料は移籍のときだけ、出来高と昇給は選手の詳しい画面の
/// 「契約の中身」で組み替え、リリース条項は詳しい画面で勝手に付けられた。
class ContractTerms {
  const ContractTerms({
    required this.wage,
    required this.endYear,
    this.option = false,
    this.promise = SquadStatus.regular,
    this.signingBonus = 0,
    this.goalBonus = 0,
    this.raisePct = 0,
    this.releaseClause,
    this.relegationCutPct,
    this.promotionRisePct = 0,
  });

  /// 週俸(万円)。画面では年俸で見せる。
  final int wage;
  final int endYear;
  final bool option;
  final SquadStatus promise;

  /// サイン料(契約のときに1回払う。万円)。
  final int signingBonus;

  /// 出来高: リーグ戦の1点ごとに払う額(万円)。
  final int goalBonus;

  /// 年ごとの昇給(%)。
  final int raisePct;

  /// リリース条項(万円)。null なら付けない。
  final int? releaseClause;

  /// 降格したら年俸を下げる割合(%)。null は国の既定。
  final int? relegationCutPct;

  /// 昇格したら年俸を上げる割合(%)。
  final int promotionRisePct;

  ContractTerms copyWith({
    int? wage,
    int? endYear,
    bool? option,
    SquadStatus? promise,
    int? signingBonus,
    int? goalBonus,
    int? raisePct,
    int? Function()? releaseClause,
    int? Function()? relegationCutPct,
    int? promotionRisePct,
  }) =>
      ContractTerms(
        wage: wage ?? this.wage,
        endYear: endYear ?? this.endYear,
        option: option ?? this.option,
        promise: promise ?? this.promise,
        signingBonus: signingBonus ?? this.signingBonus,
        goalBonus: goalBonus ?? this.goalBonus,
        raisePct: raisePct ?? this.raisePct,
        releaseClause:
            releaseClause != null ? releaseClause() : this.releaseClause,
        relegationCutPct: relegationCutPct != null
            ? relegationCutPct()
            : this.relegationCutPct,
        promotionRisePct: promotionRisePct ?? this.promotionRisePct,
      );
}

/// 条件の値打ちの決まり。選手(代理人)は、年俸以外の項目も1週あたりの
/// 額に直して年俸に足し、それで要求に届くかを見る(移籍のサイン料を年数で
/// ならすのと同じ考え。PlayerTermsEngine.effectiveWeekly)。
class ContractTermsEngine {
  const ContractTermsEngine._();

  /// 年ごとの昇給の選択肢(%)。
  static const raiseChoices = [0, 5, 10, 15];

  /// 降格の条項の選択肢(年俸を下げる割合%。null は国の既定)。
  static const relegationChoices = [0, 20, 30, 40, 50];

  /// 昇格の条項の選択肢(年俸を上げる割合%)。
  static const promotionChoices = [0, 10, 20, 30];

  /// リリース条項の選択肢(市場価値の何倍か。0 は付けない)。
  static const releaseMultiples = [0.0, 1.5, 2.0, 3.0, 5.0];

  /// 降格・昇格が起きる見込み(条項の値打ちの重み)。
  static const divisionChangeWeight = 0.2;

  /// 1季に取りそうなリーグ戦の得点(出来高の見積もり)。今季の得点が
  /// 分かれば、それと位置の目安の大きいほう。
  static double expectedGoals(Player p, {int goalsThisSeason = 0}) {
    final byPos = switch (p.position.group) {
      PositionGroup.gk => 0.0,
      PositionGroup.def => 1.5,
      PositionGroup.mid => 4.0,
      PositionGroup.att => 11.0,
    };
    return max(byPos, goalsThisSeason.toDouble());
  }

  /// リリース条項が選手にとってどれだけ嬉しいか(年俸に対する割合)。
  /// 安い条項ほど、上のクラブへ移れる道が開くので喜ぶ。
  static double releaseValueShare(int? clause, int marketValue) {
    if (clause == null || marketValue <= 0) return 0;
    final m = clause / marketValue;
    if (m <= 1.5) return 0.06;
    if (m <= 2) return 0.04;
    if (m <= 3) return 0.02;
    return 0.01;
  }

  /// 選手から見た、年俸以外の項目の1週あたりの値打ち(万円)。
  ///
  /// [requiredBonus]は選手が求めるサイン料(それより多ければ上乗せ、
  /// 少なければ差し引き)、[defaultRelegationCutPct]は国の既定の降格の
  /// 条項(それより軽ければ喜ぶ)。
  static int extrasWeekly(
    Player p,
    ContractTerms t, {
    required int requiredBonus,
    required int defaultRelegationCutPct,
    required int years,
    int goalsThisSeason = 0,
  }) {
    final y = max(1, years);
    final wage = t.wage;
    var v = (t.signingBonus - requiredBonus) / (52 * y);
    v += t.goalBonus * expectedGoals(p, goalsThisSeason: goalsThisSeason) / 52;
    // 昇給は契約の途中から効く(1年目は据え置き)。平均の上乗せ。
    v += wage * t.raisePct / 100 * (y - 1) / 2;
    final cut = t.relegationCutPct ?? defaultRelegationCutPct;
    v += wage * (defaultRelegationCutPct - cut) / 100 * divisionChangeWeight;
    v += wage * t.promotionRisePct / 100 * divisionChangeWeight;
    v += wage * releaseValueShare(t.releaseClause, p.marketValue);
    return v.round();
  }

  /// 序列の約束で、求める週俸がどれだけ変わるか(今の序列に対する比)。
  static double promiseFactor(SquadStatus current, SquadStatus promise) =>
      promise.wageFactor / current.wageFactor;

  /// クラブが1季に払う見込みの出来高(万円)。
  static int expectedGoalBonusPerSeason(Player p, ContractTerms t,
          {int goalsThisSeason = 0}) =>
      (t.goalBonus * expectedGoals(p, goalsThisSeason: goalsThisSeason))
          .round();

  /// 契約の期間で払う年俸の合計(昇給を含む。万円)。
  static int totalSalary(ContractTerms t, int years) {
    var total = 0.0;
    var weekly = t.wage.toDouble();
    for (var i = 0; i < max(1, years); i++) {
      total += weekly * 52;
      weekly *= 1 + t.raisePct / 100;
    }
    return total.round();
  }
}
