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
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/support.dart';
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
    this.companion = TrainingCompanion.alone,
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
  final TrainingCompanion companion;

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
  int professionalism = 0;
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
Future<Career> runCareer(Playstyle style, int seed) async {
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
  );

  final career = Career(style)..startOverall = controller.state!.player.overall;
  await controller.setSimStyle(style.sim);
  await controller.setHabits(style.habits);
  if (style.directive != Directive.none) {
    await controller.setDirective(style.directive);
  }
  if (style.drills) await controller.setDrill(SetPiece.freeKick);
  await controller.setEffort(style.effort);

  var guard = 0;
  while (!controller.state!.retired && guard++ < 30) {
    final state = controller.state!;
    // 重傷でポテンシャルは下がる。伸びの上限として見るのは最大値。
    career.potential = max(career.potential, state.player.potential);

    // --- シーズンを戦う ---
    var matches = 0;
    while (!state.seasonFinished && matches++ < 60) {
      // 練習を決める。疲れていたら休む。
      await controller.setMenu(_menuFor(state, style));
      // 組む相手は移籍で入れ替わる。毎週その時点の顔ぶれで選び直す。
      await controller.setCompanion(state.companionChoices.contains(style.companion)
          ? style.companion
          : TrainingCompanion.alone);
      if (controller.pendingEvent != null) {
        career.events++;
        final choices = controller.pendingEvent!.choices;
        await controller.resolveEvent(choices[random.nextInt(choices.length)]);
      }
      // 「無傷 → 負傷」の瞬間だけ数える。離脱中は毎試合 Injury が作り直される
      // ので、単に別物かどうかで見ると離脱の長さを数えてしまう。
      final wasInjured = state.injured;
      await controller.simulateMatch();
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
      }
      career.seenStates
          .add('FixtureStake.${Newsroom.stakeFor(controller.state!).name}');
      career.seenStates
          .add('MomentumState.${controller.state!.form.state.name}');
      for (final item in controller.state!.news.take(3)) {
        career.seenStates.add('NewsKind.${item.kind.name}');
      }
      if (controller.state!.injured) career.missedMatches++;
      // 取り返しのつかない状態に、実際に到達するか。
      if (controller.state!.frozenOut) career.seenStates.add('frozenOut');
      if (controller.state!.trustAtRisk) career.seenStates.add('trustAtRisk');
      career.moraleSum += controller.state!.morale.value;
      career.fatigueSum += controller.state!.fatigue.value;
      career.moraleSamples++;
      career.peakOverall =
          max(career.peakOverall, controller.state!.player.overall);
    }

    await controller.finishSeason();
    final done = controller.state!;
    final stats = done.seasonStats;
    career.seasons++;
    career.appearances += stats.appearances;
    career.goals += stats.goals;
    career.assists += stats.assists;
    career.ratingSum += stats.averageRating * stats.appearances;
    career.bestTier = min(career.bestTier, done.club.tier);
    if (done.club.tier == 1) {
      career.bestPrestige =
          max(career.bestPrestige, World.byId(done.club.countryId).prestige);
    }
    career.peakValue = max(career.peakValue, done.reputation.marketValue);
    career.peakSalary = max(career.peakSalary, done.salary);
    career.caps = done.caps;
    career.awards = done.reputation.awards.length;
    career.seenStates.add('SquadStatus.${done.squadStatus.name}');
    career.minGap = min(career.minGap, done.player.overall - done.club.strength);
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
      career.seenStates
          .add('SecondCareer.${controller.suggestedSecondCareer.name}');
    }
    career.savings = done.finances.savings;
    career.signatures = done.development.signatures.length;
    career.breakthroughs = done.development.breakthroughs;
    career.greatWeeks = done.development.greatWeeks;
    career.professionalism = done.player.personality.professionalism;
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
    career.topTierOffers +=
        offers.where((o) => !o.isRenewal && !o.loan && o.club.tier == 1).length;
    final accepted = _pick(offers, style, done);
    if (accepted.loan) career.loans++;
    if (!accepted.isRenewal && accepted.club.name != done.club.name) {
      career.transfers++;
    }

    // 稼ぎの使い道。
    if (style.invests) _invest(controller);

    await controller.setPreseason(style.preseason);
    await controller.advanceSeason(
        accepted: accepted, bodyPlan: style.bodyPlan);
  }

  career.retireAge = controller.state!.player.age;
  return career;
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
    List<TransferOffer> offers, Playstyle style, CareerState state) {
  if (!style.ambitious) {
    return offers.firstWhere((o) => o.isRenewal, orElse: () => offers.first);
  }
  // 出番が無いならローンでも受ける。あるなら格と年俸で選ぶ。
  final stuck = state.seasonStats.appearances < 8;
  final ranked = [...offers]..sort((a, b) {
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
  final loaned = careers.where((c) => c.loans > 0).length * 100 / careers.length;
  final league = careers.fold(0, (s, c) => s + c.leagueTitles);
  final cup = careers.fold(0, (s, c) => s + c.cupTitles);
  final wc = careers.where((c) => c.worldCups > 0).length * 100 / careers.length;

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
  print('  ポテンシャル到達 ${reached.toStringAsFixed(0)}%  '
      '1部到達 ${topTier.toStringAsFixed(0)}%  '
      '代表経験 ${capped.toStringAsFixed(0)}%  '
      '限界突破 ${broke.toStringAsFixed(0)}%  '
      '個人技 ${signature.toStringAsFixed(0)}%  '
      'ローン ${loaned.toStringAsFixed(0)}%  '
      'W杯 ${wc.toStringAsFixed(0)}%');
  print('  リーグ優勝 $league回  国内カップ優勝 $cup回');
}

