import 'package:flutter/material.dart';
import 'layout.dart';

/// 遊び方。はじめて始めるときに1度見せ、はじめの画面と設定からいつでも開ける。
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key, this.onStart});

  /// はじめて始めるときだけ渡す(「はじめる」ボタンが出る)。
  final VoidCallback? onStart;

  static const items = <(String, String)>[
    ('1シーズンを勝ち抜く', '地区予選・県大会・全国大会の3つ。どの大会も8つの行き先を順に選び、最後が決勝。全国大会で優勝すれば日本一。'),
    ('試合は4クォーター×2ラウンド', '毎ラウンド手札を5枚引き、スタミナ3で好きなだけカードを出す(左上の数字がスタミナ)。「ラウンド終了」で相手が攻めてくる。最後に点の多いほうが勝ち。同点なら延長。'),
    ('相手の予告を見て決める', '相手が次にしてくる攻め(予告)と点数が、前もって分かる。シュートで点を取るか、守りで相手の点を削るか。守備は相手の点をそのまま減らす。連続攻撃は1本ずつ削る。'),
    ('カードの種類', '橙はシュート(点)、青は組み立て(引く・次のシュートを強く)、緑は守り(守備)、紫は流れ(試合ずっと効く)。パスのあとはアリウープやユーロステップが強くなる。疲労は出せないカードで、試合が終わると消える。'),
    ('勝つとカードが増える', '勝ったら3枚の候補から1枚をデッキに入れられる。取らなくてもよい。枚数が増えると、強いカードを引く回数は減る。部室では部費でカードを買い、弱いカードを外せる。'),
    ('仲間は5人まで', '強豪に勝つと、仲間が加わりたいと言ってくる。仲間はそれぞれ得意を持ち、試合ずっと効く(3Pのシュート+1など)。部室や出来事でも迎えられる。'),
    ('気持ち', '普通の試合や強豪に負けると、気持ち(ハート)が1つ減る。0になるとシーズン終了。決勝に負けたら、その場で敗退。練習で休むと1つ戻り、次の大会に進んでも1つ戻る。'),
    ('練習・出来事', '練習ではカードを1枚強くする(＋になる)か、休む。出来事では差し入れ・取材・合同練習などが起きて、選んだことで部費やカードが変わる。'),
    ('実績と難しさ', '実績を達成すると、新しいカードや仲間が出るようになる。全国大会で優勝すると、ひとつ上の難しさを選べる。難しさ3からは気持ち2で始まる。'),
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
