/// ピッチの外で起きたことの効き方。
///
/// 数字はすべて小さい。ここが大きいと、試合でも練習でもなく
/// 「イベント運」でキャリアが決まってしまう。
class LifeEffect {
  const LifeEffect({
    this.morale = 0,
    this.fame = 0,
    this.manager = 0,
    this.teammates = 0,
    this.money = 0,
    this.condition = 0,
    this.fatigue = 0,
    this.confidence = 0,
    this.ambition = 0,
    this.professionalism = 0,
    this.temper = 0,
    this.special = LifeSpecial.none,
  });

  final int morale;
  final int fame;
  final int manager;
  final int teammates;

  /// 貯蓄の増減（万円）。
  final int money;

  final int condition;
  final int fatigue;

  final int confidence;
  final int ambition;
  final int professionalism;
  final int temper;

  /// 数字では表せない結果。
  final LifeSpecial special;
}

/// 数字ではない結果。状態そのものを変えるもの。
enum LifeSpecial {
  none,
  acceptSponsor,
  declineSponsor,
  takeCaptain,
  declineCaptain,
  foundCharity,
}

/// 出来事に対する選択肢。
class LifeChoice {
  const LifeChoice({
    required this.label,
    required this.outcome,
    required this.effect,
  });

  final String label;

  /// 選んだ後に表示する一文。
  final String outcome;

  final LifeEffect effect;
}

/// 出来事が起きる条件。
class LifeRequirement {
  const LifeRequirement({
    this.minAge = 0,
    this.maxAge = 99,
    this.minFame = 0,
    this.minSavings = 0,
    this.abroad = false,
    this.afterInjury = false,
    this.needsSponsorOffer = false,
    this.needsCaptaincy = false,
    this.lowMorale = false,
  });

  final int minAge;
  final int maxAge;
  final int minFame;
  final int minSavings;

  /// 母国の外でプレーしていること。
  final bool abroad;

  /// 怪我から戻った直後であること。
  final bool afterInjury;

  /// スポンサーの話が来ていること。
  final bool needsSponsorOffer;

  /// キャプテンの話が来ていること。
  final bool needsCaptaincy;

  /// 気持ちが落ちていること。
  final bool lowMorale;

  bool matches(LifeContext c) {
    if (c.age < minAge || c.age > maxAge) return false;
    if (c.fame < minFame) return false;
    if (c.savings < minSavings) return false;
    if (abroad && !c.abroad) return false;
    if (afterInjury && !c.afterInjury) return false;
    if (needsSponsorOffer && !c.sponsorOffered) return false;
    if (needsCaptaincy && !c.captaincyOffered) return false;
    if (lowMorale && !c.lowMorale) return false;
    return true;
  }
}

/// 出来事を選ぶときに見る、今の状況。
class LifeContext {
  const LifeContext({
    required this.age,
    required this.fame,
    required this.savings,
    required this.abroad,
    required this.afterInjury,
    required this.sponsorOffered,
    required this.captaincyOffered,
    required this.lowMorale,
  });

  final int age;
  final int fame;
  final int savings;
  final bool abroad;
  final bool afterInjury;
  final bool sponsorOffered;
  final bool captaincyOffered;
  final bool lowMorale;
}

/// ピッチの外で起きること。
///
/// 選手の人生は試合だけで出来ていない。ただし、どれを選んでも
/// 致命傷にはならない大きさに収めてある。物語であって、罠ではない。
class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.choices,
    this.requirement = const LifeRequirement(),
    this.once = true,
  });

  final String id;
  final String title;
  final String body;
  final List<LifeChoice> choices;
  final LifeRequirement requirement;

  /// キャリアで一度きりか。
  final bool once;
}
