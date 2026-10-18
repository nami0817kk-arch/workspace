import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/exp.dart';
import '../game/game.dart';
import '../game/player.dart';
import '../game/traits.dart';
import 'controller.dart';
import 'labels.dart';

/// 管理者画面: 素質・特性・コツ・能力・経験点を自由に書き換える。
/// 上限や矛盾のルールは無視される(調整・検証用)。
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final g = controller.game;
        return Scaffold(
          appBar: AppBar(title: const Text('管理者機能')),
          body: g == null || g.phase == Phase.retired
              ? const Center(child: Text('育成中の選手がいません'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Text('ルール(特性は4つまで・矛盾する組は不可)を無視して書き換えます。'),
                        const SizedBox(height: 8),
                        _Potential(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _Traits(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _Coach(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _Abilities(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _ExpCard(controller: controller, game: g),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Potential extends StatelessWidget {
  const _Potential({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final v = game.player.potential;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('素質(ポテンシャル): $v', style: Theme.of(context).textTheme.titleSmall),
          const Text('伸びの速さに効く(0〜100)。高いほど経験点がたくさん貯まる。',
              style: TextStyle(fontSize: 12)),
          Slider(
            key: const Key('admin-potential'),
            value: v.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$v',
            onChanged: (x) =>
                controller.admin((g) => g.adminSetPotential(x.round())),
          ),
        ]),
      ),
    );
  }
}

class _Traits extends StatelessWidget {
  const _Traits({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final have = game.player.traits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('特性 (${have.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (final t in Trait.values)
              Tooltip(
                message: t.description,
                child: FilterChip(
                  key: Key('admin-trait-${t.name}'),
                  label: Text(t.label),
                  selected: have.contains(t),
                  onSelected: (on) => controller.admin(
                    (g) => g.adminSetTraits(
                        on ? {...have, t} : ({...have}..remove(t))),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Coach extends StatelessWidget {
  const _Coach({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final coach = game.cast.coach;
    if (coach == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('コーチ: ${coach.name}',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('コツ ${coach.tips} / $tipsNeeded(満タンにするとその場で習得)',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('admin-tips'),
            value: coach.tips.toDouble(),
            min: 0,
            max: tipsNeeded.toDouble(),
            divisions: tipsNeeded,
            label: '${coach.tips}',
            onChanged: (x) =>
                controller.admin((g) => g.adminSetCoachTips(x.round())),
          ),
          const Text('教える特性'),
          Wrap(spacing: 6, children: [
            ChoiceChip(
              key: const Key('admin-teach-none'),
              label: const Text('なし'),
              selected: coach.teaches == null,
              onSelected: (_) =>
                  controller.admin((g) => g.adminSetCoachTeaches(null)),
            ),
            for (final t in Trait.values)
              ChoiceChip(
                key: Key('admin-teach-${t.name}'),
                label: Text(t.label),
                selected: coach.teaches == t,
                onSelected: (_) =>
                    controller.admin((g) => g.adminSetCoachTeaches(t)),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('能力 (${roleLabel(p.role)})',
              style: Theme.of(context).textTheme.titleSmall),
          for (final a in abilitiesOf(p.role))
            Row(children: [
              SizedBox(width: 72, child: Text('${abilityLabel(a)} ${p.of(a)}')),
              Expanded(
                child: Slider(
                  key: Key('admin-ability-${a.name}'),
                  value: p.of(a).toDouble(),
                  min: 0,
                  max: 99,
                  divisions: 99,
                  onChanged: (x) =>
                      controller.admin((g) => g.adminSetAbility(a, x.round())),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _ExpCard extends StatelessWidget {
  const _ExpCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '経験点(全種類): ${[
                for (final c in Category.values) '${c.label} ${game.exp.of(c)}'
              ].join(' / ')}',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final n in [100, 500, 2000])
              OutlinedButton(
                key: Key('admin-exp-$n'),
                onPressed: () => controller.admin((g) => g.adminAddExp(n)),
                child: Text('+$n'),
              ),
            OutlinedButton(
              key: const Key('admin-exp-reset'),
              onPressed: () => controller.admin((g) => g.adminAddExp(-100000)),
              child: const Text('0にする'),
            ),
          ]),
        ]),
      ),
    );
  }
}
