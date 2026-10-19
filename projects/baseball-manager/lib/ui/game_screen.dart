import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/calendar.dart';
import '../game/career.dart';
import '../game/epilogue.dart';
import '../game/exp.dart';
import '../game/flavor.dart';
import '../game/characters.dart' show tipsNeeded;
import '../game/life_log.dart';
import '../game/rival_story.dart';
import '../game/school.dart';
import '../game/marks.dart';
import '../game/goals.dart';
import '../game/game.dart';
import '../game/invest.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';
import 'art/avatar.dart';
import 'art/radar.dart';
import 'art/scene.dart';
import 'admin_screen.dart';
import 'controller.dart';
import 'home_screen.dart' show showAdminToggled;
import 'labels.dart';
import '../game/records.dart';
import '../game/season.dart';
import '../game/snapshot.dart';
import 'player_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// 画面の中身の最大幅。広い画面(Web・タブレット)では中央に寄せる。
const contentMaxWidth = 560.0;

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// 下のタブ: 0 育成 / 1 能力 / 2 キャリア / 3 関係。
  int _tab = 0;
  Phase? _lastPhase;

  /// タブの印(赤い点): いま手をつけられることがあるとき。
  bool get _trainMark =>
      game.canChooseSchool || game.canChoosePosition || game.canChooseOffseason;
  bool get _abilityMark => abilitiesOf(game.player.role)
      .any((a) => buy(game.player, game.exp, a) != null);
  int get _abilityCount => abilitiesOf(game.player.role)
      .where((a) => buy(game.player, game.exp, a) != null)
      .length;
  bool get _careerMark => game.canUseFa || game.canMoveOverseas;

  Widget _tabIcon(IconData icon, bool mark, String name, {int? count}) =>
      Semantics(
        label: mark ? '手をつけられることがあります' : null,
        child: Badge(
          key: mark ? Key('mark-$name') : null,
          smallSize: 9,
          label: count == null ? null : Text('$count'),
          isLabelVisible: mark,
          child: Icon(icon),
        ),
      );

  GameController get controller => widget.controller;
  Game get game => widget.game;

  @override
  Widget build(BuildContext context) {
    if (game.phase == Phase.retired) {
      return EndingView(controller: controller, game: game);
    }
    // 出来事・進路の選択が出たら、育成タブに戻して見せる。
    if (game.phase != _lastPhase) {
      if (game.phase != Phase.term) _tab = 0;
      _lastPhase = game.phase;
    }
    final p = game.player;
    return CallbackShortcuts(
      bindings: {
        if (game.phase == Phase.term) ...{
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              controller.act(recommendedPlan(game)),
          const SingleActivator(LogicalKeyboardKey.keyR): () =>
              controller.act(Plan.rest),
          // 数字キー1〜7: 行動のタイルの順(練習・特訓・休養・研究・交流・練習試合・コーチ)
          for (var i = 0; i < Plan.values.length; i++)
            SingleActivator(_digitKeys[i]): () =>
                controller.act(Plan.values[i]),
        },
        if (controller.canUndo)
          const SingleActivator(LogicalKeyboardKey.keyZ): controller.undo,
      },
      child: Focus(autofocus: true, child: _scaffold(context, p)),
    );
  }

  Widget _scaffold(BuildContext context, Player p) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              key: const Key('tab-train'),
              icon:
                  _tabIcon(Icons.sports_baseball_outlined, _trainMark, 'train'),
              selectedIcon: const Icon(Icons.sports_baseball),
              label: '育成'),
          NavigationDestination(
              key: const Key('tab-ability'),
              icon: _tabIcon(Icons.insights_outlined, _abilityMark, 'ability',
                  count: _abilityCount),
              selectedIcon: _tabIcon(Icons.insights, _abilityMark, 'ability',
                  count: _abilityCount),
              label: '能力'),
          NavigationDestination(
              key: const Key('tab-career'),
              icon: _tabIcon(Icons.timeline_outlined, _careerMark, 'career'),
              selectedIcon: _tabIcon(Icons.timeline, _careerMark, 'career'),
              label: 'キャリア'),
          const NavigationDestination(
              key: Key('tab-relations'),
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: '関係'),
        ],
      ),
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('title'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (controller.tapTitle()) showAdminToggled(context, controller);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.name}  ${p.age}歳'),
              Text(
                  '${stageLabel(game.stage)}  ${game.slotName}'
                  '${game.stage == Stage.pro && game.proTeam != null ? '  ${game.proTeam}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('player-open'),
            tooltip: '選手情報',
            icon: const Icon(Icons.person),
            onPressed: () => _openPlayer(),
          ),
          IconButton(
            key: const Key('records-open'),
            tooltip: '成績',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => RecordsScreen(game: game)),
            ),
          ),
          IconButton(
            key: const Key('settings-open'),
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          if (controller.adminMode)
            IconButton(
              key: const Key('admin-open'),
              tooltip: '管理者機能',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => AdminScreen(controller: controller)),
              ),
            ),
        ],
      ),
      body: _wide(context)
          ? Row(children: [
              for (final tab in [_trainTab(context, p), _abilityTab()])
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: contentMaxWidth),
                      child: ListView(
                        key: ValueKey('wide-${identityHashCode(tab)}'),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        children: tab,
                      ),
                    ),
                  ),
                ),
            ])
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView(
                  key: ValueKey('tab-$_tab'),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: switch (_tab) {
                    1 => _abilityTab(),
                    2 => _careerTab(context),
                    3 => _relationsTab(),
                    _ => _trainTab(context, p),
                  },
                ),
              ),
            ),
    );
  }

  /// 広い画面(パソコン)では、育成と能力を横に並べて出す。
  bool _wide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1000 && (_tab == 0 || _tab == 1);

  List<Widget> _trainTab(BuildContext context, Player p) => [
        _Header(game: game, onTap: _openPlayer),
        const SizedBox(height: 6),
        _StatusCard(
            game: game,
            controller: controller,
            onOpenAbility: () => setState(() => _tab = 1)),
        if (controller.recent.isNotEmpty) ...[
          const SizedBox(height: 6),
          _RecentCard(lines: controller.recent, limit: 2),
        ],
        if (_isFirstTurn) ...[
          const SizedBox(height: 6),
          const _FirstHint(),
        ],
        _TodoChips(game: game),
        if (game.canChooseSchool) ...[
          const SizedBox(height: 6),
          _SchoolCard(controller: controller, game: game),
        ],
        if (game.stage == Stage.pro &&
            (game.canChooseOffseason || game.canChoosePosition)) ...[
          // プロは毎年のことなので、1枚にたたんで場所を取らない(開くと選べる)。
          const SizedBox(height: 6),
          _ProDecisions(controller: controller, game: game),
        ] else ...[
          if (game.canChooseOffseason) ...[
            const SizedBox(height: 6),
            _OffseasonCard(controller: controller, game: game),
          ],
          if (game.canChoosePosition) ...[
            const SizedBox(height: 6),
            _PositionCard(controller: controller, game: game),
          ],
        ],
        const SizedBox(height: 6),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(game.phase),
              child: _mainCard(),
            ),
          ),
        ),
      ];

  List<Widget> _abilityTab() => [
        _OverallHeader(game: game),
        _TraitChips(game: game),
        _AbilityCard(controller: controller, game: game),
      ];

  List<Widget> _careerTab(BuildContext context) => [
        if (game.records.isNotEmpty) ...[
          Card(
            key: const Key('career-summary'),
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: Text(careerSummary(game.records)),
              subtitle: Text('${game.records.length}年ぶんの成績'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (controller.recent.length > 2) ...[
          _RecentCard(
              lines: controller.recent, cardKey: const Key('recent-full')),
          const SizedBox(height: 8),
        ],
        if (game.stage == Stage.pro)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: const Key('money-card'),
              child: ListTile(
                leading: const Icon(Icons.savings, color: Color(0xFF2E7D32)),
                title: Text('資産 ${fmtMoney(game.money)}'),
                subtitle: Text(game.records.any((r) => r.stage == Stage.pro)
                    ? '昨年の年俸 ${fmtSalary(salaryOf(game.records.lastWhere((r) => r.stage == Stage.pro)))}'
                    : '年俸はシーズンのあとに決まります'),
              ),
            ),
          ),
        if (game.phase == Phase.term && game.stage == Stage.pro) ...[
          _ProCard(controller: controller, game: game),
          const SizedBox(height: 8),
        ],
        if (game.records.isNotEmpty) ...[
          _RecentRecordCard(game: game),
          const SizedBox(height: 8),
        ],
        _LogCard(game: game),
      ];

  List<Widget> _relationsTab() => [
        if (game.cast.rival != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: const Key('rival-line'),
              child: ListTile(
                leading: const Icon(Icons.sports_kabaddi),
                title: Text('ライバル ${game.cast.rival!.name}'),
                subtitle: Text(rivalStatus(
                    storyOfCharacter(game.cast.rival!)!.avoiding(game.proTeam),
                    game.player.age)),
              ),
            ),
          ),
        CastCard(game: game, expanded: true),
      ];

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlayerScreen(snapshot: PlayerSnapshot.fromGame(game), game: game),
      ),
    );
  }

  /// 最初の数ターンだけ、遊び方の案内を出す。
  bool get _isFirstTurn =>
      game.records.isEmpty && game.player.age == startAge && game.slot < 2;

  Widget _mainCard() {
    switch (game.phase) {
      case Phase.event:
        return _AutoReveal(
            key: ValueKey('event-${game.pendingEvent?.id}'),
            child: _EventCard(controller: controller, game: game));
      case Phase.pathChoice:
        return _PathCard(controller: controller);
      default:
        return _ActionCard(controller: controller, game: game);
    }
  }
}

