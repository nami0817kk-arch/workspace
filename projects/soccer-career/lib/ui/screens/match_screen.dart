import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/match_engine.dart';
import '../../game/scenarios.dart';
import '../../models/attributes.dart';
import '../../models/injury.dart';
import '../../models/news.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import '../club_identity.dart';
import '../readable_width.dart';

/// 1試合を進める画面。局面 → 結果 → 次の局面、を繰り返す。
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  ScenarioResolution? _last;
  MatchResult? _result;
  bool _busy = false;

  Future<void> _choose(int index) async {
    if (_busy) return;
    setState(() {
      _last = widget.controller.choose(index);
    });
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.controller.finishMatch();
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  Future<void> _simulateRest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.controller.simulateMatch();
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.controller.currentMatch;
    final result = _result;

    if (result != null) {
      return _MatchSummary(
        result: result,
        week: widget.controller.lastWeek,
        // その試合について書かれた見出しがあれば、結果と一緒に見せる。
        headline: widget.controller.news
            .where((n) => n.matchday == result.matchday)
            .take(1)
            .toList(),
      );
    }
    if (match == null) return const SizedBox.shrink();

    if (match.appearance == Appearance.benched) {
      return _BenchedView(
        onDone: _finish,
        busy: _busy,
        // 何試合続けて外れているか。戻り道を数字で見せる。
        idle: MatchEngine.idleRun(widget.controller.state!.leagueResults),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('第${match.matchday}節  vs ${match.opponent.name}'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ReadableWidth(
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MatchHeader(match: match),
              const SizedBox(height: 20),
              Expanded(
                child: match.isFinished
                    ? _ReadyToFinish(last: _last, onFinish: _finish, busy: _busy)
                    : _ScenarioView(
                        match: match,
                        last: _last,
                        seasonStart: widget.controller.state!.seasonStart,
                        onChoose: _choose,
                      ),
              ),
              if (!match.isFinished)
                TextButton(
                  onPressed: _busy ? null : _simulateRest,
                  child: Text('残りを自動で進める（${widget.controller.state!.simStyle.label}）'),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final MatchInProgress match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 今どうなっているか。1点負けている終盤の1本と、
        // 3点リードでの1本は、同じ手でも意味が違う。
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      match.home ? match.club.name : match.opponent.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClubCrest(
                      club: match.home ? match.club : match.opponent, size: 26),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                match.home
                    ? match.scoreLine
                    : '${match.concededBy(match.isFinished ? 90 : match.currentMinute)} - '
                        '${match.scoredBy(match.isFinished ? 90 : match.currentMinute)}',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  ClubCrest(
                      club: match.home ? match.opponent : match.club, size: 26),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      match.home ? match.opponent.name : match.club.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          match.home ? 'ホーム・${match.appearance.label}' : 'アウェイ・${match.appearance.label}',
          style: muted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat(theme, '局面', '${match.currentIndex}/${match.scenarios.length}'),
            _stat(theme, '評価点', match.rating.toStringAsFixed(1)),
            _stat(theme, 'G / A', '${match.goals} / ${match.assists}'),
            _stat(theme, '調子', '${match.player.condition}'),
          ],
        ),
      ],
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      );
}

class _ScenarioView extends StatelessWidget {
  const _ScenarioView({
    required this.match,
    required this.last,
    required this.seasonStart,
    required this.onChoose,
  });

  final MatchInProgress match;
  final ScenarioResolution? last;

  /// 今季の開幕時の能力値。局面のたびに、練習ぶんの伸びを添える。
  final Attributes? seasonStart;

  final void Function(int) onChoose;

  /// その手に使う能力が、今季どれだけ伸びたか。記録が無ければ 0。
  int _growthOf(ScenarioOption option) {
    final before = seasonStart;
    if (before == null) return 0;
    final was = option.detail != null
        ? before.detail(option.detail!)
        : before[option.key];
    return match.attributeFor(option) - was;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scenario = match.current;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last != null) _ResolutionCard(resolution: last!),
          if (last != null) const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${MatchInProgress.minuteLabel(match.currentMinute)}'
                    ' ・ ${match.scoreLine}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(scenario.situation,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text(match.opponentStyle.label),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (match.situationLabel != null)
                        Chip(
                          label: Text(match.situationLabel!),
                          backgroundColor: match.margin < 0
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.secondaryContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (match.bigMatch)
                        Chip(
                          label: const Text('大一番'),
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (match.weakFootMoment)
                        Chip(
                          label: const Text('逆足で対応'),
                          backgroundColor: theme.colorScheme.errorContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < scenario.options.length; i++) ...[
            _OptionButton(
              option: scenario.options[i],
              attribute: match.attributeFor(scenario.options[i]),
              growth: _growthOf(scenario.options[i]),
              chance: match.chanceFor(scenario.options[i]),
              onPressed: () => onChoose(i),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.attribute,
    required this.growth,
    required this.chance,
    required this.onPressed,
  });

  final ScenarioOption option;
  final int attribute;

  /// 今季の開幕からの伸び。練習がこの局面に効いていることを、
  /// 選ぶその場で見せるためのもの。0 なら何も出さない。
  final int growth;

  /// 特性とコンディションを含んだ成功率。判定と同じ値。
  final double chance;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (chance * 100).round();
    // 数字だけだと、3つの手を見比べるのに毎回読む必要がある。
    // 帯があれば、どれが堅くてどれが賭けかが一目で分かる。
    final color = chance >= 0.6
        ? theme.colorScheme.primary
        : chance >= 0.4
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(option.label, style: theme.textTheme.titleSmall),
              ),
              if (option.outcome != Outcome.play)
                // 手が通る確率と、それが点になる確率は別。
                // 「決まるのは半分ほど」を数字で見せておく。
                Chip(
                  label: Text(option.outcome == Outcome.goal
                      ? 'ゴール ${(chance * Formulas.goalConversion * 100).round()}%'
                      : 'アシスト ${(chance * Formulas.assistConversion * 100).round()}%'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text('$percent%',
                    style: theme.textTheme.titleSmall?.copyWith(color: color)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: chance,
                    minHeight: 6,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${option.detail?.label ?? option.key.label} $attribute',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (growth > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('↑$growth',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.resolution});

  final ScenarioResolution resolution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = resolution.success
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = resolution.success
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resolution.isGoal
                ? 'ゴール'
                : resolution.isAssist
                    ? 'アシスト'
                    : resolution.success
                        ? '成功'
                        : '失敗',
            style: theme.textTheme.labelLarge?.copyWith(color: onColor),
          ),
          const SizedBox(height: 4),
          Text(resolution.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor)),
        ],
      ),
    );
  }
}

