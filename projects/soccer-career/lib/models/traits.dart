import 'dart:math';

import '../l10n/lang.dart';
import '../game/formulas.dart';
import '../game/scenarios.dart';
import 'attributes.dart';

/// 局面で特性を評価するときの文脈。
class TraitContext {
  const TraitContext({
    required this.minute,
    required this.home,
    required this.outcome,
    required this.afterFailure,
    required this.afterSuccess,
    required this.key,
    required this.detail,
    required this.scenarioId,
    required this.international,
    this.bigMatch = false,
    this.margin = 0,
    this.weakFoot = false,
    this.abroad = false,
    this.substitute = false,
  });

  final int minute;
  final bool home;
  final Outcome outcome;
  final bool afterFailure;
  final bool afterSuccess;
  final AttributeKey key;
  final Detail? detail;
  final String scenarioId;
  final bool international;

  /// 格上との対戦や代表戦。
  final bool bigMatch;

  /// その時点の得失点差。負けていれば負の数。
  final int margin;

  /// 逆足で対応する局面か。
  final bool weakFoot;

  /// 母国の外でプレーしているか。
  final bool abroad;

  /// 途中出場か。
  final bool substitute;
}

/// 局面での効き方。「どういうとき」と「いくつ」の組。
///
/// 判定はこの並びを足し、画面はこの並びを文にする。表示用に別の式を
/// 書かないための形。ここがずれると「クラッチと書いてあるのに」になる。
class TraitRule {
  const TraitRule(this.when, this.value, this.applies);

  /// 「後半30分以降」のような条件の言葉。
  final String when;

  /// 成功率への加算。
  final double value;

  final bool Function(TraitContext) applies;

  String get text => '$when ${Trait.percent(value)}';
}

/// 選手の特性。キャリア開始時に2つ、たまに欠点が1つ付く。
///
/// 数値の大小ではなく「どういう場面で強いか（弱いか）」を作るもの。
/// **どれも一長一短にしてあり、上位互換の特性は無い。**
/// 引ける長所が多いほど、同じ能力値でも別の選手になる。
enum Trait {
  // ---- 場面 ----
  clutch(Say('クラッチ', 'Clutch'), Say('後半30分以降、成功率が上がる', 'Better from the 75th minute on')),
  composed(Say('冷静', 'Composed'), Say('ゴールに直結する手の成功率が上がる', 'Better on shots at goal')),
  fighter(Say('負けず嫌い', 'Sore Loser'), Say('失敗した直後の手は成功率が上がる', 'Better on the move right after a failure')),
  homeHero(Say('ホームの英雄', 'Home Hero'), Say('ホームで成功率が上がり、アウェイで少し下がる', 'Better at home, slightly worse away')),
  roadWarrior(Say('アウェイの狼', 'Road Warrior'), Say('アウェイで成功率が上がり、ホームでは平常どおり', 'Better away, normal at home')),
  gambler(Say('勝負師', 'Gambler'), Say('ゴール・アシストの手が得意で、安全な手が苦手', 'Strong on shots and assists, weak on the safe option')),
  craftsman(Say('職人', 'Craftsman'), Say('安全な手が得意で、ゴールの手が少し苦手', 'Strong on the safe option, slightly weak on shots')),
  bigGame(Say('大舞台', 'Big Stage'), Say('代表戦で成功率が上がる', 'Better in internationals')),
  ironNerve(Say('本番強者', 'Nerves of Steel'), Say('格上との対戦や代表戦で強い', 'Strong against better sides and in internationals')),
  comeback(Say('逆境の男', 'Fighting Spirit'), Say('負けているときに強い', 'Strong when behind')),
  frontRunner(Say('先行逃げ切り', 'Front Runner'), Say('リードしているとき強く、負けていると力が出ない', 'Strong in the lead, flat when behind')),
  penaltyKing(Say('PK職人', 'Penalty King'), Say('PKの局面で大きく有利', 'A big edge from the spot')),
  captain(Say('キャプテンシー', 'Captaincy'), Say('評価点が少し高くつく', 'Match ratings come in slightly higher')),
  twoFooted(Say('両足使い', 'Two-Footed'), Say('逆足の局面でも精度がほとんど落ちない', 'Barely loses accuracy on his weaker foot')),
  cosmopolitan(Say('国際派', 'Cosmopolitan'), Say('国外のクラブでも力を出せる', 'Performs abroad as well as at home')),
  superSub(Say('スーパーサブ', 'Super Sub'), Say('途中出場のとき、成功率が上がる', 'Better when coming off the bench')),
  fastStarter(Say('出足が速い', 'Fast Starter'), Say('前半30分までは成功率が上がる', 'Better up to the 30th minute')),
  hotHand(Say('乗ると止まらない', 'Hot Hand'), Say('成功した直後の手は成功率が上がる', 'Better on the move right after a success')),
  assistKing(Say('ラストパスの名手', 'Last Pass'), Say('アシストに直結する手の成功率が上がる', 'Better on moves that lead to assists')),
  organizer(Say('守備の統率者', 'Defensive Organiser'), Say('無失点で終えたときの評価が高い', 'Rated highly after a clean sheet')),

  // ---- 得意技 ----
  aerialAce(Say('空中戦の鬼', 'Aerial Ace'), Say('ヘディングと競り合いに強い', 'Strong in the air and in duels')),
  sprinter(Say('スプリンター', 'Sprinter'), Say('スピード勝負に強い', 'Strong in a race for the ball')),
  playmaker(Say('司令塔', 'Playmaker'), Say('パスの手に強い', 'Strong on passing moves')),
  poacher(Say('ポーチャー', 'Poacher'), Say('決定力の手に強い', 'Strong on finishing moves')),
  wall(Say('鉄壁', 'Rock at the Back'), Say('守備の手に強い', 'Strong on defensive moves')),
  dribbler(Say('ドリブラー', 'Dribbler'), Say('仕掛ける手に強い', 'Strong when taking players on')),
  tackler(Say('潰し屋', 'Destroyer'), Say('タックルとインターセプトに強い', 'Strong at tackles and interceptions')),
  longRange(Say('ミドルの名手', 'Long Range'), Say('ロングシュートに強い', 'Strong at shots from distance')),
  crosser(Say('クロッサー', 'Crosser'), Say('クロスとロングパスに強い', 'Strong at crosses and long passes')),
  tempoSetter(Say('テンポメーカー', 'Tempo Setter'), Say('短いパスとボール扱いに強い', 'Strong at short passing and close control')),
  sweeperKeeper(Say('飛び出すGK', 'Sweeper Keeper'), Say('GKのポジショニングに強い', 'Strong at goalkeeper positioning')),
  reflexKeeper(Say('反応の鬼', 'Lightning Reflexes'), Say('セービングに強い', 'Strong at shot-stopping')),
  deadBallMaster(Say('セットプレーの名手', 'Dead Ball Specialist'), Say('居残り練習の伸びが速く、キッカーとして強い', 'Improves quickly in extra sessions and is strong as the taker')),

