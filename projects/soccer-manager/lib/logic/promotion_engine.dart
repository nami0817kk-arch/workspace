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

  /// 昇格プレーオフの1試合を決着させる(引き分けの場合はPK戦)。
  static PromotionPlayoffMatch _playSingleMatch({
    required String roundLabel,
    required Team home,
    required Team away,
  }) {
    final result = MatchEngine.simulate(home: home, away: away, matchday: 0);
    final decidedByPenalties = result.homeGoals == result.awayGoals;
    final winnerId = result.homeGoals > result.awayGoals
        ? home.id
        : result.homeGoals < result.awayGoals
            ? away.id
            : CupEngine.decidePenaltyWinner(home, away);
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

  /// [tier1Teams]/[tier2Teams]は今シーズンの各ディビジョンの全チーム。実際に
  /// プレイされた側は[tier1PlayedOrder]/[tier2PlayedOrder]に最終順位順のチーム
  /// リストを渡す(片方のみ非null)。渡されなかった側はその場でシミュレートする。
  ///
  /// 入れ替えの数は[rules]で国ごとに変わる。既定は、上位2チームが自動昇格し、
  /// 続く4チームが昇格プレーオフ(準決勝2試合+決勝、引き分けはPK戦)を行う形。
  /// 入れ替え戦のある国では、上の部の降格圏のすぐ上と、下の部の自動昇格の
  /// すぐ下が1試合を戦い、勝った方が上の部に入る。
  static PromotionResult resolve({
    required List<Team> tier1Teams,
    required List<Team> tier2Teams,
    List<Team>? tier1PlayedOrder,
    List<Team>? tier2PlayedOrder,
    PromotionRules rules = PromotionRules.standard,
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

      final semiA = _playSingleMatch(
        roundLabel: Tr.pick('昇格プレーオフ 準決勝', 'Play-off semi-final'),
        home: pool[0],
        away: pool[3],
      );
      final semiB = _playSingleMatch(
        roundLabel: Tr.pick('昇格プレーオフ 準決勝', 'Play-off semi-final'),
        home: pool[1],
        away: pool[2],
      );
      // 決勝のホームは、順位が上だった側。準決勝は上位がホーム
      // (1位vs4位 / 2位vs3位)なので、決勝だけ順位が効かないのは筋が通らない。
      final winnerA = pool.firstWhere((t) => t.id == semiA.winnerId);
      final winnerB = pool.firstWhere((t) => t.id == semiB.winnerId);
      final finalHome =
          pool.indexOf(winnerA) <= pool.indexOf(winnerB) ? winnerA : winnerB;
      final finalAway = identical(finalHome, winnerA) ? winnerB : winnerA;
      final finalMatch = _playSingleMatch(
        roundLabel: Tr.pick('昇格プレーオフ 決勝', 'Play-off final'),
        home: finalHome,
        away: finalAway,
      );
      playoffMatches = [semiA, semiB, finalMatch];

      final playoffWinner = orderedTier2.firstWhere(
        (t) => t.id == finalMatch.winnerId,
      );
      promoted = [...autoPromoted, playoffWinner];
    } else {
      promoted = orderedTier2.take(rules.autoUp).toList();
    }

    // 入れ替え戦: 上の部で降格圏のすぐ上のクラブ(ホーム)と、下の部で
    // 昇格の枠のすぐ下のクラブ。下の部が勝てば入れ替わる。
    if (rules.relegationPlayoff &&
        remainingTier1.isNotEmpty &&
        orderedTier2.length > promoted.length) {
      final upperSide = remainingTier1.last;
      final lowerSide = orderedTier2
          .firstWhere((t) => !promoted.any((p) => p.id == t.id));
      final match = _playSingleMatch(
        roundLabel: Tr.pick('入れ替え戦', 'Relegation play-off'),
        home: upperSide,
        away: lowerSide,
      );
      playoffMatches = [...playoffMatches, match];
      if (match.winnerId == lowerSide.id) {
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
