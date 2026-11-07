import 'package:flutter/material.dart';
import 'layout.dart';

/// 遊び方。はじめて始めるときに1度見せ、はじめの画面と設定からいつでも開ける。
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key, this.onStart});

  /// はじめて始めるときだけ渡す(「はじめる」ボタンが出る)。
  final VoidCallback? onStart;

  static const items = <(String, String)>[
    ('GMとして10年', '30チームから1つを選び、そのGM(チームの編成を任される人)になる。任期は10年。試合は自動で進み、GMの仕事はシーズンの外にある。優勝を何回できるか。'),
    ('シーズンの流れ', '30チームが東西の地区に分かれて82試合。地区の1〜6位はプレーオフへ、7〜10位はプレーインで残り2枠を争う。どの回戦も4勝で勝ち抜け、ファイナルで勝てば優勝。'),
    ('選手の力と伸びしろ', '数字は今の力。伸びしろ(S・A・B・C)が大きい若手は、オフごとに伸びる。30歳を過ぎると力は落ちていき、やがて引退する。'),
    ('年俸の上限', '年俸の合計には上限がある。上限を超えていても、自分の選手との再契約と最低年俸の契約はできる。ぜいたく税の線を超えると、オーナーの信頼が下がる。'),
    ('トレード', '相手のチームを選び、出す選手と受け取る選手(ドラフトの指名権も)を選ぶ。相手の考え(優勝を狙う・立て直し中など)で欲しいものが違う。反応は申し込む前に見える。締め切りはシーズンの半分(41試合)まで。'),
    ('ドラフト', 'オフに新人を指名する。候補の力は幅でしか分からない。スカウトを送ると幅が狭まる。プレーオフに出なかった14チームは、くじで上位4つの順番を引ける。'),
    ('契約', '契約が切れた選手は、再契約するか放すかを決める。残り1年の選手とは、シーズン前とシーズン中に延長の交渉もできる。自由契約の選手は補強のタブで取れる。'),
    ('オーナーの信頼', 'シーズンの初めに勝ち数の目標が決まる。目標との差・プレーオフの結果・ぜいたく税で信頼が動き、0になると解任。'),
    ('ローテーションと気持ち', 'チームの画面で先発と控えの順を決められる。力の低い選手を先発にすると弱くなる。出番が減った選手は気持ちが下がり、20を切ると再契約に応じない。'),
    ('経営とオーナーの目標', '入場料を選ぶ。人気が高く値段が安いほど客が入る。毎シーズン目標が3つ(勝ち数・黒字・もう1つ)。果たすと信頼が上がる。'),
    ('けがとスタッフ', '出場した選手はけがをすることがある。トレーナーが良いとけがが少ない。コーチは若手の伸び、スカウトはドラフトのスカウトの数に効く。'),
    ('チーム選びと実績', '強いチームはオーナーの期待が高く、弱いチームは若手と指名権で先を見る。実績は11個。記録と実績は任期をまたいで残る。'),
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
