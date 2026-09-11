// ignore_for_file: avoid_print
/// キャリアを引退まで回すための道具一式。
///
/// バランスを見るときは、実際の画面と同じ道（CareerController）を通す。
/// エンジンを直接叩くと、遊んだときの挙動と数字がずれて調整の意味が無くなる。
///
/// - `test/balance_sim.dart` … 200人ぶん回して数字を並べる（手動実行）
/// - `test/balance_test.dart` … 数人ぶん回して、壊れていないことを見る（CI）
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/knacks.dart';
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/support.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/state/career_controller.dart';

class MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

/// 遊び方の型。人によって進め方が違うので、いくつかの型で回す。
class Playstyle {
  const Playstyle({
    required this.name,
    required this.position,
    required this.startAge,
    required this.sim,
    required this.agent,
    this.rests = true,
    this.invests = false,
    this.drills = false,
    this.directive = Directive.none,
    this.ambitious = true,
    this.habits = const Habits(),
    this.bodyPlan = BodyPlan.maintain,
    this.preseason = PreseasonPlan.camp,
    this.effort = TrainingEffort.normal,
    this.easeFrom,
    this.pick,
    this.focus = const [],
    this.menu,
    this.companion = TrainingCompanion.alone,
    this.spendsPoints = false,
    this.autoRestBelow,
    this.traits,
    this.pinAbility,
    this.staysPut = false,
  });

  final String name;
  final Position position;
  final int startAge;
  final SimStyle sim;
  final Agent agent;

  /// 疲れたら休む。false なら毎週練習し続ける。
  final bool rests;

  /// 稼ぎを専属スタッフに回す。
  final bool invests;

  /// 週の踏み込み方と、組む相手。
  final TrainingEffort effort;

  /// この歳から「流す」に切り替える。null なら切り替えない。
  ///
  /// 一定の踏み込み方しか測っていないと、**踏み込み方を変える**という
  /// 一番面白い手が測れない。若いうちに伸ばして、身体が効かなくなる前に
  /// 引くのが効くのかどうかは、混ぜて回さないと分からない。
  final int? easeFrom;

  /// その歳のときの踏み込み方。
  TrainingEffort effortAt(int age) =>
      easeFrom != null && age >= easeFrom! ? TrainingEffort.easy : effort;

  /// 育てる方向。**何を選んだかが選手の形を変えるか**を測るために要る。
  final List<Detail> focus;

  /// 練習メニューを固定する。null ならポジションの既定。
  final TrainingMenu? menu;

  /// 局面での手の選び方を差し替える。null なら `SimStyle` に任せる。
  ///
  /// **「選択が実際にキャリアを変えているか」を測るために要る。**
  /// わざと一番悪い手を選び続けたキャリアと最善手のキャリアが同じなら、
  /// 2280回ある選択は飾りということになる。
  final ScenarioOption Function(MatchInProgress match)? pick;
  final TrainingCompanion companion;

  /// 自分で経験点を振るか。false なら今までどおり自動。
  final bool spendsPoints;

  /// 自動休養のしきい値。null なら既定のまま。
  final int? autoRestBelow;

  /// 特性を固定する。null なら今までどおり引く。
  ///
  /// **「特性がキャリアをどれだけ変えているか」を測るために要る。**
  /// 能力値と選び方を揃えて特性だけ差し替え、結果が動かないなら
  /// 特性は飾りということになる。
  final List<Trait>? traits;

  /// 毎週この値に能力を固定する。null なら普通に成長する。
  ///
  /// **「能力99の選手が底辺の環境で何を残すか」を測るために要る。**
  /// 普通に回すと、強くなった選手は移籍で環境ごと変わってしまう。
  final int? pinAbility;

  /// 移籍の話が来ても必ず残留する。環境を固定するための札。
  final bool staysPut;

  /// 居残りでセットプレーを磨く。
  final bool drills;

  final Directive directive;

  /// 条件の良いオファーへ移る。false なら基本的に残留する。
  final bool ambitious;

  final Habits habits;
  final BodyPlan bodyPlan;
  final PreseasonPlan preseason;
}

