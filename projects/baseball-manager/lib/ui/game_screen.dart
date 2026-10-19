import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/calendar.dart';
import '../game/career.dart';
import '../game/epilogue.dart';
import '../game/exp.dart';
import '../game/flavor.dart';
import '../game/life_log.dart';
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
import '../game/tactics.dart';
import 'player_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// 画面の中身の最大幅。広い画面(Web・タブレット)では中央に寄せる。
const contentMaxWidth = 560.0;

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    if (game.phase == Phase.retired) {
      return EndingView(controller: controller, game: game);
    }
    final p = game.player;
    return Scaffold(
      bottomNavigationBar: game.phase == Phase.term
          ? _QuickBar(controller: controller, game: game)
          : null,
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
            onPressed: () => _openPlayer(context),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              GestureDetector(
                key: const Key('banner'),
                onTap: () => _openPlayer(context),
                child: SceneBanner(
                  season: seasonOf(game.stage, game.slot),
                  stage: game.stage,
                  role: p.role,
                  mood: moodOf(game.motivation),
                  label: game.slotName,
                ),
              ),
              const SizedBox(height: 8),
              _StatusCard(game: game, controller: controller),
              if (controller.recent.isNotEmpty) ...[
                const SizedBox(height: 8),
                _RecentCard(lines: controller.recent),
              ],
              const SizedBox(height: 8),
              if (_isFirstTurn) ...[
                const SizedBox(height: 8),
                const _FirstHint(),
              ],
              _TodoChips(game: game),
              if (game.canChooseOffseason) ...[
                const SizedBox(height: 8),
                _OffseasonCard(controller: controller, game: game),
              ],
              if (game.canChooseSchool) ...[
                const SizedBox(height: 8),
                _SchoolCard(controller: controller, game: game),
              ],
              if (game.canChoosePosition) ...[
                const SizedBox(height: 8),
                _PositionCard(controller: controller, game: game),
              ],
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              _AbilityCard(controller: controller, game: game),
              if (game.phase == Phase.term && game.stage == Stage.pro) ...[
                const SizedBox(height: 8),
                _ProCard(controller: controller, game: game),
              ],
              if (game.records.isNotEmpty) ...[
                const SizedBox(height: 8),
                _RecentRecordCard(game: game),
              ],
              const SizedBox(height: 8),
              CastCard(game: game),
              const SizedBox(height: 8),
              _LogCard(game: game),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.game, required this.controller});
  final Game game;
  final GameController controller;

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 選手カード: 所属・背番号・投打・守備位置
            Container(
              key: const Key('player-card'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        affiliationOf(game.stage, p.name,
                            proTeam: game.proTeam),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                        playerCardLine(game.stage, p,
                            position: game.position,
                            numberOverride:
                                specialNumberOf(p.role, game.records)),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
            ),
            Row(children: [
              Text(game.slotName,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: game.slot / game.slotsInYear,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text('${game.slot + 1}/${game.slotsInYear}'),
            ]),
            if (game.stage == Stage.pro && game.seasonProgress != null) ...[
              const SizedBox(height: 8),
              _PennantRow(progress: game.seasonProgress!),
            ],
            if (game.goal != null) ...[
              const SizedBox(height: 8),
              _GoalRow(game: game),
              if (game.canChooseGoal) ...[
                const SizedBox(height: 6),
                _GoalPicker(game: game, controller: controller),
              ],
            ],
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.favorite, size: 18, color: Color(0xFFE57373)),
              const SizedBox(width: 6),
              const Text('体力'),
              const SizedBox(width: 8),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: stamina),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 12,
                    color: staminaColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Icon(_moodIcon(m), color: _moodColor(m), size: 22),
                  Text('やる気: ${m.label}',
                      style: Theme.of(context).textTheme.titleSmall),
                  if (c.injured) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.healing,
                        color: Color(0xFFD32F2F), size: 18),
                    const Text('怪我で安静中',
                        style: TextStyle(color: Color(0xFFD32F2F))),
                  ],
                ]),
            if (spendable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonalIcon(
                  key: const Key('quick-spend'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40)),
                  onPressed: controller.autoSpend,
                  icon: const Icon(Icons.trending_up),
                  label: const Text('貯めた経験点を、おまかせで振り分ける'),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
                spacing: 6,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('経験点', style: Theme.of(context).textTheme.labelLarge),
                  for (final cat in usableCategories(game.player.role))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${cat.label} ${game.exp.of(cat)}'
                        '${(game.lastGain[cat] ?? 0) > 0 ? ' (+${game.lastGain[cat]})' : ''}',
                      ),
                    ),
                ]),
            if (game.player.traits.isNotEmpty)
              Wrap(spacing: 6, children: [
                for (final t in game.player.traits)
                  Tooltip(
                    message: t.description,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                          t.positive
                              ? Icons.auto_awesome
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: t.positive
                              ? const Color(0xFFF9A825)
                              : const Color(0xFF607D8B)),
                      // 明るい背景には暗い文字(ダークテーマでも読める)
                      label: Text(t.label,
                          style: const TextStyle(color: Color(0xFF263238))),
                      backgroundColor: t.positive
                          ? Colors.amber.shade100
                          : Colors.blueGrey.shade100,
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
    final items = <String>[
      if (game.canChooseSchool) '進学先を決められる',
      if (game.canChoosePosition) 'ポジションを決められる',
      if (game.canChooseOffseason) 'オフの過ごし方を選べる',
      if (game.canUseFa) 'FA権を使える',
      if (game.canMoveOverseas) '海外へ移籍できる',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        key: const Key('todo-chips'),
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (untilTournament(game.stage, game.slot) != null)
            Builder(builder: (context) {
              final u = untilTournament(game.stage, game.slot)!;
              return Text(
                  u.left == 0
                      ? '今が${u.name}'
                      : '${u.name}まであと${u.left}${u.unit}',
                  key: const Key('until-tournament'),
                  style: Theme.of(context).textTheme.bodySmall);
            }),
          for (final i in items)
            Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.flag, size: 16),
                label: Text(i)),
          TextButton.icon(
            key: const Key('year-plan'),
            onPressed: () => showDialog<void>(
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('閉じる'))
                ],
              ),
            ),
            icon: const Icon(Icons.event_note, size: 18),
            label: const Text('今年の予定'),
          ),
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
            Text('年に一度、選べます(選ばなくてもOK)。自主トレは、下で選んだ重点の能力を鍛えます。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in Offseason.values)
                Tooltip(
                  message: o.description,
                  child: OutlinedButton(
                    key: Key('offseason-${o.name}'),
                    onPressed: () => controller.chooseOffseason(o),
                    child: Text(o.label),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
                [
                  for (final o in Offseason.values)
                    '${o.label}: ${o.description}'
                ].join('\n'),
                style: Theme.of(context).textTheme.bodySmall),
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
            Row(children: [
              Text('能力 (${roleLabel(p.role)})',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
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
                          child: Text(abilityLabel(a)))),
                  SizedBox(
                      width: 54,
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
                      )),
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
                      child: Text('+1 (${expCost(p.of(a))})'),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${game.slotName}は何をする?',
                style: Theme.of(context).textTheme.titleSmall),
            Text('おすすめの理由: ${recommendReason(game)}',
                key: const Key('recommend-reason'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            const Text('重点にする能力'),
            Wrap(spacing: 6, children: [
              for (final a in abilities)
                ChoiceChip(
                  key: Key('focus-${a.name}'),
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
            if (game.tacticRelevant) ...[
              const SizedBox(height: 10),
              _TacticPicker(controller: controller, game: game),
            ],
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 420 ? 2 : 1;
              final w = (box.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in Plan.values)
                  SizedBox(
                      width: w,
                      child: _PlanTile(
                          plan: a,
                          focus: focus,
                          controller: controller,
                          recommended: a == recommendedPlan(game))),
              ]);
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('auto-year'),
                onPressed: controller.autoYear,
                icon: const Icon(Icons.fast_forward, size: 18),
                label: const Text('おすすめで年末まで進める'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.focus,
    required this.controller,
    this.recommended = false,
  });
  final Plan plan;
  final Ability focus;
  final GameController controller;

  /// 今のおすすめ(疲れ・気持ちから決める)。
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _planStyle(plan);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${planTitle(plan, focus)}。${planHint(plan, focus)}${recommended ? '。おすすめ' : ''}',
      excludeSemantics: true,
      child: Material(
        key: Key('act-${plan.name}'),
        color: color.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => controller.act(plan),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planTitle(plan, focus),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(planHint(plan, focus),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (recommended)
                Container(
                  key: Key('recommended-${plan.name}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('おすすめ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
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
                child: Text('二刀流は両方を使えるが、練習が分散して伸びが0.6倍になる。',
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

class _LogCard extends StatelessWidget {
  const _LogCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final recent = game.log.reversed.take(6).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('できごと', style: Theme.of(context).textTheme.titleSmall),
            for (final l in recent) Text('・$l'),
          ],
        ),
      ),
    );
  }
}

/// 直前の操作で起きたこと。
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.lines});
  final List<String> lines;

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
        key: const Key('recent'),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(l, style: Theme.of(context).textTheme.bodyLarge),
                ),
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
    return Card(
      key: const Key('first-hint'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'はじめに: 下の「練習」などを選んで、季節を進めましょう。\n'
          '練習すると「経験点」が貯まり、「+1」で能力に振り分けられます。\n'
          '体力が減ったら休養も大切です。',
        ),
      ),
    );
  }
}

