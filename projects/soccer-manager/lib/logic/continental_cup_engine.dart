import 'dart:math';

import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import 'background_match_engine.dart';
import 'cup_engine.dart';
import 'match_engine.dart';
import 'weather_engine.dart';
import '../l10n/tr.dart';

/// 大陸カップ: グループステージ(4チーム総当たり)+決勝トーナメント
/// (準決勝はホーム&アウェイ2試合合計、決勝は1試合)を管理する。
class ContinentalCupEngine {
  static final Random _rng = Random();

  /// 1グループあたりのチーム数。
  static const int groupSize = 4;

  /// [teamIds]を[groupSize]チームずつのグループに振り分け、各組の総当たり
  /// の対戦表を生成する。
  ///
  /// [homeAndAway]なら総当たりをホームとアウェイの2回(6節。実在の大会の
  /// グループステージの形)、そうでなければ1回(3節。古い形)。
  /// [strength]を渡すと、強さの順に4つのポットに分けて各組に1クラブずつ
  /// 入れ、[countries]を渡すと、できるだけ同じ国のクラブを同じ組にしない
  /// (実在の組み分けの抽選に寄せる)。[stepDue]は各段階を消化できるように
  /// なる節([currentStep]の数え方)。
  static ContinentalCup create({
    required String name,
    required List<String> teamIds,
    bool homeAndAway = false,
    int level = 1,
    Map<String, int>? strength,
    Map<String, String>? countries,
    List<int>? stepDue,
  }) {
    final groups = strength == null
        ? _plainGroups(teamIds)
        : _potGroups(teamIds, strength, countries ?? const {});

    final perGroupMatches = groups.map(_groupRoundRobin).toList();
    const maxRound = groupSize - 1;
    final matches = <CupMatch>[];
    for (int round = 1; round <= maxRound; round++) {
      for (final groupMatches in perGroupMatches) {
        matches.addAll(groupMatches.where((m) => m.round == round));
      }
    }
    if (homeAndAway) {
      // 後半の3節は、前半の対戦のホームとアウェイを入れ替えたもの。
      final firstHalf = [...matches];
      for (final m in firstHalf) {
        matches.add(CupMatch(
          round: m.round + maxRound,
          homeTeamId: m.awayTeamId,
          awayTeamId: m.homeTeamId,
        ));
      }
    }
    return ContinentalCup(
      name: name,
      groups: groups,
      groupMatches: matches,
      level: level,
      countries: countries,
      stepDue: stepDue,
    );
  }

  static List<List<String>> _plainGroups(List<String> teamIds) {
    final shuffled = [...teamIds]..shuffle(_rng);
    final groups = <List<String>>[];
    for (var i = 0; i < shuffled.length; i += groupSize) {
      final end =
          (i + groupSize < shuffled.length) ? i + groupSize : shuffled.length;
      groups.add(shuffled.sublist(i, end));
    }
    return groups;
  }

  /// 強さの順のポットから1クラブずつ各組へ。同じ国のクラブはできるだけ
  /// 別の組に入れる(何度かくじを引き直し、無理なら国の重なりを許す)。
  static List<List<String>> _potGroups(List<String> teamIds,
      Map<String, int> strength, Map<String, String> countries) {
    final groupCount = (teamIds.length / groupSize).ceil();
    final sorted = [...teamIds]
      ..shuffle(_rng)
      ..sort((a, b) => (strength[b] ?? 0).compareTo(strength[a] ?? 0));
    List<List<String>>? best;
    var bestClashes = 1 << 30;
    for (var attempt = 0; attempt < 40; attempt++) {
      final groups = List.generate(groupCount, (_) => <String>[]);
      for (var pot = 0; pot * groupCount < sorted.length; pot++) {
        final end = ((pot + 1) * groupCount).clamp(0, sorted.length);
        final members = sorted.sublist(pot * groupCount, end)..shuffle(_rng);
        for (final id in members) {
          final open = [
            for (var g = 0; g < groupCount; g++)
              if (groups[g].length <= pot) g,
          ];
          final c = countries[id];
          final clean = open
              .where(
                  (g) => c == null || !groups[g].any((x) => countries[x] == c))
              .toList();
          final pick = (clean.isNotEmpty ? clean : open);
          groups[pick[_rng.nextInt(pick.length)]].add(id);
        }
      }
      var clashes = 0;
      for (final g in groups) {
        final seen = <String>{};
        for (final id in g) {
          final c = countries[id];
          if (c != null && !seen.add(c)) clashes++;
        }
      }
      if (clashes < bestClashes) {
        best = groups;
        bestClashes = clashes;
      }
      if (clashes == 0) break;
    }
    return best!;
  }