/// 1つのキャリアの結末。
class Career {
  Career(this.style);

  final Playstyle style;

  int seasons = 0;
  int retireAge = 0;
  int peakOverall = 0;
  int potential = 0;
  int startOverall = 0;
  int appearances = 0;
  int goals = 0;
  int assists = 0;
  double ratingSum = 0;
  int injuries = 0;
  int severeInjuries = 0;
  int missedMatches = 0;
  int transfers = 0;
  int lastTier = 9;

  /// 去年いたクラブ。**昇格で上がったのか、移籍で上がったのか**は
  /// クラブが同じかどうかでしか区別できない。
  String lastClub = '';

  /// そのシーズンに昇格した回数。
  int promotions = 0;

  /// 配られた特性。**枚数が選手を変えているか**を見るために残す。
  int strengthCount = 0;
  int flawCount = 0;
  bool hadRare = false;

  /// 1試合で2点・3点取った回数と、1試合の最多得点。
  ///
  /// **「ハットトリックができない」を数字で見るために要る。**
  /// 通算ゴールが同じでも、毎試合0.5点と「たまに3点」はまるで違う試合になる。
  int braces = 0;
  int hatTricks = 0;
  int bestMatchGoals = 0;
  bool reachedTopByPromotion = false;
  int loans = 0;
  int bestTier = 9;
  int bestPrestige = 0;
  int caps = 0;
  int awards = 0;
  int peakValue = 0;
  int peakSalary = 0;
  int savings = 0;
  int outOfSquadSeasons = 0;
  int zeroAppearanceSeasons = 0;
  int continentalSeasons = 0;
  int cupTitles = 0;
  int leagueTitles = 0;
  int worldCups = 0;
  int breakthroughs = 0;
  int greatWeeks = 0;
  int knackAge = 0;
  int professionalism = 0;
  int confidence = 0;
  int ambition = 0;
  int temper = 0;
  int atPotentialSeasons = 0;
  int signatures = 0;
  int plateaus = 0;
  int events = 0;

  /// 実際に起きた状態。「作ってあるのに起きない」を探すために数える。
  final Set<String> seenStates = {};

  /// クラブの強さとの差の、いちばん厳しかったところ。
  int minGap = 99;
  int offersSeen = 0;
  int topTierOffers = 0;
  int overallAt21 = 0;
  int overallAt25 = 0;
  int overallAt29 = 0;

  /// 引退したときの総合力と、33歳以降の出場・ゴール。
  ///
  /// 「流す」の見返りは**ピークの高さではなく、落ちるのが遅いこと**なので、
  /// ピークだけを見ていると差が出ているのに見えない。
  /// じっくりやる試合が、どれだけ来たか。
  int bigFixtures = 0;
  int leagueMatches = 0;
  int scenariosSeen = 0;

  /// 引退時の能力。**選んだことが形に出たか**を見るために残す。
  Attributes? finalAttributes;

  /// どの項目を何回狙ったか。
  Map<Detail, int> dedication = const {};
  int dedicationOf(Detail detail) => dedication[detail] ?? 0;

  int finalOverall = 0;
  int lateAppearances = 0;
  int lateGoals = 0;

  /// 引退時の身体の消耗。
  double strain = 0;
  int moraleSum = 0;
  int fatigueSum = 0;
  int moraleSamples = 0;
  bool reachedPotential = false;

  double get averageRating => appearances == 0 ? 0 : ratingSum / appearances;
  int get growth => peakOverall - startOverall;
  double get averageMorale =>
      moraleSamples == 0 ? 0 : moraleSum / moraleSamples;
  double get averageFatigue =>
      moraleSamples == 0 ? 0 : fatigueSum / moraleSamples;
}