  // ---- 体 ----
  ironman(Say('鉄人', 'Iron Man'), Say('衰え始める年齢が2年遅い', 'Starts to decline two years later')),
  robust(Say('頑丈', 'Durable'), Say('怪我をしにくい', 'Rarely gets injured')),
  engine(Say('無尽蔵', 'Bottomless'), Say('試合と練習の消耗が少ない', 'Loses less condition in matches and training')),
  tireless(Say('タフネス', 'Tough'), Say('疲れが溜まりにくい', 'Fatigue builds up slowly')),
  fastHealer(Say('回復が早い', 'Quick Healer'), Say('離脱の期間が短い', 'Spends less time out injured')),
  quickRecovery(Say('寝れば戻る', 'Sleeps It Off'), Say('休養で戻るコンディションが大きい', 'Recovers more condition from rest')),
  earlyBloomer(Say('早熟', 'Early Bloomer'), Say('若いうちに速く伸びるが、ピークが早い', 'Grows quickly when young, but peaks early')),
  lateBloomer(Say('大器晩成', 'Late Bloomer'), Say('若いうちは伸びにくいが、ピークが遅く長い', 'Slow to grow when young, but peaks late and stays there')),
  cleanPlayer(Say('クリーンプレーヤー', 'Clean Player'), Say('荒い手でも警告を受けにくい', 'Rarely booked, even for rough challenges')),

  // ---- 頭と心 ----
  quickLearner(Say('飲み込みが早い', 'Quick Learner'), Say('練習の効きが上がる', 'Gets more out of training')),
  unshakable(Say('動じない', 'Unshakeable'), Say('気持ちが落ちにくい', 'Morale rarely drops')),
  streaky(Say('波に乗る', 'Streaky'), Say('ゾーンにもスランプにも入りやすい', 'Falls into hot and cold spells easily')),
  moodMaker(Say('ムードメーカー', 'Mood Setter'), Say('良いことがあると気持ちが大きく上向く', 'Morale rises sharply when things go well')),
  studious(Say('研究熱心', 'Student of the Game'), Say('相手の戦い方に慣れるのが速い', 'Adapts quickly to an opponent\'s style')),
  breaker(Say('殻を破る', 'Breaks Through'), Say('限界突破が起きやすい', 'Breaks his ceiling more often')),
  steady(Say('足踏みしない', 'Never Stalls'), Say('停滞期が短い', 'Shorter plateaus')),
  coachable(Say('監督受けがいい', 'Manager\'s Favourite'), Say('監督の信頼が上がりやすい', 'Earns the manager\'s trust easily')),
  utility(Say('ユーティリティ', 'Utility'), Say('慣れないポジションでも力が落ちにくい', 'Barely drops off out of position')),
  showman(Say('華がある', 'Star Quality'), Say('知名度が伸びやすい', 'Fame grows quickly')),

  // ---- 超越 ----
  // 1つの詳細能力だけ、上限（99）を超えて伸ばせる。ポテンシャルに達しても
  // その1つは伸び続ける。付いた瞬間には何も変わらず、上に行って初めて効く。
  eagleEye(Say('イーグルアイ', 'Eagle Eye'), Say('視野だけ、上限を10超えて伸ばせる', 'Vision alone can go 10 past the ceiling')),
  cannon(Say('大砲', 'Howitzer'), Say('シュート力だけ、上限を10超えて伸ばせる', 'Shot power alone can go 10 past the ceiling')),
  lightning(Say('韋駄天', 'Flash'), Say('最高速だけ、上限を10超えて伸ばせる', 'Top speed alone can go 10 past the ceiling')),
  glue(Say('吸い付くボール', 'Glue Touch'), Say('ボールコントロールだけ、上限を10超えて伸ばせる', 'Ball control alone can go 10 past the ceiling')),
  sniper(Say('狙撃手', 'Marksman'), Say('決定力だけ、上限を10超えて伸ばせる', 'Finishing alone can go 10 past the ceiling')),
  hawk(Say('鷹の読み', 'Hawk Eye'), Say('インターセプトだけ、上限を10超えて伸ばせる', 'Interceptions alone can go 10 past the ceiling')),
  ironLungs(Say('鉄の肺', 'Iron Lungs'), Say('スタミナだけ、上限を10超えて伸ばせる', 'Stamina alone can go 10 past the ceiling')),
  catReflex(Say('猫の反射', 'Cat Reflexes'), Say('セービングだけ、上限を10超えて伸ばせる', 'Shot-stopping alone can go 10 past the ceiling')),

  // ---- 欠点 ----
  fragile(Say('怪我がち', 'Injury Prone'), Say('怪我をしやすい', 'Gets injured easily'), flaw: true),
  moody(Say('気分屋', 'Moody'), Say('直前の結果に引きずられる。成功の後は強く、失敗の後は弱い', 'Carried along by the last result. Strong after a success, weak after a failure'), flaw: true),
  slowStarter(Say('スロースターター', 'Slow Starter'), Say('前半30分までは成功率が下がる', 'Worse up to the 30th minute'), flaw: true),
  bigGameShy(Say('本番に弱い', 'Shrinks on the Day'), Say('格上との対戦や代表戦で力を出せない', 'Cannot perform against better sides or in internationals'), flaw: true),
  homesick(Say('ホームシック', 'Homesick'), Say('国外のクラブでは力を出しにくい', 'Struggles to perform at a club abroad'), flaw: true),
  slowHealer(Say('治りが遅い', 'Slow Healer'), Say('離脱の期間が長い', 'Spends longer out injured'), flaw: true),
  lazy(Say('練習嫌い', 'Hates Training'), Say('練習の効きが下がる', 'Gets less out of training'), flaw: true),
  hothead(Say('瞬間湯沸かし器', 'Short Fuse'), Say('荒い手で警告を受けやすい', 'Booked easily for rough challenges'), flaw: true),
  benchCold(Say('途中出場が苦手', 'Poor Substitute'), Say('途中出場のとき、成功率が下がる', 'Worse when coming off the bench'), flaw: true),
  difficult(Say('扱いにくい', 'Difficult'), Say('監督の信頼が下がりやすい', 'Loses the manager\'s trust easily'), flaw: true),

