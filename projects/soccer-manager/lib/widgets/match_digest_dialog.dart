import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../screens/player_detail_screen.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'club_emblem.dart';

/// 試合のあとに出す、結果のまとめ(FM の試合のあとの画面)。
///
/// **どの大会の試合でも、これ1つを出す**(2026-11-24)。試合経過の画面は
/// 利用者と決めて外した(2026-11-25「試合経過の画面は不要」)。
///
/// 2026-11-25 に FM に寄せて作り直した:
/// - スコアはホーム−アウェイの順(以前は自クラブが左で、アウェイの試合は
///   逆さまに出ていた)。
/// - 中身はタブで分ける(概要・数字・採点)。どのタブも1画面に収め、送らずに
///   済むようにする。
///   - 概要: 両チームの得点・カード・交代を時間の順に左右へ。マン・オブ・ザ・
///     マッチ・2つの期待の動き・賞金。
///   - 数字: 支配率・シュート・枠内・xG(分析部門があるとき)・パス成功率・
///     カード・交代。
///   - 採点: 出場した選手の採点表(両チーム)。押すと選手の詳細。
///
/// [competition] は見出しに出す大会の名前(「リーグ戦 第8節」「国内カップ
/// 3回戦」「親善試合」など)。[prizeNote] は勝ち上がりの賞金の知らせ。
Future<void> showMatchDigestDialog(
  BuildContext context, {
  required MatchResult result,
  required String userTeamId,
  required List<Team> teams,
  required String competition,
  int supportDelta = 0,
  int shareDelta = 0,
  String? prizeNote,
  String? penaltyNote,
}) async {
  // 前の知らせの帯(スナックバー)が、まとめの下に重なって残っていた
  // (カップ戦のまとめ。2026-11-25)。まとめを出す前に片付ける。
  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  final isHome = result.homeTeamId == userTeamId;
  final userGoals = isHome ? result.homeGoals : result.awayGoals;
  final oppGoals = isHome ? result.awayGoals : result.homeGoals;
  final xg = context.read<GameState>().xgOf(result);
  // xgOf は自クラブ−相手の順。ホーム−アウェイの順に並べ直す。
  final xgHomeAway = xg == null ? null : (isHome ? xg : (xg.$2, xg.$1));

  // 終わりの笛と、勝敗に合わせた歓声。
  FeedbackService.matchResult(
      won: userGoals > oppGoals, drew: userGoals == oppGoals);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => MatchDigestView(
      result: result,
      userTeamId: userTeamId,
      teams: teams,
      competition: competition,
      supportDelta: supportDelta,
      shareDelta: shareDelta,
      prizeNote: prizeNote,
      penaltyNote: penaltyNote,
      xg: xgHomeAway,
      onOpenPlayer: (id) {
        Navigator.pop(dialogContext);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: id)),
        );
      },
    ),
  );
}

/// まとめの中身(撮影・検査のために、ダイアログの外でも組めるようにしてある)。
class MatchDigestView extends StatelessWidget {
  const MatchDigestView({
    super.key,
    required this.result,
    required this.userTeamId,
    required this.teams,
    required this.competition,
    this.supportDelta = 0,
    this.shareDelta = 0,
    this.prizeNote,
    this.penaltyNote,
    this.xg,
    this.onOpenPlayer,
  });

  final MatchResult result;
  final String userTeamId;
  final List<Team> teams;
  final String competition;
  final int supportDelta;
  final int shareDelta;
  final String? prizeNote;
  final String? penaltyNote;

  /// ホーム−アウェイの xG(分析部門があるときだけ)。
  final (double, double)? xg;
  final void Function(String playerId)? onOpenPlayer;

