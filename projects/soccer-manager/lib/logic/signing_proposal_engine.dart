import '../l10n/tr.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 監督が挙げる補強の候補。オーナーは自分で市場を探さず、この候補を
/// 買う/見送るで決める。
class SigningProposal {
  const SigningProposal({required this.player, required this.reason});

  final Player player;

  /// なぜこの選手か。画面にそのまま出す一文。
  final String reason;
}

class SigningProposalEngine {
  const SigningProposalEngine._();

  /// 候補の数。
  static const int count = 3;

  /// 市場から、監督が挙げる候補を [maxCount] 人まで選ぶ。
  ///
  /// いまのチームで層がいちばん薄いポジションの大分類を見つけ、そこで
  /// 既存の主力より強い選手を、総合力の高い順に挙げる。資金を大きく
  /// 超える選手は出さない(買えない提案は決断にならない)。
  /// [passed] は、オーナーがすでに見送った選手のID。
  static List<SigningProposal> propose(
    Team team,
    List<Player> market, {
    required int budget,
    Set<String> passed = const {},
    int maxCount = count,
  }) {
    if (market.isEmpty) return const [];
    final weakest = weakestGroup(team);
    final top = _topOf(team, weakest);
    final baseline = top.isEmpty
        ? 0.0
        : top.fold<int>(0, (s, p) => s + p.overall) / top.length;

    final candidates = market
        .where((p) => !passed.contains(p.id) && p.marketValue <= budget * 1.2)
        .toList();
    final inGroup = candidates
        .where((p) => p.position.group == weakest && p.overall > baseline)
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    final result = <SigningProposal>[];
    for (final p in inGroup.take(maxCount)) {
      result.add(SigningProposal(
        player: p,
        reason: Tr.pick(
            '${groupLabel(weakest)}の層が薄いので、スカウトが主力より上と見ている選手です。',
            'Our ${groupLabel(weakest)} depth is thin, and the scouts rate him above our regulars.'),
      ));
    }
    if (result.length < maxCount) {
      // 足りなければ、ポジションを問わず総合力の高い選手で埋める。
      final rest = candidates
          .where((p) => !result.any((r) => r.player.id == p.id))
          .toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      for (final p in rest.take(maxCount - result.length)) {
        result.add(SigningProposal(
          player: p,
          reason: Tr.pick('スカウトの報告で目を引いた選手です。',
              'He stood out in the scouting reports.'),
        ));
      }
    }
    return result;
  }

  static List<Player> _topOf(Team team, PositionGroup g) {
    final ps = team.players.where((p) => p.position.group == g).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return ps.take(3).toList();
  }

  /// 層がいちばん薄い(上位3人の平均が低い)ポジションの大分類。
  static PositionGroup weakestGroup(Team team) {
    PositionGroup weakest = PositionGroup.mid;
    var weakestScore = 1 << 30;
    for (final g in PositionGroup.values) {
      final top = _topOf(team, g);
      final score = top.isEmpty
          ? 0
          : top.fold<int>(0, (s, p) => s + p.overall) ~/ top.length;
      if (score < weakestScore) {
        weakestScore = score;
        weakest = g;
      }
    }
    return weakest;
  }

  static String groupLabel(PositionGroup g) => switch (g) {
        PositionGroup.gk => 'GK',
        PositionGroup.def => Tr.pick('ディフェンス', 'defense'),
        PositionGroup.mid => Tr.pick('ミッドフィールド', 'midfield'),
        PositionGroup.att => Tr.pick('フォワード', 'attack'),
      };
}