  // ---- 稀 ----
  // 滅多に付かない代わりに、付けばキャリアの形が変わる。
  genius(Say('天才', 'Genius'), Say('滅多に生まれない。伸びが速く、上限も高い', 'Rarely born. Grows fast, and the ceiling is high'), rare: true),
  ironBody(Say('鋼の身体', 'Body of Steel'), Say('滅多に生まれない。ほとんど怪我をせず、しても早い', 'Rarely born. Hardly ever injured, and quick to recover'), rare: true),
  bornStar(Say('生まれながらの主役', 'Born Star'), Say('滅多に生まれない。名が広まり、評価も高くつく', 'Rarely born. The name spreads, and ratings come in high'), rare: true),
  bigMoment(Say('大一番の申し子', 'Child of the Big Night'), Say('滅多に生まれない。終盤と大一番で別人になる', 'Rarely born. A different player late on and on the big occasions'), rare: true),
  glassBody(Say('ガラスの身体', 'Glass Body'), Say('滅多に無い。怪我が多く、治りも遅い', 'Rarely seen. Injuries are frequent, and slow to heal'), flaw: true, rare: true);

  const Trait(
    Say label,
    Say description, {
    this.flaw = false,
    this.rare = false,
  }) : _label = label,
       _description = description;

  /// **名前と説明は日本語と英語の2つを持つ**（[Say]）。enum の引数は
  /// 定数なので `tr()` を直に書けない。外には `String` のまま見せる。
  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  /// 欠点なら true。長所と同じ引き方はしない。
  final bool flaw;

  /// 稀な特性なら true。普通の引き方には入らず、低い確率で置き換わる。
  ///
  /// 効きは強いが、それでも「一長一短」の線は残す（天才と大器晩成は排他、
  /// 鋼の身体は頑丈系と排他）。強さの釣り合いは確率で取る。
  final bool rare;

  /// 稀な長所が付く確率。20人に1人。
  static const double rareChance = 0.05;

  /// 稀な欠点が付く確率。50人に1人。
  static const double rareFlawChance = 0.02;

  /// 同時には付かない組み合わせ。
  static const List<Set<Trait>> _exclusive = [
    {Trait.earlyBloomer, Trait.lateBloomer},
    {Trait.gambler, Trait.craftsman},
    {Trait.robust, Trait.fragile},
    {Trait.fighter, Trait.moody},
    {Trait.clutch, Trait.slowStarter},
    {Trait.homeHero, Trait.roadWarrior},
    {Trait.ironNerve, Trait.bigGameShy},
    {Trait.bigGame, Trait.bigGameShy},
    {Trait.comeback, Trait.frontRunner},
    {Trait.cosmopolitan, Trait.homesick},
    {Trait.fastHealer, Trait.slowHealer},
    {Trait.quickLearner, Trait.lazy},
    {Trait.twoFooted, Trait.moody},
    {Trait.tireless, Trait.fragile},
    {Trait.superSub, Trait.benchCold},
    {Trait.fastStarter, Trait.slowStarter},
    {Trait.hotHand, Trait.moody},
    {Trait.cleanPlayer, Trait.hothead},
    {Trait.coachable, Trait.difficult},
    // 超越は1人に1つ。2つ持てると「上限の無い選手」になる。
    {
      Trait.eagleEye,
      Trait.cannon,
      Trait.lightning,
      Trait.glue,
      Trait.sniper,
      Trait.hawk,
      Trait.ironLungs,
      Trait.catReflex,
    },
    {Trait.genius, Trait.lateBloomer},
    {Trait.genius, Trait.lazy},
    {Trait.ironBody, Trait.robust},
    {Trait.ironBody, Trait.fragile},
    {Trait.ironBody, Trait.glassBody},
    {Trait.ironBody, Trait.fastHealer},
    {Trait.bornStar, Trait.showman},
    {Trait.bigMoment, Trait.clutch},
    {Trait.bigMoment, Trait.ironNerve},
    {Trait.bigMoment, Trait.slowStarter},
    {Trait.bigMoment, Trait.bigGameShy},
    {Trait.glassBody, Trait.robust},
    {Trait.glassBody, Trait.fragile},
    {Trait.glassBody, Trait.tireless},
    {Trait.glassBody, Trait.fastHealer},
  ];

  static bool compatible(Trait a, Trait b) =>
      a != b && !_exclusive.any((s) => s.contains(a) && s.contains(b));

  static List<Trait> get strengths =>
      values.where((t) => !t.flaw && !t.rare).toList();
  static List<Trait> get flaws =>
      values.where((t) => t.flaw && !t.rare).toList();
  static List<Trait> get rares => values.where((t) => t.rare).toList();

  /// GK にしか意味の無い特性。
  static const Set<Trait> _keeperOnly = {
    Trait.sweeperKeeper,
    Trait.reflexKeeper,
    Trait.catReflex,
  };

  /// GK には意味の無い特性。
  static const Set<Trait> _outfieldOnly = {
    Trait.aerialAce,
    Trait.sprinter,
    Trait.playmaker,
    Trait.poacher,
    Trait.dribbler,
    Trait.tackler,
    Trait.longRange,
    Trait.crosser,
    Trait.tempoSetter,
    Trait.assistKing,
    Trait.composed,
    Trait.twoFooted,
    Trait.eagleEye,
    Trait.cannon,
    Trait.lightning,
    Trait.glue,
    Trait.sniper,
    Trait.hawk,
  };

  /// 守備の選手にしか効かない特性（無失点の評価が乗るポジション）。
  static const Set<Trait> _defenceOnly = {Trait.organizer};

