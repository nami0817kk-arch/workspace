import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/season_tickets.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 年間シート。開幕前に1回だけ、入場券の一部をまとめて売る。
class SeasonTicketsCard extends StatelessWidget {
  const SeasonTicketsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final sold = gs.seasonTicketShareNow;
    final rate = (SeasonTicketEngine.priceRate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 説明は「?」の中へ(2026-11-21)。
            TitleWithHelp(
              title: Tr.pick('年間シート', 'Season tickets'),
              help: Tr.pick(
                  '開幕前に、入場券の一部を1試合の$rate%の値段でまとめて売ります。お金はすぐ入り、成績が落ちても減りません。その代わり、勝って客が増えても増えません。',
                  'Before the season, sell part of your tickets up front at $rate% of the matchday price. The money comes in now and does not fall if results slump, but it does not grow if crowds do.'),
            ),
            if (sold > 0)
              Text(Tr.pick('今季は入場券の$sold%を年間シートで売りました',
                  'This season $sold% of tickets were sold as season tickets'))
            else if (!gs.canSellSeasonTickets)
              Text(Tr.pick('年間シートは開幕前にだけ売れます',
                  'Season tickets can only be sold before the season starts'))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final share in SeasonTicketEngine.shares.where((x) => x > 0))
                    OutlinedButton(
                      onPressed: () => gs.sellSeasonTickets(share),
                      child: Text(Tr.pick(
                          '$share%を売る(${formatMoney(gs.seasonTicketUpfront(share))})',
                          'Sell $share% (${formatMoney(gs.seasonTicketUpfront(share))})')),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
