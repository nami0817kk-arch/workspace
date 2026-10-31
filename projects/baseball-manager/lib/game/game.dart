import 'dart:math';

import 'calendar.dart';
import 'career.dart';
import 'characters.dart';
import 'combo.dart';
import 'exp.dart';
import 'life.dart';
import 'path.dart';
import 'player.dart';
import 'difficulty.dart';
import 'goals.dart';
import 'life_log.dart';
import 'records.dart';
import 'flavor.dart';
import 'childhood.dart';
import 'invest.dart';
import 'relations.dart';
import 'shop.dart';
import 'rival_story.dart';
import 'school.dart';
import 'snapshot.dart';
import 'world.dart';
import 'season.dart';
import 'awards.dart';
import 'marks.dart';
import 'talent.dart';
import 'skills.dart';
import 'competition.dart';
import 'missions.dart';
import 'traits.dart';
import 'tryout.dart';
import 'after_career.dart';
import 'farm.dart';
import 'fielding.dart';
import 'final_moment.dart';
import 'training.dart' show abilityCap, applyAgeCeiling;

/// いま何を待っているか。画面はこれを見て出すものを決める。
enum Phase {
  term, // 季節の過ごし方を選ぶ
  event, // 出来事の選択肢を選ぶ
  pathChoice, // ドラフトに外れた。大学/社会人を選ぶか、諦めるか
  retired, // 終わり
}

/// 引退時のまとめ。
/// プロの年のはじめの、オフの過ごし方。
enum Offseason {
  camp('自主トレ', '疲れ+12。重点の能力の経験点+8。'),
  family('家族旅行', '疲れ-20、やる気+20。'),
  rehab('治療・調整', '疲れ-15。怪我中なら治りが1か月早まる。');

  const Offseason(this.label, this.description);
  final String label;
  final String description;
}

/// FA(フリーエージェント)の決断。
enum FaChoice { stay, contender, cash }

class Ending {
  const Ending({
    required this.title,
    required this.madePro,
    required this.proYears,
    required this.peakOverall,
    required this.championships,
    required this.wasTwoWay,
    this.rivalWins = 0,
    this.rivalLosses = 0,
    this.partnerName,
    this.titles = const [],
  });

  final String title;
  final bool madePro;
  final int proYears;
  final int peakOverall;
  final int championships;
  final bool wasTwoWay;
  final int rivalWins;
  final int rivalLosses;

  /// 絆が深かった恋人の名前(いれば結婚した)。
  final String? partnerName;
  bool get married => partnerName != null;

  /// 獲得したタイトル(年ごとに1つずつ、重複あり)。
  final List<String> titles;
}

/// 6歳から引退までの一代記を進める本体。画面には依存しない。
/// 乱数は注入する(テストで再現できる)。
class Game {
  Game._(this.rng, this.player, this.cast,
      [this.difficulty = Difficulty.normal]);