IconData _moodIcon(Motivation m) => switch (m) {
      Motivation.terrible => Icons.sentiment_very_dissatisfied,
      Motivation.bad => Icons.sentiment_dissatisfied,
      Motivation.normal => Icons.sentiment_neutral,
      Motivation.good => Icons.sentiment_satisfied,
      Motivation.great => Icons.sentiment_very_satisfied,
    };

Color _moodColor(Motivation m) => switch (m) {
      Motivation.terrible => const Color(0xFFD32F2F),
      Motivation.bad => const Color(0xFFF57C00),
      Motivation.normal => const Color(0xFF78909C),
      Motivation.good => const Color(0xFF7CB342),
      Motivation.great => const Color(0xFF2E9B3E),
    };

/// 背景の絵・所属・背番号・1年の進み具合を、1枚にまとめた見出し。
class _Header extends StatelessWidget {
  const _Header({required this.game, required this.onTap});
  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final u = untilTournament(game.stage, game.slot);
    // 絵と文字は重ねず、左に絵・右に所属などを並べる。
    return Semantics(
      button: true,
      label: '選手の詳細を開く',
      child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
                key: const Key('banner'),
                onTap: onTap,
                child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: box.maxWidth * 0.36,
                          height: 96,
                          child: SceneBanner(
                            season: seasonOf(game.stage, game.slot),
                            stage: game.stage,
                            role: p.role,
                            mood: moodOf(game.motivation),
                            label: '', // 月・季節は、上のバーと行動カードに出ている

                            height: 96,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            key: const Key('player-card'),
                            constraints: const BoxConstraints(minHeight: 96),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    affiliationOf(game.stage, p.name,
                                        proTeam: game.proTeam),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    playerCardLine(game.stage, p,
                                        position: game.position,
                                        numberOverride: specialNumberOf(
                                            p.role, game.records)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: game.slot / game.slotsInYear,
                                      minHeight: 5,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${game.slot + 1}/${game.slotsInYear}',
                                      style: t.bodySmall),
                                ]),
                                if (u != null)
                                  Text(
                                      u.left == 0
                                          ? '今が${u.name}'
                                          : '${u.name}まであと${u.left}${u.unit}',
                                      key: const Key('until-tournament'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ]),
                ),
              )),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.game, required this.controller, this.onOpenAbility});
  final Game game;
  final GameController controller;

  /// 経験点をタップしたとき、能力タブへ移る。
  final VoidCallback? onOpenAbility;

  @override
  Widget build(BuildContext context) {
    final c = game.condition;
    final p = game.player;
    final spendable =
        abilitiesOf(p.role).any((a) => buy(p, game.exp, a) != null);
    final stamina = (100 - c.fatigue) / 100;
    final staminaColor = stamina > 0.55
        ? const Color(0xFF43A047)
        : stamina > 0.3
            ? const Color(0xFFFB8C00)
            : const Color(0xFFE53935);
    final m = game.motivation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (game.stage == Stage.pro && game.seasonProgress != null) ...[
              _PennantRow(progress: game.seasonProgress!),
              const SizedBox(height: 6),
            ],
            if (game.goal != null && game.phase != Phase.pathChoice)
              _GoalRow(
                  game: game,
                  onChange: game.canChooseGoal
                      ? () => _openGoalSheet(context, controller)
                      : null),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.favorite, size: 18, color: Color(0xFFE57373)),
              const SizedBox(width: 4),
              const Text('体力'),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: stamina),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 10,
                    color: staminaColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(_moodIcon(m), color: _moodColor(m), size: 20),
              const SizedBox(width: 2),
              Flexible(
                flex: 3,
                child: Text('やる気: ${m.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ]),
            if (c.injured)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.healing, color: Color(0xFFD32F2F), size: 18),
                  const SizedBox(width: 4),
                  Text('怪我で安静中(あと${c.injuredTerms}回で復帰)',
                      key: const Key('injury-left'),
                      style: const TextStyle(color: Color(0xFFD32F2F))),
                ]),
              )
            else if (c.fatigue >= 70)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.battery_alert, color: Color(0xFFEF6C00), size: 18),
                  SizedBox(width: 4),
                  Text('疲れがたまっています。休養がおすすめ',
                      key: Key('tired-note'),
                      style: TextStyle(color: Color(0xFFEF6C00))),
                ]),
              ),
            if (spendable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FilledButton.tonalIcon(
                  key: const Key('quick-spend'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(36)),
                  onPressed: controller.autoSpend,
                  icon: const Icon(Icons.trending_up),
                  label: const Text('経験点をおまかせで振り分け'),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('経験点', style: Theme.of(context).textTheme.labelLarge),
                  for (final cat in usableCategories(game.player.role))
                    ActionChip(
                      key: Key('exp-${cat.name}'),
                      onPressed: onOpenAbility,
                      tooltip: '能力タブで振り分ける',
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${cat.label} ${game.exp.of(cat)}'
                        '${(game.lastGain[cat] ?? 0) > 0 ? ' (+${game.lastGain[cat]})' : ''}',
                      ),
                    ),
                ]),
          ],
        ),
      ),
    );
  }
}