  /// **コツとして掴める特性と、そのために積む能力**。
  ///
  /// 特性は生まれ持ったものだが、**キャリアの終盤に1つだけ、
  /// 自分がやってきたことから身に付く**（パワプロの「コツ」）。
  /// ここに無い特性は掴めない——生まれつきでしか手に入らないもの
  /// （早熟・大器晩成・稀なもの・欠点）を、後から選べるようにはしない。
  ///
  /// 紐づけているのは**その場面で何度も勝負したか**を測るカテゴリ。
  /// 「パスばかり選んできた選手が、ラストパスの名手になる」という形にする。
  /// コツとして掴める特性と、掴むのに要る場面。
  ///
  /// **得意技だけを並べていたので、掴むものが決め打ちになっていた**——
  /// 実測（`test/craft_sim.dart`）で CM の90%が「司令塔」、GK の97%が
  /// 「反応の鬼」、CB の82%が「鉄壁」。よく選ぶカテゴリの順に候補を出して
  /// その先頭を取るので、**同じポジションなら同じコツ**になる。
  ///
  /// **やってきたことは、得意技だけではない。** 20年その場面で戦った選手が
  /// 身に付けるのは「そこが上手くなる」ことだけでなく、
  /// **そこでの振る舞い**（落ち着き・粘り・出足）でもある。
  /// 同じカテゴリに複数並べて、掴むものが選手ごとに割れるようにする。
  static const Map<Trait, AttributeKey> _knackKeys = {
    // ---- 配る場面 ----
    Trait.playmaker: AttributeKey.passing,
    Trait.assistKing: AttributeKey.passing,
    Trait.crosser: AttributeKey.passing,
    Trait.tempoSetter: AttributeKey.passing,
    Trait.craftsman: AttributeKey.passing,

    // ---- 決める場面 ----
    Trait.poacher: AttributeKey.shooting,
    Trait.longRange: AttributeKey.shooting,
    Trait.composed: AttributeKey.shooting,
    Trait.aerialAce: AttributeKey.shooting,
    Trait.clutch: AttributeKey.shooting,
    Trait.gambler: AttributeKey.shooting,

    // ---- 仕掛ける場面 ----
    Trait.dribbler: AttributeKey.dribbling,
    Trait.twoFooted: AttributeKey.dribbling,
    Trait.hotHand: AttributeKey.dribbling,

    // ---- 走る場面 ----
    Trait.sprinter: AttributeKey.pace,
    Trait.fastStarter: AttributeKey.pace,

    // ---- 止める場面 ----
    Trait.wall: AttributeKey.defending,
    Trait.tackler: AttributeKey.defending,
    Trait.organizer: AttributeKey.defending,
    Trait.comeback: AttributeKey.defending,
    Trait.cleanPlayer: AttributeKey.defending,

    // ---- 当たる・競る場面 ----
    Trait.ironNerve: AttributeKey.physical,
    Trait.fighter: AttributeKey.physical,
    Trait.tireless: AttributeKey.physical,

    // ---- GK ----
    Trait.reflexKeeper: AttributeKey.goalkeeping,
    Trait.sweeperKeeper: AttributeKey.goalkeeping,
    Trait.unshakable: AttributeKey.goalkeeping,
  };

  /// コツとして掴めるか。掴めないなら null。
  AttributeKey? get knackKey => _knackKeys[this];

  /// コツとして掴める特性の一覧。
  static List<Trait> get knacks => _knackKeys.keys.toList();

  /// そのポジションで意味を持つ特性か。
  ///
  /// ストライカーに「反応の鬼」が付くと、飾りの特性になる。
  /// 2つしか引けないのに、片方が死んでいるのは損でしかない。
  bool fitsPosition(Position position) {
    if (_keeperOnly.contains(this)) return position == Position.gk;
    if (_outfieldOnly.contains(this)) return position != Position.gk;
    if (_defenceOnly.contains(this)) {
      return position == Position.gk ||
          position == Position.cb ||
          position == Position.sb ||
          position == Position.dm;
    }
    return true;
  }

  /// **長所の数は、選手ごとに違う。**
  ///
  /// ずっと「長所2つ＋3割で欠点1つ」の固定だった。**同じ数のカードを
  /// 配られた選手しか生まれない**ので、能力値が似ていれば選手も似る。
  /// 特性が実際にキャリアを動かすようになった（`test/trait_sim.dart` で
  /// 長所2つと特性なしの差が ピーク +0.8〜1.1 / 代表 +4〜7）いま、
  /// **配られる枚数そのものを引く**ことに意味が出る。
  ///
  /// 重みは**平均がちょうど 2.0** になるように置いてある——ここがずれると、
  /// 特性の数を変えただけで世界の強さが動く。
  /// 1つ 36% / 2つ 36% / 3つ 18% / 4つ 9%。
  static const List<int> strengthCounts = [1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 4];

  /// 長所が1つ増えるごとに、欠点の付きやすさがどれだけ上がるか。
  ///
  /// **尖った選手ほど穴がある。** 長所を4つ配って欠点の確率がそのままだと、
  /// ただの当たりくじになる。2つのときが 0.3 で、1つなら 0.20、4つなら 0.50。
  /// **平均するとこれまでと同じ 0.30**。
  ///
  /// **0.15 に置いたら、重しが効きすぎて枚数の見返りが消えていた。**
  /// 特性を揃えて枚数だけ変えると 評価は 1枚 7.11 → 4枚 7.34 と上がるのに、
  /// 実際に引かせて枚数で束ねると 2枚 7.21 / 4枚 7.21 で**平ら**だった——
  /// 欠点の増分（4枚で 0.60＋2枚目まで）が、枚数の得をちょうど食っていた。
  /// **持っているのに効かない**のは、このゲームで何度も踏んでいる形。
  static const double flawPerStrength = 0.10;

