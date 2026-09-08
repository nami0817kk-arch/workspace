import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../models/entourage.dart';
import '../../models/support.dart';
import '../../models/traits.dart';
import '../../models/training.dart';

/// 遊び方のガイド。
///
/// 仕組みが多いので、画面の中だけでは説明しきれない。ここに1か所だけ
/// まとめておく。**数字は実装から引く**（特性・練習メニュー・スタッフは
/// enum をそのまま並べる）ので、仕様を足したときに古くならない。
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('遊び方ガイド')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'このゲームは、1人の選手の現役生活をなぞるもの。'
                  'やることは「今週どう過ごすか」と「試合の3つの局面で何を選ぶか」の2つだけで、'
                  'それを38節×十数シーズンくり返す。'
                  '残りはすべて、その積み重ねの結果として動く。',
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final section in _sections) _GuideTile(section: section),
          ],
        ),
      ),
    );
  }
}

/// ガイドの1項目。
class _GuideSection {
  const _GuideSection(this.title, this.body, {this.extra});

  final String title;
  final List<String> body;

  /// 一覧など、実装から作る部分。
  final Widget Function(BuildContext)? extra;
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.section});

  final _GuideSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(section.title, style: theme.textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in section.body) ...[
            Text(paragraph, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
          ],
          if (section.extra != null) section.extra!(context),
        ],
      ),
    );
  }
}

/// 一覧を並べるための小さな部品。
Widget _list(BuildContext context, List<(String, String)> rows) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (name, description) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleSmall),
              Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
    ],
  );
}