/// ポジションを決める(決められる時だけ出る)。適性はランクで見える。
/// 能力タブの先頭: 総合評価・素質・今年の伸び。
class _OverallHeader extends StatelessWidget {
  const _OverallHeader({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final ov = overall(game.player).round();
    final hist = game.overallHistory;
    final delta = hist.isEmpty ? null : ov - hist.last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: const Key('overall-header'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            RankBadge(value: ov),
            const SizedBox(width: 8),
            Text('総合評価 $ov', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Flexible(
              child: Text(
                  '素質 ${potentialStars(game.player.potential)}'
                  '${delta == null || delta == 0 ? '' : '\n今年 ${delta > 0 ? '+' : ''}$delta'}',
                  key: const Key('overall-delta'),
                  textAlign: TextAlign.right),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 特性のチップ(能力タブの上に出す)。
class _TraitChips extends StatelessWidget {
  const _TraitChips({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    if (game.player.traits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 6, children: [
        for (final t in game.player.traits)
          Tooltip(
            message: t.description,
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                  t.positive ? Icons.auto_awesome : Icons.warning_amber_rounded,
                  size: 16,
                  color: t.positive
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF607D8B)),
              // 明るい背景には暗い文字(ダークテーマでも読める)
              label: Text(t.label,
                  style: const TextStyle(color: Color(0xFF263238))),
              backgroundColor:
                  t.positive ? Colors.amber.shade100 : Colors.blueGrey.shade100,
            ),
          ),
      ]),
    );
  }
}

class _InvestRow extends StatelessWidget {
  const _InvestRow(
      {required this.game, required this.controller, required this.item});
  final Game game;
  final GameController controller;
  final Invest item;

  @override
  Widget build(BuildContext context) {
    final lv = game.investLevel(item);
    final cost = investCost(lv);
    final can = cost != null && game.money >= cost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item.label}  Lv$lv/$maxInvestLevel',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(item.description, style: const TextStyle(fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: FilledButton.tonal(
            key: Key('invest-${item.name}'),
            onPressed: can ? () => controller.buyInvest(item) : null,
            child: Text(cost == null ? '最大' : fmtMoney(cost)),
          ),
        ),
      ]),
    );
  }
}

