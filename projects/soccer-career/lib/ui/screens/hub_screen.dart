import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/attributes.dart';
import '../../game/eligibility.dart';
import '../../game/formulas.dart';
import '../../game/world.dart';
import '../../models/career.dart';
import '../../models/personality.dart';
import '../../models/objective.dart';
import '../../models/competition.dart';
import '../../game/newsroom.dart';
import '../../models/development.dart';
import '../../models/news.dart';
import '../../models/entourage.dart';
import '../../models/life.dart';
import '../../models/support.dart';
import '../../models/training.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import '../club_identity.dart';
import 'guide_screen.dart';
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

  /// 遊び方のガイドを開く。仕組みが多いので、1か所にまとめてある。
  void _openGuide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideScreen()),
    );
  }

  Future<void> _showExport(BuildContext context) async {
    final code = controller.exportCode();
    if (code == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引き継ぎコード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'このコードをコピーして、別の端末で「セーブを読み込む」に貼り付けると、'
              '続きから遊べる。長いので、メモアプリなどに保存しておくとよい。',
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  code,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('引き継ぎコードをコピーした')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
          ),
        ],
      ),
    );
  }

  /// 引き継ぎコードから復元する。今のキャリアは上書きされる。
  Future<void> _showImport(BuildContext context) async {
    final input = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('セーブを読み込む'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '別の端末で作った引き継ぎコードを貼り付ける。'
              '今のキャリアは上書きされる。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'SC1:...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(input.text),
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final ok = await controller.importCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? 'キャリアを読み込んだ' : 'コードを読めなかった。今のキャリアはそのまま。'),
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${state.player.name}  ${state.year}シーズン'),
          actions: [
            IconButton(
              onPressed: () => _openGuide(context),
              icon: const Icon(Icons.help_outline),
              tooltip: '遊び方',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _showExport(context);
                  case 'import':
                    _showImport(context);
                  case 'delete':
                    _confirmDelete(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'export', child: Text('引き継ぎコードを出す')),
                PopupMenuItem(value: 'import', child: Text('セーブを読み込む')),
                PopupMenuItem(value: 'delete', child: Text('キャリアを削除')),
              ],
            ),
          ],
          bottom: const TabBar(
            labelPadding: EdgeInsets.symmetric(horizontal: 2),
            tabs: [
              Tab(text: '試合'),
              Tab(text: '選手'),
              Tab(text: '育成'),
              Tab(text: 'クラブ'),
              Tab(text: '記録'),
            ],
          ),
        ),
        // 一番よく押すものは、どのタブに居ても手の届く場所に置く。
        // 以前は画面を6つ分スクロールしないと試合に入れなかった。
        floatingActionButton: _PrimaryAction(
          state: state,
          onPlay: () => _playNext(context),
          onEndSeason: () => _endSeason(context),
        ),
        body: TabBarView(
          children: [
            _MatchTab(
              controller: controller,
              state: state,
              stats: stats,
              onPlay: () => _playNext(context),
              onSimulate: () => _simulateOne(context),
              onSimulateUntilEvent: () => _simulateUntilEvent(context),
              onSimStyle: controller.setSimStyle,
              onEndSeason: () => _endSeason(context),
            ),
            _PlayerTab(state: state),
            _TrainingTab(state: state, controller: controller),
            _ClubTab(state: state, controller: controller),
            _CareerTab(state: state),
          ],
        ),
      ),
    );
  }
}

/// どのタブからでも押せる、今いちばんやること。
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.state,
    required this.onPlay,
    required this.onEndSeason,
  });

  final CareerState state;
  final VoidCallback onPlay;
  final VoidCallback onEndSeason;

  @override
  Widget build(BuildContext context) {
    if (state.seasonFinished) {
      return FloatingActionButton.extended(
        onPressed: onEndSeason,
        icon: const Icon(Icons.flag_outlined),
        label: const Text('シーズンを終える'),
      );
    }
    final label = state.pendingInternational
        ? (state.calledUp && !state.injured ? '代表戦へ' : '代表ウィークを飛ばす')
        : state.injured
            ? '欠場する'
            : '試合へ';
    return FloatingActionButton.extended(
      onPressed: onPlay,
      icon: Icon(state.injured
          ? Icons.healing_outlined
          : Icons.sports_soccer_outlined),
      label: Text(label),
    );
  }
}

