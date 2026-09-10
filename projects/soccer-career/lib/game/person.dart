import 'dart:math';

import '../models/career.dart';
import '../models/competition.dart';
import '../models/personality.dart';
import '../models/reputation.dart';
import '../models/traits.dart';
import 'formulas.dart';
import 'world.dart';

/// 選手を「一人の人間」として扱う部分。
///
/// 性格・市場価値・評判・監督との関係・お金。どれも試合の外で動き、
/// 試合の中には成功率や出場機会という形でしか現れない。
class Person {
  Person({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 市場価値を計算する。
  ///
  /// 実力・年齢・契約の残り・直近の出来で決まる。年俸とは別で、
  /// これが移籍オファーの質と労働許可の審査に効く。
  int marketValueFor(CareerState state) {
    final overall = state.player.overall;
    final base = pow(max(0, overall - 45), 2.1).toDouble();

    // 年齢。ピーク前後で山になり、30を過ぎると急に落ちる。
    final age = state.player.age;
    final ageFactor = age <= 21
        ? 1.35
        : age <= 27
        ? 1.2
        : age <= 30
        ? 0.9
        : age <= 33
        ? 0.5
        : 0.2;

    // 契約が短いほど安く買える＝値札は下がる。
    final contractFactor = 0.6 + state.contractYears * 0.15;

    // 直近の出来。
    final stats = state.seasonStats;
    final form = stats.appearances == 0
        ? 0.85
        : (0.7 + (stats.averageRating - 6.0) * 0.3).clamp(0.6, 1.5);

    // リーグの格。同じ実力でも見られている場所で値段が違う。
    final prestige = World.byId(state.club.countryId).prestige;
    final leagueFactor = 0.6 + prestige * 0.18;

    final value = base * ageFactor * contractFactor * form * leagueFactor * 1.6;
    return max(50, (value / 50).round() * 50);
  }

  /// 知名度。活躍と代表と大陸カップで上がり、何もしないと少し落ちる。
  int fameFor(CareerState state) {
    final stats = state.seasonStats;
    var gained = 0;

    // 代表と大陸カップは、リーグに出ていなくても目に触れる。
    gained += state.seasonCaps * 2;
    gained += state.continentalStage.points * 2;
    gained += state.cupStage.points;
    // 世界大会は桁が違う。1度出るだけで名前が知れ渡る。
    gained += state.worldCupStage.points * 4;

    // リーグでの露出は「出場していること」が前提。試合に出ない選手は
    // どんなに格の高いリーグに籍を置いていても忘れられていく。
    if (stats.appearances > 0) {
      gained += (stats.goals + stats.assists) ~/ 3;
      if (state.club.tier == 1) gained += 2;
      gained += World.byId(state.club.countryId).prestige;
    }
    // 華のある選手は同じ働きでも名前が広まる。忘れられる速さは同じ。
    final fame =
        state.reputation.fame -
        2 +
        (gained * state.player.traits.fameFactor).round();
    return fame.clamp(0, 100);
  }

  /// そのシーズンで得た称号。
  List<Award> awardsFor(CareerState state, {required bool promoted}) {
    final earned = <Award>[];
    final totals = state.careerTotals;
    final stats = state.seasonStats;

    if (totals.appearances >= 1) earned.add(Award.debut);
    if (totals.goals >= 1) earned.add(Award.firstGoal);
    if (totals.appearances >= 100) earned.add(Award.hundredMatches);
    if (totals.appearances >= 200) earned.add(Award.twoHundredMatches);
    if (totals.goals >= 50) earned.add(Award.fiftyGoals);
    if (totals.goals >= 100) earned.add(Award.hundredGoals);
    if (state.caps >= 1) earned.add(Award.firstCap);
    if (state.caps >= 50) earned.add(Award.fiftyCaps);

    // 新人王は21歳以下で好成績のとき一度だけ。
    if (state.player.age <= 21 &&
        stats.appearances >= 15 &&
        stats.averageRating >= 6.9) {
      earned.add(Award.youngPlayer);
    }
    // 得点王は、その部で突出したとき。
    if (stats.goals >= 18 && stats.appearances >= 20) {
      earned.add(Award.topScorer);
    }
    if (stats.appearances >= 20 && stats.averageRating >= 7.3) {
      earned.add(Award.seasonBest);
    }
    if (state.leaguePosition == 1 && state.club.tier == 1) {
      earned.add(Award.leagueTitle);
    }
    if (promoted) earned.add(Award.promotion);
    if (state.continentalStage == ContinentalStage.winner) {
      earned.add(Award.continentalTitle);
    }
    if (state.cupStage == CupStage.winner) earned.add(Award.domesticCup);
    if (state.worldCupStage.participated) earned.add(Award.worldCup);
    if (state.worldCupStage == WorldCupStage.winner) {
      earned.add(Award.worldCupTitle);
    }
    return earned;
  }

  /// 監督の信頼を更新する。
  ///
  /// 目標の達成、出場、評価点で動く。気性が荒いとぶつかりやすい。
  Relations updateRelations(CareerState state) {
    final stats = state.seasonStats;
    var manager = 0;
    var teammates = 0;

    if (stats.appearances == 0) {
      manager -= 10;
    } else {
      manager += ((stats.averageRating - 6.4) * 18).round();
    }
    if (state.objective?.achieved(stats) ?? false) manager += 12;

    // 自分から口にした約束。果たせば厚く、破れば重い。
    // 与えられた目標より重く扱う（自分で選んだ数字なので）。
    final promise = state.promise;
    if (promise != null) {
      manager += promise.achievedBy(stats)
          ? promise.weight.trustKept
          : -promise.weight.trustBroken;
    }

    // 気性が荒いと衝突する。プロ意識が高いと信頼される。
    final personality = state.player.personality;
    manager += (personality.professionalism - 10) ~/ 3;
    manager -= max(0, personality.temper - 14) ~/ 2;

    // 監督受けの良し悪し。上がるときと下がるときで別に効く。
    final traits = state.player.traits;
    manager = manager > 0
        ? (manager * traits.relationGainFactor).round()
        : (manager * traits.relationLossFactor).round();

    // ロッカールームは在籍年数と出場、そして気性で決まる。
    teammates += stats.appearances ~/ 6;
    teammates += (personality.professionalism - 10) ~/ 4;
    teammates -= max(0, personality.temper - 15) ~/ 2;

    return state.relations.bump(manager: manager, teammates: teammates);
  }

  /// 経験で性格が少しずつ変わる。
  ///
  /// **足し算をやめて、落ち着き先へ1歩ずつ寄せる。**
  /// 条件が続く限り足し続ける形だったので、40キャリアを回すと
  /// 全員がプロ意識 20（上限）・自信 15.8・野心 15.4 で引退していた。
  /// 性格で選手が違ってくるはずの部分（練習の効き・衰え始めの年齢）が、
  /// 20年やれば誰でも同じになっていた。
  ///
  /// 落ち着き先は**生まれ持った値＋今の立場**。立場が変われば戻る。
  Personality evolve(CareerState state) {
    var personality = state.player.personality;
    final born = personality.born;
    for (final axis in PersonalityAxis.values) {
      // 毎季きっちり1歩動くと、同じ立場の選手が同じ速さで同じ値に着く。
      if (_random.nextDouble() >= Formulas.personalitySettleChance) continue;
      personality = personality.settleToward(
        axis,
        born[axis] + _shiftFor(axis, state),
      );
    }
    return personality;
  }

  /// 今の立場が、生まれ持った値からどれだけ動かすか。
  int _shiftFor(PersonalityAxis axis, CareerState state) {
    final stats = state.seasonStats;
    return switch (axis) {
      // 上手くいけば自信が付き、干されれば削られる。
      PersonalityAxis.confidence =>
        (stats.appearances >= 15 && stats.averageRating >= 7.0 ? 3 : 0) +
            (stats.appearances >= 25 && stats.averageRating >= 7.3 ? 2 : 0) +
            (stats.appearances <= 5 ? -4 : 0),
      // 燻ると強くなり、満たされると落ち着く。
      PersonalityAxis.ambition =>
        (state.relations.manager < 30 ? 3 : 0) +
            ((state.rival?.leads(state.player.overall) ?? false) ? 2 : 0) +
            (state.club.tier == 1 && state.leaguePosition <= 3 ? -2 : 0),
      // 整えた生活と、年齢と、若いうちに見た背中。
      PersonalityAxis.professionalism =>
        (state.habits.disciplined ? 4 : 0) +
            (state.habits.reckless ? -4 : 0) +
            (state.player.age >= 28 ? 2 : 0) +
            (state.mentor != null && state.player.age <= 23 ? 2 : 0),
      // 歳を取ると丸くなる。崩した生活は荒くする。
      PersonalityAxis.temper =>
        (state.player.age >= 28 ? -3 : 0) + (state.habits.reckless ? 2 : 0),
    };
  }

  /// 監督の信頼が出場機会に与える下駄。
  ///
  /// 評価点だけで決めると「監督との関係」が飾りになる。信頼が厚いと
  /// 多少調子を落としても使われ、構想外だと good な数字でもベンチに座る。
  static double appearanceBonusFrom(Relations relations) =>
      (relations.manager - 50) * 0.008;
}