  /// 長所を引き、その数に応じて欠点が付く。矛盾する組み合わせは避ける。
  ///
  /// ポジションを渡せば、そこで意味を持つものからだけ引く。
  /// [flawChance] を渡すと欠点の確率を固定する（0 なら欠点を引かない）。
  static List<Trait> roll(
    Random random, {
    double? flawChance,
    Position? position,
  }) {
    // **枚数を最初に引く。** ここで乱数を1つ使うので、同じ種でも
    // これまでとは違う選手が出る（種で再現している既存テストは作り直した）。
    final want = strengthCounts[random.nextInt(strengthCounts.length)];

    final picked = <Trait>[];
    final pool = [
      for (final t in strengths)
        if (position == null || t.fitsPosition(position)) t,
    ]..shuffle(random);
    for (final t in pool) {
      if (picked.length >= want) break;
      if (picked.every((p) => compatible(p, t))) picked.add(t);
    }
    final strengthCount = picked.length;

    // 欠点。**長所が多いほど付きやすい。** 渡されていれば、その値のまま使う
    // （`flawChance: 0` で欠点なしを頼む呼び方が既にある）。
    final flawOdds =
        flawChance ?? (0.3 + (strengthCount - 2) * flawPerStrength);
    var flaws = 0;
    if (flawOdds > 0) {
      // 2枚目は、長所を4つもらった選手にだけ。3枚で2つ欠点が付くと、
      // 「尖っている」ではなく「ただ穴だらけ」になる。
      final second = strengthCount >= 4 ? flawPerStrength : 0.0;
      for (final odds in [flawOdds, second]) {
        if (random.nextDouble() >= odds) continue;
        final candidates = Trait.flaws
            .where(
              (f) =>
                  !picked.contains(f) &&
                  (position == null || f.fitsPosition(position)) &&
                  picked.every((p) => compatible(p, f)),
            )
            .toList();
        if (candidates.isEmpty) break;
        picked.add(candidates[random.nextInt(candidates.length)]);
        flaws++;
      }
    }

    // 稀なもの。普通の引きが終わったあとに判定するので、外れた選手は
    // それまでと同じ結果になる。**長所の1枚と置き換える**ので、
    // 長所を1つしかもらえなかった選手にも起きる。
    if (strengthCount > 0 && random.nextDouble() < rareChance) {
      final replace = strengthCount - 1;
      final candidates = rares
          .where(
            (r) =>
                !r.flaw &&
                (position == null || r.fitsPosition(position)) &&
                !picked.contains(r) &&
                [
                  for (var i = 0; i < picked.length; i++)
                    if (i != replace) picked[i],
                ].every((p) => compatible(p, r)),
          )
          .toList();
      if (candidates.isNotEmpty) {
        picked[replace] = candidates[random.nextInt(candidates.length)];
      }
    }
    // 欠点を引かない呼び方（flawChance 0）では、稀な欠点も付けない。
    if (flawOdds > 0 && flaws == 0 && random.nextDouble() < rareFlawChance) {
      final candidates = rares
          .where(
            (r) =>
                r.flaw &&
                (position == null || r.fitsPosition(position)) &&
                picked.every((p) => compatible(p, r)),
          )
          .toList();
      if (candidates.isNotEmpty) {
        picked.add(candidates[random.nextInt(candidates.length)]);
      }
    }
    return picked;
  }

  /// 「+8%」「-2%」の形。
  static String percent(double value) {
    final n = (value * 100).round();
    return n >= 0 ? '+$n%' : '$n%';
  }

  static String _times(double factor) => '×${factor.toStringAsFixed(1)}';

  static String _years(int offset) => offset > 0 ? tr('+$offset年', '+$offset yrs') : tr('$offset年', '$offset yrs');

  /// 局面での効き方。判定と画面が同じものを読む。
  List<TraitRule> get rules {
    switch (this) {
      // ---- 場面 ----
      case Trait.clutch:
        return [TraitRule(tr('後半30分以降', 'From the 75th minute'), 0.15, (c) => c.minute >= 75)];
      case Trait.composed:
        return [TraitRule(tr('ゴールの手', 'Shots at goal'), 0.10, (c) => c.outcome == Outcome.goal)];
      case Trait.fighter:
        return [TraitRule(tr('失敗した直後', 'Right after a failure'), 0.12, (c) => c.afterFailure)];
      case Trait.homeHero:
        return [
          TraitRule(tr('ホーム', 'At home'), 0.08, (c) => !c.international && c.home),
          TraitRule(tr('アウェイ', 'Away'), -0.03, (c) => !c.international && !c.home),
        ];
      case Trait.roadWarrior:
        return [TraitRule(tr('アウェイ', 'Away'), 0.11, (c) => !c.international && !c.home)];
      case Trait.gambler:
        return [
          TraitRule(tr('ゴール・アシストの手', 'Shots and assists'), 0.09, (c) => c.outcome != Outcome.play),
          TraitRule(tr('安全な手', 'The safe option'), -0.07, (c) => c.outcome == Outcome.play),
        ];
      case Trait.craftsman:
        return [
          TraitRule(tr('安全な手', 'The safe option'), 0.10, (c) => c.outcome == Outcome.play),
          TraitRule(tr('ゴールの手', 'Shots at goal'), -0.05, (c) => c.outcome == Outcome.goal),
        ];
      case Trait.bigGame:
        return [TraitRule(tr('代表戦', 'Internationals'), 0.15, (c) => c.international)];
      case Trait.ironNerve:
        return [TraitRule(tr('格上との対戦・代表戦', 'Against better sides and in internationals'), 0.12, (c) => c.bigMatch)];
      case Trait.comeback:
        return [TraitRule(tr('負けているとき', 'When behind'), 0.12, (c) => c.margin < 0)];
      case Trait.frontRunner:
        return [
          TraitRule(tr('リードしているとき', 'When in the lead'), 0.10, (c) => c.margin > 0),
          TraitRule(tr('負けているとき', 'When behind'), -0.07, (c) => c.margin < 0),
        ];
      case Trait.penaltyKing:
        return [TraitRule('PK', 0.20, (c) => c.scenarioId.contains('-pk'))];
      case Trait.twoFooted:
        // 逆足の落ち込みを打ち消す方向に働く。
        return [TraitRule(tr('逆足の局面', 'On his weaker foot'), 0.14, (c) => c.weakFoot)];
      case Trait.cosmopolitan:
        return [TraitRule(tr('国外のクラブ', 'At a club abroad'), 0.09, (c) => c.abroad)];
      case Trait.superSub:
        return [TraitRule(tr('途中出場', 'Off the bench'), 0.11, (c) => c.substitute)];
      case Trait.fastStarter:
        return [TraitRule(tr('前半30分まで', 'Up to the 30th minute'), 0.09, (c) => c.minute < 30)];
      case Trait.hotHand:
        return [TraitRule(tr('成功した直後', 'Right after a success'), 0.11, (c) => c.afterSuccess)];
      case Trait.assistKing:
        return [TraitRule(tr('アシストの手', 'Assist moves'), 0.09, (c) => c.outcome == Outcome.assist)];

      // ---- 得意技 ----
      case Trait.aerialAce:
        return [
          TraitRule(
            tr('ヘディング・競り合い', 'In the air and in duels'),
            0.13,
            (c) => c.detail == Detail.heading || c.detail == Detail.jumping,
          ),
        ];
      case Trait.sprinter:
        return [TraitRule(tr('スピードの手', 'A race for the ball'), 0.10, (c) => c.key == AttributeKey.pace)];
      case Trait.playmaker:
        return [TraitRule(tr('パスの手', 'Passing moves'), 0.08, (c) => c.key == AttributeKey.passing)];
      case Trait.poacher:
        return [TraitRule(tr('決定力の手', 'Finishing moves'), 0.12, (c) => c.detail == Detail.finishing)];
      case Trait.wall:
        return [
          TraitRule(tr('守備の手', 'Defensive moves'), 0.10, (c) => c.key == AttributeKey.defending),
        ];
      case Trait.dribbler:
        return [
          TraitRule(tr('仕掛ける手', 'Taking players on'), 0.10, (c) => c.key == AttributeKey.dribbling),
        ];
      case Trait.tackler:
        return [
          TraitRule(
            tr('タックル・インターセプト', 'Tackles and interceptions'),
            0.12,
            (c) =>
                c.detail == Detail.tackling || c.detail == Detail.interceptions,
          ),
        ];
      case Trait.longRange:
        return [
          TraitRule(tr('ロングシュート', 'Shots from distance'), 0.15, (c) => c.detail == Detail.longShots),
        ];
      case Trait.crosser:
        return [
          TraitRule(
            tr('クロス・ロングパス', 'Crosses and long passes'),
            0.12,
            (c) =>
                c.detail == Detail.crossing || c.detail == Detail.longPassing,
          ),
        ];
      case Trait.tempoSetter:
        return [
          TraitRule(
            tr('短いパス・ボール扱い', 'Short passes and close control'),
            0.10,
            (c) =>
                c.detail == Detail.shortPassing ||
                c.detail == Detail.ballControl,
          ),
        ];
      case Trait.sweeperKeeper:
        return [
          TraitRule(
            tr('GKのポジショニング', 'Goalkeeper positioning'),
            0.13,
            (c) => c.detail == Detail.gkPositioning,
          ),
        ];
      case Trait.reflexKeeper:
        return [TraitRule(tr('セービング', 'Shot-stopping'), 0.13, (c) => c.detail == Detail.reflexes)];

      // ---- 欠点 ----
      case Trait.moody:
        return [
          TraitRule(tr('成功した直後', 'Right after a success'), 0.09, (c) => c.afterSuccess),
          TraitRule(tr('失敗した直後', 'Right after a failure'), -0.10, (c) => c.afterFailure),
        ];
      case Trait.slowStarter:
        return [TraitRule(tr('前半30分まで', 'Up to the 30th minute'), -0.09, (c) => c.minute < 30)];
      case Trait.bigGameShy:
        return [TraitRule(tr('格上との対戦・代表戦', 'Against better sides and in internationals'), -0.12, (c) => c.bigMatch)];
      case Trait.homesick:
        return [TraitRule(tr('国外のクラブ', 'At a club abroad'), -0.10, (c) => c.abroad)];
      case Trait.benchCold:
        return [TraitRule(tr('途中出場', 'Off the bench'), -0.11, (c) => c.substitute)];
      case Trait.bigMoment:
        return [
          TraitRule(tr('後半30分以降', 'From the 75th minute'), 0.18, (c) => c.minute >= 75),
          TraitRule(tr('格上との対戦・代表戦', 'Against better sides and in internationals'), 0.15, (c) => c.bigMatch),
        ];

      // ---- 試合の外でだけ効くもの ----
      case Trait.captain:
      case Trait.organizer:
      case Trait.deadBallMaster:
      case Trait.ironman:
      case Trait.robust:
      case Trait.engine:
      case Trait.tireless:
      case Trait.fastHealer:
      case Trait.quickRecovery:
      case Trait.earlyBloomer:
      case Trait.lateBloomer:
      case Trait.cleanPlayer:
      case Trait.quickLearner:
      case Trait.unshakable:
      case Trait.streaky:
      case Trait.moodMaker:
      case Trait.studious:
      case Trait.breaker:
      case Trait.steady:
      case Trait.coachable:
      case Trait.utility:
      case Trait.showman:
      case Trait.fragile:
      case Trait.slowHealer:
      case Trait.lazy:
      case Trait.hothead:
      case Trait.difficult:
      case Trait.genius:
      case Trait.ironBody:
      case Trait.bornStar:
      case Trait.glassBody:
      case Trait.eagleEye:
      case Trait.cannon:
      case Trait.lightning:
      case Trait.glue:
      case Trait.sniper:
      case Trait.hawk:
      case Trait.ironLungs:
      case Trait.catReflex:
        return const [];
    }
  }