final List<_GuideSection> _sections = [
  const _GuideSection('1週間の流れ', [
    '「育成」タブで今週の練習を決め、「試合」タブ（または右下のボタン）から試合に入る。'
    '試合では3つの局面で手を選ぶ。終われば1週間が過ぎ、次の節が来る。',
    '練習すると伸びる可能性がある代わりに疲れる。休養は伸びないが戻る。'
    '疲れたまま試合に出ると成功率が落ち、怪我もしやすくなる。',
    '全38節を戦い終えるとシーズンが終わり、契約・移籍・オフの過ごし方を決める。',
  ]),
  const _GuideSection('試合で選ぶ', [
    '各局面には3つの手がある。だいたい「難しいが得点に直結する手」と'
    '「安全だが見返りの小さい手」が対になっている。常に正解になる手は無い。',
    '手に出ている％は、その手が通る確率。特性・コンディション・相手の強さ・'
    '気持ちまで含んだ、実際に判定に使う数字そのもの。',
    'ゴールやアシストの手には「ゴール◯%」も出る。手が通っても決まるとは限らない。'
    '枠を捉えても止められるのがサッカーで、そこを分けてある。',
    '終盤（75分以降）に同点以下から決めた得点は、評価点が重く付く。',
    '1試合の1/4くらいは逆足で対応することになる。逆足の精度が低いとそこで落ちる。',
  ]),
  _GuideSection('評価点と出場機会', [
    '局面の成否で評価点が動く。基準は6.0で、良い試合は7点台、悪い試合は5点台。',
    '直近5試合の評価点で、次節の起用が決まる。'
    '${Formulas.benchThreshold}を下回ると途中出場、'
    '${Formulas.squadThreshold}を下回るとベンチ外。',
    'ベンチ外が続いても、そのまま終わりにはならない。'
    '外れている間は評価が甘く見られ、${Formulas.benchPatience}試合続けて外れたら'
    '必ず一度は声がかかる。まず途中出場から戻る。',
    '調子が良くても、疲れていれば休まされることがある。'
    '長い離脱から戻った直後も、まずはベンチからになる。',
    '監督との関係・戦術との相性・同ポジションの競争相手も、起用に効いている。',
  ]),
  _GuideSection('伸ばす', [
    '能力は「練習」と「試合で成功した手」で伸びる。'
    '何を選ぶかがそのまま選手の形になる。',
    '若いほど伸びる。21歳までは1回の成長で2つぶん伸び、'
    '${Formulas.peakAge}歳を過ぎると鈍り、31歳あたりから落ち始める。',
    '能力には土台がある。筋力が低いまま最高速だけを上げることはできず、'
    '頭打ちのときは土台のほうが伸びる。',
    'ポテンシャル（上限）は数字では見せない。帯だけを出している。'
    '上限に達しても、若く・プロ意識が高く・試合を積んだ選手は稀に超える。',
    '伸び続けると停滞期が来る。数試合は積み上がらない。',
  ], extra: _trainingMenus),
  _GuideSection('自分の位置を知る', [
    '「育成」タブの「練習の成果」に、開幕からの伸びが出る。'
    '能力が1上がると、その能力で判定する局面が約0.9%通りやすくなる。'
    '＋5なら約4.5%。試合中の選択肢にも、今季伸びたぶんが↑で付く。',
    'その下の「◯回勝負して◯%成功」は、実際にその能力で戦った結果。'
    '伸ばしているのに数字が動かないなら、その能力の局面が来ていないか、'
    '相手が強すぎる。',
    '「選手」タブの「選手としての水準」で、総合力が世界のどのあたりかが分かる。'
    '総合力${Formulas.callUpOverall}が代表に呼ばれる目安で、'
    'それ以上なら「一流」、82以上で「ワールドクラス」。',
    '「クラブ」タブの「リーグの格付け」で、所属リーグが世界で何位かを見られる。'
    'S は世界最高峰、D は最下層。数字はそのリーグのクラブの平均的な強さで、'
    'これが高いほど同じ手が通らなくなる。',
    '自分の総合力と所属クラブの強さを比べれば、'
    'チームの中心なのか、出場を争う立場なのかが分かる。',
  ]),
  const _GuideSection('身体と個人技', [
    '身長・体重・利き足は生まれつきで、練習では動かない。'
    '試合の判定にだけ効く（高ければ 競り合いに強く、重ければ当たりに強い代わりに鈍い）。',
    'オフに増量・減量を選べる。体重が動くと、当たりの強さとキレが入れ替わる。',
    '能力が水準に達している選手は、その練習を続けているうちに個人技を覚える。'
    '狙って取りには行けない。最大3つまで。',
    '居残り練習でFK・PK・CKを磨ける。'
    '${SetPieceSkills.takerThreshold}に届くとクラブのキッカーを任され、'
    'そこで初めて試合の得点に出るようになる。',
  ]),
  _GuideSection('生まれ持った特性', [
    '選手を作ると、長所が2つ付く。3割の確率で欠点も1つ付く。'
    'どれも一長一短で、上位互換は無い。',
    '特性は伸ばせない。その選手の「向き・不向き」で、'
    '同じ能力値でも別の選手になる。',
  ], extra: _traitList),
  const _GuideSection('クラブと監督', [
    '監督には戦術と要求がある。自分の能力が戦術と噛み合っていれば起用されやすい。'
    '成績が期待を下回れば監督は飛び、代われば信頼は白紙に戻る。',
    '信頼の厚かった監督は「恩師」として残り、よそのクラブから呼ぶことがある。',
    '同ポジションの競争相手との力の差が、そのまま序列になる。'
    '相方とは一緒に試合を重ねるほど呼吸が合い、移籍すると一からになる。',
    '若いうちはメンターが居ると練習が身になる。'
    'クラブの練習環境と医療のレベルは、強さと国の格から決まる。',
  ], extra: _directives),
  const _GuideSection('契約と移籍', [
    '契約が残っている間は、残留しても条件は動かない（1年減るだけ）。'
    '残り1年になって初めて、他クラブからの話が届く。',
    '契約には違約金が付く。伸びた選手は自分の違約金を追い越し、'
    '契約が残っていても話が動き出す。',
    '出番の無い若手にはローンの話が来る。保有元との契約は凍り、1年で戻る。'
    '買い取りオプション付きで結果を出せば、そのまま買われる。',
    '代理人は交渉力・人脈・手数料が違う。'
    'シーズン終了時に前金を払って「売り込ませる」こともできる（空振りもある）。',
    '上乗せ交渉は、移籍のオファーだと失敗して撤回されることがある。'
    '契約更改は撤回されない。',
  ]),
  const _GuideSection('代表・カップ', [
    '代表は実力だけでは呼ばれない。総合力と直近の出来の両方が要る。'
    '複数の国籍を持っていれば、どの代表でやるかを選べる。',
    'ワールドカップは4年に1度。代表に呼ばれている選手だけが出られる。',
    '国内カップは一発勝負なので、格下でも勝ち上がることがある。'
    '優勝すれば翌季の大陸カップ出場権が付く。',
    '大陸カップはリーグ上位のクラブに出場権がある。'
    '出れば知名度と労働許可の審査で有利になる。',
  ]),
  const _GuideSection('怪我・コンディション・気持ち', [
    'コンディションは1週間で戻るが、累積疲労は戻らない。'
    'オフでだいたい抜けるが、30を過ぎると残る。',
    '怪我をしたら復帰の進め方を選べる。強行すれば早く戻れる代わりに、'
    '復帰直後の再発が跳ね上がる。重傷は能力とポテンシャルを恒久的に削る。',
    '気持ちは出番と私生活で動く。低いと何をしても噛み合わない。'
    'ピッチ外の出来事で上下するが、1回で人生が決まるほどの効きは無い。',
    '実力とは別に、数試合だけ続く波（ゾーン／スランプ）がある。',
  ]),
  const _GuideSection('お金', [
    '年俸からは税・代理人手数料・生活費が引かれ、残りが貯蓄になる。',
    '貯蓄は自分への投資に使える。専属コーチ・トレーナー・栄養士は'
    '毎シーズン人件費がかかり、払えなくなれば契約は切れる。',
    '知名度が上がるとスパイクのスポンサーが付く。年俸とは別の収入になる。',
  ], extra: _staffKinds),
  const _GuideSection('引退とその後', [
    '33歳から引退を選べる。37歳のシーズンを終えると引退になる。',
    '引退後は通算成績と称号が残り、次に進む道を選ぶ。'
    '現役でやってきたことが、そのまま次の職業の適性になる。',
  ]),
  const _GuideSection('保存と持ち運び', [
    'セーブは端末ごとに独立している。'
    'PCで進めた内容とスマホの内容は別物になる。',
    '右上のメニューから「引き継ぎコード」を出して別の端末に貼り付けると、'
    '続きから遊べる。読めないコードでは、今のキャリアは消えない。',
  ]),
];

Widget _trainingMenus(BuildContext context) => _list(context, [
      for (final menu in TrainingMenu.values)
        (
          menu.label,
          menu.isRest
              ? '${menu.description}（コンディション +${menu.recovery}）'
              : '${menu.description}（消耗 ${menu.conditionCost}）',
        ),
    ]);

Widget _traitList(BuildContext context) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('長所（${Trait.strengths.length}種）',
          style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.strengths) (trait.label, trait.description),
      ]),
      const SizedBox(height: 8),
      Text('欠点（${Trait.flaws.length}種）',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.error)),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.flaws) (trait.label, trait.description),
      ]),
    ],
  );
}

Widget _directives(BuildContext context) => _list(context, [
      for (final directive in Directive.values)
        if (directive != Directive.none) (directive.label, directive.effect),
    ]);

Widget _staffKinds(BuildContext context) => _list(context, [
      for (final kind in StaffKind.values) (kind.label, kind.description),
      for (final level in [1, 2, 3])
        (
          StaffTeam.levelLabels[level],
          '年間 ${StaffTeam.costPerLevel[level]}万円',
        ),
    ]);
