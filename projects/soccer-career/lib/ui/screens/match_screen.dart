import 'package:flutter/material.dart';

import '../../game/match_engine.dart';
import '../../game/scenarios.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final match = widget.controller.currentMatch;
    final result = _result;

    if (result != null) return _MatchSummary(result: result);
    if (match == null) return const SizedBox.shrink();

    if (match.appearance == Appearance.benched) {
      return _BenchedView(onDone: _finish, busy: _busy);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('第${match.matchday}節  vs ${match.opponent.name}'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
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
                        onChoose: _choose,
                      ),
              ),
            ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stat(theme, match.home ? 'ホーム' : 'アウェイ', match.appearance.label),
        _stat(theme, '局面', '${match.currentIndex}/${match.scenarios.length}'),
        _stat(theme, '評価点', match.rating.toStringAsFixed(1)),
        _stat(theme, 'G / A', '${match.goals} / ${match.assists}'),
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
    required this.onChoose,
  });

  final MatchInProgress match;
  final ScenarioResolution? last;
  final void Function(int) onChoose;

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
              child: Text(scenario.situation,
                  style: theme.textTheme.titleMedium),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < scenario.options.length; i++) ...[
            _OptionButton(
              option: scenario.options[i],
              attribute: match.player.attributes[scenario.options[i].key],
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
    required this.onPressed,
  });

  final ScenarioOption option;
  final int attribute;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chance = MatchInProgress.successChance(attribute, option.difficulty);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${option.key.label} $attribute  ·  成功率 ${(chance * 100).round()}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (option.outcome != Outcome.play)
            Chip(
              label:
                  Text(option.outcome == Outcome.goal ? 'ゴール' : 'アシスト'),
              visualDensity: VisualDensity.compact,
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
  const _BenchedView({required this.onDone, required this.busy});

  final VoidCallback onDone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                '直近の評価点が低く、今節は招集されなかった。'
                '出場すれば評価は上げ直せる。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
  const _MatchSummary({required this.result});

  final MatchResult result;

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
