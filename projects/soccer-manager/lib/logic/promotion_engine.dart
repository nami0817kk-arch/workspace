import '../models/league.dart';
import '../models/league_theme.dart';
import '../models/team.dart';
import 'background_match_engine.dart';
import 'cup_engine.dart';
import 'fixture_generator.dart';
import 'match_engine.dart';
import '../l10n/tr.dart';

/// 昇格プレーオフの1試合(準決勝または決勝)の結果。
class PromotionPlayoffMatch {
  final String roundLabel;
  final String homeId;
  final String homeName;
  final String awayId;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final bool decidedByPenalties;
  final String winnerId;

  const PromotionPlayoffMatch({
    required this.roundLabel,
    required this.homeId,
    required this.homeName,
    required this.awayId,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.decidedByPenalties,
    required this.winnerId,
  });

  String get winnerName => winnerId == homeId ? homeName : awayName;
}

/// シーズン終了時の昇格・降格を解決した結果。
class PromotionResult {
  final List<Team> tier1;
  final List<Team> tier2;
  final List<String> promotedTeamNames;
  final List<String> relegatedTeamNames;

  /// 昇格プレーオフが行われた場合の各試合結果(準決勝2試合+決勝の順)。
  /// プレーオフが発生しなかった場合(下部リーグの参加数が少ない場合など)は空。
  final List<PromotionPlayoffMatch> promotionPlayoff;

  const PromotionResult({
    required this.tier1,
    required this.tier2,
    required this.promotedTeamNames,
    required this.relegatedTeamNames,
    this.promotionPlayoff = const [],
  });
}

/// 1部・2部の入れ替え(昇格/降格)を解決する。
///
/// ユーザーが所属しない側のディビジョンは週次で試合を進行させないため、シーズン
/// 終了時にその場で1シーズン分をまとめてシミュレートし、最終順位を確定する。
class PromotionEngine {
  static const int swapCount = 3;

  /// 2部の最終順位のうち、自動昇格となる上位チーム数。
  static const int automaticPromotionCount = 2;

  /// 昇格プレーオフに進出するチーム数(3位〜(2+playoffPoolSize)位)。
  static const int playoffPoolSize = 4;

  /// [teams]で1シーズン分(ホーム&アウェイ総当たり)を即座にシミュレートし、
  /// 最終順位順に並べ替えて返す。呼び出し側([tier1PlayedOrder]/
  /// [tier2PlayedOrder]が渡されない場合のフォールバック)でしか使わないため、
  /// 大量の試合を一括処理してもUIが固まらないよう軽量エンジンを使う。
  static List<Team> _simulateSeason(List<Team> teams) {
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    for (final f in fixtures) {
      final home = teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = teams.firstWhere((t) => t.id == f.awayTeamId);
      f.result = BackgroundMatchEngine.simulate(
        home: home,
        away: away,
        matchday: f.matchday,
      );
    }
    final standings = League(teams: teams, fixtures: fixtures).sortedStandings;
    return standings
        .map((row) => teams.firstWhere((t) => t.id == row.teamId))
        .toList();
  }

  /// 昇格プレーオフの1試合を決着させる。引き分けは、[extraTime]なら延長戦
  /// (30分)を行い、それでも並べば[drawWinner](順位が上のクラブ。いなければ
  /// PK戦)。
  static PromotionPlayoffMatch _playSingleMatch({
    required String roundLabel,
    required Team home,
    required Team away,
    bool extraTime = false,
    Team? drawWinner,
  }) {
    var result = MatchEngine.simulate(home: home, away: away, matchday: 0);
    if (extraTime && result.homeGoals == result.awayGoals) {
      result = CupEngine.extraTime(result, home, away);
    }
    final level = result.homeGoals == result.awayGoals;
    final decidedByPenalties = level && drawWinner == null;
    final winnerId = result.homeGoals > result.awayGoals
        ? home.id
        : result.homeGoals < result.awayGoals
            ? away.id
            : (drawWinner?.id ?? CupEngine.decidePenaltyWinner(home, away));
    return PromotionPlayoffMatch(
      roundLabel: roundLabel,
      homeId: home.id,
      homeName: home.name,
      awayId: away.id,
      awayName: away.name,
      homeGoals: result.homeGoals,
      awayGoals: result.awayGoals,
      decidedByPenalties: decidedByPenalties,
      winnerId: winnerId,
    );
  }