/// いま決められることのお知らせ(選んでも選ばなくてもよい)。
class _TodoChips extends StatelessWidget {
  const _TodoChips({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    // 進学先・ポジション・オフは、このタブの下にカードが出るので、お知らせは要らない。
    // キャリアタブでしか決められないものだけ知らせる。
    final items = <String>[
      if (game.canUseFa) 'FA権あり(キャリア)',
      if (game.canMoveOverseas) '海外移籍可(キャリア)',
    ];
    final outlook = game.draftOutlook;
    final release = game.releaseWarning;
    final late = game.stage == Stage.pro && game.player.age >= 40;
    if (items.isEmpty && outlook == null && release == null && !late) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        key: const Key('todo-chips'),
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final i in items)
            Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.flag, size: 16),
                label: Text(i)),
          if (outlook != null)
            Chip(
                key: const Key('draft-outlook'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.star_border, size: 16),
                label: Text('ドラフトの見込み: $outlook')),
          if (release != null)
            Chip(
                key: const Key('release-warning'),
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFFFFCDD2),
                avatar: const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFC62828)),
                label: Text('総合が低い状態が続くと、あと$release年で戦力外',
                    style: const TextStyle(color: Color(0xFF263238)))),
          if (late)
            const Chip(
                key: Key('late-career'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.hourglass_bottom, size: 16),
                label: Text('現役の終わりが近い')),
        ],
      ),
    );
  }
}

/// 今年の予定を開く。
void _showYearPlan(BuildContext context, Game game) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('今年の予定'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in yearPlanOf(game.stage, game.player.age))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('・$p'),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))
      ],
    ),
  );
}

String _offShort(Offseason o) => switch (o) {
      Offseason.camp => '(疲れ↑)',
      Offseason.family => '(やる気↑)',
      Offseason.rehab => '(疲れ↓)',
    };

/// プロの年のはじめの任意の決めごと(オフの過ごし方・ポジション)を、たたんでまとめる。
class _ProDecisions extends StatelessWidget {
  const _ProDecisions({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final todo = [
      if (game.canChooseOffseason) 'オフの過ごし方',
      if (game.canChoosePosition) 'ポジション',
    ];
    return Card(
      key: const Key('pro-decisions'),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.flag_outlined),
        title: const Text('年のはじめの決めごと'),
        subtitle: Text(
            '${todo.join('・')}(任意)。ポジション: ${positionOf(game.player, game.position)}'),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        children: [
          if (game.canChooseOffseason)
            _OffseasonCard(controller: controller, game: game),
          if (game.canChooseOffseason && game.canChoosePosition)
            const SizedBox(height: 6),
          if (game.canChoosePosition)
            _PositionCard(controller: controller, game: game),
        ],
      ),
    );
  }
}

