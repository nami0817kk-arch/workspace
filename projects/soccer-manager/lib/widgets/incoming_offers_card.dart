import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/sale_advice_engine.dart';
import '../models/incoming_offer.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 移籍オファーを選手ごとにグループ化し、各グループ内は金額の高い順に並べる
/// (複数クラブが競合している場合、最高額が先頭に来る)。
List<List<IncomingOffer>> groupOffersByPlayer(List<IncomingOffer> offers) {
  final byPlayer = <String, List<IncomingOffer>>{};
  for (final o in offers) {
    byPlayer.putIfAbsent(o.playerId, () => []).add(o);
  }
  for (final group in byPlayer.values) {
    group.sort((a, b) => b.amount.compareTo(a.amount));
  }
  return byPlayer.values.toList();
}

Player? _playerOf(GameState gameState, IncomingOffer offer) {
  for (final p in gameState.userTeam.players) {
    if (p.id == offer.playerId) return p;
  }
  return null;
}

/// 他のクラブから届いた、自分の選手への移籍オファー。受ける・断る・対案を
/// その場で選べる。状況(ホーム)と移籍の画面の「届いたオファー」で同じ物を使う。
class IncomingOffersCard extends StatelessWidget {
  const IncomingOffersCard({super.key, this.showTitle = true});