/// 次の試合と、今の状態。開いてすぐ「今どうなっていて、次に何をするか」が分かる。
class _MatchTab extends StatelessWidget {
  const _MatchTab({
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // 答えを待っているものが先。埋もれると、そのまま忘れられる。
        if (controller.pendingEvent != null) ...[
          _EventCard(controller: controller),
          const SizedBox(height: 16),
        ],
        if (!state.squadStatus.canPlay) ...[
          _OutOfSquadCard(state: state),
          const SizedBox(height: 16),
        ],
        if (state.injured) ...[
          _InjuryCard(state: state, controller: controller),
          const SizedBox(height: 16),
        ],
        // まだ1試合もしていないうちだけ、次にやることを1行で出す。
        if (state.results.isEmpty && state.history.isEmpty) ...[
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('はじめに', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    '「育成」タブで今週の練習を選び、下の「試合へ」で試合に入る。'
                    '試合では3つの局面で手を選ぶ。まずは1試合やってみるのが早い。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (finished)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('全${state.fixtures.length}節を戦い終えた',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${state.club.name}  ${state.leaguePosition}位',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onEndSeason,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('シーズンを終える'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _NextMatchCard(
            state: state,
            stake: controller.stake,
            onPlay: onPlay,
            onSimulate: onSimulate,
            onSimulateUntilEvent: onSimulateUntilEvent,
            onSimStyle: onSimStyle,
          ),
        const SizedBox(height: 16),
        if (controller.news.isNotEmpty) ...[
          _NewsCard(news: controller.news.take(3).toList()),
          const SizedBox(height: 16),
        ],
        _StatusCard(state: state),
        const SizedBox(height: 16),
        if (state.objective != null) ...[
          _ObjectiveCard(objective: state.objective!, stats: stats),
          const SizedBox(height: 16),
        ],
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

/// 次の相手と、自動で進める手段。
class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({
    required this.state,
    required this.stake,
    required this.onPlay,
    required this.onSimulate,
    required this.onSimulateUntilEvent,
    required this.onSimStyle,
  });

  final CareerState state;

  /// その試合が持つ意味（ダービー・首位攻防など）。
  final FixtureStake stake;

  final VoidCallback onPlay;
  final VoidCallback onSimulate;
  final VoidCallback onSimulateUntilEvent;
  final Future<void> Function(SimStyle) onSimStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final total = state.fixtures.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                state.pendingInternational
                    ? '代表ウィーク'
                    : '第${state.matchday}節 / $total',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 6),
            if (!state.pendingInternational) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (state.matchday - 1) / total,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              state.pendingInternational
                  ? (state.calledUp && !state.injured
                      ? '代表に招集された'
                      : '招集は無かった')
                  : '${state.isHome(state.matchday) ? "ホーム" : "アウェイ"}  '
                      'vs ${state.opponentFor(state.matchday).name}',
              style: theme.textTheme.titleLarge,
            ),
            if (!state.pendingInternational && stake.isSpecial) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stake.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer)),
                    Text(stake.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer)),
                  ],
                ),
              ),
            ],
            if (!state.pendingInternational) ...[
              const SizedBox(height: 4),
              Text(
                '相手の戦い方: '
                '${ClubStyle.of(state.opponentFor(state.matchday)).label}'
                '（${ClubStyle.of(state.opponentFor(state.matchday)).description}）',
                style: muted,
              ),
            ],
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
            const SizedBox(height: 16),
            Text('自動で進める', style: muted),
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
            Text('負傷・代表ウィーク・シーズン終了で止まる。', style: muted),
          ],
        ),
      ),
    );
  }
}

/// 今の状態を1枚に。数字を読まなくても、危ないかどうかが分かるようにする。
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今の状態', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _ConditionBar(condition: player.condition),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(theme, '気持ち ${state.morale.label}',
                    warn: state.morale.needsCare),
                _tag(theme, '疲労 ${state.fatigue.label}',
                    warn: state.fatigue.value >= 70),
                if (state.form.isActive)
                  _tag(theme, state.form.state.label,
                      good: state.form.state == MomentumState.zone,
                      warn: state.form.state == MomentumState.slump),
                if (state.development.inPlateau)
                  _tag(theme, '停滞期 あと${state.development.plateau}試合'),
                if (state.captain) _tag(theme, 'キャプテン', good: true),
                if (state.calledUp) _tag(theme, '代表招集', good: true),
                // 待っている話は、出来事が来るまで気づけないので前に出す。
                if (state.captaincyOffered)
                  _tag(theme, '腕章の打診が来ている', good: true),
                if (state.sponsorOffer != null)
                  _tag(theme, 'スポンサーの話が来ている', good: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(ThemeData theme, String label,
      {bool warn = false, bool good = false}) {
    final color = warn
        ? theme.colorScheme.errorContainer
        : good
            ? theme.colorScheme.primaryContainer
            : null;
    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 選手そのもの。能力・身体・積み上げ。
class _PlayerTab extends StatelessWidget {
  const _PlayerTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _PlayerCard(state: state),
          const SizedBox(height: 16),
          _BodyCard(state: state),
          const SizedBox(height: 16),
          _DevelopmentCard(state: state),
        ],
      );
}