  /// 2試合合計の対戦。第1戦は[lower](順位が下)のホーム、第2戦は[higher]の
  /// ホーム。合計で並べば、[higherSeedOnTie]なら[higher]が勝ち上がり、
  /// そうでなければ第2戦を延長戦まで戦い、それでも並べばPK戦。
  /// 2試合の記録(どちらも winnerId は勝ち上がったクラブ)と勝者を返す。
  static (List<PromotionPlayoffMatch>, Team) _playTwoLegs({
    required String roundLabel,
    required Team higher,
    required Team lower,
    required bool higherSeedOnTie,
  }) {
    final leg1 = MatchEngine.simulate(home: lower, away: higher, matchday: 0);
    var leg2 = MatchEngine.simulate(home: higher, away: lower, matchday: 0);
    int aggHigher() => leg1.awayGoals + leg2.homeGoals;
    int aggLower() => leg1.homeGoals + leg2.awayGoals;
    var pens = false;
    Team winner;
    if (aggHigher() == aggLower() && !higherSeedOnTie) {
      leg2 = CupEngine.extraTime(leg2, higher, lower);
    }
    if (aggHigher() > aggLower()) {
      winner = higher;
    } else if (aggHigher() < aggLower()) {
      winner = lower;
    } else if (higherSeedOnTie) {
      winner = higher;
    } else {
      pens = true;
      winner = CupEngine.decidePenaltyWinner(higher, lower) == higher.id
          ? higher
          : lower;
    }
    final aggLabel = Tr.pick(
        '(合計 ${higher.name} ${aggHigher()}-${aggLower()} ${lower.name})',
        ' (aggregate ${higher.name} ${aggHigher()}-${aggLower()} ${lower.name})');
    return (
      [
        PromotionPlayoffMatch(
          roundLabel: Tr.pick('$roundLabel 第1戦', '$roundLabel, 1st leg'),
          homeId: lower.id,
          homeName: lower.name,
          awayId: higher.id,
          awayName: higher.name,
          homeGoals: leg1.homeGoals,
          awayGoals: leg1.awayGoals,
          decidedByPenalties: false,
          winnerId: winner.id,
        ),
        PromotionPlayoffMatch(
          roundLabel: Tr.pick(
              '$roundLabel 第2戦$aggLabel', '$roundLabel, 2nd leg$aggLabel'),
          homeId: higher.id,
          homeName: higher.name,
          awayId: lower.id,
          awayName: lower.name,
          homeGoals: leg2.homeGoals,
          awayGoals: leg2.awayGoals,
          decidedByPenalties: pens,
          winnerId: winner.id,
        ),
      ],
      winner,
    );
  }