  /// いまの段階の番号(0から)。グループの第r節は r-1、決勝トーナメントの
  /// k回戦(1から)の第l戦(0から)は「グループの節の数 + (k-1)×2 + l」。
  /// 1試合制の決勝は第0戦。消化する試合が残っていなければ null。
  static int? currentStep(ContinentalCup cup) {
    final groupRounds = cup.groupMatches.isEmpty
        ? 0
        : cup.groupMatches.map((m) => m.round).reduce(max);
    if (!cup.isGroupStageComplete) {
      final m = nextGroupMatch(cup);
      return m == null ? null : m.round - 1;
    }
    if (cup.knockoutRounds.isEmpty) return null;
    final open = cup.knockoutRounds.last.where((t) => !t.isComplete).toList();
    if (open.isEmpty) return null;
    final leg = open.map((t) => t.legs.length).reduce(min);
    return groupRounds + (cup.knockoutRounds.length - 1) * 2 + leg;
  }

  /// いまの段階を消化できるようになる節(決まっていなければ null)。
  static int? currentStepDue(ContinentalCup cup) {
    final due = cup.stepDue;
    final step = currentStep(cup);
    if (due == null || due.isEmpty || step == null) return null;
    return due[step.clamp(0, due.length - 1)];
  }

  /// グループ[groupCount]組(各[groupSize]クラブ、ホームとアウェイの総当たり)
  /// の大会の段階の数。
  static int stepCountFor(int groupCount) {
    var knockoutRounds = 0;
    for (var n = groupCount * 2; n > 1; n ~/= 2) {
      knockoutRounds++;
    }
    return (groupSize - 1) * 2 + (knockoutRounds - 1) * 2 + 1;
  }

  /// いまの段階のうち、[userTeamId]の出ない試合を裏の試合(他の部の試合と
  /// 同じ軽い計算)でまとめて決める。グループの節は全組の試合を、決勝
  /// トーナメントは全カードのその回の試合を同じ週に行う。
  static void playCpuStep(
      ContinentalCup cup, List<Team> allTeams, String userTeamId) {
    bool mine(String a, String b) => a == userTeamId || b == userTeamId;
    if (!cup.isGroupStageComplete) {
      final round = nextGroupMatch(cup)?.round;
      if (round == null) return;
      for (final m in [...cup.groupMatches]) {
        if (m.round != round || m.result != null) continue;
        if (mine(m.homeTeamId, m.awayTeamId)) continue;
        final home = _find(allTeams, m.homeTeamId);
        final away = _find(allTeams, m.awayTeamId);
        if (home == null || away == null) continue;
        applyGroupMatchResult(
          cup,
          allTeams,
          m,
          BackgroundMatchEngine.simulate(
              home: home, away: away, matchday: m.round),
        );
      }
      return;
    }
    if (cup.knockoutRounds.isEmpty) return;
    final round = cup.knockoutRounds.last;
    final open = round.where((t) => !t.isComplete).toList();
    if (open.isEmpty) return;
    final leg = open.map((t) => t.legs.length).reduce(min);
    for (final tie in open) {
      if (tie.legs.length != leg) continue;
      if (mine(tie.teamAId, tie.teamBId)) continue;
      final firstLeg = tie.singleLeg || tie.legs.isEmpty;
      final home = _find(allTeams, firstLeg ? tie.teamAId : tie.teamBId);
      final away = _find(allTeams, firstLeg ? tie.teamBId : tie.teamAId);
      if (home == null || away == null) continue;
      // 1試合制の決勝は中立の会場。
      applyKnockoutLegResult(
        cup,
        allTeams,
        tie,
        BackgroundMatchEngine.simulate(
            home: home, away: away, matchday: 0, neutral: tie.singleLeg),
      );
    }
  }

