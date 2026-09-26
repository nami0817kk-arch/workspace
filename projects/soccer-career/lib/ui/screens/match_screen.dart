import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/match_engine.dart';
import '../../game/match_target.dart';
import '../../game/newsroom.dart';
import '../../game/scenarios.dart';
import '../../models/attributes.dart';
import '../../models/development.dart';
import '../../models/injury.dart';
import '../../models/news.dart';
import '../../models/season.dart';
import '../../models/training.dart';
import '../../state/career_controller.dart';
import '../fixture_banner.dart';
import '../pitch_view.dart';
import '../stat_tile.dart';
import '../readable_width.dart';

/// 1試合を進める画面。局面 → 結果 → 次の局面、を繰り返す。
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  ScenarioResolution? _last;
  MatchResult? _result;
  bool _busy = false;

  Future<void> _choose(int index) async {
    if (_busy) return;
    setState(() {
      _last = widget.controller.choose(index);
    });
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.controller.finishMatch();
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  Future<void> _simulateRest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.controller.simulateMatch();
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 試合の途中で「戻る」（Android の戻るボタン・ブラウザの戻る）を
    // 押しても抜けられない。抜けると次に「試合へ」を押した瞬間に
    // 同じ節が引き直され、選んだ手が消える。結果が出てからは戻れる。
    return PopScope(canPop: _result != null, child: _body(context));
  }

  /// 連続の添え書き。切れているあいだは出さない。
  ///
  /// 「あと何試合で経験点か」まで書く。**節目が見えないと、続けている
  /// ことに値打ちが無い**——お金は毎回同じ額しか入らない。
  String _streakNote(int streak) {
    if (streak < 1) return '';
    final toStep = MatchTarget.streakStep - (streak % MatchTarget.streakStep);
    if (toStep == MatchTarget.streakStep) return ' ・ $streak連続';
    return ' ・ $streak連続、あと$toStepで経験点';
  }

  Widget _body(BuildContext context) {
    final match = widget.controller.currentMatch;
    final result = _result;

    if (result != null) {
      return _MatchSummary(
        result: result,
        week: widget.controller.lastWeek,
        // 今節の的を達成したか。試合が終わった場所で言う。
        targetMet: widget.controller.lastTargetMet,
        streak: widget.controller.state?.targetStreak ?? 0,
        targetPoints: widget.controller.lastTargetPoints,
        // その試合について書かれた見出しがあれば、結果と一緒に見せる。
        headline: widget.controller.news
            .where((n) => n.matchday == result.matchday)
            .take(1)
            .toList(),
      );
    }
    if (match == null) return const SizedBox.shrink();

    if (match.appearance == Appearance.benched) {
      return _BenchedView(
        onDone: _finish,
        busy: _busy,
        // 何試合続けて外れているか。戻り道を数字で見せる。
        idle: MatchEngine.idleRun(widget.controller.state!.leagueResults),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('第${match.matchday}節  vs ${match.opponent.name}'),
        automaticallyImplyLeading: false,
      ),
      // **今節の的。** 次節カードには余白が無い（1行増やすと
      // 「今の状態」が画面の外に出る）ので、試合に入ったここで出す。
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '今節の的: ${MatchTarget.of(widget.controller.state!).label}'
            '（達成で${MatchTarget.reward}万円）'
            '${_streakNote(widget.controller.state!.targetStreak)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MatchHeader(match: match),
                const SizedBox(height: 12),
                Expanded(
                  child: match.isFinished
                      ? _ReadyToFinish(
                          last: _last,
                          match: match,
                          onFinish: _finish,
                          busy: _busy,
                        )
                      : _ScenarioView(
                          match: match,
                          last: _last,
                          seasonStart: widget.controller.state!.seasonStart,
                          focus: widget.controller.state!.focus,
                          objectiveReach:
                              widget.controller.state!.objectiveReach,
                          scorerChase: ScorerRace.chaseFor(
                            widget.controller.state!,
                          ),
                          promiseReach: widget.controller.state!.promiseReach,
                          onChoose: _choose,
                          onArm: widget.controller.armSignature,
                        ),
                ),
                if (!match.isFinished)
                  TextButton(
                    onPressed: _busy ? null : _simulateRest,
                    child: Text(
                      '残りを自動で進める（${widget.controller.state!.simStyle.label}）',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final MatchInProgress match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 今どうなっているか。1点負けている終盤の1本と、
    // 3点リードでの1本は、同じ手でも意味が違う。
    final minute = match.isFinished ? 90 : match.currentMinute;
    final score = match.home
        ? match.scoreLine
        : '${match.concededBy(minute)} - ${match.scoredBy(minute)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FixtureBanner(
          club: match.club,
          opponent: match.opponent,
          home: match.home,
          centre: Text(
            score,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14140F),
              height: 1,
            ),
          ),
          caption: match.home
              ? 'ホーム・${match.appearance.label}'
              : 'アウェイ・${match.appearance.label}',
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatTile(
              small: true,
              label: '局面',
              value: '${match.currentIndex}/${match.scenarios.length}',
            ),
            StatTile(
              small: true,
              label: '評価点',
              value: match.rating.toStringAsFixed(1),
              accent: ratingColor(theme, match.rating),
            ),
            StatTile(
              small: true,
              label: 'G / A',
              value: '${match.goals} / ${match.assists}',
            ),
            StatTile(
              small: true,
              label: '調子',
              value: '${match.player.condition}',
            ),
          ],
        ),
      ],
    );
  }
}

