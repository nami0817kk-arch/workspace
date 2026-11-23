import 'dart:math';

import 'package:flutter/material.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/tr.dart';
import '../widgets/onboarding_art.dart';

class _OnboardingSlide {
  final OnboardingArtKind art;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.art,
    required this.title,
    required this.description,
  });
}

// const にできないのは、各スライドの文言が表示時の言語で決まるため。
// final にすると最初のアクセスで言語が固定され、設定で切り替えても
// 反映されなくなるので、参照のたびに組み立てるゲッターにしている。
//
// 2026-11-23 にオーナー型の遊び方へ書き直した。以前は「戦術を作り込む」
// 「試合をライブで采配」と監督のゲームの説明で、遊び始めると話が違った。
List<_OnboardingSlide> get _slides => [
      _OnboardingSlide(
        art: OnboardingArtKind.climb,
        title: Tr.pick('あなたはクラブのオーナー', 'You own the club'),
        description: Tr.pick(
            '3部のクラブから上の部を目指します。決めるのはお金・人・方針。補強・スタッフ・スポンサー・施設はオーナーの仕事です。',
            'You start with a Tier 3 club and aim for the top. You decide the money, the people and the direction: signings, staff, sponsors and facilities are yours.'),
      ),
      _OnboardingSlide(
        art: OnboardingArtKind.live,
        title: Tr.pick('試合は監督に任せる', 'The manager runs the matches'),
        description: Tr.pick(
            '先発も戦い方も、雇った監督が決めます。あなたは結果を見て、スタッフや補強で監督を支えます。',
            'The manager you hire picks the team and the tactics. You watch the results and back him with staff and signings.'),
      ),
      _OnboardingSlide(
        art: OnboardingArtKind.squad,
        title: Tr.pick('2つの期待を保つ', 'Keep two groups happy'),
        description: Tr.pick(
            'サポーターは成績と順位を、株主は収支を見ています。サポーターの期待は毎月の結果と、あなたの手(チケットの値段・広報・地域活動・補強)で上下します。',
            'Supporters watch results and the table; shareholders watch the books. Supporter expectation moves with each month\'s results and with your own moves: ticket prices, PR, community work and signings.'),
      ),
      _OnboardingSlide(
        art: OnboardingArtKind.market,
        title: Tr.pick('期待が尽きると手放す', 'Run out and you must sell'),
        description: Tr.pick(
            'サポーターの期待が10を割ると最後通告が出て、3か月のうちに戻せないか、資金が尽きると、クラブを手放します。下がり始めたら、オーナー室の広報やファン向けの催しで支えましょう。',
            "If supporter expectation drops below 10 the fans issue a final warning, and if it is not back within three months, or the money runs out, you have to sell. When it starts to slip, use PR and fan events in the owner's office."),
      ),
      _OnboardingSlide(
        art: OnboardingArtKind.career,
        title: Tr.pick('手放しても続きがある', 'Selling is not the end'),
        description: Tr.pick(
            '手放しても実績は殿堂に残り、別のクラブを買い直して続けられます。この説明は「設定」からいつでも見返せます。',
            'Your record stays in the hall of fame, and you can buy another club and carry on. You can see this again any time from Settings.'),
      ),
    ];

/// 初回起動時に表示するシンプルなチュートリアル。設定画面からも再表示できる。
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    final size = MediaQuery.sizeOf(context);
    // 横画面(852x393 など)は縦が短い。絵を左・文を右に並べ、下の点と
    // ボタンを1行にまとめる。縦に積むと本文とボタンがはみ出した。
    final wide = size.width > size.height;
    final scheme = Theme.of(context).colorScheme;
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _slides.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _index ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
    final button = FilledButton(
      onPressed: _next,
      child: Text(isLast
          ? context.l10n.onboardingStart
          : context.l10n.onboardingNext),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(context.l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  final align = wide ? TextAlign.start : TextAlign.center;
                  final text = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: wide
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Text(
                        slide.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: align,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        slide.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: align,
                      ),
                    ],
                  );
                  if (wide) {
                    return LayoutBuilder(builder: (context, c) {
                      // 絵の高さは幅の2/3。欄の高さに収まる幅まで縮める。
                      final artWidth = min(260.0, c.maxHeight * 1.4);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          children: [
                            OnboardingArt(kind: slide.art, width: artWidth),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(child: text),
                              ),
                            ),
                          ],
                        ),
                      );
                    });
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // アイコン1つだと画面の大半が余白だった。
                            // 幅は画面に合わせて縮める(小型端末で溢れさせない)。
                            OnboardingArt(
                              kind: slide.art,
                              width: min(260.0, size.width * 0.68),
                            ),
                            const SizedBox(height: 28),
                            text,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 4, 40, 12),
                child: Row(
                  children: [
                    dots,
                    const Spacer(),
                    SizedBox(width: 220, child: button),
                  ],
                ),
              )
            else ...[
              dots,
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(width: double.infinity, child: button),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
