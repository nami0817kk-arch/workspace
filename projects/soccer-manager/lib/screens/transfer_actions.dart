import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/transfer_talk_engine.dart';
import '../logic/transfer_terms_engine.dart';
import '../logic/transfer_window.dart';
import '../models/player.dart';
import '../models/transfer_talk.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/disabled_reason.dart';
import 'contract_offer_screen.dart';
import 'transfer_bid_screen.dart';

/// 他のクラブ・所属なしの選手への獲得の操作(2026-11-25 に移籍の画面から
/// 分けた)。移籍の一覧の行の「獲得」と、選手の詳しい画面の「操作」から
/// 同じものを開く。

/// 移籍金を提示する画面(FM の提示の画面)を開く。[talk]は対案に出し直す
/// とき。
Future<void> openTransferBid(BuildContext context, Player player,
    {TransferTalk? talk}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TransferBidScreen(playerId: player.id, talk: talk)));
}

/// 選手(代理人)に年俸・契約の満了の年・サイン料を出す(クラブと合意した
/// あと、または所属なしの選手)。
Future<void> openPersonalTerms(BuildContext context, Player player) async {
  await openContractOffer(context, player: player, kind: ContractKind.signing);
}

/// 獲得の選び方(移籍金を提示・ローン3種)を出す。
void showAcquireSheet(BuildContext context, Player player) {
  final gameState = context.read<GameState>();
  final save = gameState.save!;
  final total = player.marketValue;
  final agentFee = TransferTermsEngine.agentFee(total);
  final talk = gameState.talkFor(player.id);
  final loanFee = (total * GameState.loanFeeRatioPercent / 100).round();
  final buyOptionFee = (total * GameState.loanBuyOptionRatio).round();
  // 窓の外で開けるのは GK の緊急の特例だけ。そのときは期限付き(ローン)のみ。
  final permanentAllowed = gameState.isTransferWindowOpen;
  final obligationFee =
      (loanFee * GameStateForms.obligationLoanFeeFactor).round();
  // 選べない選び方には、説明の下に理由を出す(灰色になるだけだった)。
  final windowShut = Tr.pick(
      '移籍の窓が閉じているあいだは選べません', 'Not available while the transfer window is shut');
  Widget sub(String text, String? reason) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          DisabledReason(reason, padding: const EdgeInsets.only(top: 2)),
        ],
      );

  // 横画面は縦が短く、4つの選び方の下が切れていた。中でスクロールでき、
  // 横画面では2列に並べる。
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final wide = size.width > size.height;
      Widget cell(Widget tile) => wide
          ? SizedBox(
              width: ((size.width < 760 ? size.width : 760) - 48) / 2,
              child: tile)
          : tile;
      Future<void> loan({bool option = false, bool obligation = false}) async {
        Navigator.pop(ctx);
        final length = await chooseLoanLength(context);
        if (length == null || !context.mounted) return;
        await runAcquire(
          context,
          () => gameState.signLoanPlayer(player.id,
              withBuyOption: option, withObligation: obligation, length: length),
          player.name,
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.pick('${player.name}を獲得', 'Sign ${player.name}'),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(children: [
                  cell(ListTile(
                    key: const ValueKey('acquire-bid'),
                    leading: const Icon(Icons.handshake),
                    title: Text(Tr.pick('移籍金を提示する', 'Make a bid')),
                    subtitle: sub(
                        talk != null
                            ? Tr.pick('もう交渉しています(「交渉とオファー」で続きを)',
                                'Talks are already under way (see Talks & offers)')
                            : Tr.pick(
                                '相手のクラブと交渉します。返事は${TransferTalkEngine.replyDays}日ほどで来ます(別に代理人手数料${formatMoney(agentFee)}ほど)',
                                'Open talks with his club. They reply in about ${TransferTalkEngine.replyDays} days (plus about ${formatMoney(agentFee)} in agent fees)'),
                        talk == null && !permanentAllowed ? windowShut : null),
                    enabled: permanentAllowed && talk == null,
                    onTap: () {
                      Navigator.pop(ctx);
                      openTransferBid(context, player);
                    },
                  )),
                  cell(ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(Tr.pick('ローンで獲得', 'Take him on loan')),
                    subtitle: sub(
                      Tr.pick(
                          '契約金${formatMoney(loanFee)}・給与の6割を負担・期間は半年(冬の窓まで)か1年(シーズン末まで)',
                          '${formatMoney(loanFee)} fee, 60% of his wages, for half a season (to the winter window) or the full season'),
                      save.budget >= loanFee
                          ? null
                          : fundsShortReason(loanFee - save.budget),
                    ),
                    enabled: save.budget >= loanFee,
                    onTap: () => loan(),
                  )),
                  cell(ListTile(
                    leading: const Icon(Icons.request_quote),
                    title: Text(Tr.pick(
                        '買取オプション付きローンで獲得', 'Loan with an option to buy')),
                    subtitle: sub(
                      Tr.pick(
                          '契約金${formatMoney(loanFee)}・給与の6割を負担・ローン期間中いつでも${formatMoney(buyOptionFee)}で完全移籍化可能',
                          '${formatMoney(loanFee)} fee, 60% of his wages, and you can make it permanent for ${formatMoney(buyOptionFee)} at any point'),
                      save.budget >= loanFee
                          ? null
                          : fundsShortReason(loanFee - save.budget),
                    ),
                    enabled: save.budget >= loanFee,
                    onTap: () => loan(option: true),
                  )),
                  cell(ListTile(
                    leading: const Icon(Icons.gavel),
                    title: Text(Tr.pick(
                        '買取義務付きローンで獲得', 'Loan with an obligation to buy')),
                    subtitle: sub(
                      Tr.pick(
                          '契約金${formatMoney(obligationFee)}(ふつうの半分)・給与の6割を負担・満了したら必ず${formatMoney(buyOptionFee)}で買い取る',
                          '${formatMoney(obligationFee)} fee (half the usual), 60% of his wages, and you must buy him for ${formatMoney(buyOptionFee)} when it ends'),
                      !permanentAllowed
                          ? windowShut
                          : save.budget >= obligationFee
                              ? null
                              : fundsShortReason(obligationFee - save.budget),
                    ),
                    enabled: permanentAllowed && save.budget >= obligationFee,
                    onTap: () => loan(obligation: true),
                  )),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// ローンの長さを選ぶ。半年は冬の窓が開く日まで、1年はシーズン末まで。
/// 冬の窓より後(半年が組めない時期)は1年だけ。
Future<LoanLength?> chooseLoanLength(BuildContext context) {
  final gameState = context.read<GameState>();
  final theme = gameState.currentLeagueTheme;
  final today = gameState.today;
  final halfOk = TransferWindowCalendar.halfLoanAvailable(today, theme);
  final halfEnd = TransferWindowCalendar.formatMonthDay(
      TransferWindowCalendar.loanEndDate(today, theme, LoanLength.half));
  final fullEnd = TransferWindowCalendar.formatMonthDay(
      TransferWindowCalendar.loanEndDate(today, theme, LoanLength.full));
  return showDialog<LoanLength>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(Tr.pick('ローンの期間', 'Loan length')),
      children: [
        if (halfOk)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, LoanLength.half),
            child: Text(Tr.pick('半年(冬の窓が開く$halfEndまで)',
                'Half a season (until the winter window opens, $halfEnd)')),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, LoanLength.full),
          child: Text(Tr.pick(
              '1年(シーズン末の$fullEndまで)', 'Full season (until $fullEnd)')),
        ),
      ],
    ),
  );
}

/// 獲得を行い、結果を下の帯で知らせる。
Future<void> runAcquire(
  BuildContext context,
  Future<bool> Function() action,
  String name,
) async {
  final gameState = context.read<GameState>();
  final ok = await action();
  ok ? FeedbackService.success() : FeedbackService.error();
  if (context.mounted) {
    final reason = gameState.lastSigningBlockReason;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? Tr.pick('$nameを獲得しました', 'You signed $name')
            : (reason ??
                Tr.pick('獲得できませんでした', 'The signing did not go through'))),
        duration: Duration(seconds: reason != null && !ok ? 6 : 4),
      ),
    );
  }
}