/// 1人ぶんのキャリアを引退まで回す。
///
/// [onDecision] を渡すと、**自動で選ぶ前に**その局面と選ぶ手を覗ける。
/// 「何が実際に試合を動かしているか」を測るために要る（`influence_sim`）。
/// 渡さなければ、これまでどおり `simulateMatch` に任せる。
Future<Career> runCareer(
  Playstyle style,
  int seed, {
  void Function(MatchInProgress match, ScenarioOption option)? onDecision,
}) async {
  final controller = CareerController(
    repository: MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed * 7919 + 13)),
    random: Random(seed * 104729 + 7),
  );
  final random = Random(seed * 31 + 5);
  await controller.startCareer(
    name: '選手$seed',
    position: style.position,
    age: style.startAge,
    agent: style.agent,
    traits: style.traits,
  );

  final career = Career(style)..startOverall = controller.state!.player.overall;
  final dealt = controller.state!.player.traits;
  career.strengthCount = dealt.where((t) => !t.flaw).length;
  career.flawCount = dealt.where((t) => t.flaw).length;
  career.hadRare = dealt.any((t) => t.rare);
  await controller.setSimStyle(style.sim);
  await controller.setHabits(style.habits);
  if (style.directive != Directive.none) {
    await controller.setDirective(style.directive);
  }
  if (style.drills) await controller.setDrill(SetPiece.freeKick);
  for (final detail in style.focus) {
    await controller.toggleFocus(detail);
  }
  await controller.setEffort(style.effort);
  if (style.autoRestBelow != null) {
    await controller.setAutoRestBelow(style.autoRestBelow!);
  }
  if (style.spendsPoints) await controller.setAutoSpend(false);

  var guard = 0;
  while (!controller.state!.retired && guard++ < 30) {
    final state = controller.state!;
    // 歳に応じて踏み込み方を切り替える（切り替えない型なら毎季同じ値）。
    await controller.setEffort(style.effortAt(state.player.age));
    // 重傷でポテンシャルは下がる。伸びの上限として見るのは最大値。
    career.potential = max(career.potential, state.player.potential);

    // --- シーズンを戦う ---
    var matches = 0;
    // リーグ38節 + カップ最大18 + 代表3。上限で切らないように余裕を持たせる。
    while (!state.seasonFinished && matches++ < 90) {
      // 練習を決める。疲れていたら休む。
      await controller.setMenu(style.menu ?? _menuFor(state, style));
      // 組む相手は移籍で入れ替わる。毎週その時点の顔ぶれで選び直す。
      await controller.setCompanion(
        state.companionChoices.contains(style.companion)
            ? style.companion
            : TrainingCompanion.alone,
      );
      if (controller.pendingEvent != null) {
        career.events++;
        final choices = controller.pendingEvent!.choices;
        await controller.resolveEvent(choices[random.nextInt(choices.length)]);
      }
      // 「無傷 → 負傷」の瞬間だけ数える。離脱中は毎試合 Injury が作り直される
      // ので、単に別物かどうかで見ると離脱の長さを数えてしまう。
      // じっくりやる試合が、どれだけ来ているか。
      if (!state.seasonFinished) {
        career.leagueMatches++;
        if (Newsroom.isBigFixture(state)) career.bigFixtures++;
      }
      // 能力を固定する型なら、毎週そこへ戻す。
      if (style.pinAbility != null) {
        controller.state!.player = controller.state!.player.copyWith(
          attributes: Attributes.fromDetails({
            for (final d in Detail.values) d: style.pinAbility!,
          }),
        );
      }
      final wasInjured = state.injured;
      if (onDecision == null && style.pick == null) {
        await controller.simulateMatch();
      } else {
        await _playWatched(controller, style, onDecision);
      }
      if (style.spendsPoints) await _spendPoints(controller);
      final after = controller.state!.injury;
      if (!wasInjured && after != null) {
        career.injuries++;
        career.seenStates.add('InjurySeverity.${after.severity.name}');
        if (after.severity.index >= 2) career.severeInjuries++;
      }
      // 直前の試合の結果は状態から読む。simulateMatch の戻り値は
      // analyzer の版によって null 許容の見立てが変わり、CI だけ落ちた。
      final results = controller.state!.results;
      if (results.isNotEmpty) {
        career.seenStates.add('Appearance.${results.last.appearance.name}');
        final scored = results.last.goals;
        if (scored >= 2) career.braces++;
        if (scored >= 3) career.hatTricks++;
        career.bestMatchGoals = max(career.bestMatchGoals, scored);
      }
      career.seenStates.add(
        'FixtureStake.${Newsroom.stakeFor(controller.state!).name}',
      );
      career.seenStates.add(
        'MomentumState.${controller.state!.form.state.name}',
      );
      for (final item in controller.state!.news.take(3)) {
        career.seenStates.add('NewsKind.${item.kind.name}');
      }
      if (controller.state!.injured) career.missedMatches++;
      // 取り返しのつかない状態に、実際に到達するか。
      if (controller.state!.frozenOut) career.seenStates.add('frozenOut');
      if (controller.state!.trustAtRisk) career.seenStates.add('trustAtRisk');
      // コツの条件に初めて届いた年齢を控える。
      if (career.knackAge == 0 && Knacks.canLearn(controller.state!)) {
        career.knackAge = controller.state!.player.age;
      }
      career.moraleSum += controller.state!.morale.value;
      career.fatigueSum += controller.state!.fatigue.value;
      career.moraleSamples++;
      career.peakOverall = max(
        career.peakOverall,
        controller.state!.player.overall,
      );
    }

    await controller.finishSeason();
    final done = controller.state!;
    final stats = done.seasonStats;
    career.seasons++;
    career.appearances += stats.appearances;
    career.goals += stats.goals;
    career.assists += stats.assists;
    career.ratingSum += stats.averageRating * stats.appearances;
    // **1部にどうやって届いたか。昇格か、移籍か。**
    //
    // ここは長いあいだ `career.lastTier == 1` を見ていて、**構造的に
    // 一度も true にならなかった**（初めて1部に届く瞬間、去年の部は
    // 必ず1ではない）。「60キャリア全員が移籍で到達、昇格は0人」という
    // 記録は、この壊れた指標から出ている。**指標そのものを疑う。**
    // 昇格と移籍を分けるのは部の数字ではなく、**クラブが同じかどうか**。
    final sameClub = career.lastClub == done.club.name;
    if (done.club.tier < career.lastTier && sameClub) career.promotions++;
    if (done.club.tier == 1 && career.bestTier > 1) {
      career.reachedTopByPromotion = sameClub;
    }
    career.lastTier = done.club.tier;
    career.lastClub = done.club.name;
    career.bestTier = min(career.bestTier, done.club.tier);
    if (done.club.tier == 1) {
      career.bestPrestige = max(
        career.bestPrestige,
        World.byId(done.club.countryId).prestige,
      );
    }
    career.peakValue = max(career.peakValue, done.reputation.marketValue);
    career.peakSalary = max(career.peakSalary, done.salary);
    career.caps = done.caps;
    career.awards = done.reputation.awards.length;
    career.seenStates.add('SquadStatus.${done.squadStatus.name}');
    career.minGap = min(
      career.minGap,
      done.player.overall - done.club.strength,
    );
    career.seenStates.add('ContinentalStage.${done.continentalStage.name}');
    career.seenStates.add('CupStage.${done.cupStage.name}');
    career.seenStates.add('WorldCupStage.${done.worldCupStage.name}');
    career.seenStates.add('CareerStage.${done.stage.name}');
    for (final award in done.reputation.awards) {
      career.seenStates.add('Award.${award.name}');
    }
    for (final trait in done.player.traits) {
      career.seenStates.add('Trait.${trait.name}');
    }
    for (final signature in done.development.signatures) {
      career.seenStates.add('Signature.${signature.name}');
    }
    if (done.development.identity != null) {
      career.seenStates.add('AttributeKey.${done.development.identity!.name}');
    }
    if (done.manager != null) {
      career.seenStates.add('Tactic.${done.manager!.tactic.name}');
    }
    if (done.retired) {
      career.seenStates.add(
        'SecondCareer.${controller.suggestedSecondCareer.name}',
      );
    }
    career.savings = done.finances.savings;
    career.signatures = done.development.signatures.length;
    career.breakthroughs = done.development.breakthroughs;
    career.greatWeeks = done.development.greatWeeks;
    career.professionalism = done.player.personality.professionalism;
    career.confidence = done.player.personality.confidence;
    career.ambition = done.player.personality.ambition;
    career.temper = done.player.personality.temper;
    if (done.player.atPotential) career.atPotentialSeasons++;
    if (done.development.inPlateau) career.plateaus++;
    if (stats.appearances == 0) career.zeroAppearanceSeasons++;
    if (!done.squadStatus.canPlay) career.outOfSquadSeasons++;
    if (done.continentalStage.participated) career.continentalSeasons++;
    if (done.cupStage == CupStage.winner) career.cupTitles++;
    if (done.leaguePosition == 1 && done.club.tier == 1) career.leagueTitles++;
    if (done.worldCupStage.participated) career.worldCups++;
    if (done.player.atPotential) career.reachedPotential = true;
    final age = done.player.age;
    if (age <= 21) career.overallAt21 = done.player.overall;
    if (age <= 25) career.overallAt25 = done.player.overall;
    if (age <= 29) career.overallAt29 = done.player.overall;
    if (age >= 33) {
      career.lateAppearances += stats.appearances;
      career.lateGoals += stats.goals;
    }
    career.finalOverall = done.player.overall;
    career.finalAttributes = done.player.attributes;
    career.dedication = done.development.dedication;
    career.strain = done.development.strain;

    // --- 去就を決める ---
    if (controller.mustRetire) {
      await controller.retire();
      break;
    }
    // 出番が無いまま歳を取ったら辞める。数字だけで粘り続ける人は少ない。
    if (controller.canRetire &&
        (stats.appearances < 8 || done.player.age >= 35) &&
        random.nextDouble() < 0.5) {
      await controller.retire();
      break;
    }

    final offers = [
      if (controller.renewalOffer != null) controller.renewalOffer!,
      ...controller.offers,
    ];
    if (offers.isEmpty) {
      await controller.retire();
      break;
    }
    career.offersSeen += offers.where((o) => !o.isRenewal && !o.loan).length;
    career.topTierOffers += offers
        .where((o) => !o.isRenewal && !o.loan && o.club.tier == 1)
        .length;
    final accepted = _pick(offers, style, done);
    if (accepted.loan) career.loans++;
    if (!accepted.isRenewal && accepted.club.name != done.club.name) {
      career.transfers++;
    }

    // 稼ぎの使い道。
    if (style.invests) _invest(controller);

    await controller.setPreseason(style.preseason);
    await controller.advanceSeason(
      accepted: accepted,
      bodyPlan: style.bodyPlan,
    );
  }

  career.retireAge = controller.state!.player.age;
  return career;
}