class _ScenarioView extends StatelessWidget {
  const _ScenarioView({
    required this.match,
    required this.last,
    required this.seasonStart,
    required this.focus,
    required this.objectiveReach,
    required this.scorerChase,
    required this.promiseReach,
    required this.onChoose,
    required this.onArm,
  });

  final MatchInProgress match;
  final ScenarioResolution? last;

  /// 今季の開幕時の能力値。局面のたびに、練習ぶんの伸びを添える。
  final Attributes? seasonStart;

  /// 育てる方向。その手が方向に乗っているかを、選ぶその場で見せる。
  final List<Detail> focus;

  /// 監督の期待に、あと一歩で届くなら、その一言。
  ///
  /// 「得点関与 あと1」はクラブタブにあるだけで、局面を選ぶ画面には無かった。
  /// 同じ局面が、シーズンのどこにいるかで意味を変える。
  final String? objectiveReach;

  /// 得点王に手が届くなら、その一言。
  ///
  /// 得点ランキングは他人の数字を眺めるだけの表で、試合の中には無かった。
  /// 終盤の1本が「得点王への1本」になる。
  final String? scorerChase;

  /// 自分から口にした約束に、あと1で届くなら、その一言。
  ///
  /// 監督に言われた数字より、自分で言った数字のほうが重い。
  final String? promiseReach;

  final void Function(int) onChoose;

  /// 切り札を構える／外す。
  final void Function(Signature?) onArm;

