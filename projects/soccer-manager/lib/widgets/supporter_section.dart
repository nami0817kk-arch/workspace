import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_controller.dart';
import '../monetization/purchase_service.dart';
import '../services/feedback_service.dart';
import '../l10n/tr.dart';

/// 「広告を消す」の購入と、購入の復元。設定画面に置く。
///
/// クラス名と商品IDが supporter のままなのは、前の版で「サポーター」として
/// 売っていたため(商品IDは変えられない)。
///
/// 復元導線は iOS の審査要件なので、購入済みかどうかに関わらず出す。
class SupporterSection extends StatefulWidget {
  const SupporterSection({super.key});

  @override
  State<SupporterSection> createState() => _SupporterSectionState();
}

class _SupporterSectionState extends State<SupporterSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MonetizationController>();
    // ストアに繋がらない環境 (Web版など) では、押せない購入ボタンを
    // 見せる意味がないので丸ごと隠す。
    if (!money.initialized || !money.storeAvailable) {
      return const SizedBox.shrink();
    }

    // 「¥」は全角に置き換え済み(MonetizationController.displayPrice)。
    // 同梱フォントに半角の「¥」が無く、そのままだと豆腐になりうる。
    final price = money.priceLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(Tr.pick('広告と課金', 'Ads and payments'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        // 広告と課金の全体像。「このアプリでお金が関わるのは何か」を
        // 一箇所で見られるようにしてある。買う前に全体を把握できる方が、
        // 判断の材料になる。
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PointRow(
                  icon: Icons.ondemand_video,
                  title: Tr.pick('広告', 'Ads'),
                  body: Tr.pick(
                      'ゲームの中で3か月たつごとに、全画面広告が1回出ます。'
                          '試合中やメニュー操作の途中に割り込むことはなく、'
                          'バナー広告もありません。',
                      'A full-screen ad appears once every three in-game months. '
                          'Nothing interrupts a match or a menu, and there are no banners.'),
                ),
                const SizedBox(height: 8),
                _PointRow(
                  icon: Icons.block,
                  title: Tr.pick('広告を消す（買い切り）', 'Remove ads (one-off purchase)'),
                  body: Tr.pick(
                      '買うと全画面広告が出なくなります。変わるのはそれだけで、'
                          '選手の成長や試合の勝率、資金は変わりません。月額ではありません。',
                      'The full-screen ads stop appearing. That is all it changes: '
                          'player growth, your chances in a match and your funds stay the same. '
                          'It is not a subscription.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              if (money.isSupporter)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(Tr.pick('広告を消しています', 'Ads removed')),
                  subtitle: Text(
                    Tr.pick('ご購入ありがとうございます。全画面広告は出ません。',
                        'Thank you for your purchase. No full-screen ads will appear.'),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(
                    price == null
                        ? Tr.pick('広告を消す', 'Remove ads')
                        : Tr.pick('広告を消す（$price）', 'Remove ads ($price)'),
                  ),
                  subtitle: Text(
                    Tr.pick('買い切りです。全画面広告が出なくなります。',
                        'A one-off purchase. The full-screen ads stop appearing.'),
                  ),
                  trailing: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _buy,
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(Tr.pick('購入を復元', 'Restore purchase')),
                subtitle: Text(
                  Tr.pick('機種変更や再インストールをした場合は、ここから購入済みの状態に戻せます',
                      'Changed device or reinstalled? Restore your purchase here'),
                ),
                onTap: _busy ? null : _restore,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _buy() =>
      _run(() => context.read<MonetizationController>().buySupporter());

  Future<void> _restore() =>
      _run(() => context.read<MonetizationController>().restorePurchases());

  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    FeedbackService.tap();
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    final message = switch (outcome) {
      PurchaseOutcome.purchased => Tr.pick(
          'ありがとうございます。全画面広告は出なくなりました',
          'Thank you. Full-screen ads are now removed'),
      // 自分でやめた場合は何も言わない。失敗のように見せない。
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable =>
        Tr.pick('対象の購入が見つかりませんでした', 'No matching purchase was found'),
      PurchaseOutcome.failed => Tr.pick('購入処理に失敗しました。時間をおいてお試しください',
          'The purchase did not go through. Please try again later'),
    };
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}



/// 課金要素の説明1件ぶん。
class _PointRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _PointRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              Text(
                body.replaceAll('**', ''),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