/// 育て方を決める場所。練習・居残り・自分への投資。
class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (state.injured)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '離脱中は練習ができない。復帰の進め方は「試合」タブで選べる。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          )
        else
          _TrainingCard(state: state, controller: controller),
        const SizedBox(height: 16),
        _SupportCard(state: state, controller: controller),
      ],
    );
  }
}

/// クラブと、その中での立ち位置。
class _ClubTab extends StatelessWidget {
  const _ClubTab({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _ClubLifeCard(state: state, controller: controller),
          const SizedBox(height: 16),
          _PersonCard(state: state, controller: controller),
          const SizedBox(height: 16),
          _LeagueCard(state: state),
          const SizedBox(height: 16),
          _ScorerCard(state: state),
          const SizedBox(height: 16),
          _TableCard(state: state),
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
                Column(
                  children: [
                    ClubCrest(club: state.club, size: 40),
                    const SizedBox(height: 4),
                    Text('${player.overall}',
                        style: theme.textTheme.titleMedium),
                  ],
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
    final menu = state.menu;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今週の練習', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            // 選んでいるものが何をするメニューなのかを、常に文字で出す。
            // 説明をツールチップに隠すと、スマホでは長押ししないと読めない。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(menu.description, style: muted),
                  const SizedBox(height: 6),
                  Text(
                    menu.isRest
                        ? 'コンディション +${menu.recovery}'
                        : '消耗 ${menu.conditionCost}'
                            '${menu.isCompound ? '  ·  2か所に触れるが、1か所あたりは伸びにくい' : ''}'
                            '${menu.injuryFactor > 1 ? '  ·  怪我をしやすい' : ''}',
                    style: muted,
                  ),
                  if (state.player.atPotential) ...[
                    const SizedBox(height: 6),
                    Text(
                      'ポテンシャルに達している。今は練習しても伸びない。',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _menuGroup(theme, '休む', [
              for (final m in menus)
                if (m.isRest) m,
            ], muted),
            _menuGroup(theme, '1か所を鍛える', [
              for (final m in menus)
                if (!m.isRest && !m.isCompound && !m.weakFoot) m,
            ], muted),
            _menuGroup(theme, '2か所を同時に', [
              for (final m in menus)
                if (m.isCompound) m,
            ], muted),
            _menuGroup(theme, '苦手をつぶす', [
              for (final m in menus)
                if (m.weakFoot) m,
            ], muted),
            const Divider(height: 28),
            Text('居残り練習', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'セットプレーだけを磨く。余分に${Formulas.drillConditionCost}疲れるが、'
              '${SetPieceSkills.takerThreshold}に届けばキッカーを任され、'
              '試合ごとに得点の機会が回ってくる。',
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
                  : 'まだキッカーは任されていない',
              style: muted?.copyWith(
                color: state.player.setPieces.isTaker
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 種類ごとに小見出しを付けて並べる。12個を一列に並べると選べない。
  Widget _menuGroup(
    ThemeData theme,
    String title,
    List<TrainingMenu> menus,
    TextStyle? muted,
  ) {
    if (menus.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: muted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in menus)
                ChoiceChip(
                  label: Text(m.label),
                  selected: state.menu == m,
                  onSelected: (_) => controller.setMenu(m),
                ),
            ],
          ),
        ],
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
              ],
            ),
          ),
          // 普段は畳んでおく。毎週触るものではないのに、開いた瞬間に
          // 20個近い選択肢が並ぶと、練習を選ぶ邪魔にしかならない。
          ExpansionTile(
            title: const Text('専属スタッフ'),
            subtitle: Text(
              staff.isEmpty
                  ? '誰も雇っていない'
                  : [
                      for (final kind in StaffKind.values)
                        if (staff[kind] > 0)
                          '${kind.label} ${StaffTeam.levelLabels[staff[kind]]}',
                    ].join('  ·  '),
              style: muted,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final kind in StaffKind.values) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${kind.label}（${kind.description}）',
                      style: theme.textTheme.labelMedium),
                ),
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
                const SizedBox(height: 14),
              ],
              Text(
                '費用はシーズンの終わりに貯蓄から引かれる。'
                '払えなければ契約は切れる。',
                style: muted,
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('生活習慣'),
            subtitle: Text(
              '睡眠 ${habits.sleepLabel}  ·  食事 ${habits.dietLabel}',
              style: muted,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('毎日の積み重ね。効きは小さいが、10年で別の身体になる。',
                    style: muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('睡眠', style: theme.textTheme.labelMedium),
              ),
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('食事', style: theme.textTheme.labelMedium),
              ),
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '管理された食事は生活費が増える。'
                  '整えるほど回復が早く、怪我をしにくい。',
                  style: muted,
                ),
              ),
            ],
          ),
        ],
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