/// 大会・シーズン最終月の作戦。
class _TacticPicker extends StatelessWidget {
  const _TacticPicker({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final isPro = game.stage == Stage.pro;
    final now = game.tactic;
    return Container(
      key: const Key('tactic-picker'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isPro ? 'ペナントの最終月に向けて、作戦を選ぼう' : '大会に向けて、作戦を選ぼう',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final t in Tactic.values)
            ChoiceChip(
              key: Key('tactic-${t.name}'),
              label: Text(t.label),
              selected: t == now,
              onSelected: (_) => controller.setTactic(t),
            ),
        ]),
        const SizedBox(height: 4),
        Text(now.description, style: Theme.of(context).textTheme.bodySmall),
      ]),
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
            'ペナント(${p.games}/$leagueGames試合): ${p.wins}勝${p.losses}敗 '
            '${fmtRate(p.winPct)}  暫定${p.rank}位',
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

/// 画面の下に固定する、いちばんよく使う操作(おすすめの行動・休養)。
class _QuickBar extends StatelessWidget {
  const _QuickBar({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final rec = recommendedPlan(game);
    final focus = abilitiesOf(game.player.role).contains(controller.focus)
        ? controller.focus
        : abilitiesOf(game.player.role).first;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentMaxWidth),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    key: const Key('quick-recommended'),
                    onPressed: () => controller.act(rec),
                    icon: const Icon(Icons.bolt, size: 20),
                    label: Text('おすすめ: ${planTitle(rec, focus)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (rec != Plan.rest) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      key: const Key('quick-rest'),
                      onPressed: () => controller.act(Plan.rest),
                      icon: const Icon(Icons.hotel, size: 18),
                      label: const Text('休む', maxLines: 1),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
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

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.game});
  final Game game;

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
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('今年の目標: ${g.text}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              g.achieved == null
                  ? '達成すると 経験点+$reward(全種類)・気持ち+${goalMoraleReward[g.level]}'
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