  /// 局面での成功率への加算。
  double chanceBonus(TraitContext c) =>
      rules.fold(0, (sum, r) => sum + (r.applies(c) ? r.value : 0));

  /// 局面の中で効く特性か。
  bool get affectsPlay => rules.isNotEmpty;

  /// 試合の外での効き方を、数字込みの言葉にする。
  ///
  /// 各 getter から作るので、数字を変えれば画面も変わる。
  List<String> get offPitchEffects => [
    if (transcendDetail != null)
      tr('${transcendDetail!.label}の上限 +${Formulas.ceilingBreak}'
          '（${Formulas.absoluteMax}まで。${Formulas.transcendRunway}以上なら'
          'ポテンシャルに達しても伸びる）', '${transcendDetail!.label} ceiling +${Formulas.ceilingBreak} (up to ${Formulas.absoluteMax}; from ${Formulas.transcendRunway} it keeps growing past his potential)'),
    if (potentialBonus != 0) tr('生まれたときのポテンシャル +$potentialBonus', 'Potential at birth +$potentialBonus'),
    if (peakAgeOffset != 0) tr('ピーク ${_years(peakAgeOffset)}', 'Peak ${_years(peakAgeOffset)}'),
    if (declineAgeOffset != 0) tr('衰え始め ${_years(declineAgeOffset)}', 'Decline begins ${_years(declineAgeOffset)}'),
    if (growthFactor(20) != 1.0) tr('22歳までの成長 ${_times(growthFactor(20))}', 'Growth to 22 ${_times(growthFactor(20))}'),
    if (growthFactor(30) != 1.0) tr('23歳からの成長 ${_times(growthFactor(30))}', 'Growth from 23 ${_times(growthFactor(30))}'),
    if (injuryFactor != 1.0) tr('怪我の確率 ${_times(injuryFactor)}', 'Injury chance ${_times(injuryFactor)}'),
    if (conditionCostFactor != 1.0) tr('試合と練習の消耗 ${_times(conditionCostFactor)}', 'Condition cost of matches and training ${_times(conditionCostFactor)}'),
    if (fatigueFactor != 1.0) tr('疲労の溜まり ${_times(fatigueFactor)}', 'Fatigue build-up ${_times(fatigueFactor)}'),
    if (restFactor != 1.0) tr('休養で戻る量 ${_times(restFactor)}', 'Condition regained by rest ${_times(restFactor)}'),
    if (trainingFactor != 1.0) tr('練習の効き ${_times(trainingFactor)}', 'Training effect ${_times(trainingFactor)}'),
    if (setPieceFactor != 1.0) tr('居残りの効き ${_times(setPieceFactor)}', 'Extra-session effect ${_times(setPieceFactor)}'),
    if (deadBallThresholdOffset != 0) tr('キッカーになる水準 $deadBallThresholdOffset', 'Level needed to be the taker $deadBallThresholdOffset'),
    if (rehabFactor != 1.0) tr('離脱の期間 ${_times(rehabFactor)}', 'Time out injured ${_times(rehabFactor)}'),
    if (moraleFactor != 1.0) tr('気持ちの落ち込み ${_times(moraleFactor)}', 'Drop in morale ${_times(moraleFactor)}'),
    if (moraleGainFactor != 1.0) tr('気持ちの上向き ${_times(moraleGainFactor)}', 'Rise in morale ${_times(moraleGainFactor)}'),
    if (formFactor != 1.0) tr('波の入りやすさ ${_times(formFactor)}', 'Chance of a hot or cold spell ${_times(formFactor)}'),
    if (ratingBonus != 0) tr('毎試合の評価点 +${ratingBonus.toStringAsFixed(2)}', 'Match rating +${ratingBonus.toStringAsFixed(2)}'),
    if (cleanSheetFactor != 1.0) tr('無失点の評価 ${_times(cleanSheetFactor)}', 'Clean sheet rating ${_times(cleanSheetFactor)}'),
    if (cardFactor != 1.0) tr('警告の確率 ${_times(cardFactor)}', 'Booking chance ${_times(cardFactor)}'),
    if (fameFactor != 1.0) tr('知名度の伸び ${_times(fameFactor)}', 'Growth in fame ${_times(fameFactor)}'),
    if (aptitudeFactor != 1.0) tr('慣れないポジションの減点 ${_times(aptitudeFactor)}', 'Penalty out of position ${_times(aptitudeFactor)}'),
    if (adaptationFactor != 1.0) tr('相手への慣れ ${_times(adaptationFactor)}', 'Adapting to an opponent ${_times(adaptationFactor)}'),
    if (breakthroughFactor != 1.0) tr('限界突破の確率 ${_times(breakthroughFactor)}', 'Chance of breaking the ceiling ${_times(breakthroughFactor)}'),
    if (breakthroughWeekOffset != 0) tr('限界突破に要る大成功の週 $breakthroughWeekOffset回', 'Great weeks needed to break the ceiling $breakthroughWeekOffset'),
    if (plateauFactor != 1.0) tr('停滞期の長さ ${_times(plateauFactor)}', 'Length of a plateau ${_times(plateauFactor)}'),
    if (relationGainFactor != 1.0) tr('監督の信頼の上がり ${_times(relationGainFactor)}', 'Trust gained from the manager ${_times(relationGainFactor)}'),
    if (relationLossFactor != 1.0) tr('監督の信頼の下がり ${_times(relationLossFactor)}', 'Trust lost with the manager ${_times(relationLossFactor)}'),
  ];