class _OffseasonCard extends StatelessWidget {
  const _OffseasonCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('offseason-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('オフの過ごし方', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('年に一度、選べます(選ばなくてもOK)。長押しで説明が出ます。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in Offseason.values)
                Tooltip(
                  message: o.description,
                  child: OutlinedButton(
                    key: Key('offseason-${o.name}'),
                    onPressed: () => controller.chooseOffseason(o),
                    child: Text('${o.label} ${_offShort(o)}'),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: const Key('school-card'),
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('進学先を決めよう', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('この${stageNameOf(game.stage)}の間、ずっと続きます。選ばなければ地元の学校です。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in School.values)
                ChoiceChip(
                  key: Key('school-${s.name}'),
                  selected: s == game.school,
                  label: Text(s.label),
                  onSelected: (_) => controller.chooseSchool(s),
                ),
            ]),
            const SizedBox(height: 6),
            Text(game.school.description,
                key: const Key('school-desc'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final cs = Theme.of(context).colorScheme;
    final now = game.effectivePos;
    final best = bestPosition(p);
    return Card(
      key: const Key('position-card'),
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ポジションを決めよう', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
                '能力から見た適性は、おすすめが「${best.label}」。'
                '適性の低い所を選ぶとチーム力が下がります。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final pos in positionsFor(p.role))
                ChoiceChip(
                  key: Key('pos-${pos.name}'),
                  selected: pos == now,
                  avatar: CircleAvatar(
                    radius: 10,
                    backgroundColor: rankColor(rankOf(aptitudeOf(p, pos))),
                    child: Text(rankOf(aptitudeOf(p, pos)),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  label: Text(pos == best ? '${pos.label} (おすすめ)' : pos.label),
                  onSelected: (_) => controller.choosePosition(pos),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

Ability _weakest(Player p) =>
    abilitiesOf(p.role).reduce((x, y) => p.of(y) < p.of(x) ? y : x);

/// 能力の行の小さな注記: いちばん低い能力は「伸ばしどころ」、他は次のランクまでの差。
String _abilityNote(Player p, Ability a) {
  if (a == _weakest(p) && abilitiesOf(p.role).length > 1) return '伸ばしどころ';
  final v = p.of(a);
  if (v >= 90) return 'S';
  final next = (v ~/ 10 + 1) * 10;
  return 'あと+${next - v}';
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('能力 (${roleLabel(p.role)})',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextButton(
                      onPressed: controller.autoSpend,
                      child: const Text('おまかせ振り分け')),
                ]),
            if (abilitiesOf(p.role).any((a) => buy(p, game.exp, a) != null))
              Container(
                key: const Key('spend-hint'),
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('経験点が貯まっています。「+1」で能力に振り分けましょう。'),
              ),
            AbilityRadar(player: p),
            const SizedBox(height: 4),
            for (final a in abilitiesOf(p.role))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  RankBadge(value: p.of(a)),
                  const SizedBox(width: 6),
                  SizedBox(
                      width: 60,
                      child: Tooltip(
                          message: abilityHint(a),
                          triggerMode: TooltipTriggerMode.tap,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(abilityLabel(a))),
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(_abilityNote(p, a),
                                        key: Key('note-${a.name}'),
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: a == _weakest(p)
                                                ? const Color(0xFFEF6C00)
                                                : Colors.grey))),
                              ]))),
                  SizedBox(
                      width: 54,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text.rich(
                            TextSpan(children: [
                              if ((controller.abilityGains[a] ?? 0) > 0)
                                TextSpan(
                                    text: '+${controller.abilityGains[a]} ',
                                    style: const TextStyle(
                                        color: Color(0xFF2E9B3E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              TextSpan(text: '${p.of(a)}'),
                            ]),
                            key: Key('gain-${a.name}'),
                            textAlign: TextAlign.right,
                          ))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: p.of(a) / 99),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        color: rankColor(rankOf(p.of(a))),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    child: OutlinedButton(
                      key: Key('buy-${a.name}'),
                      style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact),
                      onPressed: buy(p, game.exp, a) == null
                          ? null
                          : () => controller.spend(a),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('+1 (${expCost(p.of(a))})')),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _planStyle(Plan a) => switch (a) {
      Plan.train => (Icons.fitness_center, const Color(0xFF1E88E5)),
      Plan.special => (Icons.local_fire_department, const Color(0xFFE53935)),
      Plan.rest => (Icons.hotel, const Color(0xFF00897B)),
      Plan.study => (Icons.menu_book, const Color(0xFF5E35B1)),
      Plan.social => (Icons.favorite, const Color(0xFFD81B60)),
      Plan.match => (Icons.sports_baseball, const Color(0xFF2E7D32)),
      Plan.lesson => (Icons.school, const Color(0xFFF9A825)),
    };

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final abilities = abilitiesOf(game.player.role);
    final focus = abilities.contains(controller.focus)
        ? controller.focus
        : abilities.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${game.slotName}は何をする? ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: recommendReason(game)),
                    ]),
                    key: const Key('recommend-reason'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (controller.canUndo)
                IconButton(
                  key: const Key('undo'),
                  tooltip: 'ひとつ前に戻す',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.undo, size: 20),
                  onPressed: controller.undo,
                ),
              IconButton(
                key: const Key('year-plan'),
                tooltip: '今年の予定',
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.event_note, size: 20),
                onPressed: () => _showYearPlan(context, game),
              ),
            ]),
            Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('重点', style: Theme.of(context).textTheme.labelMedium),
                  for (final a in abilities)
                    ChoiceChip(
                      key: Key('focus-${a.name}'),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                      labelPadding: EdgeInsets.zero,
                      label: Text(abilityLabel(a)),
                      selected: a == focus,
                      onSelected: (_) => controller.setFocus(a),
                    ),
                ]),
            if (game.focusStreak >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    game.lastFocus == focus
                        ? '${abilityLabel(focus)}を${game.focusStreak}回連続で鍛えている'
                            '${game.streakBonus > 1 ? '(経験点+${((game.streakBonus - 1) * 100).round()}%)' : '(あと${3 - game.focusStreak}回で経験点+2%)'}'
                        : '重点を変えると、連続はリセットされる',
                    key: const Key('focus-streak'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              // 4列の小さなタイルにして、スクロールなしで全部の行動を見せる。
              final w = (box.maxWidth - 8 * 3) / 4;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in Plan.values)
                  SizedBox(
                      width: w,
                      child: _PlanTile(
                          plan: a,
                          focus: focus,
                          controller: controller,
                          recommended: a == recommendedPlan(game),
                          danger: game.condition.fatigue >= 70 &&
                              (a == Plan.special || a == Plan.match),
                          sub: a == Plan.lesson && game.cast.coach != null
                              ? 'コツ ${game.cast.coach!.tips}/$tipsNeeded'
                              : null)),
                SizedBox(
                    width: w, child: _AutoYearTile(controller: controller)),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}

String _planShort(Plan p) => switch (p) {
      Plan.train => '練習',
      Plan.special => '特訓',
      Plan.rest => '休養',
      Plan.study => '研究',
      Plan.social => '交流',
      Plan.match => '練習試合',
      Plan.lesson => 'コーチ',
    };

