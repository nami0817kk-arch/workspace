import 'package:flutter/material.dart';

import '../../game/career_engine.dart';
import '../../game/formulas.dart';
import '../../state/career_controller.dart';

/// シーズン終了。成績を振り返り、移籍・残留・引退を決める。
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

  Future<void> _retire() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引退しますか'),
        content: const Text('引退すると試合はできなくなり、通算成績だけが残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('引退する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await widget.controller.retire();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final state = controller.state!;
    final stats = state.seasonStats;
    final offers = controller.offers;
    final fate = controller.fate;
    final mustRetire = controller.mustRetire;
    final canRetire = controller.canRetire;

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
                    if (fate != ClubFate.stay) ...[
                      const SizedBox(height: 6),
                      _FateChip(fate: fate),
                    ],
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
            if (mustRetire) ...[
              Text(
                '${state.player.age}歳。体は限界を迎えた。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _retire,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('引退する'),
                ),
              ),
            ] else ...[
              if (offers.isEmpty)
                Text(
                  _stayText(state.club.name, fate),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else ...[
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
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : () => _advance(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_stayLabel(fate)),
                ),
              ),
              if (canRetire) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _retire,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('引退する'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${Formulas.retirementForcedAge}歳のシーズンを終えると引退になる。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _stayText(String clubName, ClubFate fate) => switch (fate) {
        ClubFate.promoted => 'オファーは無かったが、$clubNameは1部へ昇格する。',
        ClubFate.relegated => 'オファーは届かなかった。$clubNameは2部へ降格する。',
        ClubFate.stay => 'オファーは届かなかった。来季も$clubNameで戦う。',
      };

  String _stayLabel(ClubFate fate) => switch (fate) {
        ClubFate.promoted => '昇格して次のシーズンへ',
        ClubFate.relegated => '降格して次のシーズンへ',
        ClubFate.stay => '残留して次のシーズンへ',
      };

  Widget _stat(ThemeData theme, String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      );
}

class _FateChip extends StatelessWidget {
  const _FateChip({required this.fate});

  final ClubFate fate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final promoted = fate == ClubFate.promoted;
    return Chip(
      label: Text(promoted ? '1部昇格' : '2部降格'),
      backgroundColor: promoted
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      labelStyle: TextStyle(
        color: promoted
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onErrorContainer,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
