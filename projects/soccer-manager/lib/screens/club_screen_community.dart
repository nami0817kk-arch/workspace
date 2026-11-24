part of 'club_screen.dart';

/// ファンと街の上の帯(2026-11-25 の第6段): 数字4つと、オフシーズンだけ
/// 変えられるもの(ロゴ・チケットの値段)の今の状態。
class _FansCityOverview extends StatelessWidget {
  const _FansCityOverview();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save!;
    final subtle = SemanticColors.subtleText(context);
    final open = gs.isOffseason;
    Widget stat(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: subtle)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        );
    return FmPanel(
      key: const ValueKey('fans-city-overview'),
      title: Tr.pick('ファンと街', 'Fans & city'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            runSpacing: 6,
            children: [
              stat(Tr.pick('サポーターの期待', 'Supporter expectation'),
                  '${save.confidence}/100'),
              stat(Tr.pick('来たいファン', 'Fans wanting to come'),
                  formatCount(gs.fanDemand)),
              stat(Tr.pick('ふだんの入り', 'Usual crowd'),
                  formatCount(gs.expectedAttendance)),
              stat(Tr.pick('収容', 'Capacity'), formatCount(gs.stadiumCapacity)),
              stat(Tr.pick('チケット', 'Tickets'), save.ticketPricing.label),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            key: ValueKey(open ? 'offseason-open' : 'offseason-closed'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: open
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(open ? Icons.lock_open : Icons.lock_clock_outlined,
                    size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    open
                        ? Tr.pick(
                            'オフシーズンです。クラブの見た目(ロゴ・色)とチケットの値段は、開幕までに変えられます。',
                            'It is the off-season: you can change the club look (crest and colours) and ticket prices until the season starts.')
                        : Tr.pick(
                            'シーズン中です。クラブの見た目(ロゴ・色)とチケットの値段は、来季の開幕前(オフシーズン)にだけ変えられます。',
                            'The season is on. The club look (crest and colours) and ticket prices can only change in the off-season, before next season starts.'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
