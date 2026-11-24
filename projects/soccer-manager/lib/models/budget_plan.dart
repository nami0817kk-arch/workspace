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

  /// 補強に寄せた型。給与の上限 +10%。育成は少し薄く、施設と配当を削る
  /// (増築費 +5%、株主の期待 毎年 -2)。営業は初期のままで収入は減らさない。
  factory BudgetPlan.signingFocus() => const BudgetPlan._({
        BudgetCategory.signing: 50,
        BudgetCategory.youth: 15,
        BudgetCategory.facilities: 10,
        BudgetCategory.marketing: 15,
        BudgetCategory.dividend: 10,
      });

  /// 育成に寄せた型。育成は初期の2倍(蓄積の上限に届く量)。補強と配当を
  /// 削る(給与の上限 -5%、株主の期待 毎年 -2)。施設と営業は初期のまま。
  factory BudgetPlan.youthFocus() => const BudgetPlan._({
        BudgetCategory.signing: 20,
        BudgetCategory.youth: 40,
        BudgetCategory.facilities: 15,
        BudgetCategory.marketing: 15,
        BudgetCategory.dividend: 10,
      });

  /// 画面で配り直している途中の配分。合計が100に届いていなくてもよい
  /// (足りない分が「残り」)。保存できるのは [isComplete] のものだけ。
  /// どれかが0〜100の外、または合計が100を超えるなら [ArgumentError]。
  factory BudgetPlan.draft(Map<BudgetCategory, int> shares) {
    final copy = <BudgetCategory, int>{};
    for (final c in BudgetCategory.values) {
      final v = shares[c];
      if (v == null || v < 0 || v > 100) {
        throw ArgumentError.value(shares, 'shares', 'out of 0..100');
      }
      copy[c] = v;
    }
    final plan = BudgetPlan._(copy);
    if (plan.total > 100) {
      throw ArgumentError.value(shares, 'shares', 'total over 100');
    }
    return plan;
  }

  /// −／＋ボタンの刻み(%)。
  static const int step = 5;

  int share(BudgetCategory category) => shares[category]!;

  /// 5つの合計。保存されている配分では常に100。
  int get total => shares.values.fold<int>(0, (t, v) => t + v);

  /// まだどこにも配っていない分(%)。
  int get remaining => 100 - total;

  /// 配り切っているか。保存できるのはこのときだけ。
  bool get isComplete => remaining == 0;

  bool sameAs(BudgetPlan other) =>
      BudgetCategory.values.every((c) => share(c) == other.share(c));

  /// [category] を1刻み減らす。他の配り先は動かさず、減らした分は
  /// [remaining] に回る。5の倍数でない値(旧い保存の 33% など)からは、
  /// すぐ下の5の倍数(30%)へ寄せる。
  BudgetPlan stepDown(BudgetCategory category) {
    final v = share(category);
    if (v <= 0) return this;
    final next = v % step == 0 ? v - step : v - v % step;
    return BudgetPlan._({...shares, category: next});
  }

  /// [category] を1刻み増やす。増やせるのは [remaining] の分まで。
  /// 5の倍数でない値からは、すぐ上の5の倍数へ寄せる。残りが1刻みに
  /// 足りないとき(残り3%など)は残りを全部足すので、必ず配り切れる。
  BudgetPlan stepUp(BudgetCategory category) {
    final v = share(category);
    final room = remaining;
    if (room <= 0 || v >= 100) return this;
    final wanted = step - v % step;
    final add = wanted < room ? wanted : room;
    return BudgetPlan._({...shares, category: v + add});
  }

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
