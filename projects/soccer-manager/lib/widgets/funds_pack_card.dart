import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../monetization/funds_delivery.dart';
import '../monetization/funds_pack.dart';
import '../monetization/monetization_controller.dart';
import '../monetization/purchase_service.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';

/// 資金を買い切りで受け取るカード。クラブ経営画面に置く。
///
/// ストアに繋がらない環境 (Web版・未接続) では丸ごと消える。押しても何も
/// 起きないボタンを残すより、無いほうがよい ([RewardFundsCard] と同じ方針)。
class FundsPackCard extends StatefulWidget {
  const FundsPackCard({super.key});

  @override
  State<FundsPackCard> createState() => _FundsPackCardState();
}

class _FundsPackCardState extends State<FundsPackCard> {
  /// 購入中のパック。二重に押させないために持つ。
  FundsPack? _busy;

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MonetizationController>();
    final gameState = context.watch<GameState>();
    if (!money.initialized ||
        !money.storeAvailable ||
        gameState.save == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Tr.pick('資金を購入', 'Buy funds'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  'クラブ資金をその場で増やせます。回数の制限はありません。'
                      '買わなくてもゲームは最後まで遊べます。',
                  'Adds money to the club budget straight away, as often as you '
                      'like. You can finish the game without buying any.'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final pack in FundsPack.values) ...[
              _PackRow(
                pack: pack,
                amount: gameState.purchasedFundsAmount(pack),
                price: money.fundsPackPrices[pack],
                busy: _busy == pack,
                // 1つ買っている間は、他のボタンも押せなくする。
                enabled: _busy == null,
                onBuy: () => _buy(pack),
              ),
              if (pack != FundsPack.values.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _buy(FundsPack pack) async {
    FeedbackService.tap();
    setState(() => _busy = pack);
    final money = context.read<MonetizationController>();
    final gameState = context.read<GameState>();

    final outcome = await money.buyFundsPack(pack);
    if (!mounted) return;
    setState(() => _busy = null);

    // Tr.pick は日本語と英語の両方を引数として受け取るため、どちらの文字列も
    // 評価される。受け取り処理を文字列の中に書くと2回加算される(実際に
    // 特典側でそうなっていた)。必ず外で1回だけ呼ぶこと。
    //
    // 加算するのは「このパック」ではなく「預かっているぶん全部」。買った
    // ぶんはストアからの通知で預かりに入るので、ここで直接このパックを
    // 足すと、通知で入ったぶんと二重になる。
    final granted = await deliverPendingFunds(money, gameState);

    final message = switch (outcome) {
      PurchaseOutcome.purchased =>
        Tr.pick('$granted万円をクラブ資金に追加しました', 'Added $granted to the club budget'),
      // 自分で取りやめただけなので、責めるような文言にしない。
      PurchaseOutcome.canceled =>
        Tr.pick('購入を取りやめました', 'Purchase cancelled'),
      PurchaseOutcome.unavailable => Tr.pick(
          'いま購入できません。時間をおいてお試しください', 'Not available right now. Please try again later'),
      PurchaseOutcome.failed =>
        Tr.pick('購入を完了できませんでした', 'The purchase could not be completed'),
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PackRow extends StatelessWidget {
  final FundsPack pack;
  final int amount;
  final String? price;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;

  const _PackRow({
    required this.pack,
    required this.amount,
    required this.price,
    required this.busy,
    required this.enabled,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pack.label,
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(
                Tr.pick('$amount万円', amount.toString()),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: enabled ? onBuy : null,
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // 価格はストアから取る。取れないときは国や通貨を推測しない。
              : Text(price ?? Tr.pick('購入', 'Buy')),
        ),
      ],
    );
  }
}
