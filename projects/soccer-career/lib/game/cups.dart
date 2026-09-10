/// カップ戦の日程・抽選・勝ち上がり。
///
/// これまでカップ戦は `runDomesticCup` / `runContinental` が
/// シーズン末に**結果だけ**を振っていた。到達ラウンドは年俸にも評判にも
/// 記録にも効くのに、プレイヤーは1分もプレーしない。
///
/// ここでやるのは3つだけ。**いつ試合が入るか・誰と当たるか・勝ち上がったか**。
/// 試合そのものはリーグ戦と同じ `MatchInProgress` を通る。
library;

import 'dart:math';

import '../models/career.dart';
import '../models/club.dart';
import '../models/cup.dart';
import '../models/season.dart';
import 'formulas.dart';
import 'world.dart';

class Cups {
  Cups({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 国内カップの試合数（1回戦から決勝まで）。
  static const int domesticMatches = 5;

  /// 大陸カップの試合数（グループ6・決勝トーナメント2戦×3・決勝1）。
  static const int continentalMatches = 13;

  /// カップ戦が入る週を、シーズンの中に散らす。
  ///
  /// 節を決め打ちにすると、16クラブの国（30試合）で日程がはみ出す。
  /// 代表ウィークとぶつけない。同じ週に2試合を入れない
  /// （**1週1試合の刻みは変えない**。ここを崩すと疲労の設計が全部ずれる）。
  static List<int> weeksFor({
    required int matches,
    required int count,
    required Set<int> taken,
  }) {
    if (count <= 0 || matches <= 2) return const [];
    final weeks = <int>[];
    final step = matches / (count + 1);
    for (var i = 1; i <= count; i++) {
      var week = (step * i).round().clamp(1, matches - 1);
      // 埋まっていれば後ろへずらす。後ろが無ければ前へ。
      var guard = 0;
      while ((taken.contains(week) || weeks.contains(week)) && guard++ < matches) {
        week = week < matches - 1 ? week + 1 : week - 1;
      }
      weeks.add(week);
    }
    weeks.sort();
    return weeks;
  }

  /// 国内カップの相手。
  ///
  /// 一発勝負なので、下の部のクラブとも当たる。ラウンドが進むほど
  /// 生き残っているのは強いクラブ、という形にする。
  Club drawDomestic(CareerState state, CupRound round) {
    final country = World.byId(state.club.countryId);
    final own = state.club.tier;
    // 現実の抽選と同じで、早いラウンドは**自分と同じか下の部**と当たりやすい。
    // 一律に1部から引くと、2部のクラブは毎年1回戦で消える
    // （実測で 初戦敗退が72シーズン中51回。カップが年2試合の飾りになっていた）。
    final tiers = switch (round) {
      CupRound.round32 => [own, own, own + 1, own + 1],
      CupRound.round16 => [own, own, own + 1, own - 1],
      CupRound.quarter => [own, own, own - 1, own - 1],
      // 勝ち残っているのは上の部のクラブ。ここからは格上が普通。
      _ => [own - 1, own - 1, own],
    };
    final tier =
        tiers[_random.nextInt(tiers.length)].clamp(1, country.tierSizes.length);
    final league = World.buildLeague(state.club.countryId, tier);
    final pool = league.where((c) => c.id != state.club.id).toList();
    if (pool.isEmpty) return state.club;
    return pool[_random.nextInt(pool.length)];
  }

  /// 大陸カップの相手。同じ連盟の、別の国のクラブ。
  ///
  /// ラウンドが進むほど、格の高い国の上位クラブが残っている。
  Club drawContinental(CareerState state, CupRound round) {
    final home = World.byId(state.club.countryId);
    final others = World.countries
        .where((c) =>
            c.confederation == home.confederation && c.id != home.id)
        .toList();
    if (others.isEmpty) return drawDomestic(state, round);
    // 決勝トーナメントは格の高い国から。グループは幅を持たせる。
    final knockout = round != CupRound.group;
    others.sort((a, b) => b.prestige.compareTo(a.prestige));
    final span = knockout ? max(1, others.length ~/ 2) : others.length;
    final country = others[_random.nextInt(span)];

    final league = World.buildLeague(country.id, 1);
    // 上位ほど残っている。ラウンドが進むほど上から引く。
    final depth = switch (round) {
      CupRound.group => league.length ~/ 2,
      CupRound.round16 => max(2, league.length ~/ 3),
      CupRound.quarter => max(2, league.length ~/ 5),
      _ => max(1, league.length ~/ 8),
    };
    return league[_random.nextInt(depth)];
  }

  /// 次に戦う相手を引いて、1試合ぶんの予定を作る。
  CupTie drawTie(CareerState state, CupRun run) {
    final opponent = run.kind == CupKind.domestic
        ? drawDomestic(state, run.round)
        : drawContinental(state, run.round);
    if (run.round == CupRound.group) {
      return CupTie(
        kind: run.kind,
        round: run.round,
        opponentName: opponent.name,
        opponentStrength: opponent.strength,
        // グループは3チームとホーム&アウェイ。奇数節をホームにする。
        home: run.groupPlayed.isEven,
        groupMatch: run.groupPlayed + 1,
      );
    }
    return CupTie(
      kind: run.kind,
      round: run.round,
      opponentName: opponent.name,
      opponentStrength: opponent.strength,
      // 2戦合計の第1戦はアウェイから（現実の組み方に寄せる）。
      // 決勝は中立地なので、ホームアドバンテージは付けない。
      home: run.round.neutral ? false : !run.round.twoLegged,
    );
  }

  /// 1試合の結果を、勝ち上がりに反映する。
  ///
  /// 戻り値は「次に戦う予定」。無ければ null（敗退・優勝・そのラウンド終了）。
  CupTie? applyResult(CupRun run, CupTie tie, MatchResult result) {
    final scored = result.scored;
    final conceded = result.conceded;

    // --- グループステージ ---
    if (tie.round == CupRound.group) {
      run.groupPlayed++;
      run.groupPoints += scored > conceded ? 3 : (scored == conceded ? 1 : 0);
      run.groupGoalDifference += scored - conceded;
      if (!run.groupFinished) return null;
      if (run.groupQualified) {
        run.round = CupRound.round16;
      } else {
        run.eliminated = true;
      }
      return null;
    }

    // --- 2戦合計 ---
    if (tie.round.twoLegged && tie.leg == 1) {
      return CupTie(
        kind: tie.kind,
        round: tie.round,
        opponentName: tie.opponentName,
        opponentStrength: tie.opponentStrength,
        home: !tie.home,
        leg: 2,
        aggregateFor: scored,
        aggregateAgainst: conceded,
      );
    }

    final totalFor = tie.aggregateFor + scored;
    final totalAgainst = tie.aggregateAgainst + conceded;
    final advanced = totalFor > totalAgainst
        ? true
        : totalFor < totalAgainst
            ? false
            // 決着が付かなければPK戦。強いほうがわずかに有利、それだけ。
            : _shootoutWon(tie);

    if (!advanced) {
      run.eliminated = true;
      return null;
    }
    if (tie.round == CupRound.finalRound) {
      run.won = true;
      return null;
    }
    final path = run.kind == CupKind.domestic
        ? CupRound.domesticPath
        : CupRound.continentalPath;
    run.round = path[path.indexOf(tie.round) + 1];
    return null;
  }

  /// PK戦。**能力ではほとんど決まらない**のが現実に近い。
  ///
  /// ここを実力差で決めると、一発勝負の意味が消える。
  bool _shootoutWon(CupTie tie) =>
      _random.nextDouble() < Formulas.shootoutBase;

  /// そのラウンドで、主力が休まされるか。
  ///
  /// 現実のカップ戦の早いラウンドは、控えと若手が出る場。
  /// 序列が上の選手ほど、休まされる。カップが「若手の出番」になる。
  static bool rotatesIn(CupRound round) =>
      round == CupRound.round32 ||
      round == CupRound.round16 ||
      round == CupRound.group;

  /// カップ戦の起用に乗る下駄。
  ///
  /// 早いラウンドは普段出られない選手にも回ってくる。
  static double selectionBonus(CupRound round) =>
      rotatesIn(round) ? Formulas.cupRotationBonus : 0;
}