/// 溜まった経験点を振る。
///
/// 「そのポジションで重い能力から、安いものを順に」という、
/// 平均的な遊び方に近い振り方。強い最適化はしない。
Future<void> _spendPoints(CareerController controller) async {
  final state = controller.state!;
  var guard = 0;
  while (guard++ < 40) {
    final candidates = <Detail>[
      for (final key in AttributeKey.values)
        if ((state.development.points[key] ?? 0) > 0)
          for (final d in key.details)
            if (controller.canSpend(d)) d,
    ];
    if (candidates.isEmpty) return;
    candidates.sort((a, b) {
      final byWeight = Attributes.weightShare(
        state.player.position,
        b.category,
      ).compareTo(Attributes.weightShare(state.player.position, a.category));
      if (byWeight != 0) return byWeight;
      return controller.costOf(a).compareTo(controller.costOf(b));
    });
    if (await controller.spendPoint(candidates.first) == null) return;
  }
}

/// 練習の決め方。
TrainingMenu _menuFor(CareerState state, Playstyle style) {
  if (style.rests && state.player.condition < 45) return TrainingMenu.rest;
  if (state.player.atPotential) return TrainingMenu.lightWork;
  return switch (state.player.position) {
    Position.gk => TrainingMenu.keeperWork,
    Position.cb || Position.sb => TrainingMenu.defenceWork,
    Position.dm || Position.cm => TrainingMenu.tactical,
    Position.am || Position.wg => TrainingMenu.possession,
    Position.st => TrainingMenu.attacking,
  };
}

