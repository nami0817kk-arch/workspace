import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/calendar.dart';
import '../game/career.dart';
import '../game/epilogue.dart';
import '../game/exp.dart';
import '../game/flavor.dart';
import '../game/goals.dart';
import '../game/game.dart';
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
        return _EventCard(controller: controller, game: game);
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
                    Text(playerCardLine(game.stage, p),
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
            if (game.goal != null) ...[
              const SizedBox(height: 8),
              _GoalRow(game: game),
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
            Row(children: [
              Icon(_moodIcon(m), color: _moodColor(m), size: 22),
              const SizedBox(width: 6),
              Text('やる気: ${m.label}',
                  style: Theme.of(context).textTheme.titleSmall),
              if (c.injured) ...[
                const SizedBox(width: 12),
                const Icon(Icons.healing, color: Color(0xFFD32F2F), size: 18),
                const SizedBox(width: 4),
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
              Text(epilogueOf(e, p.name),
                  key: const Key('epilogue'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic, height: 1.5)),
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
    final reward = goalRewardExp(game.stage);
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
                  ? '達成すると 経験点+$reward(全種類)・気持ち+$goalRewardMorale'
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
    if (pro.isNotEmpty) 'プロ通算収入 ${fmtSalary(careerEarnings(pro))}',
  ];
  return lines.join('\n');
}