  /// その手に使う能力が、今季どれだけ伸びたか。記録が無ければ 0。
  int _growthOf(ScenarioOption option) {
    final before = seasonStart;
    if (before == null) return 0;
    final was = option.detail != null
        ? before.detail(option.detail!)
        : before[option.key];
    return match.attributeFor(option) - was;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scenario = match.current;
    // 今日の自分と相手。どの手を選んでも同じだけ効く。
    final shared = match.sharedFactors.where((f) => f.notable).toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last != null) _ResolutionCard(resolution: last!, match: match),
          if (last != null) const SizedBox(height: 20),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 局面の絵。文章の中にしか無かった「どこで」を、読まずに分かる形にする。
                PitchView(
                  spot: scenario.spot,
                  club: match.club,
                  opponent: match.opponent,
                  style: match.opponentStyle,
                  aspectRatio: 2.7,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${MatchInProgress.minuteLabel(match.currentMinute)}'
                        ' ・ ${match.scoreLine}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scenario.situation,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // 絵の中の白い丸がどこなのかを、言葉でも1つだけ添える。
                          _Tag(scenario.spot.label),
                          _Tag(match.opponentStyle.label),
                          // ノリ。成功を重ねるほど決まるようになる。
                          // 出さないと「なぜ決まったのか」が分からない。
                          if (match.momentum > 0)
                            _Tag(
                              'ノリ ${'●' * match.momentum}'
                              '${'○' * (Formulas.momentumMax - match.momentum)}'
                              ' 決まる確率 ×'
                              '${match.momentumFactor.toStringAsFixed(2)}',
                              background: theme.colorScheme.tertiaryContainer,
                              foreground: theme.colorScheme.onTertiaryContainer,
                            ),
                          if (match.situationLabel != null)
                            _Tag(
                              match.situationLabel!,
                              background: match.margin < 0
                                  ? theme.colorScheme.errorContainer
                                  : theme.colorScheme.secondaryContainer,
                              foreground: match.margin < 0
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onSecondaryContainer,
                            ),
                          // 監督の期待にあと一歩なら、局面の側に出す。
                          // 終盤の1本が「シーズンの1本」になる。
                          if (objectiveReach != null)
                            _Tag(
                              objectiveReach!,
                              background: theme.colorScheme.primaryContainer,
                              foreground: theme.colorScheme.onPrimaryContainer,
                            ),
                          if (scorerChase != null)
                            _Tag(
                              scorerChase!,
                              background: theme.colorScheme.primaryContainer,
                              foreground: theme.colorScheme.onPrimaryContainer,
                            ),
                          if (promiseReach != null)
                            _Tag(
                              promiseReach!,
                              background: theme.colorScheme.tertiaryContainer,
                              foreground: theme.colorScheme.onTertiaryContainer,
                            ),
                          if (match.bigMatch)
                            _Tag(
                              '大一番',
                              background: theme.colorScheme.tertiaryContainer,
                              foreground: theme.colorScheme.onTertiaryContainer,
                            ),
                          if (match.weakFootMoment)
                            _Tag(
                              '逆足で対応',
                              background: theme.colorScheme.errorContainer,
                              foreground: theme.colorScheme.onErrorContainer,
                            ),
                        ],
                      ),
                      // どの手にも同じだけ効いているもの。手ごとには出さない。
                      if (shared.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            for (final f in shared)
                              Text(
                                '${f.label} ${f.percent > 0 ? '+' : ''}${f.percent}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: f.value > 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 切り札。積み上げた個人技を、ここで出すと決める手。
          if (match.armable.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TrumpCard(match: match, onArm: onArm),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < scenario.options.length; i++) ...[
            _OptionButton(
              option: scenario.options[i],
              attribute: match.attributeFor(scenario.options[i]),
              growth: _growthOf(scenario.options[i]),
              focused:
                  scenario.options[i].detail != null &&
                  focus.contains(scenario.options[i].detail),
              favoured: match.isFavoured(scenario.options[i]),
              role: scenario.roleOf(scenario.options[i]),
              setupReady: match.setupReady,
              chance: match.chanceFor(scenario.options[i]),
              assistConversion: match.assistConversionAt(match.currentMinute),
              factors: match.distinctFactorsFor(scenario.options[i]),
              onPressed: () => onChoose(i),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// 切り札。1試合に1回だけ、覚えた個人技を「ここで出す」と決める。
///
/// 個人技はこれまで、身に付くと**常に少しだけ効く**だけだった
/// （実測: 1人あたり2.83個・局面の70%に乗って平均 +3.1%）。
/// 誰でも3つ揃い、選ぶ余地も使いどころの判断も無い。
class _TrumpCard extends StatelessWidget {
  const _TrumpCard({required this.match, required this.onArm});

  final MatchInProgress match;
  final void Function(Signature?) onArm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final armed = match.armed;
    // 窪んだ受け皿。周りのカードが紙として浮いたので、ここだけ平らな箱だと
    // 貼り付けた色紙に見える。切り札は「盤にはめ込んである」ほうが、
    // 構えるものらしい。
    final tray = armed != null
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      // **窪んだ受け皿にする。** 周りのカードが紙として浮いたので、
      // ここだけ平らな箱だと貼り付けた色紙に見える。切り札は
      // 「盤にはめ込んである」ほうが、構えるものらしい。
      // **`BoxDecoration` は `color` と `gradient` を併記すると色が捨てられる。**
      // 下地の色をグラデーションの中に混ぜて作る。
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(const Color(0x1F000000), tray),
            tray,
            Color.alphaBlend(
              theme.colorScheme.surface.withValues(alpha: 0.30),
              tray,
            ),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **見出しと但し書きを1行に畳む。** 2行の説明を下に置いていた頃、
          // このカードは 140px あって、出た局面では3つの手が全部
          // 画面の外に出ていた（`scroll_sim` の「match screen fold」）。
          // 毎回同じ文を2行読ませるより、決める材料を見せるほうが先。
          Text(
            armed == null
                ? '切り札（この試合に1回）'
                      '　乗る手に +${(Formulas.signatureArmedBonus * 100).round()}%'
                      ' / 外すと残り -${(Formulas.signatureMissPenalty * 100).round()}%'
                : '${armed.label}を構えた。${armed.detail.label}の手に乗る。',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final signature in match.armable)
                ChoiceChip(
                  label: Text(signature.label),
                  selected: armed == signature,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (on) => onArm(on ? signature : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 局面に添える札。**`Chip` は押せる部品なので、押せない札に使うと
/// タップ領域のぶんだけ縦に太る**（1行 32px）。読むだけの札は、
/// 文字の周りの余白だけでいい（1行 22px）。
/// 局面の札は最大3行並ぶので、ここが 10px 違うと 30px 効く。
class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.attribute,
    required this.growth,
    required this.focused,
    required this.favoured,
    required this.role,
    required this.setupReady,
    required this.chance,
    required this.assistConversion,
    required this.factors,
    required this.onPressed,
  });

  final ScenarioOption option;
  final int attribute;

  /// 今季の開幕からの伸び。練習がこの局面に効いていることを、
  /// 選ぶその場で見せるためのもの。0 なら何も出さない。
  final int growth;

  /// 育てる方向に入っている手か。選ぶほど、その方向に伸びる。
  final bool focused;

  /// 監督の求める形に沿った手か。沿えば信頼が上がり、逆らえば下がる。
  ///
  /// 監督はこれまで能力値だけを見ていて、**何を選んだかは見ていなかった**。
  /// 印を出さないと、信頼が動いた理由が分からない。
  final bool favoured;

  /// **この局面での役どころ。布石か、仕留めか。**
  ///
  /// 布石はその場の見返りが小さいので、印を出さないと
  /// 「ただの無難な手」にしか見えない。何のために打つのかを画面に出す。
  final ComboRole role;

  /// すでに布石が通っているか。仕留めの印を出し分けるために使う。
  final bool setupReady;

  /// 特性とコンディションを含んだ成功率。判定と同じ値。
  final double chance;

  /// アシストの手が通ったとき、実際にアシストになる見込み。
  /// 終盤ほど低く、弱いクラブほど低い。
  final double assistConversion;

  /// その数字を作っているもの。積み上げたものが試合のどこで効いているかを、
  /// 選ぶその場で見せる。
  final List<ChanceFactor> factors;

  final VoidCallback onPressed;

  /// 画面に出す数。並べすぎると、どれが効いているのか分からなくなる。
  static const int shownFactors = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (chance * 100).round();
    // 効いているものだけを、大きい順に少しだけ。
    final shown = factors.where((f) => f.notable).take(shownFactors).toList();
    // 数字だけだと、3つの手を見比べるのに毎回読む必要がある。
    // 帯があれば、どれが堅くてどれが賭けかが一目で分かる。
    final color = chance >= 0.6
        ? theme.colorScheme.primary
        : chance >= 0.4
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(option.label, style: theme.textTheme.titleSmall),
              ),
              if (option.outcome != Outcome.play)
                // 手が通る確率と、それが点になる確率は別。
                // 「決まるのは半分ほど」を数字で見せておく。
                _Tag(
                  option.outcome == Outcome.goal
                      ? 'ゴール ${(chance * Formulas.goalConversion * 100).round()}%'
                      : 'アシスト ${(chance * assistConversion * 100).round()}%',
                  background: theme.colorScheme.secondaryContainer,
                  foreground: theme.colorScheme.onSecondaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  '$percent%',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ),
              Expanded(
                child: GaugeBar(value: chance, height: 6, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                '${option.detail?.label ?? option.key.label} $attribute',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (growth > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '↑$growth',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (focused)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '重点',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              if (favoured)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '監督好み',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              // **布石は印が無いとただの無難な手に見える。**
              if (role == ComboRole.setup && !setupReady)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '布石',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              if (role == ComboRole.finish)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    setupReady ? '仕留め・布石あり' : '仕留め',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: setupReady
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                for (final f in shown)
                  Text(
                    '${f.label} ${f.percent > 0 ? '+' : ''}${f.percent}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: f.value > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 選んだ手の結果。文字だけだったところに、ボールの行方を描く。
///
/// 今の局面の絵に前の結果を重ねると、2つの場所が混ざる。
/// 結果は結果で、**その局面の場所**に小さなピッチを添えて出す。
class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.resolution, required this.match});

  final ScenarioResolution resolution;
  final MatchInProgress match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = resolution.success
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = resolution.success
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    // この結果が出た局面。選んだ瞬間に次へ進んでいるので、1つ前を見る。
    final index = match.currentIndex - 1;
    final spot = index >= 0 && index < match.scenarios.length
        ? match.scenarios[index].spot
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        color: color,
        child: Row(
          // 高さは中身に任せる。stretch にすると、スクロールの中（高さ無限）で落ちる。
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (spot != null)
              SizedBox(
                width: 128,
                height: 128 / 1.45,
                child: PitchView(
                  spot: spot,
                  club: match.club,
                  opponent: match.opponent,
                  style: match.opponentStyle,
                  aspectRatio: 1.45,
                  outcome: PitchOutcome(
                    success: resolution.success,
                    goal: resolution.isGoal,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolution.isGoal
                          ? 'ゴール'
                          : resolution.isAssist
                          ? 'アシスト'
                          : resolution.success
                          ? '成功'
                          : '失敗',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolution.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyToFinish extends StatelessWidget {
  const _ReadyToFinish({
    required this.last,
    required this.match,
    required this.onFinish,
    required this.busy,
  });

  final ScenarioResolution? last;
  final MatchInProgress match;
  final VoidCallback onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null) _ResolutionCard(resolution: last!, match: match),
        const Spacer(),
        FilledButton(
          onPressed: busy ? null : onFinish,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('試合終了'),
          ),
        ),
      ],
    );
  }
}

class _BenchedView extends StatelessWidget {
  const _BenchedView({required this.onDone, required this.busy, this.idle = 0});

  final VoidCallback onDone;
  final bool busy;

  /// 何試合続けて外れているか。
  final int idle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 次に外れると何試合連続になるか。そこで必ず一度は声がかかる。
    final remaining = Formulas.benchPatience - (idle + 1);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ベンチ外', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '直近の評価点が低く、今節は招集されなかった。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remaining <= 0
                    ? '外れ続けている。次節は途中出場から声がかかる。'
                    : 'あと$remaining試合外れると、まずは途中出場から戻ることになる。'
                          '練習で調子を戻しておく。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: busy ? null : onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('結果を見る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchSummary extends StatelessWidget {
  const _MatchSummary({
    required this.result,
    required this.week,
    this.headline = const [],
    this.targetMet = false,
    this.streak = 0,
    this.targetPoints = 0,
  });

  /// 今節の的を達成したか。
  final bool targetMet;

  /// 今季ここまでの連続達成数（この試合を含む）。
  final int streak;

  /// 節目で入った経験点。入らなければ 0。
  final int targetPoints;

  final MatchResult result;

  /// その1週間で起きたこと（練習の成果・負傷・復帰）。
  final WeekReport week;

  /// その試合について世に出た見出し。
  final List<NewsItem> headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = result.won ? '勝利' : (result.drawn ? '引き分け' : '敗戦');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${result.scoreLine}   vs ${result.opponentName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // **達成したときだけ出す。** 外した回に「外した」と
              // 言われ続けると、38試合が責められ続ける場所になる。
              if (targetMet) ...[
                const SizedBox(height: 10),
                Text(
                  '今節の的を達成　+${MatchTarget.reward}万円'
                  '${streak > 1 ? '　$streak連続' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                // **節目のぶんは別の行にする。** お金と一緒に並べると、
                // 値段の上がらない側（経験点）が誤差に見える。
                if (targetPoints > 0)
                  Text(
                    '$streak連続　経験点 +$targetPoints',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(theme, '評価点', result.rating?.toStringAsFixed(1) ?? '—'),
                  _stat(theme, 'ゴール', '${result.goals}'),
                  _stat(theme, 'アシスト', '${result.assists}'),
                ],
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        headline.first.headline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (headline.first.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          headline.first.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (week.timeline.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Timeline(events: week.timeline),
              ],
              if (week.deadBall != null) ...[
                const SizedBox(height: 20),
                Text(
                  week.deadBall!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (week.autoRested) ...[
                const SizedBox(height: 8),
                Text(
                  '疲れが残っていたので、今週は自動で休養にした。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              // その週の手応え。伸びなかった週が、運が悪かったのか
              // 踏み込みが足りなかったのかを分かるようにする。
              if (week.outcome != null) ...[
                const SizedBox(height: 20),
                Text(
                  week.companion == TrainingCompanion.alone
                      ? '練習: ${week.outcome!.label}'
                      : '練習: ${week.outcome!.label}（${week.companion.label}）',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: switch (week.outcome!) {
                      TrainingOutcome.great => theme.colorScheme.primary,
                      TrainingOutcome.good => theme.colorScheme.onSurface,
                      TrainingOutcome.flat => theme.colorScheme.error,
                    },
                  ),
                ),
                Text(
                  week.outcome!.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (week.trained != null) ...[
                const SizedBox(height: 12),
                Text(
                  week.redirected
                      ? '土台から鍛え直した: ${week.trained!.label} が 1 伸びた'
                      : '練習の成果: ${week.trained!.label} が 1 伸びた',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (week.drilled != null) ...[
                const SizedBox(height: 12),
                Text(
                  '居残りの成果: ${week.drilled!.label} の精度が上がった',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (week.learned != null) ...[
                const SizedBox(height: 12),
                Text(
                  '個人技を覚えた: ${week.learned!.label}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              // **磨いた週は、必ず画面に出す。** 伸びなくなった歳に
              // 何が起きているのかが見えないと、練習を選ぶ意味が消える。
              if (week.polished != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${week.polished!.label} に磨きがかかった',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (week.weakFootAwakened) ...[
                const SizedBox(height: 12),
                Text(
                  '逆足が形になってきた。両足で持てる選手になりつつある。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (week.plateau) ...[
                const SizedBox(height: 12),
                Text(
                  '伸び悩んでいる。しばらくは積み上がらない。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (week.recovered) ...[
                const SizedBox(height: 20),
                Text(
                  '離脱から復帰した。コンディションはまだ戻っていない。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (week.newInjury != null) ...[
                const SizedBox(height: 20),
                _InjuryNotice(injury: week.newInjury!),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
    children: [
      Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(value, style: theme.textTheme.headlineSmall),
    ],
  );
}

/// 負傷を伝えるカード。重傷は後遺症まで書く。
class _InjuryNotice extends StatelessWidget {
  const _InjuryNotice({required this.injury});

  final Injury injury;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severe = injury.severity == InjurySeverity.severe;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '負傷: ${injury.name}（${injury.severity.label}）',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${injury.matchesOut}試合の離脱',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          if (severe) ...[
            const SizedBox(height: 4),
            Text(
              '長期離脱。体は元どおりにはならない。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 試合で起きたことを時間順に並べる。
///
/// 数字だけの結果は、38試合ぶん並べても記憶に残らない。
/// 「78分に決めて追いついた」が残ると、シーズンが物語になる。
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<MatchEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '試合の流れ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final event in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    '${event.minute}分',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  switch (event.kind) {
                    MatchEventKind.conceded => Icons.remove_circle_outline,
                    MatchEventKind.ownGoal => Icons.sports_soccer,
                    MatchEventKind.ownAssist => Icons.trending_up,
                    // 退場は試合を動かした展開。得点と同じ列に並べる。
                    MatchEventKind.sentOffThem ||
                    MatchEventKind.sentOffUs => Icons.style_outlined,
                    MatchEventKind.teammateGoal => Icons.check_circle_outline,
                  },
                  size: 16,
                  color: event.kind.isOurs
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  event.kind.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        event.kind == MatchEventKind.ownGoal ||
                            event.kind == MatchEventKind.ownAssist
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