/// オファーの選び方。
TransferOffer _pick(
  List<TransferOffer> offers,
  Playstyle style,
  CareerState state,
) {
  // 環境を固定する型は、何が来ても残る。
  if (style.staysPut || !style.ambitious) {
    return offers.firstWhere((o) => o.isRenewal, orElse: () => offers.first);
  }
  // 出番が無いならローンでも受ける。あるなら格と年俸で選ぶ。
  final stuck = state.seasonStats.appearances < 8;
  final ranked = [...offers]
    ..sort((a, b) {
      int score(TransferOffer o) =>
          (o.loan ? (stuck ? 3000 : -5000) : 0) +
          o.salary +
          (4 - o.club.tier) * 800;
      return score(b).compareTo(score(a));
    });
  return ranked.first;
}

/// 貯蓄に余裕があればスタッフを雇う。
void _invest(CareerController controller) {
  final state = controller.state!;
  for (final kind in StaffKind.values) {
    for (var level = StaffTeam.maxLevel; level >= 1; level--) {
      if (state.staff[kind] >= level) break;
      final cost = StaffTeam.costPerLevel[level];
      // 3年ぶん払える範囲でだけ雇う。
      if (state.finances.savings > cost * 3) {
        if (controller.hireStaff(kind, level)) break;
      }
    }
  }
}