  static Team? _find(List<Team> teams, String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// [teamId]の試合を、同じ節(段階)の中で先頭にする(自クラブの試合を
  /// 「次の試合」にするため)。
  static void putTeamFirst(ContinentalCup cup, String teamId) {
    bool mine(String a, String b) => a == teamId || b == teamId;
    final ms = cup.groupMatches;
    final rounds = ms.map((m) => m.round).toSet().toList()..sort();
    final ordered = <CupMatch>[
      for (final r in rounds) ...[
        ...ms.where((m) => m.round == r && mine(m.homeTeamId, m.awayTeamId)),
        ...ms.where((m) => m.round == r && !mine(m.homeTeamId, m.awayTeamId)),
      ],
    ];
    ms
      ..clear()
      ..addAll(ordered);
    for (final round in cup.knockoutRounds) {
      final i = round.indexWhere((t) => mine(t.teamAId, t.teamBId));
      if (i > 0) round.insert(0, round.removeAt(i));
    }
  }

  /// 総当たり(circle method)。組の人数が奇数の場合は不戦(BYE)枠を
  /// 挟んで偶数扱いにし、BYEが絡む組み合わせだけ除外する
  /// (FixtureGenerator.generateDoubleRoundRobinと同じ考え方)。
  static List<CupMatch> _groupRoundRobin(List<String> teamIds) {
    final ids = List<String>.from(teamIds);
    final hasBye = ids.length.isOdd;
    if (hasBye) ids.add(byeTeamId);

    final n = ids.length;
    final arr = List<String>.from(ids);
    final rounds = n - 1;
    final half = n ~/ 2;
    final matches = <CupMatch>[];
    for (int r = 0; r < rounds; r++) {
      for (int i = 0; i < half; i++) {
        final home = arr[i];
        final away = arr[n - 1 - i];
        if (home == byeTeamId || away == byeTeamId) continue;
        matches.add(CupMatch(round: r + 1, homeTeamId: home, awayTeamId: away));
      }
      final last = arr.removeLast();
      arr.insert(1, last);
    }
    return matches;
  }

  /// 指定した組の順位表(勝点順。並んだ場合は直接対決優先)。
  static List<StandingRow> groupStandings(
    ContinentalCup cup,
    int groupIndex,
    List<Team> allTeams,
  ) {
    final ids = cup.groups[groupIndex].toSet();
    final groupTeams = allTeams.where((t) => ids.contains(t.id)).toList();
    final fixtures = cup.groupMatches
        .where((m) => ids.contains(m.homeTeamId) && ids.contains(m.awayTeamId))
        .map(
          (m) => Fixture(
            matchday: m.round,
            homeTeamId: m.homeTeamId,
            awayTeamId: m.awayTeamId,
            result: m.result,
          ),
        )
        .toList();
    return League(teams: groupTeams, fixtures: fixtures).sortedStandings;
  }

  /// グループステージの次の未消化試合(全組を通じて先頭のもの)。
  static CupMatch? nextGroupMatch(ContinentalCup cup) {
    for (final m in cup.groupMatches) {
      if (m.result == null) return m;
    }
    return null;
  }

  /// グループステージの次の1試合を消化する。全試合が終わると自動的に
  /// 決勝トーナメントの組み合わせが決定される。
  /// [month]は試合の日の月。天候をその季節のものにする。
  static MatchResult? playNextGroupMatch(
    ContinentalCup cup,
    List<Team> allTeams, {
    int? month,
  }) {
    final match = nextGroupMatch(cup);
    if (match == null) return null;
    final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
    final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: match.round,
      weather: WeatherEngine.roll(month: month),
    );
    applyGroupMatchResult(cup, allTeams, match, result);
    return result;
  }

  /// 外部(ライブ観戦)で確定した[result]をグループステージの[match]に
  /// 適用する。全組の試合が終わっていれば決勝トーナメントを組む。
  static void applyGroupMatchResult(
    ContinentalCup cup,
    List<Team> allTeams,
    CupMatch match,
    MatchResult result,
  ) {
    match.result = result;
    if (cup.isGroupStageComplete) {
      _startKnockout(cup, allTeams);
    }
  }

  /// 各組の上位2チームから決勝トーナメント(準決勝)を組む。同組同士が
  /// 準決勝で当たらないよう、他組の2位とクロスで組み合わせる。
  static void _startKnockout(ContinentalCup cup, List<Team> allTeams) {
    if (cup.knockoutRounds.isNotEmpty) return;
    final qualifiers = <List<String>>[];
    for (int g = 0; g < cup.groups.length; g++) {
      final standings = groupStandings(cup, g, allTeams);
      qualifiers.add(standings.take(2).map((r) => r.teamId).toList());
    }
    if (qualifiers.length < 2) return;
    // 各組の1位を、隣の組(添字+1、末尾は先頭へ循環)の2位とクロスで
    // 組み合わせる。組数が2の場合は従来通りの組み合わせになる。
    final groupCount = qualifiers.length;
    final semis = <CupTie>[
      for (int g = 0; g < groupCount; g++)
        CupTie(
          round: 1,
          teamAId: qualifiers[g][0],
          teamBId: qualifiers[(g + 1) % groupCount][1],
        ),
    ];
    cup.knockoutRounds.add(semis);
  }

