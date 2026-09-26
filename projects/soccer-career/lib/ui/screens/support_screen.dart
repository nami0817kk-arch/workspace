import 'package:flutter/material.dart';

import '../../monetize/monetization.dart';
import '../../monetize/purchase_service.dart';
import '../readable_width.dart';

/// 広告と課金の画面。
///
/// **売っているものが2つしか無いので、画面も2枚のカードで済む。**
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
      PurchaseOutcome.purchased => 'ありがとうございます。',
      PurchaseOutcome.canceled => '購入は取りやめました。',
      PurchaseOutcome.unavailable => 'ストアに繋がりませんでした。',
      PurchaseOutcome.failed => '購入できませんでした。',
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
      appBar: AppBar(title: const Text('広告・応援')),
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '強くなるものは売っていない。'
                    '能力・成長・移籍・試合結果に効く課金は1つも無く、'
                    '買わなくても最後まで同じように遊べる。',
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
                      Text('広告を消す', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '広告はシーズンの切れ目に1回だけ出る。'
                        '試合中やメニューには割り込まない。'
                        'バナーも出さない。',
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
                            const Text('購入済み。広告は出ない。'),
                          ],
                        )
                      else
                        FilledButton(
                          onPressed: _busy || !_m.storeAvailable
                              ? null
                              : () => _run(() => _m.buy(Product.noAds)),
                          child: Text(
                            _m.prices[Product.noAds] == null
                                ? '広告を消す'
                                : '広告を消す（${_m.prices[Product.noAds]}）',
                          ),
                        ),
                    ],
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
                      Text('応援する', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'ゲームの中では何も起きない。'
                        '作り続けるための気持ちだけを受け取る。',
                        style: muted,
                      ),
                      if (_m.tips > 0) ...[
                        const SizedBox(height: 8),
                        Text('これまでに ${_m.tips} 回。ありがとうございます。'),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy || !_m.storeAvailable
                            ? null
                            : () => _run(() => _m.buy(Product.tip)),
                        child: Text(
                          _m.prices[Product.tip] == null
                              ? '応援する'
                              : '応援する（${_m.prices[Product.tip]}）',
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
                child: const Text('購入を復元'),
              ),
              if (!_m.storeAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'この環境ではストアに繋がらないので、購入はできない'
                    '（ブラウザ版には広告も課金も無い）。',
                    style: muted,
                  ),
                ),
              if (_m.usingTestAdUnit)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '広告はテスト用のままです（配信前のビルド）。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text('決まりごと', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              SelectableText(
                '${SupportScreen.legalBase}/privacy.html  プライバシーポリシー\n'
                '${SupportScreen.legalBase}/terms.html  利用規約\n'
                '${SupportScreen.legalBase}/support.html  サポート',
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
