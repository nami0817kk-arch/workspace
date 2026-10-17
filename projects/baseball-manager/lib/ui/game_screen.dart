import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/characters.dart';
import '../game/exp.dart';
import '../game/game.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';
import 'controller.dart';
import 'labels.dart';

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.name}  ${p.age}歳'),
            Text('${stageLabel(game.stage)}  ${game.slotName}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _StatusCard(game: game),
          if (controller.recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            _RecentCard(lines: controller.recent),
          ],
          const SizedBox(height: 8),
          _AbilityCard(controller: controller, game: game),
          const SizedBox(height: 8),
          if (game.phase == Phase.event)
            _EventCard(controller: controller, game: game)
          else if (game.phase == Phase.pathChoice)
            _PathCard(controller: controller)
          else ...[
            _ActionCard(controller: controller, game: game),
            if (game.stage == Stage.pro) ...[
              const SizedBox(height: 8),
              _ProCard(controller: controller, game: game),
            ],
          ],
          const SizedBox(height: 8),
          _CastCard(game: game),
          const SizedBox(height: 8),
          _LogCard(game: game),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = game.condition;
    final stamina = (100 - c.fatigue) / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(game.slotName, style: Theme.of(context).textTheme.titleSmall),
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
            const SizedBox(height: 8),
            Row(children: [
              const Text('体力'),
              const SizedBox(width: 8),
              Expanded(child: LinearProgressIndicator(value: stamina, minHeight: 10)),
            ]),
            const SizedBox(height: 4),
            Text('やる気: ${game.motivation.label}',
                style: Theme.of(context).textTheme.titleSmall),
            if (c.injured)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('怪我で安静中', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              for (final cat in Category.values)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${cat.label}経験点 ${game.exp.of(cat)}'
                    '${(game.lastGain[cat] ?? 0) > 0 ? '  (+${game.lastGain[cat]})' : ''}',
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
                      label: Text(t.label),
                      backgroundColor: t.positive ? Colors.amber.shade100 : Colors.blueGrey.shade100,
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
              Text('能力 (${roleLabel(p.role)})', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(onPressed: controller.autoSpend, child: const Text('おまかせ振り分け')),
            ]),
            for (final a in abilitiesOf(p.role))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  _RankBadge(value: p.of(a)),
                  const SizedBox(width: 6),
                  SizedBox(width: 60, child: Text(abilityLabel(a))),
                  SizedBox(width: 28, child: Text('${p.of(a)}', textAlign: TextAlign.right)),
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
                          padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: buy(p, game.exp, a) == null ? null : () => controller.spend(a),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final abilities = abilitiesOf(game.player.role);
    final focus = abilities.contains(controller.focus) ? controller.focus : abilities.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${game.slotName}は何をする?', style: Theme.of(context).textTheme.titleSmall),
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
            const SizedBox(height: 8),
            for (final a in Plan.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: FilledButton.tonal(
                  key: Key('act-${a.name}'),
                  onPressed: () => controller.act(a),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: actionLabel(a),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text: '\n${actionHint(a)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
                  ),
                ),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ドラフトでは指名されなかった…', style: Theme.of(context).textTheme.titleMedium),
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
              onPressed: controller.giveUp,
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
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

class _CastCard extends StatelessWidget {
  const _CastCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final cast = game.cast;
    final rows = <Character>[
      if (cast.rival != null) cast.rival!,
      if (cast.lover != null) cast.lover!,
      if (cast.family != null) cast.family!,
      if (cast.coach != null) cast.coach!,
      ...cast.teammates,
    ];
    return Card(
      child: ExpansionTile(
        title: const Text('まわりの人たち'),
        children: [
          for (final m in rows)
            ListTile(
              dense: true,
              title: Text('${m.name}  (${m.kind.label})'),
              subtitle: Text(_sub(m)),
              trailing: SizedBox(
                width: 80,
                child: LinearProgressIndicator(value: m.bond / 100),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('ライバルとの対戦: ${cast.rivalWins}勝 ${cast.rivalLosses}敗'),
          ),
        ],
      ),
    );
  }

  String _sub(Character m) => switch (m.kind) {
        Kind.teammate => '得意: ${m.specialty == null ? '-' : abilityLabel(m.specialty!)}',
        Kind.coach => m.teaches == null
            ? 'コツ ${m.tips}/$tipsNeeded'
            : 'コツ ${m.tips}/$tipsNeeded → ${m.teaches!.label}',
        Kind.rival => '強さの目安 ${rivalLevel(m, game.player.age).round()}',
        _ => '絆 ${m.bond}',
      };
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

/// 引退後の画面: エンディング。
class EndingView extends StatelessWidget {
  const EndingView({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final e = game.ending!;
    final p = game.player;
    return Scaffold(
      appBar: AppBar(title: Text('${p.name} の一生')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(e.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(e.madePro ? 'プロで${e.proYears}年間プレーした。' : 'プロの舞台には立てなかった。'),
          const SizedBox(height: 16),
          _row('最高の総合評価', '${e.peakOverall}'),
          _row('優勝', '${e.championships}回'),
          _row('ライバルとの対戦', '${e.rivalWins}勝 ${e.rivalLosses}敗'),
          if (e.wasTwoWay) _row('二刀流', '挑戦した'),
          if (e.married) _row('家族', '${e.partnerName} と結婚した'),
          const SizedBox(height: 16),
          Wrap(spacing: 6, children: [
            for (final t in p.traits) Chip(label: Text(t.label)),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('again'),
            onPressed: controller.reset,
            child: const Text('もう一度、別の選手で'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(k)), Text(v)]),
      );
}

/// 能力のランク(G〜S)の丸いバッジ。
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final r = rankOf(value);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: rankColor(r), shape: BoxShape.circle),
      child: Text(r,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

/// 直前の操作で起きたこと。
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}
