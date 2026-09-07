import 'package:flutter/material.dart';

import '../../game/career_engine.dart';
import '../../state/career_controller.dart';

/// シーズン終了。成績を振り返り、移籍するか残留するかを決める。
class SeasonEndScreen extends StatefulWidget {
  const SeasonEndScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<SeasonEndScreen> createState() => _SeasonEndScreenState();
}

class _SeasonEndScreenState extends State<SeasonEndScreen> {
  bool _busy = false;

  Future<void> _advance({TransferOffer? offer}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.controller.advanceSeason(moveTo: offer?.club);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state!;
    final stats = state.seasonStats;
    final offers = widget.controller.offers;

    return Scaffold(
      appBar: AppBar(
        title: Text('${state.year}シーズン終了'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${state.club.name}  ${state.leaguePosition}位',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
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
            if (offers.isEmpty) ...[
              Text(
                'オファーは届かなかった。来季も${state.club.name}で戦う。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _advance(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('次のシーズンへ'),
                ),
              ),
            ] else ...[
              Text('移籍オファー', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final offer in offers) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${offer.club.name}（${offer.club.tier}部）',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(offer.reason,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed:
                              _busy ? null : () => _advance(offer: offer),
                          child: const Text('移籍する'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _advance(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('残留する'),
                ),
              ),
            ],
          ],
        ),
      ),
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