  /// 見出し「移籍オファー」を出すか(移籍の画面ではタブ名と重なるので出さない)。
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    if (gameState.incomingOffers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final windowOpen = gameState.isTransferWindowOpen;
    final nextWindow = gameState.nextTransferWindow;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Text(
                Tr.pick('移籍オファー', 'Transfer offers'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            // 窓が閉じている間は承諾できない。ボタンが薄いだけで理由が
            // 無かったので、ホームの札にはいつ開くかを書く(2026-11-23)。
            // 移籍の画面は上の帯に窓の状態が出ているので出さない。
            if (showTitle && !windowOpen)
              Padding(
                key: const ValueKey('offers-window-closed'),
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        nextWindow == null
                            ? Tr.pick('移籍の窓が開くと承諾できます。',
                                'You can accept once the transfer window opens.')
                            : Tr.pick(
                                '移籍の窓が開くと承諾できます(${CalendarEngine.formatShortDate(nextWindow.opens)}から)。',
                                'You can accept once the transfer window opens (from ${CalendarEngine.formatShortDate(nextWindow.opens)}).'),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            for (final entry in groupOffersByPlayer(gameState.incomingOffers))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          Tr.pick('${entry.first.playerName}に競合オファー',
                              'Rival bids for ${entry.first.playerName}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: SemanticColors.ink(
                                context, Colors.orange.shade800),
                          ),
                        ),
                      ),
                    for (int i = 0; i < entry.length; i++)
                      // 狭い欄・大きな文字では、ボタンを本文の下の行へ回す
                      // (文字1.5倍の英語で、本文が細い列に押し込まれ、
                      // ボタンが右へはみ出していた)。
                      LayoutBuilder(
                        builder: (context, c) {
                          final label = Row(
                            children: [
                              if (entry.length > 1 && i == 0)
                                Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.star,
                                    size: 14,
                                    color: SemanticColors.ink(
                                        context, Colors.amber,
                                        min: 3),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  Tr.pick(
                                      '${entry[i].buyerClubName}が${entry[i].playerName}に${formatMoney(entry[i].amount)}${entry[i].isFinal ? '(これ以上は出さない)' : ''}',
                                      '${entry[i].buyerClubName} bid ${formatMoney(entry[i].amount)} for ${entry[i].playerName}${entry[i].isFinal ? ' (final)' : ''}'),
                                ),
                              ),
                            ],
                          );
                          final buttons = <Widget>[
                            if (entry[i].askedAmount != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  Tr.pick('返事待ち', 'Awaiting reply'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SemanticColors.subtleText(context),
                                  ),
                                ),
                              )
                            else if (gameState
                                .canCounterIncomingOffer(entry[i]))
                              OutlinedButton(
                                onPressed: () =>
                                    showCounterOfferDialog(context, entry[i]),
                                child: Text(Tr.pick('対案', 'Counter')),
                              ),
                            TextButton(
                              onPressed: () {
                                FeedbackService.tap();
                                gameState.declineIncomingOffer(entry[i].id);
                              },
                              child: Text(Tr.pick('拒否', 'Reject')),
                            ),
                            FilledButton(
                              // 押せないときも字が読めるように、地と字の色を
                              // テーマから取る(既定は暗い地に沈む灰色だった)。
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor:
                                    scheme.surfaceContainerHighest,
                                disabledForegroundColor:
                                    scheme.onSurfaceVariant,
                              ),
                              onPressed: !windowOpen
                                  ? null
                                  : () => confirmAcceptIncomingOffer(
                                      context, entry[i]),
                              child: Text(Tr.pick('承諾', 'Accept')),
                            ),
                          ];
                          final scale =
                              MediaQuery.textScalerOf(context).scale(1);
                          if (c.maxWidth / scale < 300) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                label,
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: buttons,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: label),
                              ...buttons,
                            ],
                          );
                        },
                      ),
                    // 監督の見立て。買い手ごとに1行。
                    for (int i = 0; i < entry.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          Tr.pick('監督: ', 'Manager: ') +
                              SaleAdviceEngine.advise(
                                entry[i],
                                _playerOf(gameState, entry[i]),
                                gameState.userTeam,
                              ).comment,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
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

/// 来たオファーに、もっと高い額を求める。
Future<void> showCounterOfferDialog(
    BuildContext context, IncomingOffer offer) async {
  var ratio = 1.15;
  final asked = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final amount = (offer.amount * ratio).round();
        return AlertDialog(
          title: Text(Tr.pick('${offer.buyerClubName}に対案を返す',
              'Counter ${offer.buyerClubName}')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick('今の提示: ${formatMoney(offer.amount)}',
                  'Their bid: ${formatMoney(offer.amount)}')),
              Text(Tr.pick(
                  '求める額: ${formatMoney(amount)}(+${((ratio - 1) * 100).round()}%)',
                  'You ask: ${formatMoney(amount)} (+${((ratio - 1) * 100).round()}%)')),
              Slider(
                value: ratio,
                min: 1.05,
                max: 1.6,
                divisions: 11,
                onChanged: (v) => setState(() => ratio = v),
              ),
              Text(
                Tr.pick(
                    '買い手が出せる額には上限があります。求めすぎると話を打ち切られます。返事は2日ほどで来ます。対案を返せるのは1回だけです。',
                    'Every buyer has a limit. Ask too much and they walk away. They reply in about 2 days. You can only counter once.'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Tr.pick('やめる', 'Never mind')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, amount),
              child: Text(Tr.pick('対案を返す', 'Send counter')),
            ),
          ],
        );
      },
    ),
  );
  if (asked == null || !context.mounted) return;
  FeedbackService.tap();
  await context.read<GameState>().counterIncomingOffer(offer.id, asked);
}

/// オファーを受ける前の確認。売った選手は戻らない。
void confirmAcceptIncomingOffer(BuildContext context, IncomingOffer offer) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(Tr.pick('この移籍オファーを承諾しますか？', 'Accept this transfer offer?')),
      content: Text(
        Tr.pick(
            '${offer.playerName}が${offer.buyerClubName}へ${formatMoney(offer.amount)}で移籍します。この操作は元に戻せません。',
            '${offer.playerName} joins ${offer.buyerClubName} for ${formatMoney(offer.amount)}. This cannot be undone.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(Tr.pick('キャンセル', 'Cancel')),
        ),
        if (!offer.viaReleaseClause)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.success();
              context
                  .read<GameState>()
                  .acceptIncomingOfferWithBuyBack(offer.id);
            },
            child: Text(Tr.pick(
                '買い戻し条項付きで承諾(売値-10%)', 'Accept with a buy-back clause (-10%)')),
          ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            FeedbackService.success();
            context.read<GameState>().acceptIncomingOffer(offer.id);
          },
          child: Text(Tr.pick('承諾する', 'Accept')),
        ),
      ],
    ),
  );
}
