import '../game/formulas.dart';
import 'attributes.dart';
import 'development.dart';

/// 出来事に出てくる人。
///
/// 名前のある他人は既に居る（監督・競争相手・相方・メンター・同期・代理人）。
/// 出来事に出てこなければ、ただの数字のままになる。
enum PersonKind {
  manager('監督'),
  competitor('競争相手'),
  partner('相方'),
  mentor('メンター'),
  rival('同期'),
  agent('代理人');

  const PersonKind(this.label);

  final String label;

  /// 文中に置くしるし。表示するときに名前へ差し替える。
  String get token => '<$name>';
}

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
    this.train,
    this.trainAmount = 1,
    this.insight,
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

  /// 伸びる能力。練習の外で身に付くもの。
  ///
  /// **1回の伸びは小さく保つ。** ここが大きいと、練習でも試合でもなく
  /// 出来事の引きでキャリアが決まる。
  final Detail? train;
  final int trainAmount;

  /// 閃く個人技。すでに3つ持っていれば何も起きない。
  final Signature? insight;

  /// 数字では表せない結果。
  final LifeSpecial special;

  /// 実際に乗る疲労。
  ///
  /// **ピッチの外で身に付けるにも、時間と身体を使う。**
  /// 出来事の頻度を6節に1回から3節に1回へ上げたとき、伸びの効きだけが
  /// 倍になってピーク総合力が 76.4 → 77.5、代表経験が 53% → 63% に
  /// 膨らんだ。出来事は**ただの上乗せ装置**になっていた。
  int get totalFatigue =>
      fatigue + (train != null ? Formulas.eventTrainFatigue : 0);

  /// 何に効くか。**画面に出すのはこの一覧で、判定もこの値を使う。**
  ///
  /// 選択肢が名前だけだった頃は、どれを押しても同じに見える三択で、
  /// 選ぶ材料が一つも無かった（結果は押した後に初めて出る）。
  /// 伸びる能力だけは「どれだけ」を伏せる — 土台の都合で行き先が変わるので、
  /// 数字を書くと嘘になることがある。
  List<String> get summary =>
      _lines.isEmpty ? const ['何も動かない'] : _lines;

  List<String> get _lines => [
        if (train != null) '${train!.label}が伸びる',
        if (insight != null) 'ひらめき',
        if (condition != 0) 'コンディション ${_signed(condition)}',
        if (totalFatigue != 0) '疲労 ${_signed(totalFatigue)}',
        if (morale != 0) '気持ち ${_signed(morale)}',
        if (manager != 0) '監督 ${_signed(manager)}',
        if (teammates != 0) 'ロッカールーム ${_signed(teammates)}',
        if (fame != 0) '知名度 ${_signed(fame)}',
        if (money != 0) '貯蓄 ${_signed(money)}万円',
        if (confidence != 0) '自信 ${_signed(confidence)}',
        if (ambition != 0) '野心 ${_signed(ambition)}',
        if (professionalism != 0) 'プロ意識 ${_signed(professionalism)}',
        if (temper != 0) '気性 ${_signed(temper)}',
      ];

  static String _signed(int v) => v > 0 ? '+$v' : '$v';
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
    this.needsPerson,
    this.minOverall = 0,
    this.pushingHard = false,
    this.promised = false,
    this.lowCondition = false,
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

  /// その人が居ること。居ない相手の話は出せない。
  final PersonKind? needsPerson;

  /// 総合力の下限。若いうちに大物の話が来ないようにする。
  final int minOverall;

  /// 練習で自分を追い込んでいること。
  ///
  /// 週の選択が、ピッチの外の出来事にも返ってくるようにする。
  final bool pushingHard;

  /// 監督に約束していること。
  final bool promised;

  /// コンディションが落ちていること。
  final bool lowCondition;

  bool matches(LifeContext c) {
    if (c.age < minAge || c.age > maxAge) return false;
    if (c.fame < minFame) return false;
    if (c.savings < minSavings) return false;
    if (abroad && !c.abroad) return false;
    if (afterInjury && !c.afterInjury) return false;
    if (needsSponsorOffer && !c.sponsorOffered) return false;
    if (needsCaptaincy && !c.captaincyOffered) return false;
    if (lowMorale && !c.lowMorale) return false;
    if (needsPerson != null && !c.people.containsKey(needsPerson)) return false;
    if (c.overall < minOverall) return false;
    if (pushingHard && !c.pushingHard) return false;
    if (promised && !c.promised) return false;
    if (lowCondition && !c.lowCondition) return false;
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
    this.people = const {},
    this.overall = 0,
    this.pushingHard = false,
    this.promised = false,
    this.lowCondition = false,
  });

  final int age;
  final int fame;
  final int savings;
  final bool abroad;
  final bool afterInjury;
  final bool sponsorOffered;
  final bool captaincyOffered;
  final bool lowMorale;

  /// 今そばに居る人と、その名前。
  final Map<PersonKind, String> people;

  final int overall;

  /// 練習で追い込んでいるか・監督に約束しているか・身体が落ちているか。
  final bool pushingHard;
  final bool promised;
  final bool lowCondition;
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

  /// その出来事の主役。誰も出てこないなら null。
  ///
  /// 一緒に練習している相手の話は出やすくする。組む相手を選んだことが、
  /// ピッチの外の出来事にも返ってくる。
  ///
  /// 条件から引く。出来事ごとに書かせると、書き忘れが必ず出る。
  PersonKind? get person => requirement.needsPerson;

  /// 文中のしるしを、実際の名前に差し替えた出来事を返す。
  ///
  /// 画面側で置換すると、選択肢の文と結果の文で書き分けが要る。
  /// 出す前に1度だけ埋める。
  LifeEvent withNames(Map<PersonKind, String> names) {
    String fill(String text) {
      var result = text;
      for (final entry in names.entries) {
        result = result.replaceAll(entry.key.token, entry.value);
      }
      return result;
    }

    return LifeEvent(
      id: id,
      title: fill(title),
      body: fill(body),
      choices: [
        for (final c in choices)
          LifeChoice(
            label: fill(c.label),
            outcome: fill(c.outcome),
            effect: c.effect,
          ),
      ],
      requirement: requirement,
      once: once,
    );
  }
}
