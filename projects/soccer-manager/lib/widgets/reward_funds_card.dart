import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_controller.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../l10n/tr.dart';

/// 営業ブーストを受け取るカード。ファイナンス画面に置く。
///
/// 資金を直接配らない。次の1節だけ収入が上がる(赤字を消すほどの力は持たせない)。
///
/// 広告を出せない環境 (Web版・ストア未接続) では丸ごと消える。
/// 押しても何も起きないボタンを残すより、無いほうがよい。
class RewardFundsCard extends StatefulWidget {
  const RewardFundsCard({super.key});

  @override
  State<RewardFundsCard> createState() => _RewardFundsCardState();
}

class _RewardFundsCardState extends State<RewardFundsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MonetizationController>();
    final gameState = context.watch<GameState>();
    if (!money.initialized || gameState.save == null) {
      return const SizedBox.shrink();
    }
    // 受け取れる見込みがまったく無い環境では出さない。
    // 上限に達しているだけなら、明日また受け取れることを伝えたいので出す。
    if (!money.canClaim && money.remainingToday > 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final left = gameState.marketingBoostWeeks;
    final soldOut = money.remainingToday <= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Tr.pick('営業を強化する', 'Push marketing'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  Tr.pick('本日 ${money.remainingToday}/${money.dailyLimit}',
                      'Today ${money.remainingToday}/${money.dailyLimit}'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              soldOut
                  ? Tr.pick('本日分は受け取り済みです。日付が変わるとまた受け取れます。',
                      "You have taken today's allowance. It resets tomorrow.")
                  : money.requiresAd
                      ? Tr.pick(
                          '短い動画広告を最後まで見ると、次の1節だけ収入が増えます(貯めた分: $left節)。見なくてもゲームは最後まで遊べます。',
                          'Watch a short video to the end and income rises for the next matchday ($left banked). You can finish the game without ever watching one.')
                      : Tr.pick('サポーターとして、広告なしで次の1節の収入を増やせます(貯めた分: $left節)。',
                          'As a supporter, boost the next matchday\'s income with no ad ($left banked).'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(money.requiresAd
                        ? Icons.play_circle_outline
                        : Icons.redeem),
                label: Text(
                  soldOut
                      ? Tr.pick('本日分は受け取り済み', 'Already taken today')
                      : money.requiresAd
                          ? Tr.pick('動画を見て営業を強化', 'Watch a video to push marketing')
                          : Tr.pick('営業を強化する', 'Push marketing'),
                ),
                onPressed: _busy || soldOut ? null : _claim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim() async {
    FeedbackService.tap();
    setState(() => _busy = true);
    final money = context.read<MonetizationController>();
    final gameState = context.read<GameState>();

    final result = await money.claimReward();

    // **受け取りは mounted を見ない。** 広告を見終えた後に画面を離れると
    // State が捨てられる。ここで返していた頃は、回数だけ消費して資金が
    // 入らなかった(広告は最後まで見ているので、こちらには収入が立つ)。
    //
    // Tr.pick は日本語と英語を「両方とも引数として」受け取るため、どちらの
    // 文字列も評価される。受け取り処理を文字列の中に書くと2回実行され、
    // 特典が二重に支払われる。必ず外で1回だけ呼ぶこと。
    final banked =
        result == ClaimResult.granted ? gameState.claimMarketingBoost() : 0;

    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (result) {
      ClaimResult.granted => Tr.pick(
          '営業を強化しました。次の1節は収入が増えます(貯めた分: $banked節)',
          'Marketing pushed. Income rises next matchday ($banked banked)'),
      ClaimResult.limitReached =>
        Tr.pick('本日分の受け取りは上限に達しています', "You have reached today's limit"),
      // 途中で閉じただけなので、責めるような文言にしない。
      ClaimResult.adNotCompleted => Tr.pick('広告が最後まで再生されなかったため、受け取れませんでした',
          'The ad did not finish, so nothing was paid'),
      ClaimResult.unavailable => Tr.pick('いま表示できる広告がありません。時間をおいてお試しください',
          'No ad is available right now. Please try again later'),
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
