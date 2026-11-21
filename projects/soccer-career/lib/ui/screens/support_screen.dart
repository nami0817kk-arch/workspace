import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/lang.dart';
import '../../monetize/monetization.dart';
import '../../monetize/purchase_service.dart';
import '../readable_width.dart';

/// 広告と課金の画面。
///
/// **売っているのは「広告を消す」1つだけ。**
/// 強くなるものを売っていないことを、言い訳ではなく最初に書く——
/// キャリアものは積み上げが全部なので、「金で飛ばせる」と思われた時点で
/// 積み上げの値打ちが消える。
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.monetization});

  /// 法務ページの置き場所。
  ///
  /// **`soccer-career.pages.dev` は他人のサイト**（同じ着想の別アプリが先に
  /// 取っている）。Cloudflare が後ろに `-49p` を足したのはそのためで、
  /// 「短いほうが正しそう」と直すと、審査で他人のページを見せることになる。
  /// `test/distribution_test.dart` が STORE_LISTING.md と突き合わせている。
  static const String legalBase = 'https://soccer-career-49p.pages.dev/legal';

  final Monetization monetization;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _busy = false;

  Monetization get _m => widget.monetization;

  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    // **取りやめは失敗ではない。** 赤い文字で出すと、自分で閉じた人に
    // 何か壊れたように見える。
    final message = switch (outcome) {
      PurchaseOutcome.purchased => tr('ありがとうございます。', 'Thank you.'),
      PurchaseOutcome.canceled => tr('購入は取りやめました。', 'The purchase was cancelled.'),
      // **「取りやめ」と出さない。** 家族の承認を待っている状態で、
      // 承認されれば後から届く（そのとき広告が消える）。
      PurchaseOutcome.pending => tr('承認を待っています。承認されると反映されます。', 'Waiting for approval. It applies once approved.'),
      PurchaseOutcome.unavailable => tr('ストアに繋がりませんでした。', 'Could not reach the store.'),
      // 買っていない人が「購入を復元」を押したとき。壊れて見せない。
      PurchaseOutcome.nothingToRestore => tr('復元できる購入はありませんでした。', 'There was nothing to restore.'),
      PurchaseOutcome.failed => tr('購入できませんでした。', 'The purchase did not go through.'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('広告について', 'Ads and purchases'))),
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    tr('強くなるものは売っていない。'
                    '能力・成長・移籍・試合結果に効く課金は1つも無く、'
                    '買わなくても最後まで同じように遊べる。', 'Nothing here makes you stronger. No purchase touches ability, growth, transfers or match results, and the game plays the same to the end without buying anything.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('広告を消す', 'Remove ads'), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        tr('広告はシーズンの切れ目に1回だけ出る。'
                        '試合中やメニューには割り込まない。'
                        'バナーも出さない。', 'An ad shows once, between seasons. It never cuts into a match or a menu, and there are no banners.'),
                        style: muted,
                      ),
                      const SizedBox(height: 12),
                      if (_m.noAds)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(tr('購入済み。広告は出ない。', 'Purchased. No ads will show.')),
                          ],
                        )
                      else
                        FilledButton(
                          onPressed: _busy || !_m.storeAvailable
                              ? null
                              : () => _run(() => _m.buy(Product.noAds)),
                          child: Text(
                            _m.prices[Product.noAds] == null
                                ? tr('広告を消す', 'Remove ads')
                                : tr('広告を消す（${_m.prices[Product.noAds]}）', 'Remove ads (${_m.prices[Product.noAds]})'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // **復元の導線は iOS の審査要件。** 出していないと弾かれる。
              TextButton(
                onPressed: _busy || !_m.storeAvailable
                    ? null
                    : () => _run(_m.restore),
                child: Text(tr('購入を復元', 'Restore purchase')),
              ),
              if (!_m.storeAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    tr('この環境ではストアに繋がらないので、購入はできない'
                    '（ブラウザ版には広告も課金も無い）。', 'This build cannot reach the store, so nothing can be bought (the browser version has no ads and no purchases).'),
                    style: muted,
                  ),
                ),
              if (_m.usingTestAdUnit)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr('広告はテスト用のままです（配信前のビルド）。', 'Ads are still the test ones (pre-release build).'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(tr('決まりごと', 'The small print'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              // **押せば控えに入る。** 読むだけの文字列にしておくと、
              // スマホでは長押しして範囲を選んで…という手間になり、
              // 実質どこにも辿り着けない。ブラウザを開く仕掛け
              // （url_launcher）は端末側の部品が要るので、ここでは持たない。
              for (final (path, label) in [
                ('privacy.html', tr('プライバシーポリシー', 'Privacy policy')),
                ('terms.html', tr('利用規約', 'Terms of use')),
                ('support.html', tr('サポート・広告の報告', 'Support and reporting an ad')),
              ])
                _LegalLink(
                  url: '${SupportScreen.legalBase}/$path',
                  label: label,
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 法務ページの1行。押すとURLが控えに入る。
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.url, required this.label, this.style});

  final String url;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(tr('$label のURLをコピーしました。', 'Copied the $label URL.'))));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style),
                  SelectableText(url, style: style),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.copy,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
