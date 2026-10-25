import 'package:flutter/material.dart';
import 'layout.dart';

/// 遊び方。はじめて始めるときに1度見せ、はじめの画面と設定からいつでも開ける。
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key, this.onStart});

  /// はじめて始めるときだけ渡す(「はじめる」ボタンが出る)。
  final VoidCallback? onStart;

  static const items = <(String, String)>[
    ('1年は春夏秋冬の4回', '季節ごとに過ごし方を選ぶ。練習・特訓は伸びる代わりに疲れ、休養・交流は疲れと気持ちを戻す。疲れが溜まると動きが落ちて、怪我もしやすい。'),
    ('重点の能力は ★ を目安に', 'ポジションに効く能力のうち、いま伸ばすと得なものに ★ が付く。能力の ◎○△ は、いまのポジションで効く度合い。'),
    ('身長も能力の1つ', '身長は総合評価に入り、大きいポジションほど効く。素質(ポテンシャル)とは別で、17歳までの生活習慣(睡眠・食事・外遊び・休養)で伸びが変わる。'),
    ('夏と冬に大会', '勝ち抜きで、負けたら終わり。点差が3点以内なら「勝負どころ」。成功率を見て最後のプレーを自分で選ぶ。タイムアウトは大会で数回だけ、取ると成功率+5%。'),
    ('ハーフタイムと相手の持ち味', '前半が終わって接戦なら作戦を選ぶ。相手の持ち味(速攻型・高さ型など)との相性が出る。大会の前に「研究」すると、相性の良い作戦がさらに効く。'),
    ('ファウルと勢い', '守りが強い選手ほどファウルが増え、前半で3つ以上は「ファウルトラブル」、5つで退場。連勝すると勢いで味方が強くなり、連敗すると弱くなる。'),
    ('夢と目標を立てよう', '始めるときに「夢」を1つ選ぶ。かなうと全能力+1。年のはじめには「確実」と「挑戦」の目標が出て、達成するとごほうび。能力の緑の＋は今年の伸び。'),
    ('チームワークとコーチ', '交流・練習試合でチームワークが上がり、大会の味方が強くなる。練習を重ねるとコーチとの信頼が増え、伸びが良くなる。'),
    ('どんな選手を目指す?', '始めるときと育成中に、目指す型(スラッシャー・シャープシューターなど)を選べる。その型の能力が伸びやすく、型に合うプレーが強くなる。おまかせなら能力のつき方で決まる。'),
    ('特性・得意技・特殊能力', '特性は生まれつきや出来事で、得意技は条件を満たすと自然に身につく。特殊能力は年末にたまるポイントで、好きなものを選んで習得する。'),
    ('進路は19歳', '能力・実績・身長がプロ契約の評価になる。70点以上なら確実、35点未満は難しい。外れても大学・実業団からもう一度挑戦できる。契約するとドラフトの順位が付く。'),
    ('プロの世界', '年俸とスポンサーで収入が入り、毎年の契約更改で変わる。25・29・33歳にはフリーエージェント。活躍すると得点王・新人王・オールスターなどの表彰がある。'),
    ('育てた選手は殿堂へ', '引退するとセレモニーと称号がつき、実績が解除される。実績が増えるほど、次の選手の初期能力が上がる。集めたタイトル・ビルド・特性は図鑑に残る。'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('遊び方')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: cs.primary,
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(items[i].$1,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(items[i].$2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onStart != null)
                  FilledButton(onPressed: onStart, child: const Text('はじめる')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