/// タイルの2行目(重点の能力が効く行動は、その能力名)。
String _planSub(Plan p, Ability focus) => switch (p) {
      Plan.train || Plan.special || Plan.study => abilityLabel(focus),
      Plan.rest => '疲れを取る',
      Plan.social => 'やる気',
      Plan.match => '全体',
      Plan.lesson => 'コツ',
    };

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.focus,
    required this.controller,
    this.recommended = false,
    this.sub,
    this.danger = false,
  });
  final Plan plan;
  final Ability focus;
  final GameController controller;

  /// 今のおすすめ(疲れ・気持ちから決める)。
  final bool recommended;

  /// 2行目の文字(省略すると既定)。
  final String? sub;

  /// 疲れているのにこの行動をすると危ない(怪我しやすい)。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _planStyle(plan);
    return Semantics(
      button: true,
      label:
          '${planTitle(plan, focus)}。${planHint(plan, focus)}${recommended ? '。おすすめ' : ''}',
      excludeSemantics: true,
      child: Tooltip(
        // 長押しで、行動の説明が出る。
        message: '${planTitle(plan, focus)}: ${planHint(plan, focus)}',
        child: Material(
          key: Key('act-${plan.name}'),
          color: color.withValues(alpha: recommended ? 0.22 : 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: color.withValues(alpha: recommended ? 0.9 : 0.35),
                width: recommended ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => controller.act(plan),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 19),
                  ),
                  if (danger)
                    Positioned(
                      key: Key('danger-${plan.name}'),
                      left: -6,
                      top: -6,
                      child: const Icon(Icons.error,
                          size: 16, color: Color(0xFFD32F2F)),
                    ),
                  if (recommended)
                    Positioned(
                      key: Key('recommended-${plan.name}'),
                      right: -6,
                      top: -6,
                      child: const Icon(Icons.star,
                          size: 16, color: Color(0xFFF9A825)),
                    ),
                ]),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_planShort(plan),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(sub ?? _planSub(plan, focus),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「おすすめで年末まで進める」を、行動と同じ大きさのタイルにしたもの。
class _AutoYearTile extends StatelessWidget {
  const _AutoYearTile({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'おすすめの過ごし方で年末まで進める(出来事や節目では止まる)',
      child: Material(
        key: const Key('auto-year'),
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: controller.autoYear,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Icon(Icons.fast_forward, color: cs.onPrimary, size: 19),
              ),
              const SizedBox(height: 4),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('年末まで',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('おすすめで',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 出てきた瞬間に、画面のスクロール位置に関わらず見える所まで動かす。
class _AutoReveal extends StatefulWidget {
  const _AutoReveal({super.key, required this.child});
  final Widget child;

  @override
  State<_AutoReveal> createState() => _AutoRevealState();
}

class _AutoRevealState extends State<_AutoReveal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
          curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final e = game.pendingEvent!;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('出来事', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(e.text, style: Theme.of(context).textTheme.titleMedium),
            Text(
                'いまの体力 ${100 - game.condition.fatigue} ・ やる気 ${game.motivation.label}',
                key: const Key('event-context'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (var i = 0; i < e.choices.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: FilledButton(
                  key: Key('event-$i'),
                  onPressed: () => controller.chooseEvent(i),
                  child: Text(e.choices[i].label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.controller});
  final GameController controller;

  Future<void> _confirmGiveUp(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プロは諦めますか?'),
        content: const Text('この選手の人生がここで終わります。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
            key: const Key('give-up-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('諦める'),
          ),
        ],
      ),
    );
    if (ok == true) controller.giveUp();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ドラフトでは指名されなかった…',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('もう一度プロを目指す?  再挑戦のチャンスは1度だけ。'),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('route-university'),
              onPressed: () => controller.chooseRoute(Course.university),
              child: const Text('大学で4年間鍛える(22歳でドラフト)'),
            ),
            const SizedBox(height: 4),
            FilledButton(
              key: const Key('route-corporate'),
              onPressed: () => controller.chooseRoute(Course.corporate),
              child: const Text('社会人で3年間鍛える(21歳でドラフト)'),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              key: const Key('give-up'),
              onPressed: () => _confirmGiveUp(context),
              child: const Text('プロは諦める'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final r = game.player.role;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プロの決断', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                key: const Key('invest-open'),
                icon: const Icon(Icons.savings, size: 18),
                onPressed: () => _openInvest(context),
                label: Text('投資(資産 ${fmtMoney(game.money)})'),
              ),
              if (game.canMoveOverseas)
                OutlinedButton(
                  key: const Key('move-overseas'),
                  onPressed: () => _confirmOverseas(context),
                  child: const Text('アメリカのリーグへ移籍する'),
                ),
              if (game.canUseFa)
                OutlinedButton(
                  key: const Key('fa-open'),
                  onPressed: () => _openFa(context),
                  child: const Text('FA権を使う'),
                ),
              if (game.canReturnHome)
                OutlinedButton(
                  key: const Key('return-home'),
                  onPressed: controller.returnHome,
                  child: const Text('日本のリーグに戻る'),
                ),
              if (r != Role.twoWay)
                OutlinedButton(
                  key: const Key('role-twoway'),
                  onPressed: () => controller.changeRole(Role.twoWay),
                  child: const Text('二刀流に挑戦する'),
                ),
              if (r == Role.twoWay) ...[
                OutlinedButton(
                  onPressed: () => controller.changeRole(Role.batter),
                  child: const Text('打者に専念'),
                ),
                OutlinedButton(
                  onPressed: () => controller.changeRole(Role.pitcher),
                  child: const Text('投手に専念'),
                ),
              ],
              OutlinedButton(
                key: const Key('retire'),
                onPressed: () => _confirmRetire(context),
                child: const Text('引退する'),
              ),
            ]),
            if (r != Role.twoWay)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    '二刀流は両方を使えるが、練習が分散して伸びが0.75倍になる。両方を伸ばせば評価が上乗せされ、年俸1.4倍・人気も上がる。',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInvest(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: controller,
        builder: (ctx, _) => AlertDialog(
          title: const Text('投資'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('資産: ${fmtMoney(game.money)}',
                    key: const Key('money'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('年俸は資産になります。練習環境や体のケアに使って、選手を支えましょう。',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                for (final i in Invest.values)
                  _InvestRow(game: game, controller: controller, item: i),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          ],
        ),
      ),
    );
  }

  Future<void> _openFa(BuildContext context) async {
    final c = await showDialog<FaChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FA権を使いますか?'),
        content: const Text('一生に一度だけ決められます。\n'
            '・残留: 今のチームで、やる気が上がる\n'
            '・強豪へ: チーム力+3、契約金4000万円(やる気は少し下がる)\n'
            '・高額オファー: 再建中のチーム(チーム力-2)へ、契約金1億円'),
        actions: [
          TextButton(
              key: const Key('fa-stay'),
              onPressed: () => Navigator.pop(ctx, FaChoice.stay),
              child: const Text('残留する')),
          TextButton(
              key: const Key('fa-contender'),
              onPressed: () => Navigator.pop(ctx, FaChoice.contender),
              child: const Text('強豪へ移籍')),
          TextButton(
              key: const Key('fa-cash'),
              onPressed: () => Navigator.pop(ctx, FaChoice.cash),
              child: const Text('高額オファーへ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('あとで')),
        ],
      ),
    );
    if (c != null) controller.useFa(c);
  }

  Future<void> _confirmOverseas(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アメリカのリーグへ移籍しますか?'),
        content: const Text('相手が強くなりますが、年俸は2.5倍になります。\n'
            '慣れない環境で、最初は気持ちが下がります。日本には、年のはじめにいつでも戻れます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              key: const Key('overseas-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移籍する')),
        ],
      ),
    );
    if (ok == true) controller.moveOverseas();
  }

  Future<void> _confirmRetire(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('引退しますか?'),
        content: const Text('この選手の人生がここで終わります。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
            key: const Key('retire-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('引退する'),
          ),
        ],
      ),
    );
    if (ok == true) controller.retire();
  }
}

/// ログの1行。「── 9歳 ──」の見出しは目立たせ、それ以外は「・」つき。
Widget _logLine(BuildContext context, String l) {
  if (l.startsWith('── ')) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(l,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
  return Text('・$l');
}

/// 一生のログを、古いほうから全部見る。
void _showAllLog(BuildContext context, Game game) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('log-dialog'),
      title: const Text('これまでのできごと'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [for (final l in game.log) _logLine(ctx, l)],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))
      ],
    ),
  );
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final recent = game.log.reversed.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('log-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child:
                    Text('できごと', style: Theme.of(context).textTheme.titleSmall),
              ),
              if (game.log.length > recent.length)
                TextButton(
                  key: const Key('log-all'),
                  onPressed: () => _showAllLog(context, game),
                  child: const Text('ぜんぶ見る'),
                ),
            ]),
            for (final l in recent) _logLine(context, l),
          ],
        ),
      ),
    );
  }
}

