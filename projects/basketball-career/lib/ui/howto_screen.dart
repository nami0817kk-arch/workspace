import 'package:flutter/material.dart';
import 'layout.dart';

/// 遊び方。はじめて始めるときに1度見せ、はじめの画面と設定からいつでも開ける。
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key, this.onStart});

  /// はじめて始めるときだけ渡す(「はじめる」ボタンが出る)。
  final VoidCallback? onStart;

  static const items = <(String, String)>[
    ('GMとして長く', '30チームから1つを選び、そのGM(チームの編成を任される人)になる。任期に年数の上限は無く、オーナーに解任されるか、自分で終えるまで続く。試合は自動で進み、GMの仕事はシーズンの外にある。勝つほど「GMの格」(10段階)が上がる。'),
    ('シーズンの流れ', '30チームが東西の地区に分かれて82試合。地区の1〜6位はプレーオフへ、7〜10位はプレーインで残り2枠を争う。どの回戦も4勝で勝ち抜け、ファイナルで勝てば優勝。'),
    ('選手の力と伸びしろ', 'OVRは選手の総合の力(控えは70前後、主力は80台、スターは90台)。POTは伸びきったときの見込み。若手はオフごとに伸び、30歳を過ぎると落ちていき、やがて引退する。'),
    ('年俸の上限', '上限・税の線・第1の壁・第2の壁がある。固い上限は無く、再契約と最低年俸の契約はいつでもできる。税の線を超えると信頼が下がり、壁を超えるとトレードで受け取る年俸が制限される。'),
    ('トレード', '相手のチームを選び、出す選手と受け取る選手(ドラフトの指名権も)を選ぶ。相手の考え(優勝を狙う・立て直し中など)で欲しいものが違う。反応は申し込む前に見える。トレードブロックに載せた選手には申し込みが届きやすい。締め切りはシーズンの半分(41試合)まで。'),
    ('ドラフト', 'オフに新人を指名する。候補の力は幅でしか分からず、スカウトで狭まる。上位の順番はくじで決まる。指名権は3年先まで持て、トレードでは上位の保護を付けて出せる。候補を押すと経歴と身体測定、☆でボードに残せる。'),
    ('契約', '契約が切れた選手は、再契約するか放すかを決める。残り1年の選手とは、シーズン前とシーズン中に延長の交渉もできる。自由契約の選手は補強のタブで取れる。オフの大物はほかのチームと競り合いで、申し込むと4日のうちに行き先を決める(高く出すほど選ばれやすい)。'),
    ('オーナーの信頼', 'シーズンの初めに勝ち数の目標が決まる。目標との差・プレーオフの結果・ぜいたく税で信頼が動き、0になると解任。'),
    ('ローテーションと気持ち', 'チームの画面で先発と控えの順を決められる。力の低い選手を先発にすると弱くなる。出番が減った選手は気持ちが下がり、20を切ると再契約に応じない。'),
    ('経営とオーナーの目標', '入場料を選ぶ。人気が高く値段が安いほど客が入る。毎シーズン目標が3つ(勝ち数・黒字・もう1つ)。果たすと信頼が上がる。'),
    ('練習', 'チームの画面の「練習」で強さ(軽め・ふつう・きつい)と、選手ごとの重点を決める。きついと若手が伸びやすいが、けがが増える。重点の能力はオフに伸びる。オフの初めに成長の報告が出る。'),
    ('出場時間とコーチ陣', '出場時間は選手ごとに決められる(合計240分)。36分を超えると疲れ、期待より少ない選手は気持ちが下がる。コーチ陣はヘッドコーチ・トレーナー・スカウト・育成の4人。力が高いほど効くが給料も高い。入れ替えはシーズン前とオフだけ。'),
    ('表彰と殿堂', 'シーズンの終わりにMVP・ファイナルMVP・最優秀守備・新人王・シックスマン賞・躍進賞と、オールリーグの3チームが決まる。表彰を重ねた選手は、引退すると殿堂に入る。リーグのタブの「リーグの歴史」で見られる。'),
    ('チーム選びと実績', '強いチームはオーナーの期待が高く、弱いチームは若手と指名権で先を見る。難しさ(やさしい・ふつう・きびしい)は始めるときに選び、途中では変えられない。実績は14個。記録と実績は任期をまたいで残る。'),
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
