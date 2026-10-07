import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/scenarios.dart';
import '../../game/world.dart';
import '../../game/knacks.dart';
import '../../game/match_target.dart';
import '../../game/promises.dart';
import '../../models/attributes.dart';
import '../../models/club.dart';
import '../../models/development.dart';
import '../../models/entourage.dart';
import '../../models/role.dart';
import '../../models/support.dart';
import '../../models/traits.dart';
import '../../models/training.dart';
import '../fixture_banner.dart';
import '../pitch_view.dart';
import '../readable_width.dart';
import '../stat_tile.dart';

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
    // 章ごとに並べ替える。**16枚が同じ顔で並んでいると、畳んだままの
    // 一覧がただの壁になる**（どこから読めばいいのか分からない）。
    final chapters = <String, List<_GuideSection>>{};
    for (final section in _sections) {
      chapters.putIfAbsent(section.chapter, () => []).add(section);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('遊び方ガイド')),
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
                    'このゲームは、1人の選手の現役生活をなぞるもの。'
                    'やることは「今週どう過ごすか」と「試合の局面で何を選ぶか」の2つだけで、'
                    'それを38節×十数シーズンくり返す。'
                    '残りはすべて、その積み重ねの結果として動く。',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // **その2つを、文より先に絵で見せる。**
              const _WeekLoop(),
              const SizedBox(height: 8),
              const _ChoiceShape(),
              for (final entry in chapters.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final section in entry.value)
                  _GuideTile(section: section),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 1週間と1シーズンの回り方。**ガイドの本文はこれを言葉で説明しているが、
