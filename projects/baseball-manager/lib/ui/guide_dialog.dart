import 'package:flutter/material.dart';

import 'art/badge_icon.dart';

/// 案内の1ページ。
class GuidePage {
  const GuidePage(this.title, this.body, this.asset);
  final String title;
  final String body;

  /// 絵(`assets/icons/`)。
  final String asset;
}

/// はじめてのガイド(最初の選手を始めたときに1度だけ。設定からいつでも見られる)。
const guidePages = <GuidePage>[
  GuidePage(
      '6歳から、プロを引退するまで',
      '1人の選手を育てて、その一生を見届けるゲームです。少年野球→中学→高校→プロと進み、'
          '高校を出るときのドラフトでプロ入りを目指します。',
      'assets/icons/tab_train.png'),
  GuidePage(
      '行動を選んで、経験点を貯める',
      '練習・特訓・休養などを選んで季節(高校とプロは月)を進めます。練習すると「経験点」が貯まり、'
          '「能力」タブで好きな能力に振り分けて育てます。疲れたら休養、怪我に注意。',
      'assets/icons/plan_train.png'),
  GuidePage(
      '才能と特性が、選手ごとに違う',
      '才能は星5つで見えます。選手全体の才能(★)と、能力ごとの才能(★)があり、星が多い能力ほど少ない経験点で上がります。幼いころの出来事で、才能が伸びることもあります。'
          '特性は最大4つ(レア特性は別枠)。レアは生まれつき、またはタイトルや優勝のときの「覚醒」で手に入ります。',
      'assets/icons/tab_ability.png'),
  GuidePage(
      '勝負どころでは、選ぶ',
      '分かれ道の選択や、夏の大会の決勝の「見せ場」では、得意な能力に合った作戦を選ぶと有利です。'
          '戦力外になっても、一度だけトライアウトで再挑戦できます。',
      'assets/icons/plan_match.png'),
  GuidePage(
      '記録と周回の楽しみ',
      '成績・表彰・実績・特性図鑑が残り、引退のたびに「継承ポイント」が貯まります。'
          '引退後の道も選べます。何度でも、別の選手で遊んでみてください。',
      'assets/icons/tab_career.png'),
];

/// ガイドを見せる。最後のページの「はじめる」か「スキップ」で閉じる。
Future<void> showGuide(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GuideDialog(),
    );

class GuideDialog extends StatefulWidget {
  const GuideDialog({super.key});

  @override
  State<GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<GuideDialog> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_i >= guidePages.length - 1) {
      Navigator.pop(context);
      return;
    }
    _page.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == guidePages.length - 1;
    return Dialog(
      key: const Key('guide-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 270,
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _i = i),
              children: [
                for (final g in guidePages)
                  SingleChildScrollView(
                    child: Column(children: [
                      BadgeIcon(
                          asset: g.asset,
                          size: 72,
                          fallback:
                              const Icon(Icons.sports_baseball, size: 56)),
                      const SizedBox(height: 12),
                      Text(g.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(g.body, textAlign: TextAlign.center),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < guidePages.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _i
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(
              key: const Key('guide-skip'),
              onPressed: () => Navigator.pop(context),
              child: const Text('スキップ'),
            ),
            const Spacer(),
            Flexible(
              child: FilledButton(
                key: const Key('guide-next'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20)),
                onPressed: _next,
                child: Text(last ? 'はじめる' : '次へ'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
