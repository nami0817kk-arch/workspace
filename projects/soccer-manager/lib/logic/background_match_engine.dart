import 'dart:math';

import '../models/attributes.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'match_engine.dart';

/// 画面に表示されないバックグラウンドの試合(裏側のディビジョン等)向けの
/// 軽量なスコア推定シミュレーション。MatchEngine.simulateは分単位で選手ごとの
/// プレーを再現するため負荷が高く、大量の試合をまとめて消化する用途には
/// 不向き(節を進めるたびに体感速度が低下する原因になっていた)。
/// ここではチーム総合力からポアソン分布で得点数を推定するだけに留め、
/// 個々の選手の得点・怪我・成長は扱わない。
///
/// 警告・退場・交代だけは[applyPlayerEffects]で簡単に入れる(2026-11-22)。
/// 以前は他の部・他国のリーグの選手に警告が付かず、出場停止にもならな
/// かった(累積の警告も出場数も増えなかった)。結果([MatchResult.events])
/// には入れない(全部の試合の結果がセーブに残るので、重くしない)。
class BackgroundMatchEngine {
  static final Random _rng = Random();

  /// 1試合の警告の平均(両チームの合計)。欧州の主要リーグは1試合に
  /// 3.5〜5枚ほど。
  static const double yellowsPerMatch = 4.2;

  /// 1試合の退場の平均(両チームの合計)。主要リーグで 0.1〜0.2。
  static const double redsPerMatch = 0.15;

  /// 1チームが後半に入れる控えの人数(この値〜+2)。交代は5人まで使えるが、
  /// 実際は1試合に3〜5人ほど。
  static const int minSubsPerTeam = 3;

  /// 他の部・他国の試合の、選手への影響(出場停止の消化・出場の数・警告と
  /// 退場・後半から出た控えの出場)を入れる。[MatchEngine]の試合と同じ
  /// 決まり(警告[yellowCardSuspensionThreshold]枚・退場で1試合の出場停止)。
  ///
  /// 警告の数は1試合ごとにポアソン分布でくじ引きし、先発に割り当てる
  /// (積極性の高い選手ほど当たりやすい。GK はまれ)。交代は、出られる控えの
  /// 上から[minSubsPerTeam]〜+2人に出場を1つ足すだけ(後半からの出場)。
  static void applyPlayerEffects({
    required Team home,
    required Team away,
    Random? random,
  }) {
    final rng = random ?? _rng;
    for (final team in [home, away]) {
      if (team.players.isEmpty) continue;
      final lineup = MatchEngine.lineupOf(team);
      final lineupIds = {for (final p in lineup) p.id};
      // 前の試合までに受けた出場停止を1試合ぶん消化する(この試合に出て
      // いない選手だけ。MatchEngine と同じ)。
      for (final p in team.players) {
        if (p.suspendedMatches > 0 && !lineupIds.contains(p.id)) {
          p.suspendedMatches -= 1;
        }
      }
      for (final p in lineup) {
        p.careerAppearances += 1;
      }
      // 後半から出る控え(出られる選手の、力の高い順)。
      final bench = team.players
          .where((p) =>
              !lineupIds.contains(p.id) &&
              !p.isInjured &&
              !p.isSuspended &&
              !p.isOnInternationalDuty &&
              !p.isLoanedOut &&
              !p.notRegistered &&
              p.position != Position.gk)
          .toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      final subs = minSubsPerTeam + rng.nextInt(3);
      for (final p in bench.take(subs)) {
        p.careerAppearances += 1;
      }
      // 警告・退場。警告は別々の選手に1枚ずつ(同じ選手に2枚当てると
      // 2枚目の退場が実際の何倍にもなる)。退場(一発・2枚目)は
      // [redsPerMatch]で別にくじ引きする。
      final yellows = _poisson(yellowsPerMatch / 2, rng);
      final reds = rng.nextDouble() < redsPerMatch / 2 ? 1 : 0;
      final booked = <String>{};
      for (var i = 0; i < yellows + reds; i++) {
        final p = _pickCarded(lineup, rng, exclude: booked);
        if (p == null) break;
        booked.add(p.id);
        if (i >= yellows) {
          p.suspendedMatches += 1;
          continue;
        }
        p.yellowCards += 1;
        if (p.yellowCards >= yellowCardSuspensionThreshold) {
          p.yellowCards = 0;
          p.suspendedMatches += 1;
        }
      }
    }
  }

  /// 警告を受ける選手を選ぶ。積極性の高い選手ほど当たりやすく、GK はまれ。
  /// [exclude]の選手(この試合でもう警告・退場を受けた)は選ばない。
  static Player? _pickCarded(List<Player> lineup, Random rng,
      {Set<String> exclude = const {}}) {
    final pool = [
      for (final p in lineup)
        if (!exclude.contains(p.id)) p,
    ];
    if (pool.isEmpty) return null;
    double weightOf(Player p) =>
        (p.position == Position.gk ? 0.1 : 1.0) *
        (0.5 + p.attributeValue(AttributeKeys.aggression) / 100);
    final total = pool.fold<double>(0, (s, p) => s + weightOf(p));
    var r = rng.nextDouble() * total;
    for (final p in pool) {
      r -= weightOf(p);
      if (r <= 0) return p;
    }
    return pool.last;
  }

  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    Random? random,
  }) {
    final rng = random ?? _rng;
    final ratingDiff = (home.overallRating - away.overallRating).toDouble();
    final homeExpected = (1.35 + ratingDiff / 90 + 0.25).clamp(0.3, 3.6);
    final awayExpected = (1.15 - ratingDiff / 90).clamp(0.2, 3.3);
    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: _poisson(homeExpected, rng),
      awayGoals: _poisson(awayExpected, rng),
      events: const [],
    );
  }

  /// Knuthのアルゴリズムによるポアソン分布サンプリング。
  static int _poisson(double lambda, Random rng) {
    final l = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rng.nextDouble();
    } while (p > l);
    return k - 1;
  }
}