/// 「くり返す」という形そのものは、絵でないと一目で入らない。**
class _WeekLoop extends StatelessWidget {
  const _WeekLoop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = [
      (Icons.fitness_center, '練習を', '決める'),
      (Icons.sports_soccer, '試合で', '選ぶ'),
      (Icons.assignment_turned_in, '評価点が', '付く'),
      (Icons.event_repeat, '次の節', 'へ'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('1週間の回り方', style: theme.textTheme.titleSmall),
            ),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            steps[i].$1,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].$2,
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          steps[i].$3,
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (i < steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '38節でシーズンが終わり、契約・移籍・オフの過ごし方を決めて'
                    '次の季へ。それを引退まで。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 3つの手の形。**「常に正解になる手は無い」は、文で読むより
/// 2本の矢印が逆を向いている絵のほうが早い。**
class _ChoiceShape extends StatelessWidget {
  const _ChoiceShape();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 幅の比は見た目のためのもので、判定の数字ではない（だから％を書かない）。
    const rows = [
      ('安全な手', 0.85, 0.25),
      ('ふつうの手', 0.60, 0.55),
      ('勝負の手', 0.30, 0.95),
    ];
    Widget bar(double value, Color color) => Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('1つの局面に、3つの手', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 76),
              child: Row(
                children: [
                  Expanded(
                    child: Text('通りやすさ', style: theme.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('見返り', style: theme.textTheme.labelSmall),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final (label, chance, reward) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    bar(chance, theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    bar(reward, theme.colorScheme.tertiary),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '通りやすい手ほど見返りが小さい。常に正解になる手は無いので、'
              'どちらを選ぶかがこのゲームそのもの。'
              '通る確率は手ごとに％で出ていて、その内訳も画面に出る。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ガイドの1項目。
class _GuideSection {
  const _GuideSection(
    this.title,
    this.body, {
    required this.chapter,
    required this.icon,
    required this.lead,
    this.peek,
    this.extra,
  });

  final String title;
  final List<String> body;

  /// どの章に置くか。
  final String chapter;

  final IconData icon;

  /// **畳んだままでも何の話か分かる1行。**
  /// ここに数字を書かない——本文は実装から引いているので、
  /// 写した数字だけが黙って古くなる。
  final String lead;

  /// 本文の前に置く「実際の画面」。
  ///
  /// **絵ではなく本物のウィジェット。** 写真を貼ると、画面を直したときに
  /// ガイドだけが古くなる（数字を手で書き写すのと同じ腐り方）。
  final Widget Function(BuildContext)? peek;

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
        key: PageStorageKey<String>('guide-${section.title}'),
        leading: Icon(section.icon, color: theme.colorScheme.primary),
        title: Text(section.title, style: theme.textTheme.titleSmall),
        // **畳んだままの一覧が、それだけで目次になる。**
        subtitle: Text(
          section.lead,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.peek != null) ...[
            section.peek!(context),
            const SizedBox(height: 14),
          ],
          // 段落の頭に点を置く。**文の壁のまま流すと、どこが切れ目か
          // 分からないので一息で読めない。**
          for (final paragraph in section.body)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
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
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// 「実際の画面」の枠。中身は本物のウィジェット。
class _Peek extends StatelessWidget {
  const _Peek({required this.child, required this.note});

  final Widget child;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_iphone,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '実際の画面',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 8),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 見本に使うクラブ。**実在のリーグから引く**ので、色もエンブレムも
/// 遊んでいるときに出るものと同じ作りになる。
List<Club> _sampleClubs() => World.buildLeague('yamato', 1);

/// 次節のカード。
Widget _fixturePeek(BuildContext context) {
  final theme = Theme.of(context);
  final clubs = _sampleClubs();
  return _Peek(
    note: '「今週」タブの先頭に出るカード。'
        '自分のクラブと相手の色がそのまま帯になり、下端の細い線が'
        'シーズンの進み。移籍すれば、ここの色ごと変わる。',
    child: FixtureBanner(
      club: clubs[5],
      opponent: clubs[11],
      home: true,
      progress: 9 / 38,
      caption: 'ホーム',
      centre: Text('第9節', style: theme.textTheme.titleMedium),
    ),
  );
}

/// 局面と、そこに並ぶ3つの手。
Widget _scenarioPeek(BuildContext context) {
  final theme = Theme.of(context);
  final clubs = _sampleClubs();
  final scenario = ScenarioPool.forFamily(
    ScenarioFamily.midfield,
  ).firstWhere((s) => s.id == 'mf-build');

  return _Peek(
    note: '実際の画面では、この難しさと自分の能力・コンディション・特性から'
        '出した「通る確率」が、手ごとに％で出る。'
        'その％が何でできているかも、同じ画面に並ぶ。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PitchView(
            spot: scenario.spot,
            club: clubs[5],
            opponent: clubs[11],
            style: ClubStyle.of(clubs[11]),
          ),
        ),
        const SizedBox(height: 8),
        Text(scenario.situation, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final option in scenario.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: GaugeBar(
                    value: option.difficulty / 100,
                    color: theme.colorScheme.tertiary,
                    height: 7,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 54,
                  child: Text(
                    '難しさ ${option.difficulty}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 評価点と、監督の期待。
Widget _ratingPeek(BuildContext context) {
  final theme = Theme.of(context);
  return _Peek(
    note: '評価点の色は、起用の線（先発・ベンチ）から引いている——'
        '表示のためだけの別の線は置いていない。'
        '棒は監督の期待で、残りがひと目で分かる形にしてある。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatTile(
              label: '平均評価',
              value: '7.21',
              accent: ratingColor(theme, 7.21),
            ),
            const SizedBox(width: 20),
            const StatTile(label: '出場', value: '28'),
            const SizedBox(width: 20),
            const StatTile(label: 'ゴール', value: '9'),
          ],
        ),
        const SizedBox(height: 12),
        const StatBar(
          label: '得点関与',
          now: 11,
          target: 14,
          text: '11 / 14',
        ),
      ],
    ),
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
  _GuideSection(
    '1週間の流れ',
    chapter: '試合に出る',
    icon: Icons.calendar_today,
    lead: '練習を決めて、試合に出る。それを38節くり返す',
    peek: _fixturePeek,
    [
    '「今週」タブで次の相手と今の状態を見て、そこから試合に入る。'
        '練習はそのカードから、あるいは「育成」タブで決める。'
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
    'オフの過ごし方は4つ。鍛え込めば一番伸びるが開幕は重く怪我も増え、'
        '休めば溜まった疲れが抜ける代わりに出遅れる。'
        '絞るのはその中間、名前を売れば知名度と引き換えに疲れが残る。'
        'どれにも失うものがある。',
    '監督に伝える方針でも、行き先が変わる。出場機会が欲しいと言えば'
        '身の丈のクラブからしか声がかからず、勝ちたいと言えば格上から来る'
        '（そのぶん序列は下から）。',
  ]),
  _GuideSection(
    '試合で選ぶ',
    chapter: '試合に出る',
    icon: Icons.sports_soccer,
    lead: '局面ごとに3つの手。安全か、賭けるか',
    peek: _scenarioPeek,
    [
    'ふつうの試合は${Formulas.scenariosPerStart}つ、順位や因縁が絡む'
        '「じっくりやる試合」は${Formulas.scenariosPerBigStart}つの局面が来る'
        '（途中出場ならもっと少ない）。各局面に3つの手がある。',
    'だいたい「難しいが得点に直結する手」と「安全だが見返りの小さい手」が対になっている。'
        '常に正解になる手は無い。',
    'じっくりやる試合は局面が多いので、前の局面で布石を打ってから仕留める'
        '段取りが組める。実測では、その組み立てのほうが'
        '毎回いちばん確率の高い手を押すよりゴールもタイトルも多い'
        '（そのぶん平均評価は少し下がる）。',
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
  _GuideSection(
    '評価点と出場機会',
    chapter: '試合に出る',
    icon: Icons.trending_up,
    lead: '選んだ手が評価点になり、評価点が次の出番を決める',
    peek: _ratingPeek,
    [
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
    '次にどの立場で出られそうかは、「今週」タブの次節のところに出る。',
  ]),
  _GuideSection(
    '伸ばす',
    chapter: '選手を育てる',
    icon: Icons.fitness_center,
    lead: '伸ばす先は自分で選ぶ。練習と、試合で成功した手から',
    [
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
  _GuideSection(
    '自分の位置を知る',
    chapter: 'クラブと世界',
    icon: Icons.public,
    lead: 'いま世界の何番目にいるのかが、常に見える',
    [
    '「育成」タブの「練習の成果」に、開幕からの伸びが出る。'
        '能力が1上がると、その能力で判定する局面が'
        '約${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}%通りやすくなる。'
        '試合中の選択肢にも、今季伸びたぶんが↑で付く。',
    '「選手」タブの「選手としての水準」で、総合力が世界のどのあたりかが分かる。'
        '代表に呼ばれる線もそこに出る。線は国の格で動き、'
        '格の高い国ほど高い（格3の国で総合力${Formulas.callUpOverall}）。',
    '「クラブ」タブの「リーグの格付け」で、所属リーグが世界で何位かを見られる。'
        '上のリーグほど相手が強く、同じ手が通らなくなる。',
  ]),
  _GuideSection(
    '選手を作る',
    chapter: '選手を育てる',
    icon: Icons.person_add,
    lead: '始める前に決めること。ポテンシャルだけは選べない',
    [
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
  _GuideSection(
    '個人技',
    chapter: '選手を育てる',
    icon: Icons.auto_awesome,
    lead: '覚えた技は、構えて使うと効く',
    [
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
  _GuideSection(
    '生まれ持った特性とコツ',
    chapter: '選手を育てる',
    icon: Icons.psychology,
    lead: '生まれつきのものと、やってきたことで身に付くもの',
    [
    '特性はどれも一長一短で、上位互換は無い。伸ばせない——その選手の「向き・不向き」。',
    'コツ。キャリアで1つだけ、やってきたことが特性になる。'
        '試合経験${Knacks.experienceNeeded}・練習の大成功${Knacks.greatWeeksNeeded}回・'
        '同じ場面で${Knacks.momentsNeeded}回の勝負が条件で、候補は何度も勝負してきた'
        '場面からしか出ない。待っても引き直せない。',
  ], extra: _traitList),
  _GuideSection(
    'クラブと監督',
    chapter: 'クラブと世界',
    icon: Icons.groups,
    lead: '監督は数字ではなく「何を選んだか」を見る',
    [
    '監督には戦術がある。求める形に沿った手（試合中に「監督好み」と出る）を選ぶと信頼が上がり、'
        '逆らうと下がる。成績が期待を下回れば監督は飛び、代われば信頼は白紙に戻る。',
    '役割。監督の戦術によっては、ポジションの中の役割に就ける'
        '（全${PlayerRole.values.length}種）。役割は総合力の測り方を変える——'
        '重く見てもらう能力を選ぶ代わりに、他は軽く見られる。'
        '新しい監督が使わない役割は、オフに外れる。',
    '監督はシーズンの初めに3つの数字（出場・得点関与・平均評価）を期待として置く。'
        '**2つ以上で達成**で、信頼と契約更改の年俸に効く。'
        '普通にやって3〜4割は届かない高さに置いてある。',
    '約束。第${PromiseOffers.window}節までに1つだけ、監督に数字を約束できる。'
        '大きく出るほど見返りも罰も大きい。取り消せない。',
    '同ポジションの競争相手との力の差が、そのまま序列になる。'
        '相方とは試合と練習を重ねるほど呼吸が合い、移籍すると一からになる。',
    '相手には戦い方がある。難しくなる能力が1つ（−${(Formulas.styleMismatch * 100).round()}%、'
        '何度も当たると慣れて薄まる）、代わりに空く能力が1つ'
        '（+${(Formulas.styleOpening * 100).round()}%、こちらは慣れでは動かない）。',
    '今節の的。節ごとに1つ出て、達成すると${MatchTarget.reward}万円。'
        'リーグ戦だけで数える（カップ戦は節を進めないので素通り）。'
        '続けて達成すると連続が伸び、${MatchTarget.streakStep}回ごとに'
        'その的が問うている能力へ経験点が${MatchTarget.streakPoints}点入る。'
        '外しても、出られなくても連続は切れる。',
    '自分が出た試合と出なかった試合の成績は、「記録」タブの今シーズンの成績に並ぶ。'
        '居ないと勝てないクラブなら、そこに差が出る。',
    '自分が出る試合は、そのぶんクラブが強い（クラブとの力の差1につき'
        ' +${Formulas.starLift}、最大 +${Formulas.starLiftCap.round()}。途中出場は半分）。'
        '弱いクラブに居ても、自分が主力なら順位を持ち上げられる。出ない試合には効かない。',
  ], extra: _directives),
  _GuideSection(
    '契約と移籍',
    chapter: 'クラブと世界',
    icon: Icons.swap_horiz,
    lead: '話が来るかどうかは、出来と契約で決まる',
    [
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
    '年俸には出場給が乗る。${Formulas.appearanceBaseline}試合を基準に、'
        '出るほど増え、怪我やベンチで欠けたぶんは減る'
        '（最大 ±${(Formulas.appearanceBonusRate * 100).round()}%）。'
        '座っているだけでは、同じ額はもらえない。',
    '最上位の国のクラブは、名前で選ぶ。代表${Formulas.eliteCaps}キャップか、'
        '知名度${Formulas.eliteFame}に届くまで声がかからない。'
        '知名度は出場と代表と大舞台で上がり、露出が止まると有名なほど早く薄れる。',
    '代理人は交渉力・人脈・手数料が違う。上乗せ交渉は、移籍のオファーだと'
        '失敗して撤回されることがある。契約更改は撤回されない。',
  ]),
  const _GuideSection(
    '代表・カップ',
    chapter: 'クラブと世界',
    icon: Icons.emoji_events,
    lead: 'リーグの外の舞台。呼ばれる線は国で変わる',
    [
    '代表は総合力と直近の出来で呼ばれる。点を取り続けていれば、評価点が届かなくても呼ばれる。'
        '複数の国籍を持っていれば、どの代表でやるかを選べる。',
    '世界大会は4年に1度。代表に呼ばれている選手だけが出られる。',
    '国内カップは一発勝負なので、格下でも勝ち上がることがある。'
        '優勝すれば翌季の大陸カップ出場権が付く。カップ戦の週は練習できない。',
  ]),
  const _GuideSection(
    '怪我・コンディション・気持ち',
    chapter: '選手の人生',
    icon: Icons.healing,
    lead: '押すか休むか。重傷だけは戻らない',
    [
    'コンディションは1週間で戻るが、累積疲労は戻らない。オフでだいたい抜ける。',
    '怪我をしたら復帰の進め方を選べる。強行すれば早く戻れる代わりに、'
        '復帰直後の再発が跳ね上がる。重傷は能力とポテンシャルを恒久的に削る。',
    '気持ちは出番と私生活で動く。ピッチ外の出来事で上下するが、'
        '1回で人生が決まるほどの効きは無い。',
    '実力とは別に、数試合だけ続く波（ゾーン／スランプ）がある。',
  ]),
  const _GuideSection(
    'お金',
    chapter: '選手の人生',
    icon: Icons.savings,
    lead: '稼ぎの使い道。身体に投資するか、貯めるか',
    [
    '年俸からは税・代理人手数料・生活費が引かれ、残りが貯蓄になる。',
    '今季いくら残るかは「育成」タブの「自分への投資」に出ている。'
        '雇う前に、シーズン末の貯蓄がいくらになるかまで書いてある。',
    '貯蓄が尽きると、専属スタッフとの契約は全部切れる。'
        '足りなくなりそうなら、雇う人数を減らすか、暮らし方を下げること。',
    '暮らし方は生活費を決める。下げれば手取りが増え、'
        '上げれば気持ちが少し上向く。効きは小さい。',
    '知名度が上がるとスパイクのスポンサーが付く。年俸とは別の収入になる。',
  ], extra: _staffKinds),
  const _GuideSection(
    'ピッチの外',
    chapter: '選手の人生',
    icon: Icons.coffee,
    lead: '物語であって罠ではない。1回で人生は決まらない',
    [
    '数試合に一度、ピッチの外で何かが起きる。選択肢が出て、選んだことが'
        '気持ち・監督との関係・ロッカールームの空気・お金に残る。',
    '監督・競争相手・相方・メンター・同期・代理人は、名前を持った他人として'
        '出来事に出てくる。誰が居るかで、起きることが変わる。',
    '練習の中の出来事では、能力が伸びたり、個人技を閃いたりする。'
        'ただしポテンシャルを超えては伸びない。上限は上限のまま。',
    'どの選択肢も、1回でキャリアが決まる大きさにはしていない。'
        '10年ぶんの積み重ねが、同じ成績の選手を別の人生にする。',
  ]),
  const _GuideSection(
    '引退とその後',
    chapter: '選手の人生',
    icon: Icons.military_tech,
    lead: 'やってきたことが、次の道の適性になる',
    [
    '33歳から引退を選べる。37歳のシーズンを終えると引退になる。',
    '引退後は通算成績と称号が残り、次に進む道を選ぶ。'
        '現役でやってきたことが、そのまま次の職業の適性になる。',
  ]),
  const _GuideSection(
    '保存と持ち運び',
    chapter: '選手の人生',
    icon: Icons.save,
    lead: '記録は端末の中だけ。引き継ぎコードで運ぶ',
    [
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
      Text('長所（${Trait.strengths.length}種）', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.strengths)
          (trait.label, '${trait.description}（${trait.effects.join('、')}）'),
      ]),
      const SizedBox(height: 8),
      Text(
        '欠点（${Trait.flaws.length}種）',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
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
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
    (StaffTeam.levelLabels[level], '年間 ${StaffTeam.costPerLevel[level]}万円'),
]);

/// ガイドの本文をすべて1つの文字列で。
///
/// **テストが「載っているか」を見るためのもの**（`test/guide_test.dart`）。
/// 仕組みを足すたびにガイドを書き忘れ、9/10 からの2週間で
/// 載っていない仕組みが10を超えていた。
@visibleForTesting
String guideText() =>
    _sections.expand((s) => [s.title, s.lead, ...s.body]).join('\n');