  /// 昇格プレーオフ([pool]は順位の順)を国の形で行い、試合の記録と
  /// 勝ち上がったクラブを返す。[points]は下の部の勝ち点(差でプレーオフを
  /// 行わない決まりに使う)。
  static (List<PromotionPlayoffMatch>, Team) _runPlayoff(
    List<Team> pool,
    PromotionRules rules,
    Map<String, int>? points,
  ) {
    final semiLabel = Tr.pick('昇格プレーオフ 準決勝', 'Play-off semi-final');
    final finalLabel = Tr.pick('昇格プレーオフ 決勝', 'Play-off final');
    // 最上位が次のクラブを大きく離していれば、プレーオフを行わない。
    if (rules.playoffSkipGap > 0 && points != null && pool.length >= 2) {
      final a = points[pool[0].id];
      final b = points[pool[1].id];
      if (a != null && b != null && a - b >= rules.playoffSkipGap) {
        return (const <PromotionPlayoffMatch>[], pool[0]);
      }
    }
    int seed(Team t) => pool.indexOf(t);
    final matches = <PromotionPlayoffMatch>[];
    var semiPool = pool;
    if (pool.length >= 6) {
      // 予備の回戦: 5位対8位・6位対7位(順位が上のホーム、1試合。並べば
      // 延長戦、それでも並べば順位が上)。
      final prelimLabel =
          Tr.pick('昇格プレーオフ 1回戦', 'Play-off preliminary round');
      final p1 = _playSingleMatch(
          roundLabel: prelimLabel,
          home: pool[2],
          away: pool[5],
          extraTime: true,
          drawWinner: pool[2]);
      final p2 = _playSingleMatch(
          roundLabel: prelimLabel,
          home: pool[3],
          away: pool[4],
          extraTime: true,
          drawWinner: pool[3]);
      matches.addAll([p1, p2]);
      final w1 = pool.firstWhere((t) => t.id == p1.winnerId);
      final w2 = pool.firstWhere((t) => t.id == p2.winnerId);
      semiPool = [
        pool[0],
        pool[1],
        ...([w1, w2]..sort((a, b) => seed(a) - seed(b)))
      ];
    }
    // 準決勝: 1番手対4番手、2番手対3番手。
    final pairs = [
      (semiPool[0], semiPool[3]),
      (semiPool[1], semiPool[2]),
    ];
    final winners = <Team>[];
    for (final (hi, lo) in pairs) {
      switch (rules.playoffFormat) {
        case PlayoffFormat.singleMatches:
          final m = _playSingleMatch(roundLabel: semiLabel, home: hi, away: lo);
          matches.add(m);
          winners.add(m.winnerId == hi.id ? hi : lo);
        case PlayoffFormat.englishTwoLegSemis:
        case PlayoffFormat.twoLegsHigherSeed:
          final (ms, w) = _playTwoLegs(
            roundLabel: semiLabel,
            higher: hi,
            lower: lo,
            higherSeedOnTie:
                rules.playoffFormat == PlayoffFormat.twoLegsHigherSeed,
          );
          matches.addAll(ms);
          winners.add(w);
      }
    }
    // 決勝。順位が上だった側を上位(ホーム)にする。
    winners.sort((a, b) => seed(a) - seed(b));
    final hi = winners[0];
    final lo = winners[1];
    switch (rules.playoffFormat) {
      case PlayoffFormat.singleMatches:
        final m = _playSingleMatch(roundLabel: finalLabel, home: hi, away: lo);
        matches.add(m);
        return (matches, m.winnerId == hi.id ? hi : lo);
      case PlayoffFormat.englishTwoLegSemis:
        // 決勝は1試合。並べば延長戦、それでも並べばPK戦。
        final m = _playSingleMatch(
            roundLabel: finalLabel, home: hi, away: lo, extraTime: true);
        matches.add(m);
        return (matches, m.winnerId == hi.id ? hi : lo);
      case PlayoffFormat.twoLegsHigherSeed:
        final (ms, w) = _playTwoLegs(
            roundLabel: finalLabel,
            higher: hi,
            lower: lo,
            higherSeedOnTie: true);
        matches.addAll(ms);
        return (matches, w);
    }
  }

