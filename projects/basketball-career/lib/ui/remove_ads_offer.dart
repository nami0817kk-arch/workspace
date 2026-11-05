import 'package:flutter/material.dart';

import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// 購入・復元の結果を、利用者に見せる一言にする(取りやめは何も出さない)。
String? purchaseMessage(PurchaseOutcome r, {required bool restore}) => switch (r) {
      PurchaseOutcome.purchased => restore ? '購入を復元した。広告が出なくなった。' : 'ありがとう! 広告が出なくなった。',
      PurchaseOutcome.pending => '承認待ち。承認されると広告が消える。',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => restore ? '復元できる購入が見つからなかった。' : '購入できなかった。',
      PurchaseOutcome.failed => restore ? '復元に失敗した。あとでもう一度。' : '購入に失敗した。あとでもう一度。',
    };

/// 全画面広告のあとに、ときどき下から出す「広告を消す」の案内。閉じれば何も起きない。
/// 値段が取れない(ストアに繋がらない)ときは出さない。
Future<void> showRemoveAdsOffer(BuildContext context, Monetization money) async {
  final price = await money.price;
  if (price == null || money.adFree || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final r = await showModalBottomSheet<PurchaseOutcome>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => RemoveAdsOffer(price: displayPrice(price), money: money),
  );
  final msg = r == null ? null : purchaseMessage(r, restore: false);
  if (msg != null) {
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  }
}

class RemoveAdsOffer extends StatefulWidget {
  const RemoveAdsOffer({super.key, required this.price, required this.money});
  final String price;
  final Monetization money;

  @override
  State<RemoveAdsOffer> createState() => _RemoveAdsOfferState();
}

class _RemoveAdsOfferState extends State<RemoveAdsOffer> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    PurchaseOutcome r;
    try {
      r = await widget.money.buy();
    } catch (_) {
      r = PurchaseOutcome.failed;
    }
    // 届いた購入は Monetization が受け取っている(画面が閉じられていても広告は消える)。ここは結果を伝えるだけ
    if (mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('広告なしで遊ぶ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            line(Icons.block_rounded, '大会のあとの全画面広告が出なくなる'),
            line(Icons.bolt_rounded, '回復と特殊能力ポイントが、動画なしで受け取れる(回数は同じ)'),
            line(Icons.all_inclusive_rounded, '一度買えばずっと。機種を変えても「購入を復元」で戻せる'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _buy,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('広告を消す(${widget.price})'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('今はいい'),
            ),
          ],
        ),
      ),
    );
  }
}