  /// 決勝トーナメントで次に行われるレグ(対象タイとホーム/アウェイの
  /// 割り当て)。2ndレグはホーム/アウェイを入れ替える。残っていなければnull。
  static ({CupTie tie, String homeId, String awayId})? nextKnockoutLeg(
    ContinentalCup cup,
  ) {
    if (cup.knockoutRounds.isEmpty) return null;
    for (final tie in cup.knockoutRounds.last) {
      if (tie.isComplete) continue;
      final isFirstLeg = tie.legs.isEmpty;
      final homeId = (tie.singleLeg || isFirstLeg) ? tie.teamAId : tie.teamBId;
      final awayId = (tie.singleLeg || isFirstLeg) ? tie.teamBId : tie.teamAId;
      return (tie: tie, homeId: homeId, awayId: awayId);
    }
    return null;
  }

  /// 決勝トーナメントの次の未消化レグを1試合消化する(2ndレグはホーム/
  /// アウェイを入れ替える)。合計スコアが同点の場合はPK戦で決着する。
  /// [month]は試合の日の月。天候をその季節のものにする。1試合制の決勝は
  /// 中立の会場(ホームの利が無い)。
  static MatchResult? playNextKnockoutLeg(
    ContinentalCup cup,
    List<Team> allTeams, {
    int? month,
  }) {
    final leg = nextKnockoutLeg(cup);
    if (leg == null) return null;
    final home = allTeams.firstWhere((t) => t.id == leg.homeId);
    final away = allTeams.firstWhere((t) => t.id == leg.awayId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: 0,
      weather: WeatherEngine.roll(month: month),
      homeAdvantageFactor: leg.tie.singleLeg
          ? MatchEngine.neutralHomeAdvantageFactor
          : MatchEngine.defaultHomeAdvantageFactor,
    );
    applyKnockoutLegResult(cup, allTeams, leg.tie, result);
    // 延長戦の得点を含めた結果を返す(延長の得点は applyKnockoutLegResult
    // が選手の通算得点に数える)。
    return leg.tie.legs.last;
  }

  /// 外部(ライブ観戦)で確定した[result]を決勝トーナメントの[tie]に
  /// レグとして適用する。タイが完了して合計スコア同点ならPK戦で決着し、
  /// ラウンドが完了していれば次ラウンドを組む。
  static void applyKnockoutLegResult(
    ContinentalCup cup,
    List<Team> allTeams,
    CupTie tie,
    MatchResult result,
  ) {
    tie.legs.add(result);
    if (tie.isComplete &&
        tie.goalsFor(tie.teamAId) == tie.goalsFor(tie.teamBId)) {
      final home = allTeams.firstWhere((t) => t.id == result.homeTeamId);
      final away = allTeams.firstWhere((t) => t.id == result.awayTeamId);
      // 合計で並べば、最後の試合を延長戦(30分)まで戦う(アウェイゴールは
      // 数えない。実在の大会の今の形)。ライブ観戦側で延長を済ませて
      // いれば([CupTie.extraTime])、もう一度は行わない。
      if (!tie.extraTime && tie.penaltyWinnerId == null) {
        tie.legs[tie.legs.length - 1] = CupEngine.extraTime(result, home, away);
        tie.extraTime = true;
        // 延長の得点を選手の通算得点に数える(90分までは試合後の共通処理)。
        CupEngine.creditExtraTimeGoals(result, tie.legs.last, [home, away]);
      }
      if (tie.goalsFor(tie.teamAId) == tie.goalsFor(tie.teamBId)) {
        // ライブ観戦側で1本ずつのPK戦を先に実施済みの場合はその勝者を尊重する。
        tie.penaltyWinnerId ??= CupEngine.decidePenaltyWinner(home, away,
            result: tie.legs.last);
      }
    }
    _advanceKnockoutIfRoundComplete(cup);
  }

  static void _advanceKnockoutIfRoundComplete(ContinentalCup cup) {
    final round = cup.knockoutRounds.last;
    if (round.any((t) => !t.isComplete)) return;
    if (round.length == 1) return;
    final winners = round.map((t) => t.winnerId!).toList();
    final nextRound = <CupTie>[];
    final isFinalNext = winners.length == 2;
    for (int i = 0; i < winners.length; i += 2) {
      nextRound.add(
        CupTie(
          round: round.first.round + 1,
          teamAId: winners[i],
          teamBId: winners[i + 1],
          singleLeg: isFinalNext,
        ),
      );
    }
    cup.knockoutRounds.add(nextRound);
  }

  /// ラウンド数に応じたラウンド名(準決勝・決勝など)。
  static String roundLabel(int round, int totalRounds) {
    final fromFinal = totalRounds - round;
    return switch (fromFinal) {
      0 => Tr.pick('決勝', 'Final'),
      1 => Tr.pick('準決勝', 'Semi-final'),
      2 => Tr.pick('準々決勝', 'Quarter-final'),
      _ => Tr.pick('第$round回戦', 'Round $round'),
    };
  }
}