  /// [tier1Teams]/[tier2Teams]は今シーズンの各ディビジョンの全チーム。実際に
  /// プレイされた側は[tier1PlayedOrder]/[tier2PlayedOrder]に最終順位順のチーム
  /// リストを渡す(片方のみ非null)。渡されなかった側はその場でシミュレートする。
  ///
  /// 入れ替えの数と試合の形は[rules]で国ごとに変わる。既定は、上位2チームが
  /// 自動昇格し、続く4チームが昇格プレーオフ(準決勝2試合+決勝、引き分けは
  /// PK戦)を行う形。入れ替え戦のある国では、上の部の降格圏のすぐ上と、
  /// 下の部の自動昇格のすぐ下が戦い、勝った方が上の部に入る。
  /// [tier2Points]は下の部の勝ち点(プレーオフを行わない決まりに使う)。
  static PromotionResult resolve({
    required List<Team> tier1Teams,
    required List<Team> tier2Teams,
    List<Team>? tier1PlayedOrder,
    List<Team>? tier2PlayedOrder,
    PromotionRules rules = PromotionRules.standard,
    Map<String, int>? tier2Points,
  }) {
    final orderedTier1 = tier1PlayedOrder ?? _simulateSeason(tier1Teams);
    final orderedTier2 = tier2PlayedOrder ?? _simulateSeason(tier2Teams);

    final down = rules.autoDown.clamp(0, orderedTier1.length);
    final relegated = orderedTier1.sublist(orderedTier1.length - down);
    var remainingTier1 = orderedTier1.take(orderedTier1.length - down).toList();

    var promoted = <Team>[];
    var tier2Remainder = <Team>[];
    var playoffMatches = <PromotionPlayoffMatch>[];
    final extraRelegated = <Team>[];

    final usePlayoff = rules.playoffPool >= 4 &&
        orderedTier2.length >= rules.autoUp + rules.playoffPool;
    if (usePlayoff) {
      final autoPromoted = orderedTier2.take(rules.autoUp).toList();
      final pool =
          orderedTier2.skip(rules.autoUp).take(rules.playoffPool).toList();
      final (matches, playoffWinner) = _runPlayoff(pool, rules, tier2Points);
      playoffMatches = matches;
      promoted = [...autoPromoted, playoffWinner];
    } else {
      promoted = orderedTier2.take(rules.autoUp).toList();
    }

    // 入れ替え戦: 上の部で降格圏のすぐ上のクラブと、下の部で昇格の枠の
    // すぐ下のクラブ。下の部が勝てば入れ替わる。ドイツは2試合合計(第2戦は
    // 上の部のホーム。並べば延長・PK戦)、ほかは1試合(上の部のホーム)。
    if (rules.relegationPlayoff &&
        remainingTier1.isNotEmpty &&
        orderedTier2.length > promoted.length) {
      final upperSide = remainingTier1.last;
      final lowerSide = orderedTier2
          .firstWhere((t) => !promoted.any((p) => p.id == t.id));
      final label = Tr.pick('入れ替え戦', 'Relegation play-off');
      final String winnerId;
      if (rules.relegationPlayoffTwoLegs) {
        final (ms, w) = _playTwoLegs(
          roundLabel: label,
          higher: upperSide,
          lower: lowerSide,
          higherSeedOnTie: false,
        );
        playoffMatches = [...playoffMatches, ...ms];
        winnerId = w.id;
      } else {
        final match = _playSingleMatch(
          roundLabel: label,
          home: upperSide,
          away: lowerSide,
        );
        playoffMatches = [...playoffMatches, match];
        winnerId = match.winnerId;
      }
      if (winnerId == lowerSide.id) {
        promoted = [...promoted, lowerSide];
        remainingTier1 = remainingTier1.take(remainingTier1.length - 1).toList();
        extraRelegated.add(upperSide);
      }
    }

    tier2Remainder = orderedTier2
        .where((t) => !promoted.any((p) => p.id == t.id))
        .toList();
    final allRelegated = [...relegated, ...extraRelegated];

    final newTier1 = [...remainingTier1, ...promoted];
    final newTier2 = [...tier2Remainder, ...allRelegated];

    return PromotionResult(
      tier1: newTier1,
      tier2: newTier2,
      promotedTeamNames: promoted.map((t) => t.name).toList(),
      relegatedTeamNames: allRelegated.map((t) => t.name).toList(),
      promotionPlayoff: playoffMatches,
    );
  }

  /// 各部のクラブ数を[targetSizes](1部から順)に合わせる。昇降格の数が
  /// 上下で違う国や、国の形を変えた旧セーブで、部の大きさがずれたときに使う。
  ///
  /// 多すぎる部からは、いちばん弱いクラブを1つ下の部へ送る。少なすぎる部へは、
  /// 1つ下の部のいちばん強いクラブを上げる。最下部が足りないときは[create]で
  /// 新しく作り、余るときは外す。[protectedId]のクラブ(自クラブ)は動かさない。
  static Map<int, List<Team>> resize(
    Map<int, List<Team>> byTier,
    List<int> targetSizes, {
    required String protectedId,
    required Team Function(int tier, int index) create,
  }) {
    final out = {
      for (final e in byTier.entries) e.key: [...e.value],
    };
    final bottom = targetSizes.length;
    int strength(Team t) => t.players.isEmpty
        ? (t.retainedOverall ?? 50)
        : t.overallRating;
    for (var tier = 1; tier <= bottom; tier++) {
      final teams = out[tier] ??= [];
      final target = targetSizes[tier - 1];
      while (teams.length > target) {
        final movable = teams.where((t) => t.id != protectedId).toList()
          ..sort((a, b) => strength(a).compareTo(strength(b)));
        if (movable.isEmpty) break;
        final weakest = movable.first;
        teams.remove(weakest);
        if (tier < bottom) (out[tier + 1] ??= []).add(weakest);
      }
      var made = 0;
      while (teams.length < target) {
        final below = out[tier + 1];
        final movable = (below ?? const <Team>[])
            .where((t) => t.id != protectedId)
            .toList()
          ..sort((a, b) => strength(b).compareTo(strength(a)));
        if (tier < bottom && movable.isNotEmpty) {
          below!.remove(movable.first);
          teams.add(movable.first);
        } else {
          teams.add(create(tier, made++));
        }
      }
    }
    return out;
  }
}
