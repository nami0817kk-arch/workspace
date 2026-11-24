import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/fan_segments.dart';
import '../state/game_state.dart';
import 'disabled_reason.dart';

/// ファンの層と、自治体のスタジアムの補助。
class FanSegmentsCard extends StatelessWidget {
  const FanSegmentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final moods = gs.fanMoods;
    final mod = gs.fanAttendanceModifier;
    final pct = ((mod - 1) * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('ファンの層', 'Fan base'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                Tr.pick(
                    '3つの層の満足で、観客の入りが${pct >= 0 ? '+' : ''}$pct%変わっています(上下5%まで)。',
                    'How happy each group is changes attendance by ${pct >= 0 ? '+' : ''}$pct% (up to 5% either way).'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            for (final seg in FanSegment.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(Tr.pick(
                                '${seg.label}(${(seg.share * 100).round()}%)',
                                '${seg.label} (${(seg.share * 100).round()}%)'))),
                        Text('${moods[seg] ?? 0}'),
                      ],
                    ),
                    LinearProgressIndicator(value: (moods[seg] ?? 0) / 100),
                    Text(seg.hint, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            const Divider(height: 20),
            Text(Tr.pick('自治体とスタジアム', 'Council and stadium'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (save.stadiumSubsidyPct > 0)
              Text(Tr.pick(
                  '補助が下りています。次のスタジアムの増築は${save.stadiumSubsidyPct}%引きです。',
                  'Funding approved: your next stadium expansion is ${save.stadiumSubsidyPct}% cheaper.'))
            else ...[
              Text(
                  Tr.pick(
                      '地元・家族の満足が55以上なら、自治体が次のスタジアムの増築の${GameStateFans.subsidyPct}%を持ってくれます(${GameStateFans.subsidyCooldown}季に1回まで頼める)。',
                      'If locals and families are happy (55+), the council pays ${GameStateFans.subsidyPct}% of your next stadium expansion (ask once every ${GameStateFans.subsidyCooldown} seasons).'),
                  style: const TextStyle(fontSize: 12)),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed:
                      gs.canAskMunicipality ? () => gs.askMunicipality() : null,
                  child: Text(Tr.pick('自治体に補助を頼む', 'Ask the council')),
                ),
              ),
              // 頼めるのは数季に1回。前に頼んでから間が空くまで押せない。
              if (!gs.canAskMunicipality)
                Align(
                  alignment: Alignment.centerRight,
                  child: Builder(builder: (context) {
                    final wait = save.municipalityAskSeason +
                        GameStateFans.subsidyCooldown -
                        save.league.season;
                    return DisabledReason(
                      Tr.pick('前に頼んだばかりです。あと$wait季たつと、また頼めます',
                          'You asked recently. You can ask again in ${Tr.plural(wait, 'season')}'),
                      key: const ValueKey('council-blocked'),
                      alignEnd: true,
                    );
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
