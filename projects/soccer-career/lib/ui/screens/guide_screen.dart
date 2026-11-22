import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/scenarios.dart';
import '../../game/world.dart';
import '../../l10n/lang.dart';
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
      appBar: AppBar(title: Text(tr('遊び方ガイド', 'How to play'))),
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    tr('このゲームは、1人の選手の現役生活をなぞるもの。'
                    'やることは「今週どう過ごすか」と「試合の局面で何を選ぶか」の2つだけで、'
                    'それを38節×十数シーズンくり返す。'
                    '残りはすべて、その積み重ねの結果として動く。', 'This game follows one player through his career. There are only two things to do: decide how to spend the week, and choose what to do in the match situations. Repeat that over 38 matchdays and a dozen or more seasons. Everything else moves as a result of that.'),
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
    final steps = [
      (Icons.fitness_center, tr('練習を', 'Decide the'), tr('決める', 'training')),
      (Icons.sports_soccer, tr('試合で', 'Choose in'), tr('選ぶ', 'the match')),
      (Icons.assignment_turned_in, tr('評価点が', 'A rating'), tr('付く', 'is given')),
      (Icons.event_repeat, tr('次の節', 'On to the'), tr('へ', 'next week')),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(tr('1週間の回り方', 'How a week goes'), style: theme.textTheme.titleSmall),
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
                    tr('38節でシーズンが終わり、契約・移籍・オフの過ごし方を決めて'
                    '次の季へ。それを引退まで。', 'A season ends after 38 matchdays, then you settle your contract, transfers and the off-season, and go again. Until you retire.'),
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
    final rows = [
      (tr('安全な手', 'The safe move'), 0.85, 0.25),
      (tr('ふつうの手', 'The normal move'), 0.60, 0.55),
      (tr('勝負の手', 'The bold move'), 0.30, 0.95),
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
              child: Text(tr('1つの局面に、3つの手', 'Three moves in every situation'), style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 76),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('通りやすさ', 'Chance'), style: theme.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('見返り', 'Reward'), style: theme.textTheme.labelSmall),
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
              tr('通りやすい手ほど見返りが小さい。常に正解になる手は無いので、'
              'どちらを選ぶかがこのゲームそのもの。'
              '通る確率は手ごとに％で出ていて、その内訳も画面に出る。', 'The more likely a move is to come off, the less it pays. No move is always right, and choosing between them is the game. The chance is shown as a percentage on each move, and so is what it is made of.'),
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
                tr('実際の画面', 'On the screen'),
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
    note: tr('「今週」タブの先頭に出るカード。'
        '自分のクラブと相手の色がそのまま帯になり、下端の細い線が'
        'シーズンの進み。移籍すれば、ここの色ごと変わる。', 'The card at the top of the Week tab. Your club and the opponent colour the band, and the thin line at the bottom is the season. Move club and the colours change with you.'),
    child: FixtureBanner(
      club: clubs[5],
      opponent: clubs[11],
      home: true,
      progress: 9 / 38,
      caption: tr('ホーム', 'Home'),
      centre: Text(tr('第9節', 'Round 9'), style: theme.textTheme.titleMedium),
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
    note: tr('実際の画面では、この難しさと自分の能力・コンディション・特性から'
        '出した「通る確率」が、手ごとに％で出る。'
        'その％が何でできているかも、同じ画面に並ぶ。', 'On the real screen, the chance of the move coming off is shown as a percentage, worked out from this difficulty, your attributes, your condition and your traits. What that percentage is made of is on the same screen.'),
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
                    tr('難しさ ${option.difficulty}', 'Difficulty ${option.difficulty}'),
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
    note: tr('評価点の色は、起用の線（先発・ベンチ）から引いている——'
        '表示のためだけの別の線は置いていない。'
        '棒は監督の期待で、残りがひと目で分かる形にしてある。', 'The rating colour comes from the selection lines (starter, bench). There is no separate line just for display. The bar is the manager target, so what is left is clear at a glance.'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatTile(
              label: tr('平均評価', 'Average rating'),
              value: '7.21',
              accent: ratingColor(theme, 7.21),
            ),
            const SizedBox(width: 20),
            StatTile(label: tr('出場', 'Appearances'), value: '28'),
            const SizedBox(width: 20),
            StatTile(label: tr('ゴール', 'Goals'), value: '9'),
          ],
        ),
        const SizedBox(height: 12),
        StatBar(
          label: tr('得点関与', 'Goals and assists'),
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
    tr('1週間の流れ', 'A week at a time'),
    chapter: tr('試合に出る', 'Play the match'),
    icon: Icons.calendar_today,
    lead: tr('練習を決めて、試合に出る。それを38節くり返す', 'Decide the training, play the match. 38 times a season'),
    peek: _fixturePeek,
    [
    tr('「今週」タブで次の相手と今の状態を見て、そこから試合に入る。'
        '練習はそのカードから、あるいは「育成」タブで決める。'
        '終われば1週間が過ぎ、次の節が来る。', 'The Week tab shows your next opponent and your current state, and you go into the match from there. Training is set on that card, or on the Training tab. When it is done a week has passed and the next round comes.'),
    tr('練習は3つを決める。何をするか（メニュー）・どこまで踏み込むか'
        '（${TrainingEffort.values.map((e) => e.label).join('／')}）・'
        '誰と組むか（${TrainingCompanion.values.map((c) => c.label).join('／')}）。', 'Training is three decisions. What to do (the menu), how hard to push (${TrainingEffort.values.map((e) => e.label).join(' / ')}) and who to work with (${TrainingCompanion.values.map((c) => c.label).join(' / ')}).'),
    tr('追い込むほど大成功（1週で2つ伸びる）が出やすいが、疲れて怪我もしやすい。'
        '疲れている週ほど空回りする。追い込み続けた身体は、衰えが早く来る。', 'Push harder and great weeks (two gains in one week) come more often, but you tire and get injured more. The more tired the week, the more it is wasted. A body that keeps being pushed declines earlier.'),
    tr('${Formulas.declineAge}歳前後から衰えが始まり、歳とともに速くなる。落ちるのは'
        '走力と身体からが多い。その週に練習しているカテゴリは衰えないので、'
        '後半は「何を守るか」を練習で選ぶ。脚を守ればパスが落ち、パスを守れば脚が落ちる。', 'Decline starts around ${Formulas.declineAge} and speeds up with age. It usually takes pace and physique first. The category you are training that week does not decline, so the back half is about choosing what to protect. Protect your legs and your passing drops; protect your passing and your legs do.'),
    tr('コンディションが決めた値を下回った週は、自動で休養になる。'
        '練習も居残りも止まる。既定は40未満で、「育成」タブで変えられる'
        '（切ることもできる）。効いた週は試合結果の画面にそう出る。', 'A week where condition falls below your chosen line becomes rest automatically. Training and extra sessions both stop. The default is under 40, and you can change it on the Training tab, or switch it off. When it kicks in, the match result screen says so.'),
    tr('全38節を戦い終えるとシーズンが終わり、契約・移籍・オフの過ごし方を決める。', 'When all 38 rounds are played the season ends, and you settle your contract, transfers and the off-season.'),
    tr('オフの過ごし方は4つ。鍛え込めば一番伸びるが開幕は重く怪我も増え、'
        '休めば溜まった疲れが抜ける代わりに出遅れる。'
        '絞るのはその中間、名前を売れば知名度と引き換えに疲れが残る。'
        'どれにも失うものがある。', 'There are four ways to spend the off-season. Train hard for the biggest gains but a heavy start and more injuries; rest to clear built-up fatigue but start behind. Slimming down is in between, and building your name trades fatigue for fame. Every one of them costs something.'),
    tr('監督に伝える方針でも、行き先が変わる。出場機会が欲しいと言えば'
        '身の丈のクラブからしか声がかからず、勝ちたいと言えば格上から来る'
        '（そのぶん序列は下から）。', 'What you tell the manager changes where you can go, too. Say you want to play and only clubs your own size call; say you want to win and bigger clubs do, but you start at the back of the queue.'),
  ]),
  _GuideSection(
    tr('試合で選ぶ', 'Choosing in the match'),
    chapter: tr('試合に出る', 'Play the match'),
    icon: Icons.sports_soccer,
    lead: tr('局面ごとに3つの手。安全か、賭けるか', 'Three moves each time. Safe, or a gamble'),
    peek: _scenarioPeek,
    [
    tr('ふつうの試合は${Formulas.scenariosPerStart}つ、順位や因縁が絡む'
        '「じっくりやる試合」は${Formulas.scenariosPerBigStart}つの局面が来る'
        '（途中出場ならもっと少ない）。各局面に3つの手がある。', 'A normal match brings ${Formulas.scenariosPerStart} situations; a big one, where the table or a rivalry is at stake, brings ${Formulas.scenariosPerBigStart} (fewer off the bench). Each one has three moves.'),
    tr('だいたい「難しいが得点に直結する手」と「安全だが見返りの小さい手」が対になっている。'
        '常に正解になる手は無い。', 'Broadly they pair a hard move that leads straight to a goal with a safe move that pays little. No move is always right.'),
    tr('じっくりやる試合は局面が多いので、前の局面で布石を打ってから仕留める'
        '段取りが組める。実測では、その組み立てのほうが'
        '毎回いちばん確率の高い手を押すよりゴールもタイトルも多い'
        '（そのぶん平均評価は少し下がる）。', 'Big matches have more situations, so you can lay the ground in one and finish in another. Measured, that way of building brings more goals and more titles than always pressing the most likely move, at the cost of a slightly lower average rating.'),
    tr('手に出ている％は、その手が通る確率。判定に使う数字そのもので、'
        '何でできているかも画面に出ている。局面の上に並ぶのは'
        '「どの手でも同じだけ効くもの」、手ごとに付くのは「その手にだけ効くもの」。', 'The percentage on a move is the chance it comes off. It is the number used in the judgement itself, and what it is made of is on the screen. What is listed above the situation applies to every move; what is attached to a move applies only to that one.'),
    tr('ゴールやアシストの手には「ゴール○%」も出る。手が通っても決まるとは限らない。', 'Moves that lead to a goal or assist also show a goal percentage. A move coming off does not mean it goes in.'),
    tr('ノリ。手を通し続けると乗ってくる（最大${Formulas.momentumMax}段）。'
        '乗るほど決まる確率が上がり、1段で'
        '×${(1 + Formulas.momentumPerStep).toStringAsFixed(1)}。失敗すると消える。', 'Momentum. Keep moves coming off and it builds (up to ${Formulas.momentumMax} steps). The more it builds, the more likely things go in: times ${(1 + Formulas.momentumPerStep).toStringAsFixed(1)} per step. A failure clears it.'),
    tr('布石と仕留め。局面によっては、安全な手に「布石」、難しい得点の手に'
        '「仕留め」の印が付く。布石を通しておくと、その試合のうちに選んだ仕留めが'
        '+${(Formulas.comboBonus * 100).round()}% 通りやすく、'
        '×${Formulas.comboConversion.toStringAsFixed(1)} 決まりやすくなる。'
        '仕留めにいけば、通っても外しても使い切る。'
        '局面の多いじっくりやる試合で効く——自動で進めると、ここは使わない。', 'Set-up and finish. In some situations a safe move is marked set-up and a hard scoring move is marked finish. Get the set-up in and the finish you choose later in that match is +${(Formulas.comboBonus * 100).round()}% to come off and times ${Formulas.comboConversion.toStringAsFixed(1)} to go in. Going for the finish uses it up whether it comes off or not. It pays in big matches with more situations, and the auto-play never uses it.'),
    tr('切り札。覚えた個人技を、1試合に1回だけ「この局面で出す」と構えられる。'
        '乗る手に +${(Formulas.signatureArmedBonus * 100).round()}%。'
        '外すと、その試合の残りが −${(Formulas.signatureMissPenalty * 100).round()}%。', 'Trump card. Once a match you can set a trick you have learned for a particular situation. +${(Formulas.signatureArmedBonus * 100).round()}% on a move it fits. Miss and the rest of the match is -${(Formulas.signatureMissPenalty * 100).round()}%.'),
    tr('選べないものも試合を動かす。相手に退場者が出れば'
        ' +${(Formulas.numbersUpBonus * 100).round()}%、'
        '終盤に相手が前がかりになれば得点の手が通りやすくなる。逆もある。', 'Things you cannot choose move the match too. If they go down to ten it is +${(Formulas.numbersUpBonus * 100).round()}%, and if they push forward late your scoring moves come off more easily. It works the other way as well.'),
    tr('試合の状況で、手の値打ちが変わる。追いかけている時間（1点差なら'
        '${Formulas.situationalMinute}分、2点差なら${Formulas.bigDeficitMinute}分から）と'
        '同点の終盤（${Formulas.lateGameMinute}分以降）は、決めにいく手の評価が'
        '×${Formulas.decisiveGoalFactor.toStringAsFixed(1)}、つなぐだけの手は'
        '×${Formulas.stakesChasePlay}（同点なら×${Formulas.stakesLevelPlay}）。'
        'リードして${Formulas.situationalMinute}分を過ぎたら、つなぐ手が'
        '×${Formulas.stakesHoldPlay}、外したときの減点が×${Formulas.stakesHoldFailure}。'
        '手の横に「今は重い」「今は軽い」「外すと痛い」と出る。', 'The state of the match changes what a move is worth. While you are chasing (from the ${Formulas.situationalMinute}th minute one goal down, the ${Formulas.bigDeficitMinute}th two down) and late in a level game (from the ${Formulas.lateGameMinute}th), moves that go for it are rated times ${Formulas.decisiveGoalFactor.toStringAsFixed(1)} and moves that just keep it times ${Formulas.stakesChasePlay} (times ${Formulas.stakesLevelPlay} when level). Protecting a lead after the ${Formulas.situationalMinute}th, keeping it is times ${Formulas.stakesHoldPlay} and the cost of missing is times ${Formulas.stakesHoldFailure}. The move says worth more now, worth less now, or costly if it misses.'),
    tr('自陣の局面で手を外すと、そのまま失点することがある。シュートを打たれれば'
        '${(Formulas.concedeOnShot * 100).round()}%、決定機を与えれば'
        '${(Formulas.concedeOnChance * 100).round()}%、PKなら'
        '${(Formulas.concedeOnPenalty * 100).round()}%で決まる。手の横に「外すと失点○%」と出る。'
        '前に出て奪う手は外すと危ないが、通ればこの後の失点を1つ防ぐ（「通れば1点防ぐ」）。'
        '遅らせる・構える・蹴り返す手は通りやすいが、通っても攻撃は終わらない。'
        '評価は止めたときの${(Formulas.lingerSuccessFactor * 100).round()}%で、'
        '続いた攻撃で${(Formulas.concedeOnLinger * 100).round()}%失点する（「通っても失点」）。', 'Miss a move in your own half and you can concede from it. A shot goes in ${(Formulas.concedeOnShot * 100).round()}% of the time, a clear chance ${(Formulas.concedeOnChance * 100).round()}%, a penalty ${(Formulas.concedeOnPenalty * 100).round()}%. The move says what percentage you concede if it misses. Stepping out to win it is dangerous if you miss, but if it comes off it stops one goal that was coming. Delaying, holding your shape and clearing come off easily, but the attack does not end. They are rated at ${(Formulas.lingerSuccessFactor * 100).round()}% of a stop, and you concede ${(Formulas.concedeOnLinger * 100).round()}% of the time from the attack that follows.'),
    tr('終盤の局面はそのときのスコアで中身が変わり、追いかけているならリスクを取る局面、'
        'リードしているなら時間の使い方を問う局面が来る。', 'Late situations change with the score: chasing brings situations that ask you to take a risk, leading brings ones about using the clock.'),
    tr('1試合の1/4くらいは逆足で対応することになる。逆足の精度が低いとそこで落ちる。', 'About a quarter of a match is dealt with on your weaker foot. If that foot is poor, that is where you drop off.'),
  ]),
  _GuideSection(
    tr('評価点と出場機会', 'Ratings and game time'),
    chapter: tr('試合に出る', 'Play the match'),
    icon: Icons.trending_up,
    lead: tr('選んだ手が評価点になり、評価点が次の出番を決める', 'The moves you choose become your rating, and your rating decides your next game'),
    peek: _ratingPeek,
    [
    tr('局面の成否で評価点が動く。基準は6.0で、良い試合は7点台、悪い試合は5点台。', 'Success and failure in situations move your rating. 6.0 is the baseline; a good match is in the 7s, a poor one in the 5s.'),
    tr('直近5試合の評価点で、次節の起用が決まる。'
        '${Formulas.benchThreshold}を下回ると途中出場、'
        '${Formulas.squadThreshold}を下回るとベンチ外。', 'Your last five ratings decide whether you start the next round. Below ${Formulas.benchThreshold} and you come off the bench; below ${Formulas.squadThreshold} and you are out of the squad.'),
    tr('ゴール・アシスト（守る選手なら無失点）は評価点とは別に数えられ、'
        '出場機会と代表招集に効く。点を取る選手は干されない。', 'Goals and assists (clean sheets for defenders) are counted separately from your rating, and they feed game time and international call-ups. A player who scores does not get frozen out.'),
    tr('ベンチ外が続いても、そのまま終わりにはならない。'
        '${Formulas.benchPatience}試合続けて外れたら必ず一度は声がかかる。', 'Being left out does not end there. Miss ${Formulas.benchPatience} in a row and you are always brought back at least once.'),
    tr('監督の信頼が落ちきると「構想外」になり、評価点で取り戻す道が閉じる。'
        '戻るのは監督交代か移籍か出来事での歩み寄りだけ。'
        '落ちる前（信頼${Formulas.trustWarning}を切ったとき）に必ず画面に出る。', 'If the manager loses faith completely you are frozen out, and the way back through ratings closes. Only a new manager, a transfer or making peace off the pitch gets you back. You are always warned before it happens, when trust falls below ${Formulas.trustWarning}.'),
    tr('荒い手は、失敗すると警告を受けることがある。今季5枚で1試合の出場停止、退場なら2試合。'
        '「止めるための反則」は、選べば必ず警告になる代わりに失点を1つ消す。', 'Rough moves can be booked when they fail. Five bookings in a season is a one-match ban, a sending off two. A tactical foul is always booked, but it stops one goal.'),
    tr('次にどの立場で出られそうかは、「今週」タブの次節のところに出る。', 'What you are likely to be next round is shown next to the fixture on the Week tab.'),
  ]),
  _GuideSection(
    tr('伸ばす', 'Growing'),
    chapter: tr('選手を育てる', 'Developing the player'),
    icon: Icons.fitness_center,
    lead: tr('伸ばす先は自分で選ぶ。練習と、試合で成功した手から', 'You choose where he grows, through training and the moves that come off'),
    [
    tr('能力は「練習」と「試合で成功した手」で伸びる。何を選ぶかがそのまま選手の形になる。', 'Attributes grow through training and through moves that come off in matches. What you choose is what the player becomes.'),
    tr('「育成」タブの「育てる方向」で、伸ばしたい項目を3つまで選べる。'
        '練習ではその項目が優先して伸び、試合の成長もそこに寄る。伸びる量は変わらない。'
        '同じ項目を狙い続けるほど、土台より先に伸ばせる幅が広がる。', 'On the Training tab, under the growth focus, you can pick up to three things to work on. Training favours them, and growth from matches leans that way too. The amount does not change. Keep aiming at the same thing and you can push it further ahead of its foundations.'),
    tr('若いほど伸びる。${Formulas.peakAge}歳を過ぎると鈍り、30歳前後から落ち始める。'
        '伸びしろが残っている選手ほど、20代半ばでも伸び続ける。', 'The younger the faster. It slows after ${Formulas.peakAge} and starts to fall around 30. A player with potential left keeps growing into his mid-twenties.'),
    tr('能力には土台がある。筋力が低いまま最高速だけを上げることはできず、'
        '頭打ちのときは土台のほうが伸びる。', 'Attributes have foundations. You cannot raise top speed alone while strength stays low; when it caps out, the foundation grows instead.'),
    tr('ポテンシャル（上限）は数字では見せない。帯だけを出している。'
        '練習で大成功した週を重ねた選手は、稀に上限を超える'
        '（下地は大成功${Formulas.breakthroughGreatWeeks}回。「育成」タブに残りが出る）。', 'Potential is never shown as a number, only as a band. A player who keeps stacking great training weeks can rarely break past it (the groundwork is ${Formulas.breakthroughGreatWeeks} great weeks, and the Training tab shows how many are left).'),
    tr('経験点を自分で振ることもできる（既定は自動）。伸びるはずだったぶんを貯めて、'
        '同じカテゴリの中で好きな項目に振る。上の値ほど高くつく。', 'You can also spend experience points yourself (automatic by default). What would have grown is banked, and you put it where you like within the same category. Higher values cost more.'),
    tr('伸び続けると停滞期が来る。数試合は積み上がらない。', 'Keep growing and a plateau comes. Nothing builds up for a few matches.'),
  ], extra: _trainingMenus),
  _GuideSection(
    tr('自分の位置を知る', 'Knowing where you stand'),
    chapter: tr('クラブと世界', 'The club and the world'),
    icon: Icons.public,
    lead: tr('いま世界の何番目にいるのかが、常に見える', 'Where you rank in the world is always visible'),
    [
    tr('「育成」タブの「練習の成果」に、開幕からの伸びが出る。'
        '能力が1上がると、その能力で判定する局面が'
        '約${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}%通りやすくなる。'
        '試合中の選択肢にも、今季伸びたぶんが↑で付く。', 'Under Training results on the Training tab you can see your growth since the opening day. One point of an attribute makes situations judged on it about ${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}% more likely to come off. Match choices also show this season growth with an arrow.'),
    tr('「選手」タブの「選手としての水準」で、総合力が世界のどのあたりかが分かる。'
        '代表に呼ばれる線もそこに出る。線は国の格で動き、'
        '格の高い国ほど高い（格3の国で総合力${Formulas.callUpOverall}）。', 'Under Where you rank on the Player tab you can see where your overall sits in the world. The line for a call-up is there too. It moves with the standing of the country, higher for stronger ones (overall ${Formulas.callUpOverall} for a tier-3 nation).'),
    tr('「クラブ」タブの「リーグの格付け」で、所属リーグが世界で何位かを見られる。'
        '上のリーグほど相手が強く、同じ手が通らなくなる。', 'Under League standings on the Club tab you can see where your league ranks in the world. The higher the league, the stronger the opponents and the less the same moves come off.'),
  ]),
  _GuideSection(
    tr('選手を作る', 'Creating a player'),
    chapter: tr('選手を育てる', 'Developing the player'),
    icon: Icons.person_add,
    lead: tr('始める前に決めること。ポテンシャルだけは選べない', 'What you decide before you start. Potential is the one thing you cannot pick'),
    [
    tr('名前・ポジション・年齢・身体・能力の割り振り・出身国・代理人を決めて始める。'
        'ポテンシャルは選べない——始めてから分かるのがキャリアもの。', 'You set the name, position, age, physique, attribute spread, country and agent. Potential you cannot pick; finding out as you go is what a career game is.'),
    tr('特性は作成画面で見えていて、引き直せる。'
        '長所は${Trait.strengthCounts.reduce(min)}〜${Trait.strengthCounts.reduce(max)}つで、'
        '多く引くほど欠点も付きやすい。', 'Traits are visible on the creation screen and you can roll again. You get ${Trait.strengthCounts.reduce(min)} to ${Trait.strengthCounts.reduce(max)} strengths, and the more you draw the likelier a flaw comes with them.'),
    tr('サイドバックとウイングは、左右のどちらに立つかを決める。'
        '利き足と同じ側なら逆足の局面が減り、逆サイドなら内へ切り込んで打てる。', 'Full-backs and wingers choose which side they play. On your stronger side you face fewer weak-foot situations; on the other you can cut inside and shoot.'),
    tr('身長は競り合いに、体重は当たりの強さとキレの入れ替えに効く。'
        '練習では動かないので、ここで決めた体格は一生ついてくる。', 'Height matters in the air, and weight trades contact strength against sharpness. Training does not move them, so the build you pick here is with you for life.'),
    tr('能力はポジションの基準値から±6まで動かせる。増やしたぶんはどこかを削るので、'
        '総合力は変わらない。何を得意にするかだけを決める。', 'Attributes move up to 6 either way from the baseline for the position. What you add you take from somewhere else, so the overall does not change. You are only deciding what he is good at.'),
    tr('出身国で、始めるリーグと代表と、外国人としての扱いが決まる。', 'Your country decides the league you start in, the national team, and how you are treated as a foreign player.'),
  ]),
  _GuideSection(
    tr('個人技', 'Tricks'),
    chapter: tr('選手を育てる', 'Developing the player'),
    icon: Icons.auto_awesome,
    lead: tr('覚えた技は、構えて使うと効く', 'Tricks you have learned pay off when you set them'),
    [
    tr('元になる能力が${Signature.requirement}に届くと、その練習をしている週に'
        '個人技を覚えることがある。最大${Signature.maxOwned}つ。'
        'そのポジションで使う技しか覚えない。', 'When the attribute behind it reaches ${Signature.requirement}, a week training it can teach you the trick. Up to ${Signature.maxOwned}. You only learn tricks that your position uses.'),
    tr('1つ狙える。「育成」タブの「個人技を狙う」に、全部の技の取得条件'
        '（元になる能力・今の値・あといくつ）が並んでいる。狙っている間は、'
        '練習では他の技を覚えない代わりに、条件を満たせば'
        '${(Formulas.signatureAimChance * 100).round()}%の週で掴む'
        '（狙わなければ${(Formulas.signatureChance * 100).round()}%）。', 'You can aim for one. Under Choose a trick on the Training tab, every trick is listed with what it needs: the attribute behind it, where you are, and how far to go. While aiming you learn no other trick in training, but if you meet the requirement you pick it up in ${(Formulas.signatureAimChance * 100).round()}% of weeks (${(Formulas.signatureChance * 100).round()}% if you are not aiming).'),
    tr('覚えた技は、噛み合った手で +${(Formulas.signatureOnDetail * 100).round()}%。', 'A trick you have learned is +${(Formulas.signatureOnDetail * 100).round()}% on a move it fits.'),
    tr('磨く。伸びなくなってきた歳から、その技を扱う練習で技のほうが深くなる'
        '（最大${Signature.maxMastery}段、1段 +${(Formulas.signaturePerMastery * 100).round()}%）。'
        '能力は落ちても、引き出しは増える。', 'Polishing. From the age where growth dries up, training that uses the trick deepens the trick instead (up to ${Signature.maxMastery} steps, +${(Formulas.signaturePerMastery * 100).round()}% each). Attributes fall, but the toolbox grows.'),
    tr('居残り練習でFK・PK・CKを磨ける。${SetPieceSkills.takerThreshold}に届くと'
        'クラブのキッカーを任される。', 'Extra sessions sharpen free kicks, penalties and corners. Reach ${SetPieceSkills.takerThreshold} and the club gives you the ball.'),
  ]),
  _GuideSection(
    tr('生まれ持った特性とコツ', 'Traits you are born with, and knacks'),
    chapter: tr('選手を育てる', 'Developing the player'),
    icon: Icons.psychology,
    lead: tr('生まれつきのものと、やってきたことで身に付くもの', 'What you are born with, and what the years give you'),
    [
    tr('特性はどれも一長一短で、上位互換は無い。伸ばせない——その選手の「向き・不向き」。', 'Every trait cuts both ways; none is strictly better. You cannot train them. They are what the player is suited to.'),
    tr('コツ。キャリアで1つだけ、やってきたことが特性になる。'
        '試合経験${Knacks.experienceNeeded}・練習の大成功${Knacks.greatWeeksNeeded}回・'
        '同じ場面で${Knacks.momentsNeeded}回の勝負が条件で、候補は何度も勝負してきた'
        '場面からしか出ない。待っても引き直せない。', 'Knacks. Once in a career, what you have done becomes a trait. It needs ${Knacks.experienceNeeded} match experience, ${Knacks.greatWeeksNeeded} great training weeks and ${Knacks.momentsNeeded} goes in the same situation, and the candidates only come from situations you have been in again and again. Waiting will not reroll it.'),
  ], extra: _traitList),
  _GuideSection(
    tr('クラブと監督', 'The club and the manager'),
    chapter: tr('クラブと世界', 'The club and the world'),
    icon: Icons.groups,
    lead: tr('監督は数字ではなく「何を選んだか」を見る', 'The manager watches what you choose, not your numbers'),
    [
    tr('監督には戦術がある。求める形に沿った手（試合中に「監督好み」と出る）を選ぶと信頼が上がり、'
        '逆らうと下がる。成績が期待を下回れば監督は飛び、代われば信頼は白紙に戻る。', 'Managers have a system. Choose moves that fit what he wants (marked Manager likes during the match) and trust rises; go against it and it falls. Fall short of expectations and the manager goes, and with a new one trust starts again at zero.'),
    tr('役割。監督の戦術によっては、ポジションの中の役割に就ける'
        '（全${PlayerRole.values.length}種）。役割は総合力の測り方を変える——'
        '重く見てもらう能力を選ぶ代わりに、他は軽く見られる。'
        '新しい監督が使わない役割は、オフに外れる。', 'Roles. Depending on the manager system, you can take a role within your position (${PlayerRole.values.length} in all). A role changes how your overall is measured: you pick which attributes count for more, and the rest count for less. A role the new manager does not use comes off in the off-season.'),
    tr('監督はシーズンの初めに3つの数字（出場・得点関与・平均評価）を期待として置く。'
        '**2つ以上で達成**で、信頼と契約更改の年俸に効く。'
        '普通にやって3〜4割は届かない高さに置いてある。', 'At the start of the season the manager sets three numbers: appearances, goals and assists, and average rating. **Two of the three** counts as met, and it feeds trust and your next contract. They are set high enough that three or four seasons in ten fall short.'),
    tr('約束。第${PromiseOffers.window}節までに1つだけ、監督に数字を約束できる。'
        '大きく出るほど見返りも罰も大きい。取り消せない。', 'Promises. Up to round ${PromiseOffers.window} you can promise the manager one number. The bigger the promise, the bigger the reward and the punishment. You cannot take it back.'),
    tr('同ポジションの競争相手との力の差が、そのまま序列になる。'
        '相方とは試合と練習を重ねるほど呼吸が合い、移籍すると一からになる。', 'The gap between you and your rival for the position is the pecking order. You and your partner read each other better the more you play and train together, and a transfer resets it.'),
    tr('相手には戦い方がある。難しくなる能力が1つ（−${(Formulas.styleMismatch * 100).round()}%、'
        '何度も当たると慣れて薄まる）、代わりに空く能力が1つ'
        '（+${(Formulas.styleOpening * 100).round()}%、こちらは慣れでは動かない）。', 'Opponents have a style. One attribute is harder against them (-${(Formulas.styleMismatch * 100).round()}%, which fades as you meet them again), and one opens up instead (+${(Formulas.styleOpening * 100).round()}%, which familiarity does not change).'),
    tr('今節の的。節ごとに1つ出て、達成すると${MatchTarget.reward}万円。'
        'リーグ戦だけで数える（カップ戦は節を進めないので素通り）。'
        '続けて達成すると連続が伸び、${MatchTarget.streakStep}回ごとに'
        'その的が問うている能力へ経験点が${MatchTarget.streakPoints}点入る。'
        '外しても、出られなくても連続は切れる。', 'A target each round. One per round, and meeting it pays JPY ${(MatchTarget.reward / 100).toStringAsFixed(1)}M. Only league matches count (cup matches do not advance the round, so they are skipped). Meet it repeatedly and the streak grows, and every ${MatchTarget.streakStep} you get ${MatchTarget.streakPoints} experience points in the attribute that target asks about. Missing it, or not playing, ends the streak.'),
    tr('自分が出た試合と出なかった試合の成績は、「記録」タブの今シーズンの成績に並ぶ。'
        '居ないと勝てないクラブなら、そこに差が出る。', 'How the team does with and without you is listed in this season results on the Record tab. If the club cannot win without you, the gap shows there.'),
    tr('自分が出る試合は、そのぶんクラブが強い（クラブとの力の差1につき'
        ' +${Formulas.starLift}、最大 +${Formulas.starLiftCap.round()}。途中出場は半分）。'
        '弱いクラブに居ても、自分が主力なら順位を持ち上げられる。出ない試合には効かない。', 'When you play, the club is that much stronger (+${Formulas.starLift} for each point you are above the club, up to +${Formulas.starLiftCap.round()}; half off the bench). Even at a weak club, a first choice can lift the table position. It does not count for matches you miss.'),
  ], extra: _directives),
  _GuideSection(
    tr('契約と移籍', 'Contracts and transfers'),
    chapter: tr('クラブと世界', 'The club and the world'),
    icon: Icons.swap_horiz,
    lead: tr('話が来るかどうかは、出来と契約で決まる', 'Whether anyone calls depends on your form and your contract'),
    [
    tr('契約が残っている間は、残留しても条件は動かない（1年減るだけ）。'
        '残り1年になって初めて、他クラブからの話が届く。', 'While a contract runs, staying puts does not change the terms; it just loses a year. Only with one year left do offers from other clubs arrive.'),
    tr('移籍の話の年俸は、今季の出来で決まる。今より強いクラブは、その差のぶん上乗せして払う'
        '（強さ1につき +${(Formulas.stepUpPayPerPoint * 100).round()}%、'
        '最大 +${(Formulas.stepUpPayCap * 100).round()}%）。ただし控えとして呼ぶクラブは'
        '${(Formulas.benchOfferFactor * 100).round()}%しか払わない。'
        '話に書いてある「役割」を見ること。身の丈より上へ行くと、登録から外れることがある。', 'The wages in a transfer offer come from this season form. A stronger club pays extra for the gap (+${(Formulas.stepUpPayPerPoint * 100).round()}% per point of strength, up to +${(Formulas.stepUpPayCap * 100).round()}%). A club bringing you in as back-up pays only ${(Formulas.benchOfferFactor * 100).round()}%. Read the role in the offer. Go too far above yourself and you can be left out of the registered squad.'),
    tr('契約には違約金が付く。伸びた選手は自分の違約金を追い越し、契約が残っていても話が動き出す。', 'Contracts carry a release clause. A player who grows passes his own clause, and the phone starts ringing even mid-contract.'),
    tr('出番の無い若手にはローンの話が来る。保有元との契約は凍り、1年で戻る。', 'Young players with no game time get loan offers. The contract at home freezes and you return after a year.'),
    tr('登録外や構想外で使われていないなら、契約が残っていても話が来る（ローンは歳に関係なく）。', 'If you are unregistered or frozen out, offers come even mid-contract (loans at any age).'),
    tr('年俸には出場給が乗る。${Formulas.appearanceBaseline}試合を基準に、'
        '出るほど増え、怪我やベンチで欠けたぶんは減る'
        '（最大 ±${(Formulas.appearanceBonusRate * 100).round()}%）。'
        '座っているだけでは、同じ額はもらえない。', 'Wages carry appearance money. Based on ${Formulas.appearanceBaseline} matches, you earn more the more you play and less when injury or the bench takes it away (up to ${(Formulas.appearanceBonusRate * 100).round()}% either way). Sitting still does not pay the same.'),
    tr('最上位の国のクラブは、名前で選ぶ。代表${Formulas.eliteCaps}キャップか、'
        '知名度${Formulas.eliteFame}に届くまで声がかからない。'
        '知名度は出場と代表と大舞台で上がり、露出が止まると有名なほど早く薄れる。', 'Clubs in the strongest countries buy a name. They do not call until you have ${Formulas.eliteCaps} caps or ${Formulas.eliteFame} fame. Fame rises with appearances, internationals and big occasions, and the more famous you are the faster it fades once the exposure stops.'),
    tr('代理人は交渉力・人脈・手数料が違う。上乗せ交渉は、移籍のオファーだと'
        '失敗して撤回されることがある。契約更改は撤回されない。', 'Agents differ in negotiating, contacts and fee. Asking for more can make a transfer offer be withdrawn. A contract renewal is never withdrawn.'),
  ]),
  _GuideSection(
    tr('代表・カップ', 'Internationals and cups'),
    chapter: tr('クラブと世界', 'The club and the world'),
    icon: Icons.emoji_events,
    lead: tr('リーグの外の舞台。呼ばれる線は国で変わる', 'Stages outside the league. The line for a call-up moves with the country'),
    [
    tr('代表は総合力と直近の出来で呼ばれる。点を取り続けていれば、評価点が届かなくても呼ばれる。'
        '複数の国籍を持っていれば、どの代表でやるかを選べる。', 'Call-ups come from your overall and your recent form. Keep scoring and you are called even if your rating falls short. With more than one nationality, you choose which country to play for.'),
    tr('世界大会は4年に1度。代表に呼ばれている選手だけが出られる。', 'The world tournament is every four years. Only players in the squad take part.'),
    tr('国内カップは一発勝負なので、格下でも勝ち上がることがある。'
        '優勝すれば翌季の大陸カップ出場権が付く。カップ戦の週は練習できない。', 'The domestic cup is one-legged, so a smaller club can go through. Win it and you qualify for the continental cup next season. There is no training in a cup week.'),
  ]),
  _GuideSection(
    tr('怪我・コンディション・気持ち', 'Injuries, condition and morale'),
    chapter: tr('選手の人生', 'A player life'),
    icon: Icons.healing,
    lead: tr('押すか休むか。重傷だけは戻らない', 'Push or rest. Only a bad injury never comes back'),
    [
    tr('コンディションは1週間で戻るが、累積疲労は戻らない。オフでだいたい抜ける。', 'Condition returns within a week; built-up fatigue does not. It mostly clears in the off-season.'),
    tr('怪我をしたら復帰の進め方を選べる。強行すれば早く戻れる代わりに、'
        '復帰直後の再発が跳ね上がる。重傷は能力とポテンシャルを恒久的に削る。', 'When you are injured you choose how to come back. Rush it and you return sooner, but the risk of breaking down again jumps. A serious injury takes attributes and potential away for good.'),
    tr('気持ちは出番と私生活で動く。ピッチ外の出来事で上下するが、'
        '1回で人生が決まるほどの効きは無い。', 'Morale moves with game time and life off the pitch. Events move it up and down, but no single one decides a career.'),
    tr('実力とは別に、数試合だけ続く波（ゾーン／スランプ）がある。', 'Separate from ability, there are hot and cold spells that last a few matches.'),
  ]),
  _GuideSection(
    tr('お金', 'Money'),
    chapter: tr('選手の人生', 'A player life'),
    icon: Icons.savings,
    lead: tr('稼ぎの使い道。身体に投資するか、貯めるか', 'What you do with what you earn. Invest in the body, or save'),
    [
    tr('年俸からは税・代理人手数料・生活費が引かれ、残りが貯蓄になる。', 'Tax, agent fees and living costs come out of your wages, and the rest is savings.'),
    tr('今季いくら残るかは「育成」タブの「自分への投資」に出ている。'
        '雇う前に、シーズン末の貯蓄がいくらになるかまで書いてある。', 'What is left this season is shown under Investing in yourself on the Training tab. Before you hire anyone it tells you what your savings will be at the end of the season.'),
    tr('貯蓄が尽きると、専属スタッフとの契約は全部切れる。'
        '足りなくなりそうなら、雇う人数を減らすか、暮らし方を下げること。', 'If your savings run out, every one of your personal staff goes. If it is going to be tight, hire fewer people or live more cheaply.'),
    tr('暮らし方は生活費を決める。下げれば手取りが増え、'
        '上げれば気持ちが少し上向く。効きは小さい。', 'How you live sets your living costs. Live cheaply and you keep more; live well and morale lifts a little. The effect is small.'),
    tr('知名度が上がるとスパイクのスポンサーが付く。年俸とは別の収入になる。', 'As your name spreads, a boot sponsor comes along. That is income on top of wages.'),
  ], extra: _staffKinds),
  _GuideSection(
    tr('ピッチの外', 'Off the pitch'),
    chapter: tr('選手の人生', 'A player life'),
    icon: Icons.coffee,
    lead: tr('物語であって罠ではない。1回で人生は決まらない', 'Stories, not traps. One choice never decides a life'),
    [
    tr('数試合に一度、ピッチの外で何かが起きる。選択肢が出て、選んだことが'
        '気持ち・監督との関係・ロッカールームの空気・お金に残る。', 'Every few matches something happens off the pitch. You choose, and what you chose stays in your morale, your standing with the manager, the dressing room and your money.'),
    tr('監督・競争相手・相方・メンター・同期・代理人は、名前を持った他人として'
        '出来事に出てくる。誰が居るかで、起きることが変わる。', 'The manager, your rival, your partner, your mentor, your intake and your agent appear as people with names. Who is around changes what happens.'),
    tr('競争相手・相方・得点王を争った相手は、関わった人として覚えておく。'
        '別れたあとも続きがあり、伸びて上のクラブへ移ったり、早くに消えたり、'
        'いつか自分のクラブに来て、また先発を争ったりする。'
        '今どこに居るかは記録タブで見られる。', 'Your rivals, partners and scoring rivals are remembered as people you crossed paths with. Their story carries on after you part: they grow and move up, fade early, or one day join your club and fight you for a place again. The Record tab shows where they are now.'),
    tr('練習の中の出来事では、能力が伸びたり、個人技を閃いたりする。'
        'ただしポテンシャルを超えては伸びない。上限は上限のまま。', 'Events during training can raise an attribute or spark a trick. They never take you past your potential. The ceiling stays the ceiling.'),
    tr('どの選択肢も、1回でキャリアが決まる大きさにはしていない。'
        '10年ぶんの積み重ねが、同じ成績の選手を別の人生にする。', 'No single choice is big enough to decide a career. Ten years of them turn players with the same numbers into different lives.'),
  ]),
  _GuideSection(
    tr('引退とその後', 'Retirement and after'),
    chapter: tr('選手の人生', 'A player life'),
    icon: Icons.military_tech,
    lead: tr('やってきたことが、次の道の適性になる', 'What you did becomes what you are suited to next'),
    [
    tr('33歳から引退を選べる。37歳のシーズンを終えると引退になる。', 'You can retire from 33. After the season you turn 37, you retire.'),
    tr('引退後は通算成績と称号が残り、次に進む道を選ぶ。'
        '現役でやってきたことが、そのまま次の職業の適性になる。', 'After retiring your career record and titles remain, and you choose what to do next. What you did as a player is what you are suited to.'),
  ]),
  _GuideSection(
    tr('保存と持ち運び', 'Saving and moving'),
    chapter: tr('選手の人生', 'A player life'),
    icon: Icons.save,
    lead: tr('記録は端末の中だけ。引き継ぎコードで運ぶ', 'The record lives on the device. Carry it with a transfer code'),
    [
    tr('セーブは端末ごとに独立している。'
        'PCで進めた内容とスマホの内容は別物になる。', 'Saves are separate on each device. What you played on a PC and what you played on a phone are different things.'),
    tr('右上のメニューから「引き継ぎコード」を出して別の端末に貼り付けると、'
        '続きから遊べる。読めないコードでは、今のキャリアは消えない。', 'From the menu at the top right, show the transfer code and paste it on another device to carry on. A code that cannot be read never deletes the career you have.'),
  ]),
];