/// 直前の操作で起きたこと。
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.lines, this.limit, this.cardKey});
  final List<String> lines;

  /// 指定すると、その行数までにして「ほかN行」と出す。
  final int? limit;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(lines.join('|')),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: Card(
        key: cardKey ?? const Key('recent'),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in limit == null ? lines : lines.take(limit!))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(l, style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (limit != null && lines.length > limit!)
                Text('ほか${lines.length - limit!}行(「キャリア」で全部見られます)',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引退後の画面: エンディング。
class EndingView extends StatelessWidget {
  const EndingView({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final e = game.ending!;
    final p = game.player;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${p.name} の一生'),
        actions: [
          IconButton(
            key: const Key('player-open'),
            tooltip: '選手情報',
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerScreen(
                    snapshot: PlayerSnapshot.fromGame(game), game: game),
              ),
            ),
          ),
          IconButton(
            key: const Key('settings-open'),
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SceneBanner(
                season: Season.autumn,
                stage: e.madePro ? Stage.pro : Stage.pathChoice,
                role: p.role,
                mood: e.madePro ? Mood.happy : Mood.flat,
                label: '${p.age}歳',
              ),
              const SizedBox(height: 16),
              Text(e.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(e.madePro
                  ? '${game.proTeam == null ? '' : '${game.proTeam}で'}プロで${e.proYears}年間プレーした。'
                  : 'プロの舞台には立てなかった。'),
              const SizedBox(height: 10),
              Text(
                  '${epilogueOf(e, p.name, worldChampion: game.worldRecords.where((r) => r.champion).length, worldPlayed: game.worldRecords.length, overseasYears: game.records.where((r) => r.overseas).length, popularity: popularityOf(game.records, game.worldRecords), retiredNumber: uniformNumberOf(Stage.pro, p))}'
                  '\nその後: ${afterCareerOf(title: e.title, proYears: e.proYears, popularity: popularityOf(game.records, game.worldRecords), money: game.money, madePro: e.madePro, team: game.proTeam)}',
                  key: const Key('epilogue'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic, height: 1.5)),
              Builder(builder: (context) {
                final pool = game.records.any((r) => r.stage == Stage.pro)
                    ? game.records.where((r) => r.stage == Stage.pro)
                    : game.records;
                if (pool.isEmpty) return const SizedBox.shrink();
                final best = pool
                    .reduce((a, b) => b.line.rating > a.line.rating ? b : a);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'ベストシーズン: ${best.age}歳 ${describeLine(best.line)}',
                      key: const Key('best-season')),
                );
              }),
              Builder(builder: (context) {
                final vote = hallOfFameVote(
                    records: game.records, title: e.title, madePro: e.madePro);
                if (vote == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '殿堂入り投票: 得票率$vote%${inHallOfFame(vote) ? '(殿堂入り!)' : '(75%に届かず)'}',
                      key: const Key('hof-vote'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
              const SizedBox(height: 16),
              if (controller.newlyUnlocked.isNotEmpty) ...[
                Card(
                  key: const Key('new-achievements'),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('新しく解除した実績',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          for (final a in controller.newlyUnlocked)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                const Icon(Icons.military_tech,
                                    color: Color(0xFFE53935), size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                    child:
                                        Text('${a.title} ― ${a.description}')),
                              ]),
                            ),
                        ]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _row('最高の総合評価', '${e.peakOverall}'),
                    _row('優勝', '${e.championships}回'),
                    _row('タイトル', '${e.titles.length}個'),
                    _row('ライバルとの対戦', '${e.rivalWins}勝 ${e.rivalLosses}敗'),
                    if (e.wasTwoWay) _row('二刀流', '挑戦した'),
                    if (game.money > 0) _row('最終資産', fmtMoney(game.money)),
                    if (e.married) _row('家族', '${e.partnerName} と結婚した'),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              RecordsView(snapshot: PlayerSnapshot.fromGame(game)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final t in p.traits)
                  Chip(
                    avatar:
                        Icon(Icons.auto_awesome, size: 16, color: cs.tertiary),
                    label: Text(t.label),
                  ),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('copy-result'),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('結果をコピーする'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                      ClipboardData(text: endingShareText(game)));
                  messenger.showSnackBar(
                      const SnackBar(content: Text('コピーしました。友だちに見せよう')));
                },
              ),
              const SizedBox(height: 8),
              if (game.ending?.married ?? false) ...[
                FilledButton.tonal(
                  key: const Key('continue-heir'),
                  onPressed: controller.continueAsHeir,
                  child: const Text('この選手の子(二世)で続ける'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('again'),
                onPressed: controller.reset,
                child: const Text('もう一度、別の選手で'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k)),
          const SizedBox(width: 8),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold)))
        ]),
      );
}

