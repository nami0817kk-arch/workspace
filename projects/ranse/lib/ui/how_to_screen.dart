import 'package:flutter/material.dart';

import '../app/controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// 遊び方（2026-11-25）。初めて開いた人に一度だけ出し（`AppController.autoGuide`）、タイトルの「遊び方」からも開ける。
/// 位の解説（`rank_guide.dart`）と同じ見た目（金の見出し・和紙の札）で、要点を数枚に分けて見せる。

/// 一枚ぶん。見出しと、短い段落（一つずつ札に載せる）。
typedef HowToPage = ({String title, List<(String, String)> items});

const kHowToPages = <HowToPage>[
  (
    title: '生まれは籤',
    items: [
      ('運命の籤', '身分・国・才・特性は、すべて運で決まる。選べるのは、生まれる性別だけ。'),
      ('引き直し', '生まれる前なら、何度でも籤を引き直せる。生まれたあとは変えられない。'),
      ('人生の長さ', '命の尽きるまで、または天下を統べるまで続く。途中でやめても、年の初めから続きを遊べる。'),
    ],
  ),
  (
    title: 'この年の心がけと岐路',
    items: [
      ('この年の心がけ', '一年ごとに、その年に力を入れることを一つ選ぶ。能力が伸び、その年に起きる岐路の種類も変わる。'),
      ('岐路', '年の途中で、人生の分かれ道に出会う。選んだ先は、短い匂わせだけを頼りに決める。成功の見込みは数字では出ない。'),
      ('札', '能力や特性のおかげで開けた手・起きた場面には、小さな札が付く。'),
      ('大きな分かれ道', '世を変えうる場面や、一生の向きを変える場面には「大きな分かれ道」の印が付く。'),
    ],
  ),
  (
    title: '位と下剋上',
    items: [
      ('位', '主家に仕えると、功・信頼・兵がそろうたびに位が上がる。立ち位置のカードを押すと、位の解説が開く。'),
      ('下剋上', '城主から宿老までの位で主家に仕え、戦える身には「下剋上の誘い」が来ることがある。'),
      ('謀反の支度', 'この年の心がけで「謀反の支度をする」を選ぶと、味方や兵糧が積もり、誘いを待たずに自ら兵を挙げられる。露見すれば危うい。'),
      ('勝ち目', '主家に比べて自分の兵が多いほど、支度が積もるほど、下剋上は成りやすい。しくじれば、命か身分を失う。'),
      ('天下', '一国の主となり、天下の勢力の半ばを握れば、天下人となる。'),
    ],
  ),
  (
    title: '体と縁',
    items: [
      ('病を養う', '健康が落ちると病にかかりやすい。病に伏したら、次の年の心がけに「病を養う」が出る。養えば持ち直しやすい。'),
      ('縁のある人', '幼なじみ・師・好敵手・連れ合い。選んだことで縁が深まり、何年もあとに返ってくる。'),
      ('歴史は変わる', '史実の分かれ目で、あなたの選択が歴史を変えることがある。動いたときは知らせが出る。'),
    ],
  ),
  (
    title: '最期と図鑑',
    items: [
      ('最期', '歩んだ道と死に方で、千通りほどある最期のどれかにたどり着く。'),
      ('最期の図鑑', '見た最期は図鑑に集まり、何度でも読み返せる。'),
      ('これまでの人生', '生きた人は一人ずつ記録に残り、タイトルの「これまでの人生」から振り返れる。'),
    ],
  ),
];

class HowToScreen extends StatefulWidget {
  const HowToScreen(this.c, {super.key});
  final AppController c;

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == kHowToPages.length - 1;

  void _next() {
    if (_last) {
      widget.c.closeGuide();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '遊び方',
                    style: TextStyle(
                      fontSize: 20,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                      color: Pal.gold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.c.closeGuide,
                  child: const Text('閉じる', style: TextStyle(color: Pal.muted)),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: [for (final p in kHowToPages) _HowToPageView(p)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < kHowToPages.length; i++)
                  Container(
                    width: i == _page ? 16 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page ? Pal.accent : Pal.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: BigButton(_last ? '乱世へ' : '次へ', _next),
          ),
        ],
      ),
    );
  }
}

class _HowToPageView extends StatelessWidget {
  const _HowToPageView(this.p);
  final HowToPage p;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        Text(
          p.title,
          style: const TextStyle(
            color: Pal.gold,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 10),
        for (final (name, note) in p.items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Pal.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Pal.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Pal.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(note, style: const TextStyle(fontSize: 13.5, height: 1.6)),
              ],
            ),
          ),
      ],
    );
  }
}