  /// 効き方をすべて言葉にしたもの。画面とガイドの両方で使う。
  List<String> get effects => [
    for (final r in rules) r.text,
    ...offPitchEffects,
  ];

  int get peakAgeOffset => switch (this) {
    Trait.earlyBloomer => -2,
    Trait.lateBloomer => 3,
    _ => 0,
  };

  int get declineAgeOffset => switch (this) {
    Trait.ironman => 2,
    Trait.lateBloomer => 2,
    _ => 0,
  };

  /// 成長判定の倍率。年齢で変わる。
  double growthFactor(int age) => switch (this) {
    Trait.earlyBloomer => age <= 22 ? 1.4 : 0.85,
    Trait.lateBloomer => age <= 22 ? 0.7 : 1.25,
    Trait.genius => 1.3,
    _ => 1.0,
  };

  /// 上限を超えて伸ばせる詳細能力。超越の特性だけが持つ。
  Detail? get transcendDetail => switch (this) {
    Trait.eagleEye => Detail.vision,
    Trait.cannon => Detail.shotPower,
    Trait.lightning => Detail.sprintSpeed,
    Trait.glue => Detail.ballControl,
    Trait.sniper => Detail.finishing,
    Trait.hawk => Detail.interceptions,
    Trait.ironLungs => Detail.stamina,
    Trait.catReflex => Detail.reflexes,
    _ => null,
  };

  /// 生まれたときのポテンシャルへの上乗せ。キャリア開始時にだけ効く。
  ///
  /// **長所は「速さ」ではなく「届く高さ」に返す。**
  /// 実測（`test/trait_sim.dart`、能力値と選び方を揃えて特性だけ差し替え）で、
  /// 練習の効き 1.25 倍と限界突破 1.6 倍を持つ「飲み込みが早い＋殻を破る」が、
  /// **特性なしよりピーク +0.4 しか高くなかった**。速く伸びても
  /// **ポテンシャルで止まるので同じ選手になる**（週の踏み込み方で
  /// 先に踏んだのと同じ壁）。一方、欠点2つは −3.1 効いていた——
  /// **下振れには上限が無いのに、上振れには上限がある**というのが
  /// 「長所が効かない」の正体だった。
  /// 伸びる速さを持つ長所には、少しだけ高さも渡す。
  int get potentialBonus => switch (this) {
    Trait.genius => 6,
    Trait.quickLearner => 2,
    // 「ピークが遅く長い」と書いてあるのに、**高さは同じ**だった。
    // 遅れて伸びるぶんの見返りをここに置く。
    Trait.lateBloomer => 3,
    _ => 0,
  };

  /// 限界突破に要る「追い込んだ週」の数への下駄。
  ///
  /// `breakthroughFactor` は**起きる確率の倍率**なので、そもそも条件を
  /// 満たさないキャリアには何も返らない（実測で限界突破は普通の
  /// 踏み込み方だと 8%）。殻を破る選手は、条件そのものを軽くする。
  int get breakthroughWeekOffset => switch (this) {
    Trait.breaker => -6,
    Trait.genius => -4,
    _ => 0,
  };

  /// 負傷確率の倍率。
  double get injuryFactor => switch (this) {
    Trait.robust => 0.6,
    Trait.fragile => 1.7,
    Trait.ironBody => 0.3,
    Trait.glassBody => 2.5,
    _ => 1.0,
  };

  /// 試合・練習の消耗の倍率。
  double get conditionCostFactor => switch (this) {
    Trait.engine => 0.6,
    _ => 1.0,
  };

  /// 累積疲労の溜まりやすさ。
  double get fatigueFactor => switch (this) {
    Trait.tireless => 0.6,
    Trait.ironBody => 0.7,
    _ => 1.0,
  };