  Team? _team(String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final home = _team(r.homeTeamId);
    final away = _team(r.awayTeamId);
    final isHome = r.homeTeamId == userTeamId;
    final userGoals = isHome ? r.homeGoals : r.awayGoals;
    final oppGoals = isHome ? r.awayGoals : r.homeGoals;
    final resultLabel = userGoals > oppGoals
        ? Tr.pick('勝利', 'Win')
        : userGoals < oppGoals
            ? Tr.pick('敗北', 'Defeat')
            : Tr.pick('引き分け', 'Draw');
    final resultColor = userGoals > oppGoals
        ? SemanticColors.positive(context)
        : userGoals < oppGoals
            ? SemanticColors.negative(context)
            : SemanticColors.neutral(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    final scheme = Theme.of(context).colorScheme;
    final homeName = home?.name ?? '-';
    final awayName = away?.name ?? '-';

    Widget side(String id, String name, {required bool right}) {
      final emblem = ClubEmblem(teamId: id, teamName: name, size: 26);
      final text = Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 15,
            fontWeight: id == userTeamId ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      );
      return Row(
        mainAxisAlignment:
            right ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: right
            ? [emblem, const SizedBox(width: 6), text]
            : [text, const SizedBox(width: 6), emblem],
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  competition,
                  key: const ValueKey('match-digest-competition'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: SemanticColors.subtleText(context),
                      ),
                ),
              ),
              Text(
                Tr.pick('結果: $resultLabel', 'Result: $resultLabel'),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: resultColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ホーム−アウェイの順(左がホーム)。
          Row(
            children: [
              Expanded(child: side(r.homeTeamId, homeName, right: false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${r.homeGoals} - ${r.awayGoals}',
                  key: const ValueKey('match-digest-score'),
                  semanticsLabel:
                      '$homeName ${r.homeGoals} - ${r.awayGoals} $awayName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: resultColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              Expanded(child: side(r.awayTeamId, awayName, right: true)),
            ],
          ),
          if (penaltyNote != null)
            Text(penaltyNote!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    final tabs = [
      Tab(height: 36, text: Tr.pick('概要', 'Overview')),
      Tab(height: 36, text: Tr.pick('数字', 'Stats')),
      Tab(height: 36, text: Tr.pick('採点', 'Ratings')),
    ];
    final body = DefaultTabController(
      length: tabs.length,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          TabBar(tabs: tabs, dividerColor: scheme.outlineVariant),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(
                  view: this,
                  home: home,
                  away: away,
                ),
                _StatsTab(view: this, home: home, away: away),
                _RatingsTab(view: this, home: home, away: away),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 14,
                    children: [
                      _MeterDelta(
                          label: Tr.pick('サポーター', 'Fans'),
                          delta: supportDelta),
                      _MeterDelta(
                          label: Tr.pick('株主', 'Shareholders'),
                          delta: shareDelta),
                    ],
                  ),
                ),
                FilledButton(
                  key: const ValueKey('match-digest-close'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44)),
                  onPressed: () => Navigator.pop(context),
                  child: Text(Tr.pick('閉じる', 'Close')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // 横画面は縦が短い。高さを画面に合わせて決め、中のタブは1画面に収める。
    final height = (size.height - (wide ? 24 : 96)).clamp(280.0, 560.0);
    return Dialog(
      key: const ValueKey('match-digest'),
      insetPadding: wide
          ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: wide ? 760 : double.maxFinite,
        height: height,
        child: body,
      ),
    );
  }
}

/// 概要: 得点・カード・交代を、ホームは左、アウェイは右に時間の順で。
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.view, this.home, this.away});

  final MatchDigestView view;
  final Team? home;
  final Team? away;

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    final events = [
      for (final e in r.events)
        if (e.type != MatchEventType.chance) e,
    ]..sort((a, b) => a.minute.compareTo(b.minute));
    final motmId = r.manOfTheMatchId;
    String? nameOf(String? id) {
      if (id == null) return null;
      for (final t in [home, away]) {
        for (final p in t?.players ?? const <Player>[]) {
          if (p.id == id) return p.name;
        }
      }
      return null;
    }

