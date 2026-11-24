import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/board_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/risk_engine.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 地域貢献のレベル。続けている間は毎月サポーターの期待が上がり、不祥事の
/// 傷も浅くなる。
///
/// 以前は経営の「備えと地域貢献」の札の下半分にあった。地域の用件は
/// 「クラブ > ファンと街」に寄せる(2026-11-24)。中身と効き目は同じ。
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final level = save.communityLevel;
    final next = level + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('地域貢献 Lv$level / ${RiskEngine.maxCommunityLevel}',
                  'Community Lv$level / ${RiskEngine.maxCommunityLevel}'),
              help: Tr.pick(
                  '地域貢献(Lv1以上)を続けている間は、毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}。レベルを上げるほど、シーズンの終わりに起きうる不祥事の傷が浅くなります。',
                  'While you keep up community work (Lv1 or higher), supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month. Higher levels soften any scandal at season end.'),
            ),
            // Lv0 では「期待が0上がる」と出ていた。今の効き目があれば
            // それを、まだ無ければ次のレベルで何が起きるかを出す。
            Text(
              level == 0
                  ? Tr.pick(
                      'Lv1にすると地域活動が始まり、毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}されます。',
                      'At Lv1 community work begins, and supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month.')
                  : Tr.pick(
                      '地域活動を続けています。毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}されます。',
                      'Community work is ongoing: supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            FilledButton(
              key: const ValueKey('community-upgrade'),
              onPressed: level < RiskEngine.maxCommunityLevel
                  ? () => gs.upgradeCommunity()
                  : null,
              child: Text(level < RiskEngine.maxCommunityLevel
                  ? Tr.pick(
                      'Lv$nextにする(${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})',
                      'Raise to Lv$next (${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})')
                  : Tr.pick('最大です', 'Maxed')),
            ),
          ],
        ),
      ),
    );
  }
}