  /// 休養で戻るコンディションの倍率。
  double get restFactor => switch (this) {
    Trait.quickRecovery => 1.4,
    _ => 1.0,
  };

  /// 練習の効きの倍率。
  double get trainingFactor => switch (this) {
    Trait.quickLearner => 1.25,
    Trait.lazy => 0.75,
    Trait.genius => 1.2,
    _ => 1.0,
  };

  /// 居残り練習の効きの倍率。
  double get setPieceFactor => switch (this) {
    Trait.deadBallMaster => 1.6,
    _ => 1.0,
  };

  /// 離脱期間の倍率。
  double get rehabFactor => switch (this) {
    Trait.fastHealer => 0.7,
    Trait.slowHealer => 1.4,
    Trait.ironBody => 0.6,
    Trait.glassBody => 1.5,
    _ => 1.0,
  };

  /// 気持ちの動きやすさ。落ち込みにだけ効かせる。
  double get moraleFactor => switch (this) {
    Trait.unshakable => 0.5,
    _ => 1.0,
  };

  /// 気持ちの上がりやすさ。良いことがあったときにだけ効かせる。
  double get moraleGainFactor => switch (this) {
    Trait.moodMaker => 1.5,
    _ => 1.0,
  };

  /// 好不調の波に入りやすさ。
  double get formFactor => switch (this) {
    Trait.streaky => 1.8,
    _ => 1.0,
  };

  /// 試合ごとの評価点への加算。
  double get ratingBonus => switch (this) {
    Trait.captain => 0.15,
    Trait.bornStar => 0.1,
    _ => 0,
  };

  /// 無失点で終えたときの評価の倍率。守備の選手にだけ乗る項に掛ける。
  double get cleanSheetFactor => switch (this) {
    Trait.organizer => 1.4,
    _ => 1.0,
  };

  /// キッカーを任される水準への下駄。
  int get deadBallThresholdOffset => switch (this) {
    Trait.deadBallMaster => -10,
    _ => 0,
  };

  /// 荒い手で警告を受ける確率の倍率。止めるための反則には効かない。
  double get cardFactor => switch (this) {
    Trait.cleanPlayer => 0.5,
    Trait.hothead => 1.6,
    _ => 1.0,
  };

  /// 知名度の伸びの倍率。
  double get fameFactor => switch (this) {
    Trait.showman => 1.4,
    Trait.bornStar => 2.0,
    _ => 1.0,
  };

  /// 慣れないポジションで引かれる減点の倍率。
  double get aptitudeFactor => switch (this) {
    Trait.utility => 0.5,
    _ => 1.0,
  };

  /// 相手の戦い方に慣れる速さ。
  double get adaptationFactor => switch (this) {
    Trait.studious => 2.0,
    _ => 1.0,
  };

  /// 限界突破が起きる確率の倍率。
  double get breakthroughFactor => switch (this) {
    Trait.breaker => 1.6,
    Trait.genius => 2.0,
    _ => 1.0,
  };

  /// 停滞期の長さの倍率。
  double get plateauFactor => switch (this) {
    Trait.steady => 0.5,
    _ => 1.0,
  };

  /// 監督の信頼が上がるときの倍率。
  double get relationGainFactor => switch (this) {
    Trait.coachable => 1.4,
    _ => 1.0,
  };

  /// 監督の信頼が下がるときの倍率。
  double get relationLossFactor => switch (this) {
    Trait.difficult => 1.5,
    _ => 1.0,
  };
}

/// 複数の特性をまとめて評価する。
extension TraitList on List<Trait> {
  double chanceBonus(TraitContext c) =>
      fold(0, (sum, t) => sum + t.chanceBonus(c));

  int get peakAgeOffset => fold(0, (s, t) => s + t.peakAgeOffset);
  int get declineAgeOffset => fold(0, (s, t) => s + t.declineAgeOffset);
  double growthFactor(int age) => fold(1.0, (f, t) => f * t.growthFactor(age));
  double get injuryFactor => fold(1.0, (f, t) => f * t.injuryFactor);
  double get conditionCostFactor =>
      fold(1.0, (f, t) => f * t.conditionCostFactor);
  double get fatigueFactor => fold(1.0, (f, t) => f * t.fatigueFactor);
  double get restFactor => fold(1.0, (f, t) => f * t.restFactor);
  double get trainingFactor => fold(1.0, (f, t) => f * t.trainingFactor);
  double get setPieceFactor => fold(1.0, (f, t) => f * t.setPieceFactor);
  double get rehabFactor => fold(1.0, (f, t) => f * t.rehabFactor);
  double get moraleFactor => fold(1.0, (f, t) => f * t.moraleFactor);
  double get moraleGainFactor => fold(1.0, (f, t) => f * t.moraleGainFactor);
  double get formFactor => fold(1.0, (f, t) => f * t.formFactor);
  double get ratingBonus => fold(0, (s, t) => s + t.ratingBonus);
  double get cleanSheetFactor => fold(1.0, (f, t) => f * t.cleanSheetFactor);
  int get deadBallThresholdOffset =>
      fold(0, (s, t) => s + t.deadBallThresholdOffset);
  double get cardFactor => fold(1.0, (f, t) => f * t.cardFactor);
  double get fameFactor => fold(1.0, (f, t) => f * t.fameFactor);
  double get aptitudeFactor => fold(1.0, (f, t) => f * t.aptitudeFactor);
  double get adaptationFactor => fold(1.0, (f, t) => f * t.adaptationFactor);
  double get breakthroughFactor =>
      fold(1.0, (f, t) => f * t.breakthroughFactor);
  double get plateauFactor => fold(1.0, (f, t) => f * t.plateauFactor);
  double get relationGainFactor =>
      fold(1.0, (f, t) => f * t.relationGainFactor);
  double get relationLossFactor =>
      fold(1.0, (f, t) => f * t.relationLossFactor);
  int get potentialBonus => fold(0, (s, t) => s + t.potentialBonus);
  int get breakthroughWeekOffset =>
      fold(0, (s, t) => s + t.breakthroughWeekOffset);

  /// 上限を超えて伸ばせる詳細能力。超越は1人に1つなので、最初の1つ。
  Detail? get transcendDetail {
    for (final t in this) {
      if (t.transcendDetail != null) return t.transcendDetail;
    }
    return null;
  }

  /// その詳細能力の上限。超越の対象なら 99 を超える。
  int ceilingFor(Detail detail) =>
      transcendDetail == detail ? Formulas.absoluteMax : Formulas.maxAttribute;
}