    final motmName = nameOf(motmId);
    final motmTeam = motmId == null
        ? null
        : (home?.players.any((p) => p.id == motmId) ?? false)
            ? home
            : away;
    final subtle = SemanticColors.subtleText(context);

    Widget column(String teamId, {required bool right}) {
      final mine = [
        for (final e in events)
          if (e.teamId == teamId) e,
      ];
      if (mine.isEmpty) {
        return Align(
          alignment: right ? Alignment.topLeft : Alignment.topRight,
          child: Text('—', style: TextStyle(color: subtle)),
        );
      }
      return Column(
        crossAxisAlignment:
            right ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          for (final e in mine) _EventLine(event: e, right: right),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (events.isEmpty)
            Text(
              Tr.pick('得点者はいませんでした', 'Nobody scored'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtle),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: column(r.homeTeamId, right: false)),
                Container(
                  width: 1,
                  // 線の長さは、出来事の多いほうの側に合わせる。
                  height: 18.0 *
                      [
                        events.where((e) => e.teamId == r.homeTeamId).length,
                        events.where((e) => e.teamId == r.awayTeamId).length,
                        1,
                      ].reduce((a, b) => a > b ? a : b),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: column(r.awayTeamId, right: true)),
              ],
            ),
          const SizedBox(height: 10),
          if (motmName != null)
            InkWell(
              key: const ValueKey('match-digest-motm'),
              onTap: view.onOpenPlayer == null
                  ? null
                  : () => view.onOpenPlayer!(motmId!),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Icon(Icons.star,
                        color:
                            SemanticColors.ink(context, Colors.amber, min: 3),
                        size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        Tr.pick(
                            'マン・オブ・ザ・マッチ: $motmName(${motmTeam?.name ?? ''}・${r.playerRatings[motmId]!.toStringAsFixed(1)})',
                            'Player of the match: $motmName (${motmTeam?.name ?? ''}, ${r.playerRatings[motmId]!.toStringAsFixed(1)})'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 勝ち上がりの賞金(以前は画面の下に一瞬出る帯だった)。
          if (view.prizeNote != null)
            Row(
              key: const ValueKey('match-digest-prize'),
              children: [
                Icon(Icons.payments_outlined,
                    size: 18, color: SemanticColors.positive(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(view.prizeNote!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 出来事の1行(「23' ⚽ 名前(アシスト)」)。ホームは右寄せ、アウェイは左寄せ。
class _EventLine extends StatelessWidget {
  const _EventLine({required this.event, required this.right});

  final MatchEvent event;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final (Widget icon, String text) = switch (e.type) {
      MatchEventType.goal => (
          Icon(Icons.sports_soccer,
              size: 14, color: SemanticColors.positive(context)),
          '${e.scorerName ?? Tr.pick('不明', 'Unknown')}'
              '${e.setPiece == SetPieceKind.penalty ? Tr.pick('(PK)', ' (pen)') : ''}'
              '${e.assistName != null ? Tr.pick('(アシスト ${e.assistName})', ' (assist ${e.assistName})') : ''}',
        ),
      MatchEventType.yellowCard => (
          const _CardMark(color: Color(0xFFF2C200)),
          e.scorerName ?? '',
        ),
      MatchEventType.redCard => (
          const _CardMark(color: Color(0xFFD32F2F)),
          e.scorerName ?? '',
        ),
      MatchEventType.substitution => (
          Icon(Icons.swap_vert,
              size: 14, color: SemanticColors.subtleText(context)),
          Tr.pick('${e.scorerName ?? ''} ← ${e.assistName ?? ''}',
              '${e.scorerName ?? ''} for ${e.assistName ?? ''}'),
        ),
      MatchEventType.chance => (const SizedBox.shrink(), ''),
    };
    final minute = SizedBox(
      width: 28,
      child: Text("${e.minute}'",
          textAlign: right ? TextAlign.left : TextAlign.right,
          style: TextStyle(
              fontSize: 11, color: SemanticColors.subtleText(context))),
    );
    // 長い名前(アシストつき)は切らずに縮める。
    final label = Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: right ? Alignment.centerLeft : Alignment.centerRight,
        child: Text(
        text,
        maxLines: 1,
        textAlign: right ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              e.type == MatchEventType.goal ? FontWeight.w700 : FontWeight.w400,
          color: e.type == MatchEventType.substitution
              ? SemanticColors.subtleText(context)
              : null,
        ),
      ),
      ),
    );
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment:
            right ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: right
            ? [minute, icon, const SizedBox(width: 4), label]
            : [label, const SizedBox(width: 4), icon, minute],
      ),
    );
  }
}

class _CardMark extends StatelessWidget {
  const _CardMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
}

/// パス成功率(%)の見積もり。試合の記録にパスの数は無いので、支配率と、
/// 出場した選手の技術の平均から決める(乱数は使わない。同じ試合なら同じ値)。
int passAccuracyOf(MatchResult r, {required bool home, Team? team}) {
  final poss = (home ? r.homePossession : r.awayPossession) ?? 50;
  final played = [
    for (final p in team?.players ?? const <Player>[])
      if (r.playerRatings.containsKey(p.id)) p,
  ];
  final tech = played.isEmpty
      ? 60.0
      : played.map((p) => p.technique).reduce((a, b) => a + b) / played.length;
  return (74 + (poss - 50) * 0.35 + (tech - 60) * 0.3).round().clamp(58, 93);
}

/// 数字: 両チームの数字を、真ん中に項目名を置いて左右に。
class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.view, this.home, this.away});

  final MatchDigestView view;
  final Team? home;
  final Team? away;

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    int count(String teamId, MatchEventType t) =>
        r.events.where((e) => e.teamId == teamId && e.type == t).length;
    final rows = <(String, String, String, double?)>[
      if (r.homePossession != null && r.awayPossession != null)
        (
          Tr.pick('支配率', 'Possession'),
          '${r.homePossession}%',
          '${r.awayPossession}%',
          r.homePossession! / 100,
        ),
      if (r.homeShots != null)
        (
          Tr.pick('シュート', 'Shots'),
          '${r.homeShots}',
          '${r.awayShots ?? 0}',
          _share(r.homeShots!, r.awayShots ?? 0),
        ),
      if (r.homeShotsOnTarget != null)
        (
          Tr.pick('枠内シュート', 'On target'),
          '${r.homeShotsOnTarget}',
          '${r.awayShotsOnTarget ?? 0}',
          _share(r.homeShotsOnTarget!, r.awayShotsOnTarget ?? 0),
        ),
      if (view.xg case final xg?)
        (
          'xG',
          xg.$1.toStringAsFixed(1),
          xg.$2.toStringAsFixed(1),
          _shareD(xg.$1, xg.$2),
        ),
      if (r.homePossession != null)
        (
          Tr.pick('パス成功率', 'Pass completion'),
          '${passAccuracyOf(r, home: true, team: home)}%',
          '${passAccuracyOf(r, home: false, team: away)}%',
          null,
        ),
      (
        Tr.pick('警告', 'Yellow cards'),
        '${count(r.homeTeamId, MatchEventType.yellowCard)}',
        '${count(r.awayTeamId, MatchEventType.yellowCard)}',
        null,
      ),
      (
        Tr.pick('退場', 'Red cards'),
        '${count(r.homeTeamId, MatchEventType.redCard)}',
        '${count(r.awayTeamId, MatchEventType.redCard)}',
        null,
      ),
      (
        Tr.pick('交代', 'Substitutions'),
        '${count(r.homeTeamId, MatchEventType.substitution)}',
        '${count(r.awayTeamId, MatchEventType.substitution)}',
        null,
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        children: [
          for (final (label, h, a, share) in rows)
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(h,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: SemanticColors.subtleText(context))),
                        if (share != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 4,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (share * 100).round().clamp(1, 99),
                                      child: Container(color: scheme.primary),
                                    ),
                                    Expanded(
                                      flex: (100 - (share * 100).round())
                                          .clamp(1, 99),
                                      child: Container(
                                          color: scheme.outlineVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 56,
                    child: Text(a,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static double _share(int h, int a) => h + a == 0 ? 0.5 : h / (h + a);
  static double _shareD(double h, double a) => h + a == 0 ? 0.5 : h / (h + a);
}

/// 採点: 出場した選手を、ホームは左・アウェイは右に、採点の高い順で。
class _RatingsTab extends StatelessWidget {
  const _RatingsTab({required this.view, this.home, this.away});

  final MatchDigestView view;
  final Team? home;
  final Team? away;

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    if (r.playerRatings.isEmpty) {
      return Center(
        child: Text(Tr.pick('この試合の採点はありません', 'No ratings for this match'),
            style: TextStyle(color: SemanticColors.subtleText(context))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _RatingList(view: view, team: home)),
          const SizedBox(width: 12),
          Expanded(child: _RatingList(view: view, team: away)),
        ],
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({required this.view, this.team});

  final MatchDigestView view;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    final t = team;
    if (t == null) return const SizedBox.shrink();
    final players = [
      for (final p in t.players)
        if (r.playerRatings.containsKey(p.id)) p,
    ]..sort((a, b) => r.playerRatings[b.id]!.compareTo(r.playerRatings[a.id]!));
    final motm = r.manOfTheMatchId;
    final scheme = Theme.of(context).colorScheme;
    int n(String id, MatchEventType type, {bool assist = false}) => r.events
        .where((e) =>
            e.type == type && (assist ? e.assistId == id : e.scorerId == id))
        .length;
    return ListView.builder(
      itemCount: players.length,
      itemExtent: 26,
      itemBuilder: (context, i) {
        final p = players[i];
        final rating = r.playerRatings[p.id]!;
        final goals = n(p.id, MatchEventType.goal);
        final assists = n(p.id, MatchEventType.goal, assist: true);
        final yellow = n(p.id, MatchEventType.yellowCard) > 0;
        final red = n(p.id, MatchEventType.redCard) > 0;
        final subOn = n(p.id, MatchEventType.substitution) > 0;
        final ratingColor = rating >= 7.5
            ? SemanticColors.positive(context)
            : rating < 6.0
                ? SemanticColors.negative(context)
                : null;
        return InkWell(
          key: ValueKey('digest-rating-${p.id}'),
          onTap:
              view.onOpenPlayer == null ? null : () => view.onOpenPlayer!(p.id),
          child: Container(
            color: i.isOdd ? scheme.surfaceContainerLow : null,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(p.position.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: SemanticColors.subtleText(context))),
                ),
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: t.id == view.userTeamId
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (subOn)
                  Icon(Icons.arrow_upward,
                      size: 12, color: SemanticColors.positive(context)),
                for (var g = 0; g < goals; g++)
                  Icon(Icons.sports_soccer,
                      size: 12, color: SemanticColors.positive(context)),
                if (assists > 0)
                  Text(assists > 1 ? 'A$assists' : 'A',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                if (yellow) const _CardMark(color: Color(0xFFF2C200)),
                if (red) const _CardMark(color: Color(0xFFD32F2F)),
                if (p.id == motm)
                  Icon(Icons.star,
                      size: 13,
                      color: SemanticColors.ink(context, Colors.amber, min: 3)),
                SizedBox(
                  width: 32,
                  child: Text(
                    rating.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ratingColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 試合で、期待のメーターがどれだけ動いたか。
class _MeterDelta extends StatelessWidget {
  const _MeterDelta({required this.label, required this.delta});

  final String label;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0
        ? SemanticColors.positive(context)
        : delta < 0
            ? SemanticColors.negative(context)
            : SemanticColors.neutral(context);
    final text = delta > 0 ? '+$delta' : '$delta';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 13)),
        Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
