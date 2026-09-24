import '../models/league.dart';
import '../l10n/tr.dart';

/// 理事会の順位目標に対して、いまどこにいるか。
class BoardTargetProgress {
  /// 現在の順位。
  final int rank;

  /// 目標順位(この順位以内)。
  final int targetRank;

  /// 目標順位のクラブとの勝点差。目標圏内なら、下から追ってくるクラブとの差。
  final int pointsGap;

  /// 残り節数。
  final int matchdaysLeft;

  /// 目標圏内にいるか。
  final bool onTrack;

  const BoardTargetProgress({
    required this.rank,
    required this.targetRank,
    required this.pointsGap,
    required this.matchdaysLeft,
    required this.onTrack,
  });

  /// 1行で出す文面。
  ///
  /// 目標だけを出していても、いま届いているのかが分からない。順位と勝点差を
  /// 添えて、「あと何が要るか」を言えるようにする。
  String get label {
    if (matchdaysLeft <= 0) {
      return onTrack
          ? Tr.pick('目標達成。$rank位で終えました。',
              'Target met. You finished $rank.')
          : Tr.pick('目標未達。$rank位で終えました。',
              'Target missed. You finished $rank.');
    }
    if (onTrack) {
      return Tr.pick(
          '現在$rank位。目標圏内(下位クラブとの差 $pointsGap点 / 残り$matchdaysLeft節)',
          'Currently $rank, inside the target ($pointsGap pts clear, $matchdaysLeft to play)');
    }
    return Tr.pick(
        '現在$rank位。目標$targetRank位まで勝点$pointsGap差(残り$matchdaysLeft節)',
        'Currently $rank. $pointsGap pts from $targetRank ($matchdaysLeft to play)');
  }

  /// 追う側か追われる側かに関係なく、差が縮まっているほど緊張が高い。
  /// 画面の色分けに使う。
  bool get tight => pointsGap <= 3;
}

/// 順位表と目標から、進捗を組み立てる。
class BoardTargetProgressEngine {
  const BoardTargetProgressEngine._();

  static BoardTargetProgress? evaluate({
    required League league,
    required String userTeamId,
    required int targetRank,
    required int matchdaysLeft,
  }) {
    final standings = league.sortedStandings;
    final index = standings.indexWhere((r) => r.teamId == userTeamId);
    if (index < 0) return null;
    final rank = index + 1;
    final onTrack = rank <= targetRank;

    // 目標圏内なら「落ちたら困る相手」= 目標順位のすぐ下との差。
    // 圏外なら「追いつく相手」= 目標順位のクラブとの差。
    final int comparedIndex;
    if (onTrack) {
      comparedIndex = targetRank < standings.length ? targetRank : index;
    } else {
      comparedIndex = targetRank - 1;
    }
    final mine = standings[index].points;
    final theirs = standings[comparedIndex.clamp(0, standings.length - 1)].points;

    return BoardTargetProgress(
      rank: rank,
      targetRank: targetRank,
      pointsGap: (mine - theirs).abs(),
      matchdaysLeft: matchdaysLeft,
      onTrack: onTrack,
    );
  }
}