/// 通算の記録。1年ずつの積み上げの前に、全体を1枚で見せる。
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final totals = state.careerTotals;
    final clubs = {
      state.club.name,
      for (final h in state.history) h.clubName,
    };
    final countries = {
      state.club.countryId,
      for (final h in state.history) h.countryId,
    };
    final leagueTitles = state.history
        .where((h) => h.tier == 1 && h.leaguePosition == 1)
        .length;
    final cups =
        state.history.where((h) => h.cupStage == CupStage.winner).length;
    final continental = state.history
        .where((h) => h.continentalStage == ContinentalStage.winner)
        .length;
    final worldCups =
        state.history.where((h) => h.worldCupStage.participated).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('通算', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _total(theme, '試合', '${totals.appearances}'),
                _total(theme, 'ゴール', '${totals.goals}'),
                _total(theme, 'アシスト', '${totals.assists}'),
                _total(
                    theme,
                    '平均評価',
                    totals.appearances == 0
                        ? '—'
                        : totals.averageRating.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${state.history.length + 1}シーズン目  ·  '
              '${clubs.length}クラブ  ·  ${countries.length}か国'
              '${state.caps > 0 ? '  ·  代表${state.caps}キャップ' : ''}',
              style: muted,
            ),
            if (leagueTitles + cups + continental + worldCups > 0) ...[
              const SizedBox(height: 12),
              Text('タイトル', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (leagueTitles > 0)
                    Chip(
                      label: Text('リーグ優勝 $leagueTitles'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (cups > 0)
                    Chip(
                      label: Text('国内カップ $cups'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (continental > 0)
                    Chip(
                      label: Text('大陸カップ $continental'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (worldCups > 0)
                    Chip(
                      label: Text('W杯出場 $worldCups'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (state.reputation.awards.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('称号', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
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

  Widget _total(ThemeData theme, String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      );
}

/// キャリアの推移。数字の羅列より、線1本のほうが形が分かる。
class _CareerChartCard extends StatelessWidget {
  const _CareerChartCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final history = state.history;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('推移', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('棒＝シーズンの平均評価　線＝総合力', style: muted),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _CareerChartPainter(
                  history: history,
                  bar: theme.colorScheme.primaryContainer,
                  line: theme.colorScheme.primary,
                  grid: theme.colorScheme.outlineVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${history.first.year}', style: muted),
                Text('${history.last.year}', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerChartPainter extends CustomPainter {
  const _CareerChartPainter({
    required this.history,
    required this.bar,
    required this.line,
    required this.grid,
  });

  final List<SeasonRecord> history;
  final Color bar;
  final Color line;
  final Color grid;

  /// 評価点の見せる範囲。全域（4〜10）を映すと、差が潰れて読めない。
  static const double minRating = 5.5;
  static const double maxRating = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final slot = size.width / history.length;

    // 6.0 の目安線。ここが「普通の出来」。
    final basis = size.height * (1 - (6.0 - minRating) / (maxRating - minRating));
    canvas.drawLine(
      Offset(0, basis),
      Offset(size.width, basis),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    final barPaint = Paint()..color = bar;
    for (var i = 0; i < history.length; i++) {
      final record = history[i];
      if (record.stats.appearances == 0) continue;
      final value =
          ((record.stats.averageRating - minRating) / (maxRating - minRating))
              .clamp(0.0, 1.0);
      final height = size.height * value;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            slot * i + slot * 0.2,
            size.height - height,
            slot * 0.6,
            height,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // 総合力の線。記録が無いシーズン（古い保存データ）は飛ばす。
    final points = <Offset>[];
    for (var i = 0; i < history.length; i++) {
      final overall = history[i].overall;
      if (overall <= 0) continue;
      final value = ((overall - 45) / 50).clamp(0.0, 1.0);
      points.add(Offset(slot * i + slot / 2, size.height * (1 - value)));
    }
    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final point in points) {
        canvas.drawCircle(point, 2.5, Paint()..color = line);
      }
    }
  }

  @override
  bool shouldRepaint(_CareerChartPainter oldDelegate) =>
      oldDelegate.history.length != history.length;
}

/// 世の中に出た見出し。
class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.news,
    this.title = '最近の話題',
    this.limit = 3,
  });

  final List<NewsItem> news;
  final String title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final item in news.take(limit)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _colorOf(theme, item.kind),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.headline,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (item.body.isNotEmpty)
                          Text(item.body, style: muted),
                        Text('${item.dateLabel}  ·  ${item.kind.label}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorOf(ThemeData theme, NewsKind kind) => switch (kind) {
        NewsKind.milestone => theme.colorScheme.primary,
        NewsKind.transfer => theme.colorScheme.tertiary,
        NewsKind.national => theme.colorScheme.secondary,
        _ => theme.colorScheme.outline,
      };
}

/// リーグの得点ランキング。自分がどのあたりに居るのかを見せる。
class _ScorerCard extends StatelessWidget {
  const _ScorerCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scorers = ScorerRace.table(state);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('得点ランキング', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (var i = 0; i < scorers.length; i++)
              Container(
                color: scorers[i].isPlayer
                    ? theme.colorScheme.primaryContainer
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 26,
                        child: Text('${i + 1}',
                            style: theme.textTheme.bodySmall)),
                    Expanded(
                      child: Text(
                        scorers[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: scorers[i].isPlayer
                            ? theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        scorers[i].clubName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text('${scorers[i].goals}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall),
                    ),
                  ],
                ),
              ),
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

/// 順位表。クラブのタブの中に置く。
class _TableCard extends StatelessWidget {
  const _TableCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = state.sortedTable;
    final muted = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('順位表', style: theme.textTheme.titleSmall),
                  ),
                  SizedBox(width: 32, child: Text('試', style: muted, textAlign: TextAlign.end)),
                  SizedBox(width: 40, child: Text('差', style: muted, textAlign: TextAlign.end)),
                  SizedBox(width: 40, child: Text('点', style: muted, textAlign: TextAlign.end)),
                ],
              ),
            ),
            for (var index = 0; index < rows.length; index++)
              _TableRowTile(state: state, position: index + 1),
          ],
        ),
      ),
    );
  }
}

/// 順位表の1行。
///
/// 行の型（models の TableRow）は Flutter の TableRow と名前がぶつかるので、
/// ここでは型名を書かずに順位から引き直す。
class _TableRowTile extends StatelessWidget {
  const _TableRowTile({required this.state, required this.position});

  final CareerState state;
  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = state.sortedTable[position - 1];
    final mine = row.clubId == state.club.id;
    return Container(
      color: mine ? theme.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$position')),
          ClubCrest(
            club: state.league.firstWhere((c) => c.id == row.clubId,
                orElse: () => state.club),
            size: 20,
          ),
          const SizedBox(width: 8),
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
  }
}

class _CareerTab extends StatelessWidget {
  const _CareerTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _TotalsCard(state: state),
        const SizedBox(height: 16),
        if (state.news.isNotEmpty) ...[
          _NewsCard(news: state.news, title: 'これまでの話題', limit: 12),
          const SizedBox(height: 16),
        ],
        if (state.history.length >= 2) ...[
          _CareerChartCard(state: state),
          const SizedBox(height: 16),
        ],
        if (state.history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'シーズンを終えると、ここに1年ずつ積み上がる。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final record in state.history.reversed)
          Card(
            child: ListTile(
              title: Text('${record.year}  ${record.clubName}'),
              subtitle: Text(
                '${record.tier}部 ${record.leaguePosition}位  ·  '
                '${record.stats.appearances}試合 '
                '${record.stats.goals}G ${record.stats.assists}A  ·  '
                '年俸 ${record.salary}万円'
                '${record.onLoan ? '  ·  ローン' : ''}'
                '${record.caps > 0 ? '  ·  代表${record.caps}' : ''}'
                '${record.continentalStage.participated ? '  ·  大陸${record.continentalStage.label}' : ''}'
                '${record.cupStage.participated ? '  ·  国内杯${record.cupStage.label}' : ''}'
                '${record.worldCupStage.participated ? '  ·  W杯${record.worldCupStage.label}' : ''}'
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

