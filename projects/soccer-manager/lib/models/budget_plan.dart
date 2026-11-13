import '../l10n/tr.dart';

/// オーナーが年の予算を配る5つの先。
///
/// 効き方に時間差がある。補強はすぐ、営業は1年後、育成は2〜3年後、
/// 施設は3〜5年後。配当は株主の期待に効くだけで、戦力にはならない。
enum BudgetCategory { signing, youth, facilities, marketing, dividend }

extension BudgetCategoryInfo on BudgetCategory {
  String get label => switch (this) {
        BudgetCategory.signing => Tr.pick('補強', 'Signings'),
        BudgetCategory.youth => Tr.pick('育成', 'Youth'),
        BudgetCategory.facilities => Tr.pick('施設', 'Facilities'),
        BudgetCategory.marketing => Tr.pick('営業', 'Marketing'),
        BudgetCategory.dividend => Tr.pick('配当・内部留保', 'Dividends'),
      };

  String get description => switch (this) {
        BudgetCategory.signing =>
          Tr.pick('移籍金と年俸。戦力が上がり、成績に返る。効くのはすぐ。',
              'Fees and wages. Lifts the squad, and the results. Pays off at once.'),
        BudgetCategory.youth => Tr.pick(
            'ユースと練習設備。若手の伸びと将来の戦力。2〜3年後に効く。',
            'Youth and training. Young players grow. Pays off in two to three years.'),
        BudgetCategory.facilities => Tr.pick(
            'スタジアム。収入と人気の土台。3〜5年後に効く。',
            'The stadium. The base of income and popularity. Pays off in three to five years.'),
        BudgetCategory.marketing => Tr.pick(
            'スポンサーと広報。収入と人気が上がる。1年後に効く。',
            'Sponsors and PR. Lifts income and popularity. Pays off in a year.'),
        BudgetCategory.dividend => Tr.pick(
            '株主への配当と、内部留保。株主の期待に効くが、戦力にはならない。',
            'Dividends and reserves. Pleases shareholders, adds no strength.'),
      };
}

/// 5つの配り先への比率(%)。合計は常に100。
class BudgetPlan {
  final Map<BudgetCategory, int> shares;

  const BudgetPlan._(this.shares);

  /// 初期の配分。どれか1つに偏らない形。
  factory BudgetPlan.balanced() => const BudgetPlan._({
        BudgetCategory.signing: 30,
        BudgetCategory.youth: 20,
        BudgetCategory.facilities: 15,
        BudgetCategory.marketing: 15,
        BudgetCategory.dividend: 20,
      });

  int share(BudgetCategory category) => shares[category]!;

  /// [category] の比率を [share](0〜100)にし、残りの4つは今の比率の
  /// 大きさに応じて分け直す。合計は100のまま。端数は比率の大きい配り先へ
  /// 1ずつ回す。
  BudgetPlan withShare(BudgetCategory category, int share) {
    final target = share.clamp(0, 100);
    final others =
        BudgetCategory.values.where((c) => c != category).toList();
    final remaining = 100 - target;
    final otherTotal = others.fold<int>(0, (t, c) => t + shares[c]!);

    final next = <BudgetCategory, int>{category: target};
    var assigned = 0;
    for (final c in others) {
      final v = otherTotal == 0
          ? remaining ~/ others.length
          : remaining * shares[c]! ~/ otherTotal;
      next[c] = v;
      assigned += v;
    }

    final order = [...others]..sort((a, b) {
        final byShare = shares[b]!.compareTo(shares[a]!);
        return byShare != 0 ? byShare : a.index.compareTo(b.index);
      });
    var leftover = remaining - assigned;
    var i = 0;
    while (leftover > 0) {
      final c = order[i % order.length];
      next[c] = next[c]! + 1;
      leftover--;
      i++;
    }
    return BudgetPlan._(next);
  }

  Map<String, dynamic> toJson() => {
        for (final c in BudgetCategory.values) c.name: shares[c],
      };

  /// 保存されていない・壊れている・合計が100でないときは、初期の配分にする。
  factory BudgetPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BudgetPlan.balanced();
    final parsed = <BudgetCategory, int>{};
    for (final c in BudgetCategory.values) {
      final v = json[c.name];
      if (v is! int || v < 0 || v > 100) return BudgetPlan.balanced();
      parsed[c] = v;
    }
    final total = parsed.values.fold<int>(0, (t, v) => t + v);
    return total == 100 ? BudgetPlan._(parsed) : BudgetPlan.balanced();
  }
}
