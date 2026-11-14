import 'dart:math';

import '../l10n/tr.dart';
import '../models/ledger.dart';

/// 国(リーグ)ごとの財務規則の式。実在のリーグ名は使わず「〜式」と呼ぶ。
/// 名前(name)はセーブに残すので、変えない。
enum RuleSet {
  /// 直近3季の累積赤字に上限がある。超えると勝ち点を引かれる。
  britain,

  /// 債務超過と連続赤字を許さない。免許(ライセンス)の審査。
  japan;

  String get label => switch (this) {
        britain => Tr.pick('英国式(収支規則)', 'British style (profit rule)'),
        japan => Tr.pick('日本式(クラブライセンス)', 'Japanese style (club licence)'),
      };

  String get summary => switch (this) {
        britain => Tr.pick(
            '直近3季の累積赤字が上限(営業収入の約25%)を超えると、罰金と勝ち点の剥奪を受けます。',
            'If your losses over the last three seasons pass the limit (about 25% of income), you are fined and docked points.'),
        japan => Tr.pick(
            'シーズン終了時に債務超過だと補強が1季禁止になります。3季連続で赤字だと勝ち点を引かれます。',
            'If you end a season in the red, signings are banned for a season. Three losing seasons in a row cost you points.'),
      };
}

/// 規則違反に対する罰。
class RulePenalty {
  const RulePenalty({
    this.fine = 0,
    this.trustLoss = 0,
    this.banSeasons = 0,
    this.pointsDeduction = 0,
    required this.reason,
  });

  /// 罰金(万円)。
  final int fine;

  /// サポーターの期待の低下。
  final int trustLoss;

  /// 補強の禁止(季数)。
  final int banSeasons;

  /// 来季の勝ち点の剥奪。
  final int pointsDeduction;

  /// 理由(ニュースに出す)。
  final String reason;

  /// 2つの罰を合わせる。
  RulePenalty merge(RulePenalty other) => RulePenalty(
        fine: fine + other.fine,
        trustLoss: trustLoss + other.trustLoss,
        banSeasons: max(banSeasons, other.banSeasons),
        pointsDeduction: pointsDeduction + other.pointsDeduction,
        reason: '$reason / ${other.reason}',
      );
}

/// 規則の現在の状況(画面に出す1行)。
class RuleStatus {
  const RuleStatus({
    required this.label,
    required this.detail,
    required this.level,
  });

  final String label;
  final String detail;

  /// 0=問題なし、1=注意、2=違反。
  final int level;
}

class RuleReport {
  const RuleReport({required this.statuses, this.penalty});

  final List<RuleStatus> statuses;

  /// 今シーズンを終えた時点で受ける罰。無ければ null。
  final RulePenalty? penalty;
}

/// 規則の判定。画面とシーズン終了の処理の両方がここを使う。
class RulesEngine {
  const RulesEngine._();

  /// 累積赤字を数える季数。
  static const int lossWindowSeasons = 3;

  /// 累積赤字の上限の、営業収入(年平均)に対する割合。
  static const double lossLimitShare = 0.25;

  /// 上限の下限(万円)。収入が小さいクラブで 0 にならないように。
  static const int lossLimitFloor = 300;

  /// [ledgers]はシーズン順。最後が今季。
  static RuleReport evaluate({
    required RuleSet ruleSet,
    required List<SeasonLedger> ledgers,
    required int budget,
  }) =>
      switch (ruleSet) {
        RuleSet.britain => _britain(ledgers),
        RuleSet.japan => _japan(ledgers, budget),
      };

  static List<SeasonLedger> _window(List<SeasonLedger> ledgers) =>
      ledgers.length <= lossWindowSeasons
          ? ledgers
          : ledgers.sublist(ledgers.length - lossWindowSeasons);

  /// 直近の累積赤字の上限(万円)。
  static int lossLimitFor(List<SeasonLedger> window) {
    final incomes =
        window.map((l) => l.operatingIncome).where((v) => v > 0).toList();
    if (incomes.isEmpty) return lossLimitFloor;
    final avg = incomes.fold<int>(0, (s, v) => s + v) / incomes.length;
    return max(lossLimitFloor, (avg * lossLimitShare).round());
  }

  static RuleReport _britain(List<SeasonLedger> ledgers) {
    final window = _window(ledgers);
    final cumulative = window.fold<int>(0, (s, l) => s + l.profit);
    final loss = max(0, -cumulative);
    final limit = lossLimitFor(window);
    final level = loss > limit ? 2 : (loss > limit * 0.8 ? 1 : 0);
    final status = RuleStatus(
      label: Tr.pick('直近${window.length}季の累積赤字', 'Losses over ${window.length} seasons'),
      detail: Tr.pick('$loss / 上限$limit万円', '$loss / limit $limit'),
      level: level,
    );
    if (level < 2) return RuleReport(statuses: [status]);
    final excess = loss - limit;
    final points = min(12, 3 + 3 * (excess * 4 ~/ limit));
    return RuleReport(
      statuses: [status],
      penalty: RulePenalty(
        fine: (excess * 0.1).round(),
        trustLoss: 10,
        pointsDeduction: points,
        reason: Tr.pick('累積赤字が上限を$excess万円超えました',
            'Cumulative losses passed the limit by $excess'),
      ),
    );
  }

  static RuleReport _japan(List<SeasonLedger> ledgers, int budget) {
    var streak = 0;
    for (final l in ledgers.reversed) {
      if (l.profit < 0) {
        streak++;
      } else {
        break;
      }
    }
    final insolvent = budget < 0;
    final statuses = [
      RuleStatus(
        label: Tr.pick('債務超過', 'Insolvency'),
        detail: insolvent
            ? Tr.pick('資金が$budget万円(マイナス)', 'Funds are $budget (negative)')
            : Tr.pick('なし', 'None'),
        level: insolvent ? 2 : 0,
      ),
      RuleStatus(
        label: Tr.pick('連続赤字', 'Consecutive losses'),
        detail: Tr.pick('$streak季 / 3季で違反', '$streak seasons / 3 is a breach'),
        level: streak >= 3 ? 2 : (streak == 2 ? 1 : 0),
      ),
    ];
    RulePenalty? penalty;
    if (insolvent) {
      penalty = RulePenalty(
        trustLoss: 10,
        banSeasons: 1,
        reason: Tr.pick('債務超過でライセンスの審査に通りませんでした',
            'You failed the licence review because of insolvency'),
      );
    }
    if (streak >= 3) {
      final p = RulePenalty(
        trustLoss: 10,
        pointsDeduction: 6,
        reason: Tr.pick('3季連続の赤字でライセンスに条件が付きました',
            'Three losing seasons in a row put conditions on your licence'),
      );
      penalty = penalty == null ? p : penalty.merge(p);
    }
    return RuleReport(statuses: statuses, penalty: penalty);
  }
}