/// 最近の成績(直近1年)と、成績表への入口。
class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final r = game.records.last;
    final d = describeLine(r.line);
    final pay = salaryOf(r) > 0 ? '  年俸 ${fmtSalary(salaryOf(r))}' : '';
    return Card(
      child: ListTile(
        key: const Key('records-open-card'),
        leading: const Icon(Icons.bar_chart),
        title: Text('${r.age}歳の成績: ${r.resultText}'),
        subtitle: Text(d.isEmpty ? '成績表を見る' : '$d$pay\n成績表を見る'),
        isThreeLine: d.isNotEmpty,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RecordsScreen(game: game)),
        ),
      ),
    );
  }
}

/// はじめてのときの案内。
class _FirstHint extends StatelessWidget {
  const _FirstHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('first-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'はじめに: 下の行動を選んで季節を進めよう。経験点は「能力」タブで振り分け。',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

/// 今年の目標と、その状態。
/// 目標のむずかしさを選ぶ。むずかしいほど、達成のごほうびが大きい。
/// ペナントの途中経過(プロ)。月ごとに進む。
class _PennantRow extends StatelessWidget {
  const _PennantRow({required this.progress});
  final LeagueProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final d = describeLine(p.line);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('pennant'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${p.wins}勝${p.losses}敗 ${fmtRate(p.winPct)} 暫定${p.rank}位'
            '(${p.games}/$leagueGames試合)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (d.isNotEmpty)
          Text('今季ここまで: $d', style: Theme.of(context).textTheme.bodySmall),
        if (p.missed > 0)
          Text('怪我で${p.missed}試合を欠場',
              style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
      ]),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({required this.game, required this.controller});
  final Game game;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final g = game.goal!;
    final maxRounds = game.stage == Stage.pro ? 6 : 5;
    return Column(
      key: const Key('goal-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('目標のむずかしさ(むずかしいほど、ごほうびが大きい)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (var l = 0; l < 3; l++)
            Tooltip(
              message: g.withLevel(l, maxRounds: maxRounds).text,
              child: ChoiceChip(
                key: Key('goal-level-$l'),
                selected: g.level == l,
                label: Text(
                    '${goalLevelLabels[l]}(経験点+${goalExpFor(game.stage, l)})'),
                onSelected: (_) => controller.chooseGoalLevel(l),
              ),
            ),
        ]),
      ],
    );
  }
}

/// 今年の目標のむずかしさを選ぶ(画面を占領しないよう、必要なときだけ開く)。
Future<void> _openGoalSheet(BuildContext context, GameController controller) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final g = controller.game;
        if (g == null || g.goal == null) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今年の目標', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                _GoalPicker(game: g, controller: controller),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('閉じる')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.game, this.onChange});
  final Game game;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final g = game.goal!;
    final (label, color) = switch (g.achieved) {
      null => ('挑戦中', const Color(0xFF1E88E5)),
      true => ('達成!', const Color(0xFF2E9B3E)),
      false => ('未達', const Color(0xFF78909C)),
    };
    final reward = goalExpFor(game.stage, g.level);
    return Container(
      key: const Key('goal-row'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.flag, color: color, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('今年の目標: ${g.text}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              g.achieved == null
                  ? '達成で 経験点+$reward・やる気+${goalMoraleReward[g.level]}'
                  : (g.achieved! ? 'ごほうびをもらった' : '来年また挑戦しよう'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        if (onChange != null)
          IconButton(
            key: const Key('goal-change'),
            tooltip: '目標のむずかしさを変える',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.tune, color: color, size: 20),
            onPressed: onChange,
          ),
      ]),
    );
  }
}

/// 結果を共有するための短い文章。
String endingShareText(Game game) {
  final e = game.ending!;
  final p = game.player;
  final pro = game.records.where((r) => r.stage == Stage.pro).toList();
  final lines = [
    '【野球育成】${p.name} の一生: ${e.title}',
    e.madePro
        ? '${game.proTeam == null ? '' : '${game.proTeam}で'}プロで${e.proYears}年間プレー'
        : 'プロの舞台には立てなかった',
    '最高の総合評価 ${e.peakOverall}・優勝${e.championships}回・タイトル${e.titles.length}個',
    if (pro.isNotEmpty) careerSummary(game.records),
    if (pro.isNotEmpty)
      'プロ通算収入 ${fmtSalary(careerEarnings(pro))}(最終資産 ${fmtMoney(game.money)})',
    if (game.worldRecords.isNotEmpty)
      '日本代表: 世界大会${game.worldRecords.length}回出場・優勝${game.worldRecords.where((r) => r.champion).length}回',
    if (inHallOfFame(hallOfFameVote(
        records: game.records, title: e.title, madePro: e.madePro)))
      '殿堂入り!',
  ];
  return lines.join('\n');
}