  /// 新しい選手で始める。`potential` を省くと乱数で決まる。
  factory Game.newGame({
    required String name,
    required Role role,
    required Random rng,
    int? potential,
    Difficulty difficulty = Difficulty.normal,
    PlayerSnapshot? parent,
    Trait? carry,
  }) {
    // 二世: 親の素質を受け継ぎ(半分は親ゆずり)、良い特性を1つもらえることがある。
    final pot = potential ??
        (parent == null
            ? 30 + rng.nextInt(61)
            : ((parent.potential * 0.5 + (30 + rng.nextInt(61)) * 0.5) + 8)
                .round()
                .clamp(0, 100));
    var traits = rollInnateTraits(rng, role);
    if (parent != null && rng.nextDouble() < 0.6) {
      final cands = [
        for (final t in parent.traits)
          if (t.positive && t.appliesTo(role) && canGain(traits, t)) t
      ];
      if (cands.isNotEmpty) {
        traits = gain(traits, cands[rng.nextInt(cands.length)]);
      }
    }
    // 継承ポイントで持たせた特性(乱数は使わない)。
    if (carry != null && canCarry(carry, role) && canGain(traits, carry)) {
      traits = gain(traits, carry);
    }
    traits = rollBirthRare(rng, traits, role);
    final gifts = rollGifts(rng);
    if (parent != null) {
      final a = inheritedGift(rng, role, parent.gifts);
      if (a != null) gifts[a] = ((gifts[a] ?? 0) + 1).clamp(giftMin, giftMax);
    }
    final p = Player(
      name: name,
      role: role,
      age: startAge,
      potential: pot,
      abilities: {for (final a in abilitiesOf(role)) a: 15},
      traits: traits,
      gifts: gifts,
      // 生まれつきの弱点(赤い特殊能力)。乱数の並びを変えないよう、素質と天賦から決める
      skills: birthWeaknesses(
          role,
          (pot.toInt() * 7919 +
                  gifts.values
                      .fold<int>(0, (a, v) => (a * 5 + v + 2) & 0xfffffff) +
                  name.codeUnits
                      .fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff)) &
              0x7fffffff),
    );
    final g = Game._(rng, p, Cast.initial(rng, role, p.skills), difficulty)
      .._wasTwoWay = role == Role.twoWay
      ..parentName = parent?.name
      // チーム名・対戦相手の種。生まれ(素質・天賦・特性)と名前から決める(乱数の並びは変えない)。
      // 同じ名前で始めても、生まれが違えば別のチームになる。
      ..teamSeed = 1 +
          ((pot.toInt() * 104729 +
                  gifts.values
                          .fold<int>(0, (a, v) => (a * 7 + v + 3) & 0xfffffff) *
                      31 +
                  traits.fold<int>(
                          0, (a, t) => (a * 37 + t.index + 1) & 0xfffffff) *
                      17 +
                  name.codeUnits
                      .fold<int>(0, (a, c) => (a * 131 + c) & 0x7fffffff)) &
              0x3fffffff);
    g.overallHistory.add(overall(p).round());
    g.yearStart = Map.of(p.abilities);
    g._note('stage', '${stageNameOf(Stage.youth)}を始めた');
    if (parent != null) {
      g._note('stage', '${parent.name}の子として生まれた(二世)');
    }
    g._newGoal();
    return g;
  }

  final Random rng;

  /// 難しさ。はじめに選び、その一生ずっと変わらない。
  final Difficulty difficulty;
  Player player;
  Condition condition = const Condition();
  int slot = 0; // 今年の何ターン目か(0始まり)。月単位か季節かは段階で決まる
  Cast cast; // 家族・ライバル・仲間・コーチ・恋人
  ExpPool exp = const ExpPool(); // 貯めた経験点。`spend` で能力に振り分ける
  Phase phase = Phase.term;
  GameEvent? pendingEvent;
  Ability _eventFocus = Ability.contact;

  Course? route; // 大学/社会人を選んだか

  /// 達成した育成ミッションの id(`missions.dart`)。保存する(古いセーブは空)。
  final Set<String> missionsDone = {};

  /// 今年のはじめの能力(1年の成長の記録に使う)。保存する(古いセーブは空=記録しない)。
  Map<Ability, int> yearStart = {};

  /// これまでで一番伸びた1年の、能力の伸びの合計。保存する。
  int bestYearGain = 0;

  /// いまの段階の育成ミッションを判定し、達成したものの報酬を渡す。達成した数を返す。
  int checkMissions() {
    if (phase == Phase.retired) return 0;
    var n = 0;
    for (final m in missionsFor(stage)) {
      if (missionsDone.contains(m.id) || !m.check(this)) continue;
      missionsDone.add(m.id);
      final e = missionExp(stage);
      exp = exp.add(spreadExp(player.role, e));
      condition = condition.copyWith(morale: condition.morale + missionMorale);
      log.add('育成ミッション達成: ${m.text}! 経験点+$e(全種類)・やる気+$missionMorale');
      _note('title', '育成ミッション「${m.text}」を達成');
      n++;
    }
    return n;
  }

  /// チーム名・対戦相手の名前の種(選手ごと)。0 は古いセーブ(名前だけで決める)。
  int teamSeed = 0;

  /// 画面に出す所属(少年のチーム・中学・高校・大学・社会人・プロ球団)。
  String get affiliation => affiliationOf(stage, player.name,
      proTeam: proTeamLabel,
      seed: teamSeed,
      corporate: route == null ? null : route == Course.corporate);
  bool turnedPro = false;
  int lowYears = 0;

  /// トライアウトをもう使ったか(一生に一度)。
  bool tryoutUsed = false;

  /// 引退後に選んだ道(監督・コーチ・解説者・実業家・少年野球の指導者)。引退してプロだった選手だけ。
  AfterPath? afterPath;

  /// 引退後の道を選ぶ(引退済み・プロ入りした選手だけ。選び直しもできる)。
  void chooseAfterPath(AfterPath p) {
    if (phase != Phase.retired || !(ending?.madePro ?? false)) {
      throw StateError('引退後の道を選べるのは、プロを引退したときだけ');
    }
    afterPath = p;
  }

  /// 選んだ道での、引退後の物語。選んでいなければ null。
  SecondCareer? get secondCareer {
    final p = afterPath;
    final e = ending;
    if (p == null || e == null) return null;
    return secondCareerOf(
      p,
      name: player.name,
      peak: e.peakOverall,
      titles: e.titles.length,
      championships: e.championships,
      popularity: popularityOf(records, worldRecords),
      money: money,
      proYears: e.proYears,
      married: e.married,
      team: proTeam,
    );
  }

  /// 二軍(育成契約)で過ごす残りの年数。0なら一軍。保存する(古いセーブは0=一軍)。
  int farmYears = 0;

  /// 次のプロのシーズンの年俸(万円)。ドラフトで新人の契約、毎年の契約更改で決まる。0 は古いセーブ(成績から計算)。
  int nextSalary = 0;

  /// 二軍にいるか(プロ入りしていて、残りの年数がある)。
  bool get onFarm => turnedPro && farmYears > 0;

  /// 画面に出す所属: 二軍なら「○○ 二軍(育成)」。
  String? get proTeamLabel =>
      proTeam == null ? null : (onFarm ? '$proTeam 二軍(育成)' : proTeam);

  /// アマの大会の決勝を前にして、見せ場の決断を待っている途中経過。決まれば null に戻る(保存する)。
  FinalMoment? pendingFinal;
  int proYears = 0;
  int peakOverall = 0;
  int championships = 0;
  bool _wasTwoWay = false;
  final List<double> achievements = []; // アマの大会ごとの実績
  final List<String> log = []; // 画面に出す出来事の記録
  Outcome lastOutcome = Outcome.normal; // 直前のターンの出来(保存しない・画面の表示用)
  Map<Category, int> lastGain = const {}; // 直前のターンで貯まった経験点(保存しない・画面の表示用)
  Ending? ending;

  /// 引退後、殿堂(過去の選手の記録)に書き込み済みか。
  bool archived = false;

  /// 総合評価の推移。[0] が6歳の始まり、以降は年の終わりごとに1つずつ(人生のグラフ用)。
  final List<int> overallHistory = [];

  /// プロ入りした年齢。入っていなければ null。
  int? proStartAge;

  /// 入団した球団(架空)。プロ入りしてから。
  String? proTeam;

  /// プロのシーズンの途中経過(月ごとに進む)。シーズンが終わったら null に戻る。
  LeagueProgress? seasonProgress;

  /// 資産(万円)。プロの年俸が貯まり、投資に使える。
  int money = 0;

  /// 投資のレベル(0〜3)。
  final Map<Invest, int> invests = {};

  int investLevel(Invest i) => invests[i] ?? 0;

  /// 投資できる時: プロの間の、行動を選ぶ時。
  bool get canInvest => stage == Stage.pro && phase == Phase.term;

  /// 投資する。資産が足りない・最大レベルなら false。
  bool buyInvest(Invest i) {
    if (!canInvest) throw StateError('いまは投資できない');
    final cost = investCost(investLevel(i));
    if (cost == null || money < cost) return false;
    money -= cost;
    invests[i] = investLevel(i) + 1;
    log.add('${i.label}に投資した(Lv${invests[i]})。');
    _note('invest', '${i.label}に投資(Lv${invests[i]})');
    return true;
  }

  // ── お金の使い道(買い物) ──

  /// 今年の買い物の回数(年末に空に戻る)と、一生に一度の買い物で買ったもの。
  final Map<ShopItem, int> shopThisYear = {};
  final Set<ShopItem> purchases = {};

  /// 最新の用具を買った年齢(その年だけ経験点が増える)。
  int gearAge = -1;
  bool get gearActive => gearAge == player.age;

  /// 買えない理由(買えるなら null)。
  String? shopBlock(ShopItem i) {
    if (!canInvest) return 'プロの間だけ';
    if (i.once && purchases.contains(i)) return '購入済み';
    if (i.perYear > 0 && (shopThisYear[i] ?? 0) >= i.perYear) return '今年はもう使った';
    if (i == ShopItem.gift && cast.lover == null && cast.family == null) {
      return '贈る相手がいない';
    }
    if (i == ShopItem.house && cast.family == null) return '贈る相手がいない';
    if (money < i.cost) return 'お金が足りない';
    return null;
  }

  /// 買う。買えないなら false。`focus` は合宿で重点にする能力。
  bool buyShop(ShopItem i, [Ability? focus]) {
    if (shopBlock(i) != null) return false;
    money -= i.cost;
    shopThisYear[i] = (shopThisYear[i] ?? 0) + 1;
    if (i.once) purchases.add(i);
    switch (i) {
      case ShopItem.gear:
        gearAge = player.age;
        log.add(
            '最新の用具をそろえた。この1年、経験点が${((gearMultiplier - 1) * 100).round()}%増える。');
      case ShopItem.camp:
        final f = focus ?? abilitiesOf(player.role).first;
        final k = categoryOf(f);
        exp = exp.add({
          for (final c in usableCategories(player.role)) c: c == k ? 15 : 5,
        });
        condition = condition.copyWith(fatigue: condition.fatigue + 10);
        log.add('海外で自主トレ合宿をした。${k.label}の経験点+15・ほかの種類+5。');
      case ShopItem.care:
        condition = condition.copyWith(fatigue: condition.fatigue - 35);
        log.add('疲労回復の施術を受けた。疲れ-35。');
      case ShopItem.gift:
        final who = cast.lover ?? cast.family!;
        who.addBond(20);
        log.add('${who.name}に贈り物をした。絆+20。');
      case ShopItem.house:
        cast.family!.addBond(40);
        log.add('${cast.family!.name}に家を贈った。絆+40。');
        _note('invest', '${cast.family!.name}に家を贈った');
      case ShopItem.donate:
        condition = condition.copyWith(morale: condition.morale + 20);
        log.add('地元に野球場を寄付した。子どもたちが、あなたの名前のついた球場で野球をする。');
        _note('invest', '地元に野球場を寄付した');
    }
    return true;
  }

  // ── まわりの人との関係(交流の相手・頼みごと) ──

  /// 交流の相手(登場人物の id)。null なら恋人か家族。
  String? socialTargetId;

  /// 今年もう頼みごとをした人(登場人物の id。年末に空に戻る)。
  final Set<String> favorsUsed = {};

  /// 次の練習で必ず友情タッグになる仲間(頼みごと「自主練」)。
  String? tagMateId;

  Character? memberById(String? id) =>
      id == null ? null : cast.members.where((m) => m.id == id).firstOrNull;

  Character? get socialTarget => memberById(socialTargetId);

  void setSocialTarget(Character? c) => socialTargetId = c?.id;

  /// 頼めない理由(頼めるなら null)。
  String? favorBlock(Character c) {
    if (phase != Phase.term) return 'いまは頼めない';
    if (favorsUsed.contains(c.id)) return '今年はもう頼んだ';
    final line = favorBondLine(c.kind);
    if (c.bond < line) return '絆$lineで頼める';
    if (c.kind == Kind.coach && c.teaches == null) return '教わる特殊能力がない';
    return null;
  }

  /// 頼む。頼めないなら false。`focus` は合同練習の重点。
  bool askFavor(Character c, [Ability? focus]) {
    if (favorBlock(c) != null) return false;
    favorsUsed.add(c.id);
    c.addBond(-favorBondCost);
    final f = favorOf(c.kind);
    switch (f) {
      case Favor.practice:
        tagMateId = c.id;
        log.add('${c.name}に自主練を頼んだ。次の練習は友情タッグになる。');
      case Favor.meal:
        condition = condition.copyWith(
            fatigue: condition.fatigue - 25, morale: condition.morale + 5);
        log.add('${c.name}の差し入れで元気が出た。疲れ-25・やる気+5。');
      case Favor.cheer:
        condition = condition.copyWith(
            fatigue: condition.fatigue - 10, morale: condition.morale + 15);
        log.add('${c.name}が応援に来てくれた。やる気+15・疲れ-10。');
      case Favor.private:
        c.tips++;
        log.add('${c.name}に個別に見てもらった。コーチのコツ ${c.tips}/$tipsNeeded。');
        _checkCoach();
      case Favor.joint:
        final k = categoryOf(focus ?? abilitiesOf(player.role).first);
        exp = exp.add({k: 10});
        condition = condition.copyWith(morale: condition.morale + 5);
        log.add('ライバルの${c.name}と合同練習をした。${k.label}の経験点+10・やる気+5。');
    }
    checkMissions();
    return true;
  }

  /// 二世のとき、親の名前(殿堂の選手)。
  String? parentName;

  /// 節目の「覚醒」(レア特性に目覚める)をすでに起こしたか。一生に一度。
  bool awakened = false;

  /// 覚醒の判定。`chance` の確率で、持てるレア特性を1つ得る(一生に一度)。
  bool _tryAwaken(double chance, String why) {
    if (awakened || rng.nextDouble() >= chance) return false;
    // レア特性は通常の特性の枠とは別なので、通常の特性が4つ埋まっていても覚醒できる。
    final t = pickRare(rng, player.traits, player.role);
    if (t == null) return false;
    player = player.copyWith(traits: gain(player.traits, t));
    awakened = true;
    log.add('$why眠っていた才能が目覚めた! 特性「${t.label}」に覚醒した!');
    _note('trait', '覚醒: 特性「${t.label}」');
    return true;
  }

  /// 海外(アメリカ)のリーグでプレーしているか。移籍の判断はプロの間、年の最初だけ。
  bool overseas = false;

  /// 海外での所属(架空の球団)。
  String? overseasTeam;

  /// 自分で決めた守備位置・役割。決めていなければ null(適性がいちばん高い所を守る)。
  Pos? position;

  /// 実際に守るポジション。
  Pos get effectivePos => effectivePosition(player, position);

  /// 海外(アメリカ)へ移籍できる時: プロの24歳以上・総合評価70以上・年の最初。すでに海外なら不可。
  bool get canMoveOverseas =>
      phase == Phase.term &&
      slot == 0 &&
      stage == Stage.pro &&
      !overseas &&
      player.age >= 24 &&
      overall(player) >= 70;

  /// チーム移籍による、チーム力の増減(強豪へ+3、高額オファーの再建チーム-2)。
  int teamBoost = 0;
  bool faUsed = false;

  int get _proYears => records.where((r) => r.stage == Stage.pro).length;

  /// FA権を使える時: プロ8年目以降・国内・年の最初。一生に一度。
  bool get canUseFa =>
      phase == Phase.term &&
      slot == 0 &&
      stage == Stage.pro &&
      !overseas &&
      !faUsed &&
      _proYears >= 8;

  /// FA権を使う。残留(やる気+8)、強豪へ移籍(チーム力+3・契約金4000万・やる気-6)、
  /// 高額オファー(再建中のチームへ・チーム力-2・契約金1億)。
  void useFa(FaChoice c) {
    _require(Phase.term);
    if (!canUseFa) throw StateError('いまはFA権を使えない');
    faUsed = true;
    if (c == FaChoice.stay) {
      condition = condition.copyWith(morale: condition.morale + 8);
      log.add('FA権を行使せず、${proTeam ?? '今のチーム'}に残留した。');
      _note('team', 'FA権を行使せず残留');
      return;
    }
    final others = [
      for (final t in draftTeams)
        if (t != proTeam) t
    ];
    final next = others[rng.nextInt(others.length)];
    proTeam = next;
    if (c == FaChoice.contender) {
      teamBoost = 3;
      money += 4000;
      condition = condition.copyWith(morale: condition.morale - 6);
      log.add('FA宣言! 強豪の$nextに移籍した(契約金4000万円)。');
    } else {
      teamBoost = -2;
      money += 10000;
      log.add('FA宣言! 高額オファーを受けて$nextに移籍した(契約金1億円)。');
    }
    _note('team', 'FAで$nextに移籍');
    _newGoal();
  }

  /// 進学先(中学・高校)。入学の年に選ぶ。段階が変わると地元の学校に戻る。
  School school = School.local;

  bool get canChooseSchool =>
      phase == Phase.term &&
      slot == 0 &&
      (stage == Stage.juniorHigh || stage == Stage.highSchool) &&
      stageOf(player.age - 1) != stage;

  void chooseSchool(School s) {
    _require(Phase.term);
    if (!canChooseSchool) throw StateError('いまは進学先を決められない');
    school = s;
    log.add('${s.label}に進んだ。${s.description}');
    _note('stage', '${s.label}に入学');
  }

  bool offseasonDone = false;

  bool get canChooseOffseason =>
      phase == Phase.term && slot == 0 && stage == Stage.pro && !offseasonDone;

  /// オフの過ごし方を決める(年に1度。選ばなくてもよい)。`focus` は自主トレで伸ばす能力。
  void chooseOffseason(Offseason o, Ability focus) {
    _require(Phase.term);
    if (!canChooseOffseason) throw StateError('いまはオフの過ごし方を決められない');
    offseasonDone = true;
    switch (o) {
      case Offseason.camp:
        condition = condition.copyWith(fatigue: condition.fatigue + 12);
        if (abilitiesOf(player.role).contains(focus)) {
          exp = exp.add({categoryOf(focus): 8});
        }
        log.add('${_abilityJp(focus)}を鍛える自主トレに励んだ。');
      case Offseason.family:
        condition = condition.copyWith(
            fatigue: condition.fatigue - 20, morale: condition.morale + 20);
        log.add('家族とゆっくり過ごして、英気を養った。');
      case Offseason.rehab:
        condition = condition.copyWith(
          fatigue: condition.fatigue - 15,
          injuredTerms: max(0, condition.injuredTerms - 1),
        );
        log.add('体のケアと調整に専念した。');
    }
  }

  /// 日本に戻れる時: 海外にいて、プロの年の最初。
  bool get canReturnHome =>
      phase == Phase.term && slot == 0 && stage == Stage.pro && overseas;

  /// 海外のリーグへ移籍する。相手が強い環境で、年俸は桁違い(×2.5)。慣れない環境で気持ちが下がる。
  void moveOverseas() {
    _require(Phase.term);
    if (!canMoveOverseas) throw StateError('いまは海外へ移籍できない');
    overseas = true;
    overseasTeam = overseasTeams[rng.nextInt(overseasTeams.length)];
    condition = condition.copyWith(morale: condition.morale - 8);
    log.add('海を渡った! アメリカの$overseasTeamに移籍する。');
    // 向こうの球団との契約(年俸は桁違い)
    if (nextSalary > 0) {
      nextSalary =
          ((nextSalary * 2.5 / 10).round() * 10).clamp(400, 200000).toInt();
      log.add('契約: 今季の年俸は${fmtSalary(nextSalary)}。');
    }
    _note('overseas', 'アメリカの$overseasTeamに移籍');
    _newGoal(); // 相手が強くなるので、目標も立て直す
  }

  /// 日本のリーグに戻る。
  void returnHome() {
    _require(Phase.term);
    if (!canReturnHome) throw StateError('いまは日本に戻れない');
    overseas = false;
    condition = condition.copyWith(morale: condition.morale + 6);
    log.add('日本のリーグに復帰した。');
    if (nextSalary > 0) {
      nextSalary =
          ((nextSalary / 2.5 / 10).round() * 10).clamp(400, 200000).toInt();
      log.add('契約: 今季の年俸は${fmtSalary(nextSalary)}。');
    }
    _note('overseas', '日本のリーグに復帰');
    _newGoal();
  }

  /// ポジションを決められる時: 中学・高校・進路(大学・社会人)の最初の年と、プロの毎年の最初。
  bool get canChoosePosition {
    if (phase != Phase.term || slot != 0) return false;
    if (stage == Stage.pro) return true;
    if (stage == Stage.youth || stage == Stage.retired) return false;
    return stageOf(player.age - 1) != stageOf(player.age);
  }

  /// ポジションを決める。決められる時だけ。選べないポジション(役割に合わない)は拒否。
  void choosePosition(Pos pos) {
    _require(Phase.term);
    if (!canChoosePosition) throw StateError('いまはポジションを決められない');
    if (!positionsFor(player.role).contains(pos)) {
      throw ArgumentError('この役割では選べない: ${pos.label}');
    }
    position = pos;
    final adj = positionTeamAdjust(player, pos);
    log.add('ポジションを${pos.label}に決めた。'
        '${adj == 0 ? '' : '(適性が低く、チーム力$adj)'}');
    _note('position', 'ポジションを${pos.label}に決めた');
  }

  /// 年ごとの成績(大会・シーズン)。成績画面とエンディングに出す。
  final List<SeasonRecord> records = [];

  /// 日本代表として出た世界大会(U-12・U-15・U-18・U-23・プロ)の結果。
  final List<WorldRecord> worldRecords = [];

  /// 直前に起きた出来事(同じものが続かないようにする)。
  String? _lastEventId;

  /// 最近起きた出来事(同じものが続かないように。保存はしない)。
  final List<String> _recentEvents = [];

  /// 今年の目標。年の初めに決まり、大会(プロはシーズン)の成績で達成かどうかが決まる。
  Goal? goal;

  /// これまでに行動した回数と、コーチから「多くを学んだ」ときの回数(ボーナスの大きさに使う)。
  int turnCount = 0;
  int lastCoachTurn = 0;

  /// 前にコーチに教わった行動の番号(間をあけて教わるほど、教わったときの経験点が多い)。
  int lastLessonTurn = 0;

  /// 今年の練習(練習・特訓)と休養の回数。年末にログに出して戻す。
  /// 今季ここまでの月ごとの成績(4〜9月)。シーズンの記録に写して空にする。
  List<String> monthRows = [];
  int trainCount = 0;

  /// 幼少期の分かれ道で選んだもの(出来事のid → 選択肢の番号)。
  final Map<String, int> childhood = {};
  int restCount = 0;


  /// 特殊能力のコツ(0〜`maxSkillTips`)。貯まるほど安く取れる。
  Map<Skill, int> skillTips = {};

  /// 「研究」で調べる特殊能力(null ならコツの多いものを自動で選ぶ)。
  Skill? studyTarget;

  /// 同じ能力を重点に練習・特訓を続けた回数(継続は力なり)。
  int focusStreak = 0;
  Ability? lastFocus;

  /// 前のターンの行動と重点(行動の連携 `comboOf` に使う)。怪我で休んだターンのあとは null。
  Plan? lastPlan;
  Ability? lastPlanFocus;

  /// 直前のターンで起きた連携(保存しない・画面と研究のコツに使う)。
  Combo? lastCombo;

  /// 今年の連携の回数と、一生の回数。
  int comboCount = 0;
  int comboTotal = 0;

  /// いま選ぶと連携になる行動(重点 `focus` を選んでいるとき)。
  Map<Plan, Combo> combosNow(Ability focus) =>
      combosReady(lastPlan, prevFocus: lastPlanFocus, focus: focus);

  /// 継続ボーナスの倍率: 3回続けて+2%、6回続けて+4%。
  double get streakBonus =>
      focusStreak >= 6 ? 1.04 : (focusStreak >= 3 ? 1.02 : 1.0);

  /// 人生の節目(入学・進路・ドラフト・特性の習得・転向・引退)。経歴の年表に出す。
  final List<LifeEvent> lifeLog = [];

  void _note(String kind, String text) =>
      lifeLog.add(LifeEvent(player.age, kind, text));

  Stage get stage => phase == Phase.retired
      ? Stage.retired
      : stageOf(player.age, turnedPro: turnedPro);

  /// ドラフトにかかるときの実績: 直近3回の大会の平均。
  double get recentAchievement {
    if (achievements.isEmpty) return 0;
    final r = achievements.length > 3
        ? achievements.sublist(achievements.length - 3)
        : achievements;
    return r.reduce((a, b) => a + b) / r.length;
  }

  /// ドラフトの見込み(運は含めない目安)。指名の前の年・再挑戦の間だけ。
  String? get draftOutlook {
    if (turnedPro || phase != Phase.term) return null;
    final inWindow =
        route != null || (stage == Stage.highSchool && player.age >= 17);
    if (!inWindow) return null;
    final margin = draftScore(player, recentAchievement) +
        draftImpression(childhood) -
        (draftLine + difficulty.draftShift);
    if (margin >= 10) return 'ほぼ確実';
    if (margin >= 3) return '有望';
    if (margin >= -3) return '五分五分';
    if (margin >= -10) return '厳しい';
    return 'かなり厳しい';
  }

  /// プロで、総合が低い年が続いているときの、戦力外までの残り年数。なければ null。
  int? get releaseWarning {
    if (!turnedPro || lowYears <= 0 || phase == Phase.retired) return null;
    return releaseYears - lowYears;
  }

  // ── ターンの選択 ──

  /// 今のターンの表示名。月単位なら「7月」、季節なら「夏」。
  String get slotName => slotLabel(stage, slot);

  /// 今の年のターン数(12 または 4)。
  int get slotsInYear => slotsPerYear(stage);

  Motivation get motivation => motivationOf(condition.morale);

  /// 今のターンの過ごし方を決める。`focus` は練習・特訓・研究で伸ばす能力。
  /// 能力は直接は上がらず、経験点が貯まる。`spend` / `autoSpend` で振り分ける。
  void choose(Plan action, [Ability? focus]) {
    _require(Phase.term);
    final f = focus ?? abilitiesOf(player.role).first;
    if (!abilitiesOf(player.role).contains(f)) {
      throw ArgumentError('${player.role.name} にその能力は無い: ${f.name}');
    }
    final share = slotShare(stage);
    final wasInjured = condition.injured;
    turnCount++;
    final combo = wasInjured
        ? null
        : comboOf(lastPlan, action, prevFocus: lastPlanFocus, focus: f);
    final r = playTerm(player, condition, action, f, rng,
        share: share,
        trainBonus: trainerMultiplier(investLevel(Invest.trainer)),
        recoveryBonus: dietitianMultiplier(investLevel(Invest.dietitian)),
        injuryFactor: medicalFactor(investLevel(Invest.medical)),
        badFactor: comboBadFactor(combo),
        keepMorale: combo == Combo.cheer);
    player = r.player;
    condition = r.condition;
    // _afterCast が経験点(コーチのボーナス)を直接足すことがあるので、先に評価する。
    var gained = wasInjured ? r.exp : _afterCast(action, f, r.exp);
    if (school.expMultiplier != 1.0 && gained.isNotEmpty) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * school.expMultiplier).round(),
      };
    }
    if (school.fatigue > 0) {
      condition =
          condition.copyWith(fatigue: condition.fatigue + school.fatigue);
    }
    if (combo != null) gained = _applyCombo(combo, gained, share);
    lastCombo = combo;
    lastPlan = wasInjured ? null : action;
    lastPlanFocus = f;
    if (!wasInjured && (action == Plan.train || action == Plan.special)) {
      focusStreak = (lastFocus == f) ? focusStreak + 1 : 1;
      lastFocus = f;
      if (focusStreak == 6 && rng.nextDouble() < 0.25) {
        // 継続の先に開眼する(その能力が少し跳ねる)。
        player = player.copyWith(abilities: {
          ...player.abilities,
          f: (player.of(f) + 2).clamp(0, abilityCap),
        });
        log.add('${_abilityJp(f)}を鍛え続けた先に、開眼した!(+2)');
        _note('trait', '${_abilityJp(f)}に開眼');
      }
      final k = categoryOf(f);
      if (streakBonus > 1 && gained[k] != null) {
        gained = {...gained, k: (gained[k]! * streakBonus).round()};
      }
    }
    if (gearActive && gained.isNotEmpty) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * gearMultiplier).round(),
      };
    }
    if (difficulty != Difficulty.normal) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * difficulty.expMultiplier).round(),
      };
    }
    exp = exp.add(gained);
    lastGain = gained;
    lastOutcome = wasInjured ? Outcome.normal : r.outcome;
    if (!wasInjured) _gainTips(action, f, r.outcome);
    if (action == Plan.train || action == Plan.special) trainCount++;
    if (action == Plan.rest) restCount++;
    if (r.gotInjured) {
      _note('injury', injuryNameOf(player.age, slot));
    }
    if (r.gotInjured) {
      log.add('怪我をしてしまった(${injuryNameOf(player.age, slot)})。');
    }
    if (isTournamentSlot(stage, slot)) {
      _playSummer();
      if (pendingFinal != null) {
        // 決勝の見せ場の決断を待つ(決まったら `_resolveFinalMoment` が続きを進める)。
        _eventFocus = f;
        return;
      }
    } else if (stage == Stage.pro && slot < 6) {
      _playLeagueMonth();
    }
    checkMissions();
    _finishTurn(f, share);
  }

  /// 行動のあとの続き: 分かれ道・出来事、なければ次のターンへ。
  void _finishTurn(Ability f, double share) {
    // 幼少期の分かれ道は、その歳の2回目の行動のあとに必ず出る(くじでは出ない)。
    // 社会人は20歳が最後の年(21歳でドラフト)。21歳の分かれ道「ドラフトの年」も、20歳のうちに出す。
    final corporateFinal = stage == Stage.pathChoice &&
        route == Course.corporate &&
        player.age == 20;
    final kid = stage != Stage.pro && stage != Stage.retired
        ? (childhoodStepFor(player.age, childhood, slot) ??
                (corporateFinal ? childhoodStepFor(21, childhood, slot) : null))
            ?.event
        : null;
    final e = kid ??
        drawEvent(rng,
            share: share,
            stage: stage,
            cast: cast,
            exclude: _lastEventId,
            recent: _recentEvents.toSet());
    if (e == null) {
      _nextSlot();
    } else {
      pendingEvent = e;
      _lastEventId = e.id;
      _recentEvents.add(e.id);
      if (_recentEvents.length > 4) _recentEvents.removeAt(0);
      _eventFocus = f;
      phase = Phase.event;
    }
  }

  /// トライアウトの選択(受ける/引退する)。年の終わりの戦力外のあとに出る。
  void _resolveTryout(int index) {
    pendingEvent = null;
    phase = Phase.term;
    if (index == 1) {
      log.add('トライアウトは受けず、現役を退くことにした。');
      _retire('戦力外通告を受けて引退');
      return;
    }
    tryoutUsed = true;
    if (rng.nextDouble() < tryoutChance(player)) {
      final others = [
        for (final t in draftTeams)
          if (t != proTeam) t
      ];
      final next = others[rng.nextInt(others.length)];
      proTeam = next;
      lowYears = 0;
      teamBoost = -1; // 新しい球団は、あまり強くない
      condition = condition.copyWith(morale: condition.morale + 10);
      log.add('トライアウトで好投・好打を見せ、$nextと契約を勝ち取った!');
      // 拾ってもらった契約なので、年俸は低め
      if (nextSalary > 0) nextSalary = min(nextSalary, 1000);
      _note('team', 'トライアウトで$nextと契約');
      _newGoal();
    } else {
      log.add('トライアウトを受けたが、どの球団からも声がかからなかった…。');
      _retire('戦力外通告を受けて引退');
    }
  }

  /// 決勝の見せ場の決断。決まったら決勝の勝ち負けを決め、大会の続き(記録・ライバル・世界大会)を進める。
  /// 決勝の見せ場で選んだ作戦の一文(保存しない。その場でログに出すだけ)。
  String? _finalNote;

  void _resolveFinalMoment(int index) {
    final m = pendingFinal!;
    final stance = finalStances(player)[index];
    pendingEvent = null;
    pendingFinal = null;
    phase = Phase.term;
    // 決勝の試合の行のすぐ前に出す(_logRounds)
    _finalNote = '決勝の最終回、${player.name}は「${stance.$1}」を選んだ。';
    final bonus = finalBonus(index, player, rng);
    final t = finishFinal(m, bonus, rng);
    _summerAftermath(t, null);
    _finalNote = null;
    checkMissions();
    _finishTurn(_eventFocus, slotShare(stage));
  }

  void resolveEvent(int index) {
    _require(Phase.event);
    if (pendingEvent!.id == tryoutEventId) {
      _resolveTryout(index);
      return;
    }
    if (pendingEvent!.id == finalMomentId) {
      _resolveFinalMoment(index);
      return;
    }
    final ch = pendingEvent!.choices[index];
    if (childhoodStepById(pendingEvent!.id) != null) {
      childhood[pendingEvent!.id] = index;
      final note = childhoodStepById(pendingEvent!.id)!.notes[index];
      _note('childhood', note);
      log.add('${player.age}歳の分かれ道: $note。');
    }
    final before = player.traits;
    final r = ch.risky != null
        ? ch.risky!(player, condition, _eventFocus, rng)
        : ch.apply(player, condition, _eventFocus);
    player = r.player;
    condition = r.condition;
    ch.onCast?.call(cast, rng);
    for (final t in player.traits.difference(before)) {
      _note('trait', '特性「${t.label}」を習得');
    }
    _checkCoach();
    pendingEvent = null;
    phase = Phase.term;
    checkMissions();
    _nextSlot();
  }

  // ── 経験点の振り分け ──

  /// 能力を1つ上げる。足りなければ false。
  bool spend(Ability a) {
    final r = buy(player, exp, a);
    if (r == null) return false;
    player = r.player;
    exp = r.pool;
    checkMissions();
    return true;
  }

  /// 買えるだけ上げる。上がった数を返す。
  int spendAll(Ability a) {
    final r = buyAll(player, exp, a);
    player = r.player;
    exp = r.pool;
    checkMissions();
    return r.bought;
  }

  /// 「取りどき」の特殊能力: コツが3つ以上(3割以上安い)で、いまの経験点で取れるもの。
  /// 能力タブの印と、行の「取りどき」の札に使う(おまかせ振り分けは能力にしか使わないので、取り忘れを防ぐ)。
  List<Skill> get skillsInSeason => [
        for (final s in skillsFor(player.role))
          if ((skillTips[s] ?? 0) >= 3 &&
              skillBlock(player, s, exp, skillTips[s] ?? 0) == null)
            s
      ];

  /// 来年から特殊能力の値段が上がるとき(その年の最後のターン)の知らせ。
  /// 取れそうなもの(コツ1つ以上)か弱点があるときだけ。それ以外は null。
  String? get skillPriceRiseNote {
    if (phase == Phase.retired || slot != slotsInYear - 1) return null;
    final now = skillAgeMultiplier(player.age);
    final next = skillAgeMultiplier(player.age + 1);
    if (next <= now) return null;
    final any = skillsFor(player.role).any((s) =>
        !player.skills.contains(s) &&
        !s.negative &&
        (skillTips[s] ?? 0) >= minSkillTips);
    if (!any && !player.skills.any((s) => s.negative)) return null;
    String f(double x) => x.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return '来年(${player.age + 1}歳)から特殊能力の値段が×${f(now)}→×${f(next)}に上がる。取るなら今のうちに。';
  }

  /// 特殊能力の値段(いまのコツで)。
  int skillPrice(Skill s) =>
      skillCost(s, skillTips[s] ?? 0, player.age, ownedSkillCount(player));

  /// 経験点で特殊能力を取る。取れなければ理由の文を返す(取れたら null)。
  String? buySkill(Skill s) {
    final why = skillBlock(player, s, exp, skillTips[s] ?? 0);
    if (why != null) return why;
    exp = exp.spend(s.category, skillPrice(s));
    if (s.negative) {
      player = player.copyWith(skills: {...player.skills}..remove(s));
      log.add('弱点「${s.label}」を克服した!');
      _note('trait', '弱点「${s.label}」を克服');
      return null;
    }
    player = player.copyWith(skills: {...player.skills, s});
    skillTips.remove(s);
    if (studyTarget == s) studyTarget = null;
    log.add('特殊能力「${s.label}」を取得した!');
    _note('trait', '特殊能力「${s.label}」を取得');
    checkMissions();
    return null;
  }

  /// 研究の対象を決める(null で自動)。取得済み・役割に合わないものは選べない。
  void setStudyTarget(Skill? s) {
    if (s != null && (!s.appliesTo(player.role) || player.skills.contains(s))) {
      throw ArgumentError('研究できない特殊能力: ${s.name}');
    }
    studyTarget = s;
  }

  /// 研究で次にコツが貯まる特殊能力(選んだもの、なければ重点の種類でコツの多いもの)。
  /// 選んだもののコツが満タンなら、研究が無駄にならないよう自動で選ぶ。
  Skill? studyFocus(Ability focus) {
    final t = studyTarget;
    if (t != null &&
        !player.skills.contains(t) &&
        t.appliesTo(player.role) &&
        (skillTips[t] ?? 0) < maxSkillTips) {
      return t;
    }
    return pickTipTarget(player, skillTips, Random(turnCount),
            category: categoryOf(focus)) ??
        pickTipTarget(player, skillTips, Random(turnCount));
  }

  /// 特殊能力のコツを `n` 足す(上限 `maxSkillTips`)。足せたら true。ログに出す。
  bool _addTips(Skill? s, int n, String why) {
    if (s == null || n <= 0 || player.skills.contains(s)) return false;
    final before = skillTips[s] ?? 0;
    final after = (before + n).clamp(0, maxSkillTips);
    if (after == before) return false;
    skillTips[s] = after;
    log.add(
        '$why「${s.label}」のコツ +${after - before}(Lv$after/$maxSkillTips・あと${skillPrice(s)}で取れる)');
    return true;
  }

  /// 連携の効き目(経験点の倍率・超回復の経験点)とログ。失敗しにくさ・やる気は `playTerm` が受け持つ。
  Map<Category, int> _applyCombo(
      Combo combo, Map<Category, int> gained, double share) {
    comboCount++;
    comboTotal++;
    var out = gained;
    final m = comboExpMultiplier(combo);
    if (m != 1.0) {
      out = {for (final e in out.entries) e.key: (e.value * m).round()};
    }
    final String why;
    switch (combo) {
      case Combo.insight:
        why = '研究で見えたことを試して、経験点+$tComboInsight%';
      case Combo.drill:
        why = '教わったことを繰り返して、失敗しにくく経験点+$tComboDrill%';
      case Combo.recovery:
        final f = lastPlanFocus ?? abilitiesOf(player.role).first;
        final extra = focusExpOf(
            player, f, tComboRecovery / 100, share, condition.morale);
        out = {...out};
        for (final e in extra.entries) {
          out[e.key] = (out[e.key] ?? 0) + e.value;
        }
        final n = extra.values.fold(0, (a, b) => a + b);
        why = n > 0 ? '特訓の疲れが抜けて、${_abilityJp(f)}の経験点+$n' : '特訓の疲れが抜けた';
      case Combo.homework:
        why = '試合で見えた課題を研究して、コツが1つ多い';
      case Combo.cheer:
        why = '仲間の声援で、特訓でもやる気が下がらない';
    }
    log.add('連携「${combo.label}」! $why');
    return out;
  }

  /// 行動ごとに貯まる、特殊能力のコツ(行動の役割の違い)。
  /// 研究=選んだ特殊能力に+2(研究熱心は+3)/特訓=好調・大成功で重点の種類に+1/
  /// 練習試合=勝負どころの特殊能力に+1/交流=仲間の得意な種類に+1。練習・休養・コーチはなし。
  void _gainTips(Plan action, Ability f, Outcome outcome) {
    switch (action) {
      case Plan.study:
        _addTips(studyFocus(f),
            (studious ? 3 : 2) + (lastCombo == Combo.homework ? 1 : 0), '研究で');
      case Plan.special:
        if (outcome == Outcome.good || outcome == Outcome.great) {
          _addTips(
              pickTipTarget(player, skillTips, rng, category: categoryOf(f)),
              1,
              '特訓で');
        }
      case Plan.match:
        _addTips(
            pickTipTarget(player, skillTips, rng, matchesOnly: true) ??
                pickTipTarget(player, skillTips, rng),
            1,
            '練習試合で');
      case Plan.social:
        final t = socialTarget;
        final mates = [
          for (final m in cast.teammates)
            if (m.specialty != null && (t?.kind != Kind.teammate || m == t)) m
        ];
        if (mates.isNotEmpty) {
          final m = mates[rng.nextInt(mates.length)];
          final s = pickTipTarget(player, skillTips, rng,
              category: categoryOf(m.specialty!));
          _addTips(s, 1, '${m.name}に教わって');
        }
      case Plan.train:
      case Plan.rest:
      case Plan.lesson:
        break;
    }
  }

  bool get studious => player.traits.contains(Trait.studious);

  /// おまかせ: 種類ごとに低い能力から順に振り分ける。
  void autoSpend() {
    // 振り分けでミッションを達成すると経験点が入るので、それも続けて振り分ける
    for (var i = 0; i < 5; i++) {
      final r = autoSpendExp(player, exp);
      player = r.player;
      exp = r.pool;
      if (checkMissions() == 0) break;
    }
  }

  /// プロの間はいつでも役割を変えられる(二刀流にする/戻す)。
  void changeRole(Role to) {
    _require(Phase.term);
    player = switchRole(player, to, stage);
    if (to == Role.twoWay) _wasTwoWay = true;
    log.add('${roleNameOf(to)}に転向した。');
    _note('role', '${roleNameOf(to)}になった');
  }

  /// プロの間は自分で引退を決められる。
  void retire() {
    _require(Phase.term);
    if (!canChooseRetire(stage)) throw StateError('引退を選べるのはプロの間だけ');
    _retire('自ら引退を決めた');
  }

  // ── ドラフトに外れたとき ──

  void chooseRoute(Course r) {
    _require(Phase.pathChoice);
    route = r;
    phase = Phase.term;
    log.add('${courseNameOf(r)}で再挑戦する。');
    _note('route', '${courseNameOf(r)}で再挑戦');
  }

  void giveUp() {
    _require(Phase.pathChoice);
    _retire('プロを諦めた');
  }

  // ── 管理者機能(調整・検証用。ホーム画面のタイトルを7回タップで有効) ──
  //
  // 通常の遊びでは使わない。上限(特性は`maxTraits`つまで)や矛盾(大器晩成と早熟など)も無視して書き換える。

  /// 素質(0〜100)を書き換える。
  /// 動画を見た特典で、経験点を足す(使える種類すべてに `n`)。
  void gainAdExp(int n) {
    exp = exp.add(spreadExp(player.role, n));
    log.add('動画を見て、自主練に励んだ。経験点 +$n(全種類)');
  }

  /// 動画を見た特典で、疲れを大きく抜く(怪我は治さない)。保存する項目は増えない。
  void relieveFatigue() {
    condition = condition.copyWith(
        fatigue: condition.fatigue - 60, morale: condition.morale + 5);
    log.add('動画を見て、しっかり体を休めた。疲れが大きく抜けた。');
  }

  void adminSetPotential(int v) {
    player = player.copyWith(potential: v.clamp(0, 100));
  }

  /// 特性を、上限や矛盾を無視して丸ごと置き換える。
  void adminSetTraits(Set<Trait> t) {
    player = player.copyWith(traits: Set.of(t));
  }

  /// 天賦(才能の偏り)を書き換える。-2〜+2。
  void adminSetGift(Ability a, int v) {
    player =
        player.copyWith(gifts: {...player.gifts, a: v.clamp(giftMin, giftMax)});
  }

  /// 特殊能力(弱点を含む)を、年齢・コツ・もとの特殊能力を無視して丸ごと置き換える。
  void adminSetSkills(Set<Skill> s) {
    player = player.copyWith(skills: Set.of(s));
    skillTips.removeWhere((k, _) => s.contains(k));
    if (studyTarget != null && s.contains(studyTarget)) studyTarget = null;
  }

  /// 特殊能力のコツを書き換える(0〜`maxSkillTips`)。持っているもの・弱点は対象外。
  void adminSetSkillTips(Skill s, int n) {
    if (player.skills.contains(s) || s.negative) return;
    final v = n.clamp(0, maxSkillTips);
    if (v == 0) {
      skillTips.remove(s);
    } else {
      skillTips[s] = v;
    }
  }

  /// 覚醒済みの印を書き換える(もう一度覚醒を試したいとき)。
  void adminSetAwakened(bool v) => awakened = v;

  void adminSetAbility(Ability a, int v) {
    if (!abilitiesOf(player.role).contains(a)) return;
    player =
        player.copyWith(abilities: {...player.abilities, a: v.clamp(0, 99)});
  }

  /// 経験点を全種類に足す(負でも可。0未満にはならない)。
  void adminAddExp(int n) {
    exp = ExpPool({for (final c in Category.values) c: max(0, exp.of(c) + n)});
  }

  /// コーチのコツを書き換える。`tipsNeeded` 以上にすると、その場でコーチの特殊能力のコツが満タンになる。
  void adminSetCoachTips(int n) {
    final coach = cast.coach;
    if (coach == null) return;
    coach.tips = n.clamp(0, tipsNeeded);
    _checkCoach();
  }

  /// コーチが教える特殊能力を差し替える(null なら教えられない)。
  void adminSetCoachTeaches(Skill? t) {
    final i = cast.members.indexWhere((m) => m.kind == Kind.coach);
    if (i < 0) return;
    final c = cast.members[i];
    cast.members[i] = Character(
      id: c.id,
      name: c.name,
      kind: c.kind,
      bond: c.bond,
      specialty: c.specialty,
      teaches: t,
      tips: c.tips,
      talent: c.talent,
    );
  }

  // ── 内部 ──

  String _abilityJp(Ability a) => switch (a) {
        Ability.contact => 'ミート',
        Ability.power => 'パワー',
        Ability.speed => '走力',
        Ability.fielding => '守備',
        Ability.eye => '選球眼',
        Ability.stuff => '球威',
        Ability.control => '制球',
        Ability.stamina => 'スタミナ',
      };

  /// 友情タッグ・コーチ・恋人/家族への影響。経験点の量を返す。
  Map<Category, int> _afterCast(
      Plan action, Ability focus, Map<Category, int> gained) {
    final out = Map<Category, int>.of(gained);
    final trains = action == Plan.train ||
        action == Plan.special ||
        action == Plan.match ||
        action == Plan.lesson;
    if (trains && gained.isNotEmpty) {
      final picked = cast.pickTagMate(focus, rng);
      // 頼みごと「自主練」の相手がいれば、その仲間と必ずタッグになる
      final forced = memberById(tagMateId);
      final mate = forced ?? picked;
      tagMateId = null;
      if (mate != null) {
        for (final k in out.keys.toList()) {
          out[k] = (out[k]! * tagMultiplier * tagTraitMultiplier(player.traits))
              .round();
        }
        mate.addBond(8);
        log.add('${mate.name}と友情タッグ練習!');
      }
    }
    if (action == Plan.lesson &&
        tLessonGap > 0 &&
        out.isNotEmpty &&
        stage != Stage.pro) {
      // 間をあけて教わるほど身につく(コーチばかりより、練習と混ぜたほうが得)。
      // プロでは足さない(長いプロ生活で積み上がり、レジェンド・タイトルが増えすぎた)。
      final gap = turnCount - lastLessonTurn;
      lastLessonTurn = turnCount;
      final k = categoryOf(focus);
      final extra = (min(tLessonGapCap, tLessonGap * (gap - 1)) *
              slotShare(stage) *
              roleExpFactor(player.role))
          .round();
      if (extra > 0) out[k] = (out[k] ?? 0) + extra;
    }
    if (action == Plan.lesson) {
      final coach = cast.coach;
      if (coach != null) {
        coach.addBond(lessonBond);
        coach.tips++;
        _checkCoach();
      }
    }
    if (action == Plan.social) {
      final t = socialTarget;
      if (t != null) {
        t.addBond(socialTargetBond);
      } else {
        (cast.lover ?? cast.family)?.addBond(10);
      }
    }
    return out;
  }

  /// コツが貯まったら、コーチの教える特殊能力を習得する(経験点は払わない)。
  void _checkCoach() {
    final coach = cast.coach;
    if (coach == null || coach.tips < tipsNeeded) return;
    coach.tips = 0;
    final t = coach.teaches;
    // コーチは特殊能力を「くれる」のではなく、コツを最大にしてくれる(取るのは経験点で。半額)。
    // 無料で渡すと、プロで特殊能力が積み上がり、タイトル・レジェンドが増えすぎた(2026-10-24)。
    final ready = t != null &&
        t.appliesTo(player.role) &&
        !player.skills.contains(t) &&
        (skillTips[t] ?? 0) < maxSkillTips;
    if (ready) {
      skillTips[t] = maxSkillTips;
      log.add('${coach.name}のコツをつかんだ! 「${t.label}」のコツが最大(Lv$maxSkillTips)に。'
          'あと${skillPrice(t)}の経験点で取れる。');
      _note('trait', '「${t.label}」のコツをつかんだ(コーチ ${coach.name})');
    } else {
      // 学びのボーナスは、前の学びからの間があくほど大きい(コーチばかりが最善にならないように)。
      final bonus = min(40, 3 * (turnCount - lastCoachTurn));
      lastCoachTurn = turnCount;
      exp = exp.add(spreadExp(player.role, bonus));
      log.add('${coach.name}から多くを学んだ。(経験点を獲得)');
    }
  }

  void _require(Phase p) {
    if (phase != p) throw StateError('いまは ${phase.name} の段階: ${p.name} は選べない');
  }

  ({int team, List<int> opponents}) get _league => _leagueBase(stage);

  ({int team, List<int> opponents}) _leagueBase(Stage st) {
    final raw = _leagueRaw(st);
    final b = st == Stage.pro
        ? (team: raw.team + teamBoost, opponents: raw.opponents)
        : (st == Stage.juniorHigh || st == Stage.highSchool)
            ? (
                team: raw.team + school.teamAdjust + spiritBoost(childhood),
                opponents: raw.opponents
              )
            : raw;
    if (overseas && st == Stage.pro) {
      // 海外は相手が強く(+3)。
      return (team: b.team, opponents: [for (final o in b.opponents) o + 3]);
    }
    return b;
  }

  ({int team, List<int> opponents}) _leagueRaw(Stage stage) => switch (stage) {
        Stage.youth => (team: 35, opponents: const [25, 30, 35, 40]),
        Stage.juniorHigh => (team: 42, opponents: const [32, 38, 44, 50]),
        Stage.highSchool => (team: 50, opponents: const [40, 46, 52, 58, 64]),
        Stage.pathChoice => (team: 58, opponents: const [48, 54, 60, 66]),
        _ => (team: 65, opponents: const [55, 60, 66, 72, 78]),
      };

  /// 年の初めに、今年の目標を決める。
  void _newGoal() {
    if (phase == Phase.retired) return;
    goal = makeGoal(
      stage: stage,
      role: player.role,
      ov: overall(player),
      rounds: _league.opponents.length,
      pick: rng.nextDouble(),
    );
  }

  /// 成績が出たら、目標を判定して、達成なら経験点と気持ちをもらう。
  void _judgeGoal(SeasonRecord r) {
    final g = goal;
    if (g == null || g.achieved != null) return;
    g.achieved = g.judge(r);
    if (g.achieved!) {
      final n = goalExpFor(stage, g.level);
      exp = exp.add(spreadExp(player.role, n));
      condition = condition.copyWith(
          morale: condition.morale + goalMoraleReward[g.level]);
      log.add('今年の目標「${g.text}」を達成! 経験点+$n(全種類)');
    } else {
      condition = condition.copyWith(
          morale: condition.morale + goalMoraleMiss[g.level]);
      log.add('今年の目標「${g.text}」には届かなかった。');
    }
  }

  /// 目標のむずかしさを選べる時(年の最初の行動の前)。
  bool get canChooseGoal =>
      goal != null &&
      goal!.achieved == null &&
      phase == Phase.term &&
      slot == 0;

  /// 目標のむずかしさを変える(0=やさしい / 1=ふつう / 2=むずかしい)。年の最初の行動の前だけ。
  void chooseGoalLevel(int level) {
    _require(Phase.term);
    if (!canChooseGoal) throw StateError('いまは目標を選べない');
    if (level < 0 || level > 2) throw ArgumentError('level $level');
    goal = goal!.withLevel(level, maxRounds: _league.opponents.length);
  }

  /// プロのシーズンの1か月ぶん(約20試合)を進める。怪我中は自分は出られない。
  void _playLeagueMonth() {
    final l = _league;
    final team = l.team +
        traitTeamBonus(player.traits) +
        positionTeamAdjust(player, effectivePos);
    final prev = seasonProgress ?? const LeagueProgress();
    // この1か月だけの成績を出してから、これまでに足す(月間の成績を見せるため)。
    final month = playLeagueChunk(
      traitAdjusted(player),
      LeagueProgress(games: prev.games),
      teamLevel: team,
      opponents: l.opponents,
      rng: rng,
      count: 20,
      condition: condition.value,
      available: !condition.injured,
    );
    seasonProgress = LeagueProgress(
      games: month.games,
      wins: prev.wins + month.wins,
      losses: prev.losses + month.losses,
      line: prev.line + month.line,
      missed: prev.missed + month.missed,
    );
    _monthlyReport(month);
  }

  /// 月ごとの成績をログに残す。出来が飛び抜けていれば「月間MVP」。
  void _monthlyReport(LeagueProgress m) {
    _allStar();
    final d = describeLine(m.line);
    if (m.missed >= 20) {
      monthRows.add('$slotName: 怪我で全休 / ${m.wins}勝${m.losses}敗');
      log.add('$slotName: 怪我で全試合を欠場。チームは${m.wins}勝${m.losses}敗。');
      return;
    }
    // 6月は交流戦(もう一方のリーグの球団と戦う)。海外の年は呼ばない。
    final month =
        isInterleagueMonth(slotName) && !overseas ? '$slotName(交流戦)' : slotName;
    log.add('$month: ${d.isEmpty ? '' : '$d。'}チームは${m.wins}勝${m.losses}敗。');
    monthRows.add('$month: ${d.isEmpty ? '出場なし' : d} / ${m.wins}勝${m.losses}敗');
    log.add(attendanceLine(popularityOf(records, worldRecords),
        m.wins + m.losses == 0 ? 0.5 : m.wins / (m.wins + m.losses)));
    final rs = storyOfCharacter(cast.rival)?.avoiding(proTeam);
    final duel =
        rs == null ? null : rivalDuelLine(rs, player.age, slot, m.line);
    if (duel != null) log.add(duel);
    if (monthlyMvp(m.line, player.name, player.age, slot) && !onFarm) {
      log.add('$slotNameの月間MVPに選ばれた!');
      _note('title', '$slotNameの月間MVP');
      condition = condition.copyWith(morale: condition.morale + 5);
    }
  }

  /// シーズン中盤(4か月目)に、ここまでの成績と人気でオールスターに選ばれることがある。
  void _allStar() {
    if (slot != 3 || condition.injured || onFarm) return;
    final prog = seasonProgress;
    // 打者は40試合以上、投手は8試合以上の先発(投手は試合数が少なく、選ばれていなかった)
    if (prog == null || (prog.line.games < 40 && prog.line.starts < 8)) {
      return;
    }
    final l = prog.line;
    final pop = popularityOf(records, worldRecords);
    final good = (l.hasBatting && (l.ops ?? 0) >= 0.800) ||
        (l.hasPitching && (l.era ?? 99) <= 3.00);
    if (!good && pop < 55) return;
    log.add('ファン投票とリーグ推薦で、オールスターに選ばれた!');
    _note('title', 'オールスターに選出');
    condition = condition.copyWith(morale: condition.morale + 6);
  }

  /// シーズンの最後(10月)に、残りの試合を進めて、1年ぶんの結果にする。
  LeagueSeason _finishLeague(Player fighter, int team, List<int> opponents) {
    var prog = seasonProgress ?? const LeagueProgress();
    final rest = leagueGames - prog.games;
    if (rest > 0) {
      prog = playLeagueChunk(
        fighter,
        prog,
        teamLevel: team,
        opponents: opponents,
        rng: rng,
        count: rest,
        condition: condition.value,
        available: !condition.injured,
      );
    }
    seasonProgress = null;
    return prog.toSeason();
  }

  /// 大会(アマチュア)またはシーズン(プロ)を行い、成績を残す。
  void _playSummer() {
    final l = _league;
    final isPro = stage == Stage.pro;
    final fighter = traitAdjusted(player);
    final team = l.team +
        traitTeamBonus(player.traits) +
        positionTeamAdjust(player, effectivePos);
    if (isPro) {
      _summerAftermath(null, _finishLeague(fighter, team, l.opponents));
      return;
    }
    final prog = playTournamentToFinal(
      fighter,
      teamLevel: team,
      opponents: l.opponents,
      rng: rng,
      condition: condition.value,
      facedBase: amateurFacedBase(stage),
    );
    if (prog.moment != null) {
      // 決勝まで勝ち上がった。勝負を決める場面の決断を、選んでもらう。
      pendingFinal = prog.moment;
      pendingEvent = finalMomentEvent(player);
      phase = Phase.event;
      return;
    }
    _summerAftermath(prog.done, null);
  }

  /// その年の大会(またはプロのシーズン)の結果が出たあとの、記録・ライバル・世界大会など。
  void _summerAftermath(Tournament? tournament, LeagueSeason? league) {
    var ach = tournament?.achievement ?? 0;
    bool? rivalWon;
    // ライバルとの勝負・今年の目標は、試合の結果のあとに出す(読む順を、起きた順に合わせる)
    String? rivalLine;
    final rival = cast.rival;
    if (rival != null) {
      final mine = overall(player) + (rng.nextDouble() * 2 - 1) * 8;
      if (mine >= rivalLevel(rival, player.age)) {
        rivalWon = true;
        cast.rivalWins++;
        ach = min(100, ach + 5);
        condition = condition.copyWith(morale: condition.morale + 10);
        rivalLine = 'ライバルの${rival.name}との今年の勝負は、こちらの勝ち!';
      } else {
        rivalWon = false;
        cast.rivalLosses++;
        condition = condition.copyWith(morale: condition.morale - 8);
        rivalLine = 'ライバルの${rival.name}との今年の勝負は、向こうの勝ち…';
      }
      rival.addBond(5);
    }

    if (league != null) {
      final farm = onFarm; // 二軍の年: タイトル・表彰・日本一の対象外
      final titles = farm
          ? <String>[]
          : titlesOf(league.line, games: league.games, rank: league.rank);
      final proBefore =
          records.where((r) => r.stage == Stage.pro && !r.farm).toList();
      final field = fieldingOf(
          player: player,
          pos: effectivePos,
          games: league.line.hasBatting ? league.line.games : 0,
          age: player.age);
      final awards = farm
          ? <String>[]
          : awardsOf(
              league.line,
              games: league.games,
              firstYear: proBefore.isEmpty,
              prevGames: proBefore.isEmpty ? null : proBefore.last.line.games,
              fielding: player.abilities[Ability.fielding] ?? 0,
              isBatter: league.line.hasBatting && !league.line.hasPitching,
              titles: titles,
              fieldingPct: field.pct,
            );
      // 3位までがクライマックスシリーズ(海外はプレーオフ)→ 日本シリーズ。名前と年齢の乱数で決める。
      final ps = farm
          ? null
          : playPostseason(
              name: player.name,
              age: player.age,
              rank: league.rank,
              winPct: league.games == 0 ? 0.5 : league.wins / league.games,
              rating: league.line.rating.round(),
              team: proTeam,
              overseas: overseas,
            );
      final rec = SeasonRecord(
        contract: nextSalary,
        post: ps?.result ?? '',
        age: player.age,
        stage: stage,
        line: league.line,
        teamWins: league.wins,
        teamLosses: league.losses,
        rank: league.rank,
        titles: titles,
        rivalWon: rivalWon,
        overseas: overseas,
        awards: awards,
        months: List.of(monthRows),
        twoWay: player.role == Role.twoWay,
        farm: farm,
        chances: field.chances,
        errors: field.errors,
      );
      monthRows = [];
      records.add(rec);
      if (league.missed > 0) log.add('怪我で${league.missed}試合を欠場した。');
      if (farm) {
        log.add('二軍の今季は${league.rank}位(${league.wins}勝${league.losses}敗)。');
      } else {
        if (league.rank == 1) {
          championships++;
          log.add('リーグ優勝!');
        } else {
          log.add('今季は${league.rank}位(${league.wins}勝${league.losses}敗)。');
        }
        log.addAll(ps!.lines);
        if (ps.champion && !overseas) {
          awards.add('日本一');
          // シリーズMVP: 日本一の年に、打撃か投球がとくに良かった選手。
          if ((league.line.ops ?? 0) >= 0.850 ||
              (league.line.hasPitching && (league.line.era ?? 99) <= 2.50)) {
            awards.add('シリーズMVP');
          }
        }
        if (league.rank == 1 || ps.champion) {
          log.add(
              '優勝パレードには${paradeCrowd(popularityOf(records, worldRecords))}万人が集まった。');
        }
      }
      final d = describeLine(league.line);
      if (d.isNotEmpty) log.add('今季成績: $d');
      for (final t in titles) {
        log.add('タイトル獲得: $t!');
      }
      // N年連続でタイトルを獲ったとき。
      final streak = currentTitleStreak(records);
      if (const [3, 5, 8].contains(streak)) {
        log.add('$streak年連続でタイトルを獲得!');
        _note('title', '$streak年連続でタイトルを獲得');
      }
      if (titles.isNotEmpty) {
        _tryAwaken(0.08, 'タイトルを獲った今季、');
      } else if (league.rank == 1) {
        _tryAwaken(0.04, '優勝を経験した今季、');
      }
      for (final w in awards) {
        log.add('表彰: $w!');
      }
      // 通算の記録(プロ初安打など)は一軍の成績だけで数える(実際のプロ野球と同じ)。
      // 二軍の年は出さない(出すと、一軍に上がった年に「プロ初安打」がもう一度出た)。
      var careerBefore = const Line();
      for (final r in proBefore) {
        careerBefore += r.line;
      }
      for (final m in farm
          ? const <String>[]
          : careerMarks(careerBefore, careerBefore + league.line)) {
        log.add('記録達成: $m!');
        _note('title', m);
      }
      _judgeGoal(rec);
      if (rivalLine != null) log.add(rivalLine);
      log.add(coachWordOf(player));
      // 今季の年俸が資産に入る(シーズン前に決まっていた額)。
      final now = salariesOf(records).last;
      money += now;
      final cm = cmFeeOf(popularityOf(records, worldRecords));
      if (cm > 0) {
        money += cm;
        log.add('CM出演料: ${fmtMoney(cm)}');
      }
      // 契約更改: 今季の成績で、来季の年俸が決まる。
      final next = renewSalary(now, rec);
      nextSalary = next;
      final diff = next - now;
      final mark = diff > 0
          ? '(アップ)'
          : diff < 0
              ? '(ダウン)'
              : '(現状維持)';
      log.add('契約更改: 来季の年俸 ${fmtSalary(now)} → ${fmtSalary(next)} $mark');
    } else if (tournament != null) {
      achievements.add(ach);
      // アマの大会の表彰(大会優秀選手・大会最優秀選手)。
      final ampAwards = tournamentAwardsOf(
          roundsWon: tournament.roundsWon,
          rounds: tournament.rounds,
          rating: tournament.line.rating);
      final corp = stage == Stage.pathChoice && route == Course.corporate;
      final rec = SeasonRecord(
        corporate: corp,
        age: player.age,
        stage: stage,
        line: tournament.line,
        roundsWon: tournament.roundsWon,
        rounds: tournament.rounds,
        rivalWon: rivalWon,
        awards: ampAwards,
      );
      records.add(rec);
      _logRounds(tournament);
      for (final w in ampAwards) {
        log.add('表彰: $w!'); // 経歴には、成績の表彰として出る(_note すると重なる)
      }
      if (tournament.champion) {
        championships++;
        log.add(amateurChampionLine(stage, corporate: corp));
        _tryAwaken(0.03, '優勝の勢いで、');
      } else {
        // 負けた試合(次の試合)の名前で、どこまで行ったかを伝える。
        log.add(amateurLossLine(stage, tournament.roundsWon, tournament.rounds,
            corporate: corp));
      }
      final d = describeLine(tournament.line);
      if (d.isNotEmpty) log.add('大会成績: $d');
      _judgeGoal(rec);
      if (rivalLine != null) log.add(rivalLine);
    }
    _playWorld();
  }

  /// 勝ち抜き戦の各試合を、ログに残す(相手・勝ち負け・自分の出来)。
  void _logRounds(Tournament t) {
    final own = affiliation;
    final corp = stage == Stage.pathChoice && route == Course.corporate;
    final qualify = amateurQualifyIndex(stage, t.rounds, corporate: corp);
    for (var i = 0; i < t.games.length; i++) {
      final g = t.games[i];
      final name = opponentName(stage, player.age, i,
          corporate: corp, own: own, seed: teamSeed);
      final d = describeGame(g.line);
      if (qualify != null && i == qualify) {
        log.add(amateurQualifyLine(stage, corporate: corp));
      }
      if (i == t.rounds - 1 && _finalNote != null) log.add(_finalNote!);
      log.add(
          '${g.won ? '○' : '●'} ${amateurRoundLabel(stage, i, t.rounds, corporate: corp)} vs $name'
          '${d.isEmpty ? '' : ' — $d'}'
          '${isHeroGame(g.line, won: g.won) ? ' ★殊勲(${heroNoteOf(g.line)})' : ''}');
      if (i == t.rounds - 1 && g.won && isHeroGame(g.line, won: true)) {
        _note('title', '決勝で殊勲の活躍');
      }
    }
  }

  /// この年に世界大会があれば、代表に選ばれたかを決め、選ばれたら日本代表として戦う。
  /// 選ばれるのは総合評価が目安を上回る選手(運±6)。怪我中は辞退。
  void _playWorld() {
    final ev =
        worldEventFor(stage: stage, age: player.age, hasRoute: route != null);
    if (ev == null) return;
    if (condition.injured) {
      log.add('${ev.name}の代表候補だったが、怪我で辞退した。');
      return;
    }
    final score = overall(player) + (rng.nextDouble() * 2 - 1) * 6;
    if (score < ev.selectLine) return;
    log.add('${ev.name}の日本代表に選ばれた!');
    _note('world', '${ev.name}の日本代表に選出');
    final t = playTournament(
      traitAdjusted(player),
      teamLevel: ev.team +
          traitTeamBonus(player.traits) +
          positionTeamAdjust(player, effectivePos),
      opponents: ev.opponents,
      rng: rng,
      condition: condition.value +
          worldBonus(player.traits) +
          skillMatchBonus(player.skills),
    );
    final w = wrapWorld(event: ev, age: player.age, tournament: t);
    for (var i = 0; i < t.games.length; i++) {
      final d = describeGame(t.games[i].line);
      log.add('${t.games[i].won ? '○' : '●'} ${roundLabel(i, t.rounds)} '
          'vs ${ev.countries[i]}${d.isEmpty ? '' : ' — $d'}');
    }
    worldRecords.add(w.record);
    final rec = w.record;
    if (rec.champion) {
      log.add('${ev.name}で優勝! 日本が世界一になった!');
      _note('world', '${ev.name}で優勝(世界一)');
      condition = condition.copyWith(morale: condition.morale + 25);
      exp = exp.add(spreadExp(player.role, goalRewardExp(stage)));
    } else {
      log.add('${ev.name}は${rec.lostTo}に敗れ、${rec.resultText}。');
      _note('world', '${ev.name} ${rec.resultText}');
      condition = condition.copyWith(morale: condition.morale + 8);
    }
    final d = describeLine(rec.line);
    if (d.isNotEmpty) log.add('${ev.name}の成績: $d');
  }

  void _nextSlot() {
    if (slot + 1 >= slotsPerYear(stage)) {
      _endYear();
    } else {
      slot++;
    }
  }

  void _endYear() {
    // 1年の成長の記録(年のはじめの能力と比べる)。いちばん伸びた年は「自己ベスト」
    if (yearStart.isNotEmpty) {
      final ups = [
        for (final a in abilitiesOf(player.role))
          if (player.of(a) > (yearStart[a] ?? player.of(a)))
            (a, yearStart[a]!, player.of(a))
      ];
      final total = ups.fold<int>(0, (t, u) => t + u.$3 - u.$2);
      if (total > 0) {
        log.add('この1年の成長: ${[
          for (final u in ups) '${_abilityJp(u.$1)} ${u.$2}→${u.$3}'
        ].join('・')}(合計+$total)');
        if (total > bestYearGain) {
          if (bestYearGain > 0) {
            log.add('これまでで一番伸びた1年! (自己ベスト +$total)');
          }
          bestYearGain = total;
        }
      }
    }
    final before = stage;
    slot = 0;
    offseasonDone = false;
    monthRows = [];
    seasonProgress = null;
    player = endOfYear(player);
    condition = endOfYearCondition(condition);
    final partner = cast.lover ?? cast.family;
    if (partner != null && partner.bond >= 50) {
      condition = condition.copyWith(fatigue: condition.fatigue - 5); // 支えてくれる
    }
    if (purchases.contains(ShopItem.house)) {
      condition =
          condition.copyWith(fatigue: condition.fatigue - 5); // 贈った家でくつろぐ
    }
    shopThisYear.clear();
    favorsUsed.clear();
    if (trainCount + restCount > 0) {
      log.add(yearSummaryOf(trainCount, restCount, comboCount));
    }
    comboCount = 0;
    trainCount = 0;
    restCount = 0;
    peakOverall = max(peakOverall, overall(player).round());
    overallHistory.add(overall(player).round());
    // ライバルの人生の知らせ(進路・入団・活躍・引退)。
    final rs = storyOfCharacter(cast.rival)?.avoiding(proTeam);
    if (rs != null) log.addAll(rivalNews(rs, player.age));

    if (phase != Phase.retired) log.add('── ${player.age}歳 ──');
    // 大学(22歳でドラフト)・社会人(21歳でドラフト)の、最後の夏を迎える年
    final finalYear = !turnedPro &&
        route != null &&
        player.age == (route == Course.corporate ? 20 : 21);
    final an = ageNote(player.age, finalYear: finalYear);
    if (an != null && phase != Phase.retired) log.add(an);
    // 年齢による上限(体の限界)を超えている能力は、上限まで落ちる
    if (phase != Phase.retired) {
      final aged = applyAgeCeiling(player);
      if (aged.drops.isNotEmpty) {
        player = aged.player;
        log.add('体の衰え: ${[
          for (final d in aged.drops) '${_abilityJp(d.$1)} ${d.$2}→${d.$3}'
        ].join('・')}');
      }
    }
    yearStart = Map.of(player.abilities);
    if (turnedPro) {
      if (proTeam != null && !overseas && proYears >= 1 && proYears % 3 == 0) {
        log.add('新人の${kohaiOf(proTeam!, player.age)}が入団してきた。');
      }
      proYears++;
      if (farmYears > 0) {
        farmYears--;
        if (promoted(yearsLeft: farmYears, overall: overall(player))) {
          farmYears = 0;
          log.add(
              '一軍に昇格した! 支配下登録され、背番号は${uniformNumberOf(Stage.pro, player)}に。');
          _note('team', '一軍に昇格');
        }
      }
      lowYears = nextLowYears(player, lowYears);
      if (mustRetire(player, lowYears)) {
        if (isReleased(lowYears) &&
            player.age <= maxProAge &&
            canTryout(age: player.age, used: tryoutUsed)) {
          // 戦力外通告。一生に一度、トライアウトを選べる(受ける/引退する)。
          log.add('戦力外通告を受けた。');
          _note('team', '戦力外通告を受けた');
          pendingEvent = tryoutEvent;
          phase = Phase.event;
        } else {
          final why = isReleased(lowYears) ? '戦力外になった' : '年齢により引退した';
          log.add('$why。');
          _retire(isReleased(lowYears) ? '戦力外通告を受けて引退' : '年齢により引退');
        }
      }
    } else if (route == null && player.age == proEntryAge + 1) {
      _draft();
    } else if (route != null && player.age == graduationAge(route!)) {
      _draft();
    }
    _rotateCast(before);
    _newGoal();
    // 戦力外通告のあと(トライアウトを選ぶ前)は、開幕の文を出さない
    if (turnedPro && phase == Phase.term && proTeam != null) {
      // 海外の年は、日本の球団のスローガン・球場を出さない
      log.add(overseas
          ? '${player.age}歳シーズン開幕。アメリカの$overseasTeamで迎える、プロ${player.age - (proStartAge ?? player.age) + 1}年目のシーズン。'
          : '${player.age}歳シーズン開幕。$proTeam'
              'のスローガンは「${sloganOf(proTeam!, player.age)}」。'
              '本拠地は${stadiumOf(proTeam!)}。');
    }
  }

  /// 段階が変わったら、仲間とコーチが替わる(高校で恋人が現れる)。
  void _rotateCast(Stage before) {
    if (phase == Phase.retired) return;
    final after = stage;
    if (after != before) {
      cast.rotate(after, rng, player.role, player.skills);
      school = School.local;
      // 仲間とコーチは別の人になる(id は使い回される)ので、選んでいた相手・自主練の約束は外す
      final k = socialTarget?.kind;
      if (k == Kind.teammate || k == Kind.coach) socialTargetId = null;
      tagMateId = null;
      if (after != Stage.pro && after != Stage.pathChoice) {
        _note('stage', '${stageNameOf(after)}に進んだ');
      }
    }
  }

  void _draft() {
    final luck = (rng.nextDouble() * 2 - 1) * draftLuck;
    final margin = draftScore(player, recentAchievement) +
        draftImpression(childhood) +
        luck -
        (draftLine + difficulty.draftShift);
    if (margin >= 0) {
      turnedPro = true;
      proStartAge = player.age;
      final team = draftTeams[rng.nextInt(draftTeams.length)];
      proTeam = team;
      final round = draftRound(margin);
      log.add('ドラフトで指名された! $team から$round位指名。');
      log.add(pressConferenceNote(round,
          uniformNumberOf(Stage.pro, player, ikusei: farmYearsFor(round) > 0)));
      farmYears = farmYearsFor(round);
      nextSalary = rookieSalary(round);
      log.add('契約: 1年目の年俸は${fmtSalary(nextSalary)}。');
      if (farmYears > 0) {
        log.add('育成契約での入団。まずは二軍で力をつけて、一軍昇格を目指す。');
        _note('team', '育成契約で入団(二軍からのスタート)');
      }
      final mates = classmatesOf(player.name, team);
      log.add(
          '同期入団: ${[for (final m in mates) '${m.$1}(${m.$2}位)'].join('・')}');
      _note('draft', '$team から$round位指名を受けて、プロ入り');
    } else if (route == null) {
      log.add('ドラフトで指名されなかった。');
      _note('draft', 'ドラフトで指名されなかった');
      phase = Phase.pathChoice;
    } else {
      log.add('再挑戦も実らなかった。');
      _note('draft', '再挑戦のドラフトでも指名されなかった');
      _retire('再挑戦も実らず引退');
    }
  }

  void _retire(String reason) {
    _note('retire', reason);
    phase = Phase.retired;
    pendingEvent = null;
    ending = _buildEnding();
  }

  /// 称号「レジェンド」になる最高評価(dart run -DBAL_LEGEND=82 で試せる)。
  static const legendLine = int.fromEnvironment('BAL_LEGEND', defaultValue: 82);

  Ending _buildEnding() {
    // 年末の処理を通らずに引退した(シーズン後に自分で決めた)ときは、その年の分がまだ数えられていない。
    final playedProYears = max(proYears, _proYears);
    peakOverall = max(peakOverall, overall(player).round());
    final String title;
    if (!turnedPro && playedProYears == 0) {
      title = 'プロにはなれなかった';
    } else if (peakOverall >= legendLine) {
      title = 'レジェンド';
    } else if (peakOverall >= 65) {
      title = '一流選手';
    } else if (peakOverall >= 50) {
      title = 'レギュラー';
    } else {
      title = '無名の選手';
    }
    return Ending(
      title: title,
      madePro: turnedPro,
      proYears: playedProYears,
      peakOverall: peakOverall,
      championships: championships,
      wasTwoWay: _wasTwoWay,
      rivalWins: cast.rivalWins,
      rivalLosses: cast.rivalLosses,
      partnerName: (cast.lover != null && cast.lover!.bond >= 80)
          ? cast.lover!.name
          : null,
      titles: [for (final r in records) ...r.titles],
    );
  }

  // ── 保存 ──

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'condition': condition.toJson(),
        'slot': slot,
        'exp': exp.toJson(),
        'cast': cast.toJson(),
        'phase': phase.name,
        'pendingEvent': pendingEvent?.id,
        'eventFocus': _eventFocus.name,
        'route': route?.name,
        'turnedPro': turnedPro,
        'lowYears': lowYears,
        'proYears': proYears,
        'peakOverall': peakOverall,
        'championships': championships,
        'wasTwoWay': _wasTwoWay,
        'achievements': achievements,
        'archived': archived,
        'overallHistory': overallHistory,
        'proStartAge': proStartAge,
        'proTeam': proTeam,
        'position': position?.name,
        'overseas': overseas,
        'seasonProgress': seasonProgress?.toJson(),
        'parentName': parentName,
        'money': money,
        'invests': {for (final e in invests.entries) e.key.name: e.value},
        'overseasTeam': overseasTeam,
        'teamBoost': teamBoost,
        'school': school.name,
        'offseasonDone': offseasonDone,
        'faUsed': faUsed,
        'records': [for (final r in records) r.toJson()],
        'worldRecords': [for (final r in worldRecords) r.toJson()],
        'lifeLog': [for (final e in lifeLog) e.toJson()],
        'focusStreak': focusStreak,
        'skillTips': skillTipsToJson(skillTips),
        'studyTarget': studyTarget?.name,
        'turnCount': turnCount,
        'lastCoachTurn': lastCoachTurn,
        'lastLessonTurn': lastLessonTurn,
        'monthRows': monthRows,
        'trainCount': trainCount,
        'childhood': childhood,
        'restCount': restCount,
        'lastFocus': lastFocus?.name,
        'lastPlan': lastPlan?.name,
        'lastPlanFocus': lastPlanFocus?.name,
        'comboCount': comboCount,
        'comboTotal': comboTotal,
        'shopThisYear': {
          for (final e in shopThisYear.entries) e.key.name: e.value
        },
        'purchases': [for (final p in purchases) p.name],
        'gearAge': gearAge,
        'socialTargetId': socialTargetId,
        'favorsUsed': favorsUsed.toList(),
        'tagMateId': tagMateId,
        'goal': goal?.toJson(),
        'difficulty': difficulty.name,
        'awakened': awakened,
        'tryoutUsed': tryoutUsed,
        'pendingFinal': pendingFinal?.toJson(),
        'farmYears': farmYears,
        'teamSeed': teamSeed,
        'missionsDone': missionsDone.toList(),
        'yearStart': {for (final e in yearStart.entries) e.key.name: e.value},
        'bestYearGain': bestYearGain,
        'nextSalary': nextSalary,
        'afterPath': afterPath?.name,
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Game.fromJson(Map<String, dynamic> j, Random rng) {
    T pick<T extends Enum>(List<T> all, Object? name, T orElse) {
      for (final v in all) {
        if (v.name == name) return v;
      }
      return orElse;
    }

    final player =
        Player.fromJson((j['player'] as Map?)?.cast<String, dynamic>() ?? {});
    final castJson = (j['cast'] as Map?)?.cast<String, dynamic>();
    final g = Game._(
      rng,
      player,
      castJson != null
          ? Cast.fromJson(castJson)
          : Cast.initial(rng, player.role, player.skills),
      Difficulty.parse(j['difficulty']),
    );
    g.condition = Condition.fromJson(
        (j['condition'] as Map?)?.cast<String, dynamic>() ?? {});
    g.slot = (j['slot'] as num?)?.toInt() ?? 0;
    g.focusStreak = (j['focusStreak'] as num?)?.toInt() ?? 0;
    g.skillTips = skillTipsFromJson(j['skillTips']);
    g.studyTarget = Skill.parse((j['studyTarget'] as String?) ?? '');
    g.awakened = j['awakened'] == true;
    g.tryoutUsed = j['tryoutUsed'] == true;
    g.farmYears = (j['farmYears'] as num?)?.toInt() ?? 0;
    g.teamSeed = (j['teamSeed'] as num?)?.toInt() ?? 0;
    g.missionsDone.addAll([
      for (final x in (j['missionsDone'] as List?) ?? const []) x as String
    ]);
    g.yearStart = {
      for (final e in ((j['yearStart'] as Map?) ?? const {}).entries)
        if (Ability.parse(e.key as String) != null)
          Ability.parse(e.key as String)!: (e.value as num).toInt()
    };
    g.bestYearGain = (j['bestYearGain'] as num?)?.toInt() ?? 0;
    g.nextSalary = (j['nextSalary'] as num?)?.toInt() ?? 0;
    g.afterPath = AfterPath.parse(j['afterPath'] as String?);
    final pf = j['pendingFinal'];
    if (pf is Map) {
      g.pendingFinal = FinalMoment.fromJson(pf.cast<String, dynamic>());
    }
    g.turnCount = (j['turnCount'] as num?)?.toInt() ?? 0;
    g.lastCoachTurn = (j['lastCoachTurn'] as num?)?.toInt() ?? 0;
    g.lastLessonTurn = (j['lastLessonTurn'] as num?)?.toInt() ?? 0;
    g.monthRows = [
      for (final t in (j['monthRows'] as List?) ?? const []) t as String
    ];
    g.trainCount = (j['trainCount'] as num?)?.toInt() ?? 0;
    for (final e in ((j['childhood'] as Map?) ?? const {}).entries) {
      g.childhood[e.key as String] = (e.value as num).toInt();
    }
    g.restCount = (j['restCount'] as num?)?.toInt() ?? 0;
    g.lastFocus = Ability.parse((j['lastFocus'] as String?) ?? '');
    g.lastPlan = Plan.values.where((p) => p.name == j['lastPlan']).firstOrNull;
    g.lastPlanFocus = Ability.parse((j['lastPlanFocus'] as String?) ?? '');
    g.comboCount = (j['comboCount'] as num?)?.toInt() ?? 0;
    g.comboTotal = (j['comboTotal'] as num?)?.toInt() ?? 0;
    for (final e in ((j['shopThisYear'] as Map?) ?? const {}).entries) {
      final i = ShopItem.parse(e.key as String?);
      if (i != null) g.shopThisYear[i] = (e.value as num).toInt();
    }
    for (final x in (j['purchases'] as List?) ?? const []) {
      final i = ShopItem.parse(x as String?);
      if (i != null) g.purchases.add(i);
    }
    g.gearAge = (j['gearAge'] as num?)?.toInt() ?? -1;
    g.socialTargetId = j['socialTargetId'] as String?;
    g.favorsUsed.addAll(
        [for (final x in (j['favorsUsed'] as List?) ?? const []) x as String]);
    g.tagMateId = j['tagMateId'] as String?;
    g.exp = ExpPool.fromJson((j['exp'] as Map?)?.cast<String, dynamic>() ?? {});
    g.phase = pick(Phase.values, j['phase'], Phase.term);
    g.pendingEvent =
        events.where((e) => e.id == j['pendingEvent']).firstOrNull ??
            childhoodStepById(j['pendingEvent'] as String?)?.event ??
            (j['pendingEvent'] == tryoutEventId ? tryoutEvent : null) ??
            (j['pendingEvent'] == finalMomentId
                ? finalMomentEvent(g.player)
                : null);
    if (g.phase == Phase.event && g.pendingEvent == null) g.phase = Phase.term;
    g._eventFocus = pick(Ability.values, j['eventFocus'], Ability.contact);
    g.route = Course.values.where((r) => r.name == j['route']).firstOrNull;
    g.turnedPro = (j['turnedPro'] as bool?) ?? false;
    g.lowYears = (j['lowYears'] as num?)?.toInt() ?? 0;
    g.proYears = (j['proYears'] as num?)?.toInt() ?? 0;
    g.peakOverall = (j['peakOverall'] as num?)?.toInt() ?? 0;
    g.championships = (j['championships'] as num?)?.toInt() ?? 0;
    g.archived = (j['archived'] as bool?) ?? false;
    g.overallHistory.addAll(((j['overallHistory'] as List?) ?? const [])
        .map((e) => (e as num).toInt()));
    g.proStartAge = (j['proStartAge'] as num?)?.toInt();
    g.proTeam = j['proTeam'] as String?;
    g.position = Pos.parse(j['position'] as String?);
    g.overseas = (j['overseas'] as bool?) ?? false;
    g.parentName = j['parentName'] as String?;
    final sp = j['seasonProgress'];
    if (sp is Map) {
      g.seasonProgress = LeagueProgress.fromJson(sp.cast<String, dynamic>());
    }
    g.money = (j['money'] as num?)?.toInt() ?? 0;
    for (final e in ((j['invests'] as Map?) ?? const {}).entries) {
      final i = Invest.parse(e.key as String);
      if (i != null) {
        g.invests[i] = (e.value as num).toInt().clamp(0, maxInvestLevel);
      }
    }
    g.overseasTeam = j['overseasTeam'] as String?;
    g.teamBoost = (j['teamBoost'] as num?)?.toInt() ?? 0;
    g.school = School.parse(j['school']);
    g.offseasonDone = (j['offseasonDone'] as bool?) ?? false;
    g.faUsed = (j['faUsed'] as bool?) ?? false;
    g.goal = Goal.fromJson(j['goal']);
    g.lifeLog.addAll([
      for (final e in (j['lifeLog'] as List?) ?? const [])
        LifeEvent.fromJson((e as Map).cast<String, dynamic>()),
    ]);
    g.worldRecords.addAll([
      for (final r in (j['worldRecords'] as List?) ?? const [])
        WorldRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g.records.addAll([
      for (final r in (j['records'] as List?) ?? const [])
        SeasonRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g._wasTwoWay = (j['wasTwoWay'] as bool?) ?? g.player.role == Role.twoWay;
    g.achievements.addAll(((j['achievements'] as List?) ?? const [])
        .map((e) => (e as num).toDouble()));
    g.slot = g.slot.clamp(0, slotsPerYear(g.stage) - 1);
    if (g.phase == Phase.retired) g.ending = g._buildEnding();
    return g;
  }
}