Widget _trainingMenus(BuildContext context) => _list(context, [
  for (final menu in TrainingMenu.values)
    (
      menu.label,
      menu.isRest
          ? tr('${menu.description}（コンディション +${menu.recovery}）', '${menu.description} (condition +${menu.recovery})')
          : tr('${menu.description}（消耗 ${menu.conditionCost}）', '${menu.description} (cost ${menu.conditionCost})'),
    ),
]);

Widget _traitList(BuildContext context) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr('長所（${Trait.strengths.length}種）', 'Strengths (${Trait.strengths.length})'), style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.strengths)
          (trait.label, tr('${trait.description}（${trait.effects.join('、')}）',
              '${trait.description} (${trait.effects.join(', ')})')),
      ]),
      const SizedBox(height: 8),
      Text(
        tr('欠点（${Trait.flaws.length}種）', 'Flaws (${Trait.flaws.length})'),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.flaws)
          (trait.label, tr('${trait.description}（${trait.effects.join('、')}）',
              '${trait.description} (${trait.effects.join(', ')})')),
      ]),
      const SizedBox(height: 8),
      Text(tr('稀（${Trait.rares.length}種）', 'Rare (${Trait.rares.length})'), style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      Text(
        tr('長所は${(Trait.rareChance * 100).round()}%、'
        '欠点は${(Trait.rareFlawChance * 100).round()}%の確率で、'
        '普通の特性の1つと置き換わる。', 'A strength is replaced by a rare one ${(Trait.rareChance * 100).round()}% of the time, a flaw ${(Trait.rareFlawChance * 100).round()}%.'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      _list(context, [
        for (final trait in Trait.rares)
          (
            trait.flaw ? tr('${trait.label}（欠点）', '${trait.label} (flaw)') : trait.label,
            tr('${trait.description}（${trait.effects.join('、')}）',
                '${trait.description} (${trait.effects.join(', ')})'),
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
    (StaffTeam.levelLabels[level], tr('年間 ${StaffTeam.costPerLevel[level]}万円', 'JPY ${(StaffTeam.costPerLevel[level] / 100).toStringAsFixed(1)}M a year')),
]);

/// ガイドの本文をすべて1つの文字列で。
///
/// **テストが「載っているか」を見るためのもの**（`test/guide_test.dart`）。
/// 仕組みを足すたびにガイドを書き忘れ、9/10 からの2週間で
/// 載っていない仕組みが10を超えていた。
@visibleForTesting
String guideText() =>
    _sections.expand((s) => [s.title, s.lead, ...s.body]).join('\n');
