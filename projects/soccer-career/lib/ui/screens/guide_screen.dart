import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/knacks.dart';
import '../../game/promises.dart';
import '../../models/development.dart';
import '../../models/entourage.dart';
import '../../models/role.dart';
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
                  'やることは「今週どう過ごすか」と「試合の局面で何を選ぶか」の2つだけで、'
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

/// ガイドの本文。**数字は実装から引く**。
///
/// 2026-09-22 に見直したら、**9/10 以降に入れた仕組みの大半が載っておらず**、
/// 残っていた記述のうち5か所が嘘になっていた（「試合の3つの局面」
/// 「能力1で約0.9%」「個人技は狙って取りには行けない」「長所が2つ付く」
/// 「特性は選べない」）。0.9% は数字を手で書き写していたせいで、
/// 傾きを変えたときに黙って古くなった。**ここに数字を直接書かない。**
final List<_GuideSection> _sections = [
  _GuideSection('1週間の流れ', [
    '「育成」タブで今週の練習を決め、「試合」タブ（または右下のボタン）から試合に入る。'
        '終われば1週間が過ぎ、次の節が来る。',
    '練習は3つを決める。何をするか（メニュー）・どこまで踏み込むか'
        '（${TrainingEffort.values.map((e) => e.label).join('／')}）・'
        '誰と組むか（${TrainingCompanion.values.map((c) => c.label).join('／')}）。',
    '追い込むほど大成功（1週で2つ伸びる）が出やすいが、疲れて怪我もしやすい。'
        '疲れている週ほど空回りする。追い込み続けた身体は、衰えが早く来る。',
    'コンディションが決めた値を下回った週は、自動で休養になる。'
        '練習も居残りも止まる。既定は40未満で、「育成」タブで変えられる'
        '（切ることもできる）。効いた週は試合結果の画面にそう出る。',
    '全38節を戦い終えるとシーズンが終わり、契約・移籍・オフの過ごし方を決める。',
  ]),
  _GuideSection('試合で選ぶ', [
    'ふつうの試合は${Formulas.scenariosPerStart}つ、順位や因縁が絡む'
        '「じっくりやる試合」は${Formulas.scenariosPerBigStart}つの局面が来る'
        '（途中出場ならもっと少ない）。各局面に3つの手がある。',
    'だいたい「難しいが得点に直結する手」と「安全だが見返りの小さい手」が対になっている。'
        '常に正解になる手は無い。',
    '手に出ている％は、その手が通る確率。判定に使う数字そのもので、'
        '何でできているかも画面に出ている。局面の上に並ぶのは'
        '「どの手でも同じだけ効くもの」、手ごとに付くのは「その手にだけ効くもの」。',
    'ゴールやアシストの手には「ゴール○%」も出る。手が通っても決まるとは限らない。',
    'ノリ。手を通し続けると乗ってくる（最大${Formulas.momentumMax}段）。'
        '乗るほど決まる確率が上がり、1段で'
        '×${(1 + Formulas.momentumPerStep).toStringAsFixed(1)}。失敗すると消える。',
    '布石と仕留め。局面によっては、安全な手に「布石」、難しい得点の手に'
        '「仕留め」の印が付く。布石を通しておくと、その試合のうちに選んだ仕留めが'
        '+${(Formulas.comboBonus * 100).round()}% 通りやすく、'
        '×${Formulas.comboConversion.toStringAsFixed(1)} 決まりやすくなる。'
        '仕留めにいけば、通っても外しても使い切る。'
        '局面の多いじっくりやる試合で効く——自動で進めると、ここは使わない。',
    '切り札。覚えた個人技を、1試合に1回だけ「この局面で出す」と構えられる。'
        '乗る手に +${(Formulas.signatureArmedBonus * 100).round()}%。'
        '外すと、その試合の残りが −${(Formulas.signatureMissPenalty * 100).round()}%。',
    '選べないものも試合を動かす。相手に退場者が出れば'
        ' +${(Formulas.numbersUpBonus * 100).round()}%、'
        '終盤に相手が前がかりになれば得点の手が通りやすくなる。逆もある。',
    '終盤（75分以降）に同点以下から決めた得点は、評価点が重く付く。'
        '終盤の局面はそのときのスコアで中身が変わり、追いかけているならリスクを取る局面、'
        'リードしているなら時間の使い方を問う局面が来る。',
    '1試合の1/4くらいは逆足で対応することになる。逆足の精度が低いとそこで落ちる。',
  ]),
  _GuideSection('評価点と出場機会', [
    '局面の成否で評価点が動く。基準は6.0で、良い試合は7点台、悪い試合は5点台。',
    '直近5試合の評価点で、次節の起用が決まる。'
        '${Formulas.benchThreshold}を下回ると途中出場、'
        '${Formulas.squadThreshold}を下回るとベンチ外。',
    'ゴール・アシスト（守る選手なら無失点）は評価点とは別に数えられ、'
        '出場機会と代表招集に効く。点を取る選手は干されない。',
    'ベンチ外が続いても、そのまま終わりにはならない。'
        '${Formulas.benchPatience}試合続けて外れたら必ず一度は声がかかる。',
    '監督の信頼が落ちきると「構想外」になり、評価点で取り戻す道が閉じる。'
        '戻るのは監督交代か移籍か出来事での歩み寄りだけ。'
        '落ちる前（信頼${Formulas.trustWarning}を切ったとき）に必ず画面に出る。',
    '荒い手は、失敗すると警告を受けることがある。今季5枚で1試合の出場停止、退場なら2試合。'
        '「止めるための反則」は、選べば必ず警告になる代わりに失点を1つ消す。',
    '次にどの立場で出られそうかは、「試合」タブの次節のところに出る。',
  ]),
  _GuideSection('伸ばす', [
    '能力は「練習」と「試合で成功した手」で伸びる。何を選ぶかがそのまま選手の形になる。',
    '「育成」タブの「育てる方向」で、伸ばしたい項目を3つまで選べる。'
        '練習ではその項目が優先して伸び、試合の成長もそこに寄る。伸びる量は変わらない。'
        '同じ項目を狙い続けるほど、土台より先に伸ばせる幅が広がる。',
    '若いほど伸びる。${Formulas.peakAge}歳を過ぎると鈍り、30歳前後から落ち始める。'
        '伸びしろが残っている選手ほど、20代半ばでも伸び続ける。',
    '能力には土台がある。筋力が低いまま最高速だけを上げることはできず、'
        '頭打ちのときは土台のほうが伸びる。',
    'ポテンシャル（上限）は数字では見せない。帯だけを出している。'
        '練習で大成功した週を重ねた選手は、稀に上限を超える'
        '（下地は大成功${Formulas.breakthroughGreatWeeks}回。「育成」タブに残りが出る）。',
    '経験点を自分で振ることもできる（既定は自動）。伸びるはずだったぶんを貯めて、'
        '同じカテゴリの中で好きな項目に振る。上の値ほど高くつく。',
    '伸び続けると停滞期が来る。数試合は積み上がらない。',
  ], extra: _trainingMenus),
  _GuideSection('自分の位置を知る', [
    '「育成」タブの「練習の成果」に、開幕からの伸びが出る。'
        '能力が1上がると、その能力で判定する局面が'
        '約${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}%通りやすくなる。'
        '試合中の選択肢にも、今季伸びたぶんが↑で付く。',
    '「選手」タブの「選手としての水準」で、総合力が世界のどのあたりかが分かる。'
        '総合力${Formulas.callUpOverall}が代表に呼ばれる目安。',
    '「クラブ」タブの「リーグの格付け」で、所属リーグが世界で何位かを見られる。'
        '上のリーグほど相手が強く、同じ手が通らなくなる。',
  ]),
  _GuideSection('選手を作る', [
    '名前・ポジション・年齢・身体・能力の割り振り・出身国・代理人を決めて始める。'
        'ポテンシャルは選べない——始めてから分かるのがキャリアもの。',
    '特性は作成画面で見えていて、引き直せる。'
        '長所は${Trait.strengthCounts.reduce(min)}〜${Trait.strengthCounts.reduce(max)}つで、'
        '多く引くほど欠点も付きやすい。',
    'サイドバックとウイングは、左右のどちらに立つかを決める。'
        '利き足と同じ側なら逆足の局面が減り、逆サイドなら内へ切り込んで打てる。',
    '身長は競り合いに、体重は当たりの強さとキレの入れ替えに効く。'
        '練習では動かないので、ここで決めた体格は一生ついてくる。',
    '能力はポジションの基準値から±6まで動かせる。増やしたぶんはどこかを削るので、'
        '総合力は変わらない。何を得意にするかだけを決める。',
    '出身国で、始めるリーグと代表と、外国人としての扱いが決まる。',
  ]),
  _GuideSection('個人技', [
    '元になる能力が${Signature.requirement}に届くと、その練習をしている週に'
        '個人技を覚えることがある。最大${Signature.maxOwned}つ。'
        'そのポジションで使う技しか覚えない。',
    '1つ狙える。「育成」タブの「個人技を狙う」に、全部の技の取得条件'
        '（元になる能力・今の値・あといくつ）が並んでいる。狙っている間は、'
        '練習では他の技を覚えない代わりに、条件を満たせば'
        '${(Formulas.signatureAimChance * 100).round()}%の週で掴む'
        '（狙わなければ${(Formulas.signatureChance * 100).round()}%）。',
    '覚えた技は、噛み合った手で +${(Formulas.signatureOnDetail * 100).round()}%。',
    '磨く。伸びなくなってきた歳から、その技を扱う練習で技のほうが深くなる'
        '（最大${Signature.maxMastery}段、1段 +${(Formulas.signaturePerMastery * 100).round()}%）。'
        '能力は落ちても、引き出しは増える。',
    '居残り練習でFK・PK・CKを磨ける。${SetPieceSkills.takerThreshold}に届くと'
        'クラブのキッカーを任される。',
  ]),
  _GuideSection('生まれ持った特性とコツ', [
    '特性はどれも一長一短で、上位互換は無い。伸ばせない——その選手の「向き・不向き」。',
    'コツ。キャリアで1つだけ、やってきたことが特性になる。'
        '試合経験${Knacks.experienceNeeded}・練習の大成功${Knacks.greatWeeksNeeded}回・'
        '同じ場面で${Knacks.momentsNeeded}回の勝負が条件で、候補は何度も勝負してきた'
        '場面からしか出ない。待っても引き直せない。',
  ], extra: _traitList),
  _GuideSection('クラブと監督', [
    '監督には戦術がある。求める形に沿った手（試合中に「監督好み」と出る）を選ぶと信頼が上がり、'
        '逆らうと下がる。成績が期待を下回れば監督は飛び、代われば信頼は白紙に戻る。',
    '役割。監督の戦術によっては、ポジションの中の役割に就ける'
        '（全${PlayerRole.values.length}種）。役割は総合力の測り方を変える——'
        '重く見てもらう能力を選ぶ代わりに、他は軽く見られる。'
        '新しい監督が使わない役割は、オフに外れる。',
    '約束。第${PromiseOffers.window}節までに1つだけ、監督に数字を約束できる。'
        '大きく出るほど見返りも罰も大きい。取り消せない。',
    '同ポジションの競争相手との力の差が、そのまま序列になる。'
        '相方とは試合と練習を重ねるほど呼吸が合い、移籍すると一からになる。',
    '自分が出る試合は、そのぶんクラブが強い（クラブとの力の差1につき'
        ' +${Formulas.starLift}、最大 +${Formulas.starLiftCap.round()}。途中出場は半分）。'
        '弱いクラブに居ても、自分が主力なら順位を持ち上げられる。出ない試合には効かない。',
  ], extra: _directives),
  _GuideSection('契約と移籍', [
    '契約が残っている間は、残留しても条件は動かない（1年減るだけ）。'
        '残り1年になって初めて、他クラブからの話が届く。',
    '移籍の話の年俸は、今季の出来で決まる。今より強いクラブは、その差のぶん上乗せして払う'
        '（強さ1につき +${(Formulas.stepUpPayPerPoint * 100).round()}%、'
        '最大 +${(Formulas.stepUpPayCap * 100).round()}%）。ただし控えとして呼ぶクラブは'
        '${(Formulas.benchOfferFactor * 100).round()}%しか払わない。'
        '話に書いてある「役割」を見ること。身の丈より上へ行くと、登録から外れることがある。',
    '契約には違約金が付く。伸びた選手は自分の違約金を追い越し、契約が残っていても話が動き出す。',
    '出番の無い若手にはローンの話が来る。保有元との契約は凍り、1年で戻る。',
    '登録外や構想外で使われていないなら、契約が残っていても話が来る（ローンは歳に関係なく）。',
    '最上位の国のクラブは、名前で選ぶ。代表${Formulas.eliteCaps}キャップか、'
        '知名度${Formulas.eliteFame}に届くまで声がかからない。'
        '知名度は出場と代表と大舞台で上がり、露出が止まると有名なほど早く薄れる。',
    '代理人は交渉力・人脈・手数料が違う。上乗せ交渉は、移籍のオファーだと'
        '失敗して撤回されることがある。契約更改は撤回されない。',
  ]),
  const _GuideSection('代表・カップ', [
    '代表は総合力と直近の出来で呼ばれる。点を取り続けていれば、評価点が届かなくても呼ばれる。'
        '複数の国籍を持っていれば、どの代表でやるかを選べる。',
    '世界大会は4年に1度。代表に呼ばれている選手だけが出られる。',
    '国内カップは一発勝負なので、格下でも勝ち上がることがある。'
        '優勝すれば翌季の大陸カップ出場権が付く。カップ戦の週は練習できない。',
  ]),
  const _GuideSection('怪我・コンディション・気持ち', [
    'コンディションは1週間で戻るが、累積疲労は戻らない。オフでだいたい抜ける。',
    '怪我をしたら復帰の進め方を選べる。強行すれば早く戻れる代わりに、'
        '復帰直後の再発が跳ね上がる。重傷は能力とポテンシャルを恒久的に削る。',
    '気持ちは出番と私生活で動く。ピッチ外の出来事で上下するが、'
        '1回で人生が決まるほどの効きは無い。',
    '実力とは別に、数試合だけ続く波（ゾーン／スランプ）がある。',
  ]),
  const _GuideSection('お金', [
    '年俸からは税・代理人手数料・生活費が引かれ、残りが貯蓄になる。',
    '今季いくら残るかは「育成」タブの「自分への投資」に出ている。'
    '雇う前に、シーズン末の貯蓄がいくらになるかまで書いてある。',
    '貯蓄が尽きると、専属スタッフとの契約は全部切れる。'
    '足りなくなりそうなら、雇う人数を減らすか、暮らし方を下げること。',
    '暮らし方は生活費を決める。下げれば手取りが増え、'
    '上げれば気持ちが少し上向く。効きは小さい。',
    '知名度が上がるとスパイクのスポンサーが付く。年俸とは別の収入になる。',
  ], extra: _staffKinds),
  const _GuideSection('ピッチの外', [
    '数試合に一度、ピッチの外で何かが起きる。選択肢が出て、選んだことが'
    '気持ち・監督との関係・ロッカールームの空気・お金に残る。',
    '監督・競争相手・相方・メンター・同期・代理人は、名前を持った他人として'
    '出来事に出てくる。誰が居るかで、起きることが変わる。',
    '練習の中の出来事では、能力が伸びたり、個人技を閃いたりする。'
    'ただしポテンシャルを超えては伸びない。上限は上限のまま。',
    'どの選択肢も、1回でキャリアが決まる大きさにはしていない。'
    '10年ぶんの積み重ねが、同じ成績の選手を別の人生にする。',
  ]),
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
        for (final trait in Trait.strengths)
          (trait.label, '${trait.description}（${trait.effects.join('、')}）'),
      ]),
      const SizedBox(height: 8),
      Text('欠点（${Trait.flaws.length}種）',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.error)),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.flaws)
          (trait.label, '${trait.description}（${trait.effects.join('、')}）'),
      ]),
      const SizedBox(height: 8),
      Text('稀（${Trait.rares.length}種）', style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      Text(
        '長所は${(Trait.rareChance * 100).round()}%、'
        '欠点は${(Trait.rareFlawChance * 100).round()}%の確率で、'
        '普通の特性の1つと置き換わる。',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.rares)
          (
            trait.flaw ? '${trait.label}（欠点）' : trait.label,
            '${trait.description}（${trait.effects.join('、')}）',
          ),
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

/// ガイドの本文をすべて1つの文字列で。
///
/// **テストが「載っているか」を見るためのもの**（`test/guide_test.dart`）。
/// 仕組みを足すたびにガイドを書き忘れ、9/10 からの2週間で
/// 載っていない仕組みが10を超えていた。
@visibleForTesting
String guideText() =>
    _sections.expand((s) => [s.title, ...s.body]).join('\n');