/// 集計の道具。
class Stat {
  final List<double> values = [];

  void add(num v) => values.add(v.toDouble());

  double get mean =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  double percentile(double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[(sorted.length * p).clamp(0, sorted.length - 1).toInt()];
  }

  double get min => values.isEmpty ? 0 : values.reduce(mathMin);
  double get max => values.isEmpty ? 0 : values.reduce(mathMax);
}

double mathMin(double a, double b) => a < b ? a : b;
double mathMax(double a, double b) => a > b ? a : b;

String _row(String label, Stat s, {int digits = 1}) =>
    '${label.padRight(16)} '
    '平均 ${s.mean.toStringAsFixed(digits).padLeft(7)}  '
    '中央 ${s.percentile(0.5).toStringAsFixed(digits).padLeft(7)}  '
    '下位1割 ${s.percentile(0.1).toStringAsFixed(digits).padLeft(7)}  '
    '上位1割 ${s.percentile(0.9).toStringAsFixed(digits).padLeft(7)}';

void report(String title, List<Career> careers) {
  final peak = Stat();
  final growth = Stat();
  final seasons = Stat();
  final retire = Stat();
  final apps = Stat();
  final goals = Stat();
  final assists = Stat();
  final rating = Stat();
  final injuries = Stat();
  final severe = Stat();
  final missed = Stat();
  final value = Stat();
  final salary = Stat();
  final savings = Stat();
  final caps = Stat();
  final awards = Stat();
  final tier = Stat();
  final morale = Stat();
  final fatigue = Stat();
  final zero = Stat();
  final events = Stat();
  final potential = Stat();
  final at21 = Stat();
  final at25 = Stat();
  final at29 = Stat();
  final offersSeen = Stat();
  final topOffers = Stat();
  final prestige = Stat();

  for (final c in careers) {
    peak.add(c.peakOverall);
    growth.add(c.growth);
    seasons.add(c.seasons);
    retire.add(c.retireAge);
    apps.add(c.appearances);
    goals.add(c.goals);
    assists.add(c.assists);
    rating.add(c.averageRating);
    injuries.add(c.seasons == 0 ? 0 : c.injuries / c.seasons);
    severe.add(c.severeInjuries);
    missed.add(c.seasons == 0 ? 0 : c.missedMatches / c.seasons);
    value.add(c.peakValue);
    salary.add(c.peakSalary);
    savings.add(c.savings);
    caps.add(c.caps);
    awards.add(c.awards);
    tier.add(c.bestTier);
    morale.add(c.averageMorale);
    fatigue.add(c.averageFatigue);
    zero.add(c.zeroAppearanceSeasons);
    events.add(c.events);
    potential.add(c.potential);
    at21.add(c.overallAt21);
    at25.add(c.overallAt25);
    at29.add(c.overallAt29);
    offersSeen.add(c.offersSeen);
    topOffers.add(c.topTierOffers);
    prestige.add(c.bestPrestige);
  }

  final reached =
      careers.where((c) => c.reachedPotential).length * 100 / careers.length;
  final topTier =
      careers.where((c) => c.bestTier == 1).length * 100 / careers.length;
  final capped = careers.where((c) => c.caps > 0).length * 100 / careers.length;
  final broke =
      careers.where((c) => c.breakthroughs > 0).length * 100 / careers.length;
  final signature =
      careers.where((c) => c.signatures > 0).length * 100 / careers.length;
  final loaned =
      careers.where((c) => c.loans > 0).length * 100 / careers.length;
  final league = careers.fold(0, (s, c) => s + c.leagueTitles);
  final cup = careers.fold(0, (s, c) => s + c.cupTitles);
  final wc =
      careers.where((c) => c.worldCups > 0).length * 100 / careers.length;

  print('');
  print('== $title  (${careers.length}人) ==');
  print(_row('ピーク総合力', peak));
  print(_row('ポテンシャル', potential));
  print(_row('21歳の総合力', at21));
  print(_row('25歳の総合力', at25));
  print(_row('29歳の総合力', at29));
  print(_row('届いた移籍話', offersSeen, digits: 2));
  print(_row('うち1部から', topOffers, digits: 2));
  print(_row('伸び幅', growth));
  print(_row('シーズン数', seasons));
  print(_row('引退年齢', retire));
  print(_row('通算出場', apps));
  print(_row('通算ゴール', goals));
  print(_row('通算アシスト', assists));
  print(_row('平均評価', rating, digits: 2));
  print(_row('怪我/シーズン', injuries, digits: 2));
  print(_row('重傷/キャリア', severe, digits: 2));
  print(_row('離脱試合/シーズン', missed, digits: 1));
  print(_row('最高市場価値', value, digits: 0));
  print(_row('最高年俸', salary, digits: 0));
  print(_row('引退時の貯蓄', savings, digits: 0));
  print(_row('代表キャップ', caps));
  print(_row('称号', awards));
  print(_row('到達した部', tier, digits: 2));
  print(_row('1部の国の格', prestige, digits: 2));
  print(_row('平均の気持ち', morale));
  print(_row('平均の疲労', fatigue));
  print(_row('無出場シーズン', zero, digits: 2));
  print(_row('出来事', events));
  print(
    '  ポテンシャル到達 ${reached.toStringAsFixed(0)}%  '
    '1部到達 ${topTier.toStringAsFixed(0)}%  '
    '代表経験 ${capped.toStringAsFixed(0)}%  '
    '限界突破 ${broke.toStringAsFixed(0)}%  '
    '個人技 ${signature.toStringAsFixed(0)}%  '
    'ローン ${loaned.toStringAsFixed(0)}%  '
    'W杯 ${wc.toStringAsFixed(0)}%',
  );
  print('  リーグ優勝 $league回  国内カップ優勝 $cup回');
}

/// 自動進行と同じ手を選びながら、選ぶ直前に覗かせる。
///
/// `MatchInProgress.autoPlay` と同じことをしている（`pickFor` → `choose`）。
/// 覗くためだけに本体へ穴を開けたくないので、ここで同じ形をなぞる。
Future<void> _playWatched(
  CareerController controller,
  Playstyle style,
  void Function(MatchInProgress match, ScenarioOption option)? onDecision,
) async {
  final state = controller.state!;
  if (controller.currentMatch == null) {
    if (state.pendingCup != null) {
      controller.startCupMatch();
    } else {
      controller.startNextMatch();
    }
  }
  final match = controller.currentMatch;
  if (match == null) return;
  while (!match.isFinished) {
    match.autoArm(state.simStyle);
    final option = style.pick?.call(match) ?? match.pickFor(state.simStyle);
    onDecision?.call(match, option);
    match.choose(option);
  }
  await controller.finishMatch();
}
