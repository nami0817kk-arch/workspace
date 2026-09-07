import 'package:flutter/material.dart';

import '../../models/attributes.dart';
import '../../game/eligibility.dart';
import '../../game/world.dart';
import '../../models/career.dart';
import '../../models/personality.dart';
import '../../models/objective.dart';
import '../../models/entourage.dart';
import '../../models/support.dart';
import '../../models/training.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import 'match_screen.dart';
import 'season_end_screen.dart';

/// キャリアの拠点。次の試合・練習・成績・順位表・これまでの記録をここから見る。
class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.controller});

  final CareerController controller;

  Future<void> _playNext(BuildContext context) async {
    controller.startNextMatch();
    if (controller.currentMatch == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchScreen(controller: controller),
    ));
  }

  Future<void> _simulateOne(BuildContext context) async {
    final result = await controller.simulateMatch();
    if (result == null || !context.mounted) return;
    final week = controller.lastWeek;
    final label = result.won ? '勝利' : (result.drawn ? '引き分け' : '敗戦');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '$label ${result.scoreLine} vs ${result.opponentName}'
          '${result.rating != null ? '  評価 ${result.rating!.toStringAsFixed(1)}' : ''}'
          '${week.newInjury != null ? '  負傷: ${week.newInjury!.name}' : ''}',
        ),
      ));
  }

  Future<void> _simulateUntilEvent(BuildContext context) async {
    final report = await controller.simulateUntilEvent();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _SimReportDialog(report: report),
    );
  }

  Future<void> _endSeason(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeasonEndScreen(controller: controller),
    ));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('キャリアを削除しますか'),
        content: const Text('この選手の記録はすべて消えます。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteCareer();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final stats = state.seasonStats;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${state.player.name}  ${state.year}シーズン'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('キャリアを削除')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'ホーム'),
            Tab(text: '順位表'),
            Tab(text: 'キャリア'),
          ]),
        ),
        body: TabBarView(
          children: [
            _HomeTab(
              controller: controller,
              state: state,
              stats: stats,
              onPlay: () => _playNext(context),
              onSimulate: () => _simulateOne(context),
              onSimulateUntilEvent: () => _simulateUntilEvent(context),
              onSimStyle: controller.setSimStyle,
              onEndSeason: () => _endSeason(context),
            ),
            _TableTab(state: state),
            _CareerTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.state,
    required this.stats,
    required this.onPlay,
    required this.onSimulate,
    required this.onSimulateUntilEvent,
    required this.onSimStyle,
    required this.onEndSeason,
  });

  final CareerController controller;
  final CareerState state;
  final SeasonStats stats;
  final VoidCallback onPlay;
  final VoidCallback onSimulate;
  final VoidCallback onSimulateUntilEvent;
  final Future<void> Function(SimStyle) onSimStyle;
  final VoidCallback onEndSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = state.seasonFinished;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controller.pendingEvent != null) ...[
          _EventCard(controller: controller),
          const SizedBox(height: 16),
        ],
        _PlayerCard(state: state),
        const SizedBox(height: 16),
        _BodyCard(state: state),
        const SizedBox(height: 16),
        _DevelopmentCard(state: state),
        const SizedBox(height: 16),
        _ClubLifeCard(state: state, controller: controller),
        const SizedBox(height: 16),
        _PersonCard(state: state, controller: controller),
        const SizedBox(height: 16),
        _LeagueCard(state: state),
        const SizedBox(height: 16),
        if (!state.squadStatus.canPlay) ...[
          _OutOfSquadCard(state: state),
          const SizedBox(height: 16),
        ],
        if (state.injured) ...[
          _InjuryCard(state: state, controller: controller),
          const SizedBox(height: 16),
        ],
        if (state.objective != null) ...[
          _ObjectiveCard(objective: state.objective!, stats: stats),
          const SizedBox(height: 16),
        ],
        if (!finished && !state.injured) ...[
          _TrainingCard(state: state, controller: controller),
          const SizedBox(height: 16),
        ],
        _SupportCard(state: state, controller: controller),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('今シーズンの成績', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(theme, '出場', '${stats.appearances}'),
                    _stat(theme, 'ゴール', '${stats.goals}'),
                    _stat(theme, 'アシスト', '${stats.assists}'),
                    _stat(
                        theme,
                        '平均評価',
                        stats.appearances == 0
                            ? '—'
                            : stats.averageRating.toStringAsFixed(2)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (finished)
          FilledButton(
            onPressed: onEndSeason,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('シーズンを終える'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      state.pendingInternational
                          ? '代表ウィーク'
                          : '第${state.matchday}節 / ${state.fixtures.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    state.pendingInternational
                        ? (state.calledUp && !state.injured
                            ? '代表に招集された'
                            : '招集は無かった')
                        : '${state.isHome(state.matchday) ? "H" : "A"}  '
                            'vs ${state.opponentFor(state.matchday).name}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onPlay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(state.pendingInternational
                          ? (state.calledUp && !state.injured
                              ? '代表戦へ'
                              : '代表ウィークを飛ばす')
                          : state.injured
                              ? '欠場する'
                              : '試合へ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('自動で進める',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in SimStyle.values)
                        Tooltip(
                          message: s.description,
                          child: ChoiceChip(
                            label: Text(s.label),
                            selected: state.simStyle == s,
                            onSelected: (_) => onSimStyle(s),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSimulate,
                          child: const Text('この試合'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSimulateUntilEvent,
                          child: const Text('区切りまで'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '負傷・代表ウィーク・シーズン終了で止まる。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('直近の試合', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (state.results.isEmpty)
          Text('まだ試合をしていない。',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final r in state.results.reversed.take(8))
            _ResultRow(result: r),
      ],
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text('${player.overall}',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.squadNumber > 0 ? '#${state.squadNumber}  ' : ''}'
                        '${player.name}'
                        '${state.captain ? '  （C）' : ''}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (state.nickname != null)
                        Text('「${state.nickname}」', style: muted),
                      Text(
                        '${player.position.label}  ${player.age}歳'
                        '（${state.stage.label}）  ·  '
                        '${World.byId(player.nationality.primary).demonym}',
                        style: muted,
                      ),
                      Text(
                        '${state.club.name}'
                        '（${World.byId(state.club.countryId).name} ${state.club.tier}部）',
                        style: muted,
                      ),
                      Text(
                        '年俸 ${_yen(state.salary)}  ·  契約 残り${state.contractYears}年',
                        style: muted,
                      ),
                      Text(
                        '市場価値 ${state.reputation.valueLabel}  ·  '
                        '知名度 ${state.reputation.fame}',
                        style: muted,
                      ),
                      if (state.onLoan)
                        Text(
                          '${state.parentClub!.name}からのローン',
                          style: muted,
                        ),
                      if (state.releaseClause != null)
                        Text(
                          '違約金 ${state.releaseClause}万円',
                          style: muted,
                        ),
                      Text(
                        '代理人 ${state.agent.name}'
                        '${state.caps > 0 ? '  ·  代表 ${state.caps}キャップ ${state.internationalGoals}ゴール' : ''}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text('ポテンシャル ${player.potentialBand}'),
                  visualDensity: VisualDensity.compact,
                ),
                if (state.calledUp)
                  Chip(
                    label: const Text('代表招集'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                if (player.nationality.roots != null)
                  Chip(
                    label: Text(
                        '${World.byId(player.nationality.roots!).name}のルーツ'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (player.nationality.naturalized.isNotEmpty)
                  Chip(
                    label: Text(
                        '${World.byId(player.nationality.naturalized.last).name}に帰化'),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final t in player.traits)
                  Tooltip(
                    message: t.description,
                    child: Chip(
                      label: Text(t.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ConditionBar(condition: player.condition),
            const SizedBox(height: 12),
            for (final key in AttributeKey.values)
              if (key != AttributeKey.goalkeeping ||
                  player.position == Position.gk)
                _AttributeBar(label: key.label, value: player.attributes[key]),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text('詳細能力', style: theme.textTheme.bodySmall),
                children: [
                  for (final key in AttributeKey.values)
                    if (key != AttributeKey.goalkeeping ||
                        player.position == Position.gk)
                      for (final d in key.details)
                        _AttributeBar(
                          label: '  ${d.label}',
                          value: player.attributes.detail(d),
                          thin: true,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _yen(int man) =>
      man >= 10000 ? '${(man / 10000).toStringAsFixed(1)}億円' : '$man万円';
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = condition >= 70
        ? theme.colorScheme.primary
        : condition >= 40
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text('コンディション', style: theme.textTheme.bodySmall),
        ),
        SizedBox(
          width: 28,
          child: Text('$condition', style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 8,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final menus = [
      for (final m in TrainingMenu.values)
        if (m.availableFor(state.player.position)) m,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今週の練習', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              state.player.atPotential
                  ? 'ポテンシャルに達している。練習では伸びない。休養で試合に備える。'
                  : '複合メニューは2か所に触れる代わりに、1か所あたりは伸びにくく、よく疲れる。',
              style: muted,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in menus)
                  Tooltip(
                    message: m.isRest
                        ? m.description
                        : '${m.description}  (消耗 ${m.conditionCost})',
                    child: ChoiceChip(
                      label: Text(m.label),
                      selected: state.menu == m,
                      onSelected: (_) => controller.setMenu(m),
                    ),
                  ),
              ],
            ),
            const Divider(height: 28),
            Text('居残り練習', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'セットプレーだけを磨く。余分に疲れるが、'
              'キッカーを任される水準に届けば試合ごとに得点が増える。',
              style: muted,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('やらない'),
                  selected: state.drill == null,
                  onSelected: (_) => controller.setDrill(null),
                ),
                for (final piece in SetPiece.values)
                  ChoiceChip(
                    label: Text(
                        '${piece.label} ${state.player.setPieces[piece]}'),
                    selected: state.drill == piece,
                    onSelected: (_) => controller.setDrill(piece),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.player.setPieces.isTaker
                  ? 'クラブの${state.player.setPieces.best.label}キッカーを任されている'
                  : 'まだキッカーは任されていない'
                      '（${SetPieceSkills.takerThreshold}で任される）',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 身体データ。伸ばせないが、試合の判定には効いている。
class _BodyCard extends StatelessWidget {
  const _BodyCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final physique = state.player.physique;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('身体', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: Text(physique.buildLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(physique.label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              physique.effects.isEmpty
                  ? '平均的な体格。得手不得手は無い。'
                  : '試合での補正: ${physique.effects.join('  ')}',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 自腹のスタッフと生活習慣。稼ぎの使い道を決めるところ。
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  void _hire(BuildContext context, StaffKind kind, int level) {
    final ok = controller.hireStaff(kind, level);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('貯蓄が足りない')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final staff = state.staff;
    final habits = state.habits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自分への投資', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '貯蓄 ${state.finances.savingsLabel}  ·  '
              '専属の年間費用 ${staff.costPerSeason}万円',
              style: muted,
            ),
            const SizedBox(height: 12),
            for (final kind in StaffKind.values) ...[
              Text('${kind.label}（${kind.description}）',
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var level = 0; level <= StaffTeam.maxLevel; level++)
                    ChoiceChip(
                      label: Text(level == 0
                          ? StaffTeam.levelLabels[0]
                          : '${StaffTeam.levelLabels[level]} '
                              '${StaffTeam.costPerLevel[level]}万'),
                      selected: staff[kind] == level,
                      onSelected: (_) => _hire(context, kind, level),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Divider(height: 12),
            const SizedBox(height: 12),
            Text('生活習慣', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('毎日の積み重ね。効きは小さいが、10年で別の身体になる。',
                style: muted),
            const SizedBox(height: 8),
            Text('睡眠', style: muted),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < Habits.sleepLabels.length; i++)
                  ChoiceChip(
                    label: Text(Habits.sleepLabels[i]),
                    selected: habits.sleep == i,
                    onSelected: (_) =>
                        controller.setHabits(habits.copyWith(sleep: i)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('食事', style: muted),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < Habits.dietLabels.length; i++)
                  ChoiceChip(
                    label: Text(Habits.dietLabels[i]),
                    selected: habits.diet == i,
                    onSelected: (_) =>
                        controller.setHabits(habits.copyWith(diet: i)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 積み上げてきたもの。経験・型・個人技・停滞期。
class _DevelopmentCard extends StatelessWidget {
  const _DevelopmentCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final dev = state.development;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('積み上げ', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: Text(dev.identityLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('試合経験 ${dev.experience}'
                '${dev.breakthroughs > 0 ? '  ·  限界突破 ${dev.breakthroughs}回' : ''}',
                style: muted),
            if (dev.signatures.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('個人技', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in dev.signatures)
                    Chip(
                      label: Text(s.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (dev.faced.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '慣れてきた相手: ${dev.faced.entries.where((e) => e.value >= 10).map((e) => e.key.label).join('  ')}',
                style: muted,
              ),
            ],
            if (dev.inPlateau) ...[
              const SizedBox(height: 10),
              Text('停滞期。あと${dev.plateau}試合は伸びにくい。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

/// クラブでの立ち位置。監督・方針・同僚・環境・同期。
class _ClubLifeCard extends StatelessWidget {
  const _ClubLifeCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  Future<void> _convert(BuildContext context) async {
    final options = state.player.aptitude.usable
        .where((p) => p != state.player.position)
        .toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('今できるコンバートは無い')));
      return;
    }
    final picked = await showDialog<Position>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('どのポジションで戦うか'),
        children: [
          for (final p in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p),
              child: Text('${p.fullName}'
                  '（適性 ${state.player.aptitude[p]}  '
                  '想定 ${state.player.overallAt(p)}）'),
            ),
        ],
      ),
    );
    if (picked != null) controller.convertPosition(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final manager = state.manager;
    final facilities =
        state.facilitiesWith(World.byId(state.club.countryId).prestige);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('クラブでの立ち位置', style: theme.textTheme.titleSmall),
            if (manager != null) ...[
              const SizedBox(height: 8),
              Text('監督 ${manager.name}（${manager.tactic.label}）',
                  style: theme.textTheme.bodyMedium),
              Text(
                '${manager.fitLabel(state.player.attributes, state.player.position)}'
                '  ·  在任${manager.tenure + 1}年目',
                style: muted,
              ),
            ],
            const SizedBox(height: 8),
            Text(facilities.label, style: muted),
            if (state.competitor != null) ...[
              const SizedBox(height: 10),
              Text(
                '同ポジション: ${state.competitor!.name}'
                '（${state.competitor!.overall}）'
                '${state.player.overall >= state.competitor!.overall ? '  自分が上' : '  向こうが上'}',
                style: muted,
              ),
            ],
            if (state.partner != null)
              Text(
                '相方: ${state.partner!.name}  ${state.partner!.synergyLabel}',
                style: muted,
              ),
            if (state.mentor != null && state.player.age <= 23)
              Text('メンター: ${state.mentor!.name}（練習が身になる）',
                  style: muted),
            if (state.rival != null) ...[
              const SizedBox(height: 10),
              Text(
                '同期 ${state.rival!.name}（${state.rival!.clubName}）'
                '  通算${state.rival!.goals}ゴール / ${state.rival!.caps}キャップ',
                style: muted?.copyWith(
                  color: state.rival!.leads(state.player.overall)
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 24),
            Text('クラブへの方針', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in Directive.values)
                  Tooltip(
                    message: d.effect,
                    child: ChoiceChip(
                      label: Text(d.label),
                      selected: state.directive == d,
                      onSelected: (_) => controller.setDirective(d),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _convert(context),
              child: Text('ポジションを変える（今 ${state.player.position.fullName}）'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ピッチの外で起きたこと。答えるまで居座る。
class _EventCard extends StatelessWidget {
  const _EventCard({required this.controller});

  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = controller.pendingEvent!;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(event.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(event.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final choice in event.choices) ...[
              FilledButton.tonal(
                onPressed: () async {
                  final outcome = choice.outcome;
                  await controller.resolveEvent(choice);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(outcome)));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(choice.label),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttributeBar extends StatelessWidget {
  const _AttributeBar({
    required this.label,
    required this.value,
    this.thin = false,
  });

  final String label;
  final int value;

  /// 詳細能力の行。少し細く、詰めて並べる。
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: thin ? 1 : 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 99,
                minHeight: thin ? 4 : 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.won
        ? theme.colorScheme.primary
        : result.drawn
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.error;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 44,
        child: Text(result.scoreLine,
            style: theme.textTheme.titleSmall?.copyWith(color: color)),
      ),
      title: Text(result.international
          ? '代表  ${result.opponentName}'
          : '${result.home ? "H" : "A"}  ${result.opponentName}'),
      subtitle: Text(result.appearance.label),
      trailing: Text(
        result.rating?.toStringAsFixed(1) ?? '—',
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = state.sortedTable;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final mine = row.clubId == state.club.id;
        return Container(
          color: mine ? theme.colorScheme.primaryContainer : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('${index + 1}')),
              Expanded(
                child: Text(row.clubName,
                    overflow: TextOverflow.ellipsis,
                    style: mine
                        ? theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)
                        : theme.textTheme.bodyMedium),
              ),
              SizedBox(
                  width: 32,
                  child: Text('${row.played}', textAlign: TextAlign.end)),
              SizedBox(
                  width: 40,
                  child: Text(
                      row.goalDifference >= 0
                          ? '+${row.goalDifference}'
                          : '${row.goalDifference}',
                      textAlign: TextAlign.end)),
              SizedBox(
                width: 40,
                child: Text('${row.points}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CareerTab extends StatelessWidget {
  const _CareerTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'シーズンを終えると、ここに記録が積み上がる。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final record in state.history.reversed)
          Card(
            child: ListTile(
              title: Text('${record.year}  ${record.clubName}'),
              subtitle: Text(
                '${record.tier}部 ${record.leaguePosition}位  ·  '
                '${record.stats.appearances}試合 '
                '${record.stats.goals}G ${record.stats.assists}A  ·  '
                '年俸 ${record.salary}万円'
                '${record.caps > 0 ? '  ·  代表${record.caps}' : ''}'
                '${record.continentalStage.participated ? '  ·  大陸${record.continentalStage.label}' : ''}'
                '${record.objectiveMet ? '  ·  目標達成' : ''}',
              ),
              trailing: Text(
                record.stats.appearances == 0
                    ? '—'
                    : record.stats.averageRating.toStringAsFixed(2),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}

/// 負傷中であることを伝えるカード。
class _InjuryCard extends StatelessWidget {
  const _InjuryCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final injury = state.injury!;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${injury.name}（${injury.severity.label}）',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Text(
              '残り${injury.matchesOut}試合の離脱。'
              '試合には出られないが、節は進む。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Text('復帰の進め方', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final plan in RehabPlan.values)
                  Tooltip(
                    message: plan.effect,
                    child: ChoiceChip(
                      label: Text(plan.label),
                      selected: state.rehab == plan,
                      onSelected: (_) => controller.setRehab(plan),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 監督から与えられた今季の目標。達成状況を並べて見せる。
class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.objective, required this.stats});

  final SeasonObjective objective;
  final SeasonStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('監督の期待', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${objective.achievedCount(stats)} / 3',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: objective.achieved(stats)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(theme, '出場', stats.appearances, objective.appearances),
            _row(theme, '得点関与', stats.goals + stats.assists,
                objective.contributions),
            _rowDouble(theme, '平均評価', stats.averageRating, objective.rating),
            const SizedBox(height: 6),
            Text(
              '2つ以上で達成。契約更改の年俸に効く。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, int now, int target) =>
      _line(theme, label, '$now / $target', now >= target);

  Widget _rowDouble(ThemeData theme, String label, double now, double target) =>
      _line(theme, label, '${now.toStringAsFixed(2)} / ${target.toStringAsFixed(2)}',
          now >= target);

  Widget _line(ThemeData theme, String label, String value, bool met) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: met
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            const SizedBox(width: 8),
            SizedBox(width: 76, child: Text(label, style: theme.textTheme.bodySmall)),
            Text(value, style: theme.textTheme.bodySmall),
          ],
        ),
      );
}

/// 自動で進めた区間のまとめ。
class _SimReportDialog extends StatelessWidget {
  const _SimReportDialog({required this.report});

  final SimReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return AlertDialog(
      title: Text('${report.played}試合を消化'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${report.won}勝 ${report.drawn}分 ${report.lost}敗',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${report.goals}ゴール ${report.assists}アシスト'
            '${report.averageRating != null ? '  平均評価 ${report.averageRating!.toStringAsFixed(2)}' : ''}',
          ),
          const SizedBox(height: 12),
          Text('止まった理由: ${report.stoppedBy.label}', style: muted),
          if (report.injury != null) ...[
            const SizedBox(height: 4),
            Text(
              '${report.injury!.name}（${report.injury!.severity.label}、'
              '${report.injury!.matchesOut}試合の離脱）',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

/// 今いるリーグと、その国の外国人ルール。
///
/// 制度そのものを画面の主役にはしない。「自分がどう扱われるか」が分かれば十分。
class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final country = World.byId(state.club.countryId);
    final foreign =
        Eligibility.isForeignIn(state.player.nationality, country);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${country.name} ${state.club.tier}部',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Text('格 ${'★' * country.prestige}', style: muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${country.confederation.label}  ·  ${country.calendar.label}  ·  '
              '${country.clubsInTier(state.club.tier)}クラブ',
              style: muted,
            ),
            const SizedBox(height: 8),
            Text('外国人ルール: ${country.foreignRule.summary}', style: muted),
            const SizedBox(height: 4),
            Text(
              state.club.tier == 1
                  ? '上位${country.continentalSlots}クラブが大陸カップへ'
                  : '上位2クラブが昇格、3〜6位はプレーオフ',
              style: muted,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  foreign ? Icons.flight_takeoff : Icons.home,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    foreign
                        ? 'この国では外国人として扱われる'
                        : state.player.nationality.isHomegrownIn(country.id)
                            ? 'この国の自国育ちとして扱われる'
                            : 'この国では自国民として扱われる',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 登録メンバーから外れていることを伝えるカード。
///
/// 怪我でもないのに出られないのは分かりにくいので、理由まで書く。
class _OutOfSquadCard extends StatelessWidget {
  const _OutOfSquadCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = World.byId(state.club.countryId);
    final foreign =
        Eligibility.isForeignIn(state.player.nationality, country);
    final reason = foreign
        ? '外国人枠が埋まっている'
        : 'クラブの中で力が足りず、25人に入れなかった';

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('登録メンバー外',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: 4),
            Text(
              '$reason。今季は試合に出られない。'
              'ローンで出場機会を探すか、移籍市場が開くのを待つことになる。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選手を「人間」として見るカード。性格・関係・お金・称号。
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = state.player.personality;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('人となり', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: Text(p.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final axis in PersonalityAxis.values)
              Tooltip(
                message: axis.description,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 76,
                          child: Text(axis.label,
                              style: theme.textTheme.bodySmall)),
                      SizedBox(
                          width: 24,
                          child: Text('${p[axis]}',
                              style: theme.textTheme.bodySmall)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p[axis] / Personality.max,
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.player.nationality.all.length > 1) ...[
              const SizedBox(height: 12),
              Text('代表を選ぶ', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in state.player.nationality.all)
                    ChoiceChip(
                      label: Text(World.byId(id).name),
                      selected: (state.nationalTeamId ??
                              state.player.nationality.primary) ==
                          id,
                      onSelected: (_) => controller.chooseNationalTeam(id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('監督: ${state.relations.managerLabel}',
                      style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Text('ロッカールーム: ${state.relations.teammatesLabel}',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '気持ち ${state.morale.label}  ·  疲労 ${state.fatigue.label}'
              '${state.form.isActive ? '  ·  ${state.form.state.label}' : ''}',
              style: muted?.copyWith(
                color: state.morale.needsCare
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '貯蓄 ${state.finances.savingsLabel}  ·  生活 ${state.finances.lifestyleLabel}'
              '${state.sponsor != null ? '  ·  ${state.sponsor!.name}と契約中' : ''}'
              '${state.charity ? '  ·  財団' : ''}',
              style: muted,
            ),
            if (state.reputation.awards.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('称号', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in state.reputation.awards)
                    Chip(
                      label: Text(a.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
