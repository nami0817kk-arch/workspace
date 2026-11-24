import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../models/league_theme.dart';
import '../logic/country_coefficient.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/chip_switcher.dart';
import '../widgets/club_emblem.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/youth_league_table.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../widgets/screen_bar.dart';
import 'club_detail_screen.dart';
import 'league_stats_screen.dart';
import 'todo_navigation.dart';
import '../logic/todo_advisor.dart';

class FixturesScreen extends StatelessWidget {
  const FixturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;
    final seasonComplete = league.isSeasonComplete;
    final divisionTier = gameState.save!.currentDivisionTier;
    final otherDivisions = <(int tier, League league)>[
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        if (tier != divisionTier &&
            gameState.save!.otherDivisionLeagues[tier - 1] != null)
          (tier, gameState.save!.otherDivisionLeagues[tier - 1]!),
    ];

    // ユースリーグは有望株がいる年だけ存在する。順位表を見に来た流れで
    // 目に入るよう、ここにも置く(いままではユース画面からしか見られなかった)。
    final youthLeague = gameState.save!.youthLeague;
    // 他国の1部の順位表。
    final foreign = gameState.foreignLeagueTables;

    // 左メニューの「リーグ」の中(横画面)では、個人成績は隣のタブにある。
    // 縦画面(単独の画面)では、ここのタブに入れる。
    final withStats = !HideScreenBar.of(context);
    final tabs = <(String, Widget)>[
      (
        Tr.pick('順位表', 'Table'),
        _StandingsTab(
          league: league,
          userTeamId: userTeamId,
          divisionTier: divisionTier,
        ),
      ),
      if (withStats)
        (Tr.pick('個人成績', 'Player stats'), const LeagueStatsScreen()),
      if (otherDivisions.isNotEmpty)
        (
          Tr.pick('他の部', 'Other tiers'),
          ChipSwitcher(items: [
            for (final (tier, otherLeague) in otherDivisions)
              (
                Tr.pick('$tier部', 'Tier $tier'),
                (_) => _StandingsTab(
                      league: otherLeague,
                      userTeamId: userTeamId,
                      divisionTier: tier,
                    ),
              ),
          ]),
        ),
      if (youthLeague != null)
        (
          Tr.pick('ユース', 'Academy'),
          ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [YouthLeagueTable(league: youthLeague)],
          ),
        ),
      // 他国の1部はユースの後ろ(タブの並びの最後)に置く。
      if (foreign.isNotEmpty)
        (
          Tr.pick('他国', 'Abroad'),
          ChipSwitcher(items: [
            for (final (name, foreignLeague) in foreign)
              (
                name,
                (_) => _StandingsTab(
                      league: foreignLeague,
                      userTeamId: userTeamId,
                      divisionTier: 1,
                      // その国のチャンピオンズカップの枠(係数の順位で
                      // 3〜5)。その下の2クラブがヨーロッパカップ。
                      continentalQualifyCount: context
                          .read<GameState>()
                          .championsSpotsFor(leagueThemeFromName(name) ??
                              LeagueTheme.england),
                      europaQualifyCount: CountryCoefficientEngine.europaSpots,
                    ),
              ),
          ]),
        ),
    ];

    // 日程の小タブは外した(2026-11-25。日程はカレンダーにある)。「まとめて
    // 進む」は上の帯の進むボタンの長押しへ移した。
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: screenBar(
          context,
          title: Tr.pick('順位表', 'League table'),
          // いまは下タブ専用だが、スタメン・スカッドと同じ作り(ドロワーあり)
          // なので、どこかから開かれた瞬間に戻れなくなる。先に塞いでおく。
          leading: Navigator.of(context).canPop() ? const BackButton() : null,
          scrollable: tabs.length > 3,
          tabs: [for (final t in tabs) t.$1],
          actions: [
            // アイコンだけでは何のボタンか分からなかった。字を添える。
            TextButton.icon(
              key: const ValueKey('projection-button'),
              icon: const Icon(Icons.query_stats, size: 18),
              label: Text(Tr.pick('順位の予想', 'Projection')),
              onPressed:
                  seasonComplete ? null : () => _showProjectionSheet(context),
            ),
          ],
        ),
        drawer: const QuickAccessDrawer(),
        body: ResponsiveBody(
          child: TabBarView(children: [for (final t in tabs) t.$2]),
        ),
      ),
    );
  }

  Future<void> _showProjectionSheet(BuildContext context) async {
    final gameState = context.read<GameState>();
    final projections = gameState.seasonProjection;
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Tr.pick('順位予測シミュレーション', 'Projected final table'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                Tr.pick('現在の総合力をもとに残り試合を簡易シミュレーションした見込みです。実際の結果を保証するものではありません。',
                    'A rough projection of the remaining matches based on current squad strength. It is not a guarantee.'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: projections.length,
                  itemBuilder: (context, i) {
                    final p = projections[i];
                    final team = league.teams.firstWhere(
                      (t) => t.id == p.teamId,
                    );
                    final isUser = p.teamId == userTeamId;
                    final tile = Container(
                      color: isUser
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3)
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        title: Text(
                          team.name,
                          style: TextStyle(
                            fontWeight:
                                isUser ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          Tr.pick('予測勝点 ${p.avgFinalPoints.toStringAsFixed(1)}',
                              'Projected points ${p.avgFinalPoints.toStringAsFixed(1)}'),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (p.titleProbability >= 0.01)
                              Text(
                                Tr.pick(
                                    '優勝 ${(p.titleProbability * 100).toStringAsFixed(0)}%',
                                    'Title ${(p.titleProbability * 100).toStringAsFixed(0)}%'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SemanticColors.ink(
                                      context, Colors.amber,
                                      min: 3),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (p.continentalProbability >= 0.01)
                              Text(
                                Tr.pick(
                                    'カップ圏 ${(p.continentalProbability * 100).toStringAsFixed(0)}%',
                                    'Continental ${(p.continentalProbability * 100).toStringAsFixed(0)}%'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            if (p.relegationProbability >= 0.01)
                              Text(
                                Tr.pick(
                                    '降格 ${(p.relegationProbability * 100).toStringAsFixed(0)}%',
                                    'Relegation ${(p.relegationProbability * 100).toStringAsFixed(0)}%'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SemanticColors.negative(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (!isUser) return tile;
                    return Semantics(
                      label: Tr.pick(
                          '自クラブ。${i + 1}位予測: ${team.name}、予測勝点 ${p.avgFinalPoints.toStringAsFixed(1)}',
                          'Your club. Projected ${i + 1}: ${team.name}, ${p.avgFinalPoints.toStringAsFixed(1)} points'),
                      child: ExcludeSemantics(child: tile),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingsTab extends StatefulWidget {
  final League league;
  final String userTeamId;
  final int divisionTier;

  /// チャンピオンズカップの出場圏の印を付ける数。null なら自国の枠
  /// ([GameStateCoefficient.continentalSpots])。
  final int? continentalQualifyCount;

  /// その下のヨーロッパカップの出場圏の印を付ける数。自国は1(もう1枠は
  /// 国内カップの優勝クラブ)、他国は2。
  final int europaQualifyCount;

  const _StandingsTab({
    required this.league,
    required this.userTeamId,
    required this.divisionTier,
    this.continentalQualifyCount,
    this.europaQualifyCount = 1,
  });

  @override
  State<_StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<_StandingsTab> {
  static const _rowHeight = 34.0;

  /// 開いたときに自クラブの行が見える位置から始める。下位にいると
  /// 3回スクロールしないと自クラブが見えなかった(2026-11-21)。
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final i = widget.league.sortedStandings
        .indexWhere((r) => r.teamId == widget.userTeamId);
    _scroll = ScrollController(
        initialScrollOffset: i <= 2 ? 0 : (i - 2) * _rowHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final userTeamId = widget.userTeamId;
    final divisionTier = widget.divisionTier;
    final rows = league.sortedStandings;
    final showContinental = divisionTier == 1;
    final showPromotion = divisionTier > 1;
    final showRelegation = divisionTier < totalDivisionTiers;
    // 入れ替えの数は国ごとに違う(ドイツ・フランス風は入れ替え戦がある)。
    final theme = context.read<GameState>().currentLeagueTheme;
    // チャンピオンズカップの出場枠は国の係数で3〜5に変わる(実在の数:
    // イングランド・スペイン5、ドイツ・イタリア4、フランス3)。季の締めで
    // 大会を組むとき(_setUpContinentalCups)と同じ数を使う。他国の1部は、
    // その国の枠。その下がヨーロッパカップ。
    final continentalQualifyCount = widget.continentalQualifyCount ??
        context.read<GameState>().continentalSpots;
    final europaEnd = continentalQualifyCount + widget.europaQualifyCount;
    final below = theme.rulesBelow(divisionTier);
    final above = theme.rulesBelow(divisionTier - 1);
    final relegationStart = rows.length - below.relegationZone;
    final autoPromotionEnd = above.autoUp;
    final playoffEnd = autoPromotionEnd +
        (above.playoffPool > 0 ? above.playoffPool : 0) +
        (above.relegationPlayoff ? above.relegationPlayoffQualifiers : 0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (showContinental) ...[
                _ZoneLegend(
                    color: SemanticColors.ink(context, Colors.amber.shade700),
                    mark: 'CC',
                    label: Tr.pick(
                        'チャンピオンズカップ出場圏', 'Champions Cup qualification')),
                _ZoneLegend(
                    color: Colors.lightBlue.shade400,
                    mark: 'EC',
                    label: Tr.pick('ヨーロッパカップ出場圏', 'Europa Cup qualification')),
              ],
              if (showPromotion) ...[
                _ZoneLegend(
                  color: SemanticColors.positive(context),
                  mark: '↑',
                  label: Tr.pick('自動昇格圏', 'Automatic promotion'),
                ),
                _ZoneLegend(
                  color: Colors.deepPurple.shade300,
                  mark: 'PO',
                  label: above.relegationPlayoff
                      ? Tr.pick('入れ替え戦圏', 'Relegation play-off')
                      : Tr.pick('昇格プレーオフ圏', 'Promotion play-offs'),
                ),
              ],
              if (showRelegation)
                _ZoneLegend(
                  color: SemanticColors.negative(context),
                  mark: '↓',
                  label: Tr.pick('降格圏', 'Relegation'),
                ),
              Text(
                [
                  if (showPromotion) theme.describeRules(divisionTier - 1),
                  if (showRelegation) theme.describeRules(divisionTier),
                ].join(' '),
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.subtleText(context)),
              ),
            ],
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
          child: Row(
            children: [
              for (final (label, w) in [
                ('#', 26.0),
              ])
                SizedBox(
                    width: w,
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 26),
              Expanded(
                  child: Text(Tr.pick('クラブ', 'Club'),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
              for (final (label, w) in [
                (Tr.pick('試', 'P'), 26.0),
                (Tr.pick('勝', 'W'), 24.0),
                (Tr.pick('分', 'D'), 24.0),
                (Tr.pick('敗', 'L'), 24.0),
                (Tr.pick('差', 'GD'), 34.0),
                (Tr.pick('戦力', 'OVR'), 30.0),
                (Tr.pick('点', 'Pts'), 34.0),
              ])
                SizedBox(
                    width: w,
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: rows.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, i) {
              final r = rows[i];
              final team = league.teams.firstWhere((t) => t.id == r.teamId);
              final isUser = r.teamId == userTeamId;
              // 圏は色の帯だけでは見分けにくい(色の見え方によっては
              // 分からない)。行に小さな印(↑・PO など)も添える。
              Color? zoneColor;
              String? zoneMark;
              if (showContinental && i < continentalQualifyCount) {
                zoneColor = Colors.amber.shade700;
                zoneMark = 'CC';
              } else if (showContinental && i < europaEnd) {
                zoneColor = Colors.lightBlue.shade400;
                zoneMark = 'EC';
              } else if (showPromotion && i < autoPromotionEnd) {
                zoneColor = SemanticColors.positive(context);
                zoneMark = '↑';
              } else if (showPromotion && i < playoffEnd) {
                zoneColor = Colors.deepPurple.shade300;
                zoneMark = 'PO';
              } else if (showRelegation && i >= relegationStart) {
                zoneColor = SemanticColors.negative(context);
                zoneMark = '↓';
              }
              final scheme = Theme.of(context).colorScheme;
              const num = TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              );
              Widget cell(String s, double w, {TextStyle? style}) => SizedBox(
                    width: w,
                    child: Text(s,
                        textAlign: TextAlign.center, style: style ?? num),
                  );
              final row = Container(
                height: 34,
                padding: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  // 自分の行は、20行の中から一目で見つかる必要がある。
                  color: isUser
                      ? scheme.primaryContainer.withValues(alpha: 0.72)
                      : (i.isOdd ? scheme.surfaceContainerLow : null),
                  border: Border(
                    left: BorderSide(
                      color: zoneColor ??
                          (isUser ? scheme.primary : Colors.transparent),
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: num.copyWith(
                            fontWeight:
                                isUser ? FontWeight.w800 : FontWeight.w600),
                      ),
                    ),
                    ClubEmblem(teamId: team.id, teamName: team.name, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        team.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isUser ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (zoneMark != null && zoneColor != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _ZoneMark(color: zoneColor, mark: zoneMark),
                      ),
                    cell('${r.played}', 26),
                    cell('${r.won}', 24),
                    cell('${r.draw}', 24),
                    cell('${r.lost}', 24),
                    cell('${r.goalDiff >= 0 ? '+' : ''}${r.goalDiff}', 34),
                    cell('${team.overallRating}', 30,
                        style: num.copyWith(color: scheme.onSurfaceVariant)),
                    cell('${r.points}', 34,
                        style: num.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              );
              // クラブの行を押すと、そのクラブのページを開く。自クラブは
              // 選手の一覧(スカッド)へ。
              if (!isUser) {
                return InkWell(
                  key: ValueKey('standings-row-${team.id}'),
                  onTap: () => openClubPage(context, team),
                  child: row,
                );
              }
              return Semantics(
                button: true,
                label: Tr.pick(
                    '自クラブ。${i + 1}位: ${team.name}、${r.played}試合 勝${r.won} 分${r.draw} 敗${r.lost} 得失点差${r.goalDiff}、${r.points}pt、戦力${team.overallRating}',
                    'Your club. ${i + 1}: ${team.name}, P${r.played} W${r.won} D${r.draw} L${r.lost} GD${r.goalDiff}, ${r.points} pts, squad ${team.overallRating}'),
                child: ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('standings-row-${team.id}'),
                    onTap: () => openTodoPlace(context, TodoPlaces.squadList),
                    child: row,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ZoneLegend extends StatelessWidget {
  final Color color;
  final String label;

  /// 表の行に添える印(↑・PO など)。凡例にも同じ印を出す。
  final String mark;

  const _ZoneLegend(
      {required this.color, required this.mark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoneMark(color: color, mark: mark),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: SemanticColors.subtleText(context))),
      ],
    );
  }
}

/// 順位表の圏の小さな印(色の枠に「↑」「PO」など)。
class _ZoneMark extends StatelessWidget {
  const _ZoneMark({required this.color, required this.mark});

  final Color color;
  final String mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        mark,
        style: TextStyle(
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