class _ReadyToFinish extends StatelessWidget {
  const _ReadyToFinish({
    required this.last,
    required this.onFinish,
    required this.busy,
  });

  final ScenarioResolution? last;
  final VoidCallback onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null) _ResolutionCard(resolution: last!),
        const Spacer(),
        FilledButton(
          onPressed: busy ? null : onFinish,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('試合終了'),
          ),
        ),
      ],
    );
  }
}

class _BenchedView extends StatelessWidget {
  const _BenchedView({
    required this.onDone,
    required this.busy,
    this.idle = 0,
  });

  final VoidCallback onDone;
  final bool busy;

  /// 何試合続けて外れているか。
  final int idle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 次に外れると何試合連続になるか。そこで必ず一度は声がかかる。
    final remaining = Formulas.benchPatience - (idle + 1);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ベンチ外', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '直近の評価点が低く、今節は招集されなかった。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                remaining <= 0
                    ? '外れ続けている。次節は途中出場から声がかかる。'
                    : 'あと$remaining試合外れると、まずは途中出場から戻ることになる。'
                        '練習で調子を戻しておく。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: busy ? null : onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('結果を見る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchSummary extends StatelessWidget {
  const _MatchSummary({
    required this.result,
    required this.week,
    this.headline = const [],
  });

  final MatchResult result;

  /// その1週間で起きたこと（練習の成果・負傷・復帰）。
  final WeekReport week;

  /// その試合について世に出た見出し。
  final List<NewsItem> headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = result.won ? '勝利' : (result.drawn ? '引き分け' : '敗戦');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('${result.scoreLine}   vs ${result.opponentName}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(theme, '評価点',
                      result.rating?.toStringAsFixed(1) ?? '—'),
                  _stat(theme, 'ゴール', '${result.goals}'),
                  _stat(theme, 'アシスト', '${result.assists}'),
                ],
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(headline.first.headline,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall),
                      if (headline.first.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(headline.first.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
              if (week.timeline.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Timeline(events: week.timeline),
              ],
              if (week.deadBall != null) ...[
                const SizedBox(height: 20),
                Text(
                  week.deadBall!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (week.trained != null) ...[
                const SizedBox(height: 20),
                Text(
                  week.redirected
                      ? '土台から鍛え直した: ${week.trained!.label} が 1 伸びた'
                      : '練習の成果: ${week.trained!.label} が 1 伸びた',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (week.drilled != null) ...[
                const SizedBox(height: 12),
                Text(
                  '居残りの成果: ${week.drilled!.label} の精度が上がった',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (week.learned != null) ...[
                const SizedBox(height: 12),
                Text(
                  '個人技を覚えた: ${week.learned!.label}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (week.weakFootAwakened) ...[
                const SizedBox(height: 12),
                Text(
                  '逆足が形になってきた。両足で持てる選手になりつつある。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (week.plateau) ...[
                const SizedBox(height: 12),
                Text(
                  '伸び悩んでいる。しばらくは積み上がらない。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (week.recovered) ...[
                const SizedBox(height: 20),
                Text(
                  '離脱から復帰した。コンディションはまだ戻っていない。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (week.newInjury != null) ...[
                const SizedBox(height: 20),
                _InjuryNotice(injury: week.newInjury!),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      );
}

/// 負傷を伝えるカード。重傷は後遺症まで書く。
class _InjuryNotice extends StatelessWidget {
  const _InjuryNotice({required this.injury});

  final Injury injury;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severe = injury.severity == InjurySeverity.severe;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '負傷: ${injury.name}（${injury.severity.label}）',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 4),
          Text(
            '${injury.matchesOut}試合の離脱',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
          if (severe) ...[
            const SizedBox(height: 4),
            Text(
              '長期離脱。体は元どおりにはならない。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ],
        ],
      ),
    );
  }
}

/// 試合で起きたことを時間順に並べる。
///
/// 数字だけの結果は、38試合ぶん並べても記憶に残らない。
/// 「78分に決めて追いついた」が残ると、シーズンが物語になる。
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<MatchEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('試合の流れ',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final event in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('${event.minute}分',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                Icon(
                  event.kind == MatchEventKind.conceded
                      ? Icons.remove_circle_outline
                      : event.kind == MatchEventKind.ownGoal
                          ? Icons.sports_soccer
                          : event.kind == MatchEventKind.ownAssist
                              ? Icons.trending_up
                              : Icons.check_circle_outline,
                  size: 16,
                  color: event.kind.isOurs
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  event.kind.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: event.kind == MatchEventKind.ownGoal ||
                            event.kind == MatchEventKind.ownAssist
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
