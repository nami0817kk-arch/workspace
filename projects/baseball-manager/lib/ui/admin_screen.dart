import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/exp.dart';
import '../game/game.dart';
import '../game/player.dart';
import '../game/talent.dart';
import '../game/skills.dart';
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
                        const Text(
                            'ルール(特性は$maxTraitsつまで・矛盾する組は不可、特殊能力の年齢・コツ)を無視して書き換えます。'),
                        const SizedBox(height: 8),
                        _Potential(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _Traits(controller: controller, game: g),
                        const SizedBox(height: 8),
                        _Skills(controller: controller, game: g),
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
          SwitchListTile(
            key: const Key('admin-awakened'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('覚醒済み(切ると、もう一度覚醒できる)'),
            value: game.awakened,
            onChanged: (v) => controller.admin((g) => g.adminSetAwakened(v)),
          ),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (final t in Trait.values)
              Tooltip(
                message: t.description,
                child: FilterChip(
                  key: Key('admin-trait-${t.name}'),
                  label: Text(t.rare ? '★${t.label}' : t.label),
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
          Text('コツ ${coach.tips} / $tipsNeeded(満タンにすると、教える特殊能力のコツがその場で満タン)',
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
          const Text('教える特殊能力'),
          Wrap(spacing: 6, children: [
            ChoiceChip(
              key: const Key('admin-teach-none'),
              label: const Text('なし'),
              selected: coach.teaches == null,
              onSelected: (_) =>
                  controller.admin((g) => g.adminSetCoachTeaches(null)),
            ),
            for (final t in Skill.values.where((k) => !k.negative))
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

/// 特殊能力の付け外し(弱点も)と、コツの書き換え。
class _Skills extends StatelessWidget {
  const _Skills({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final have = game.player.skills;
    final list = skillsFor(game.player.role);
    final open = [
      for (final s in list)
        if (!have.contains(s) && !s.negative) s
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('特殊能力 (${have.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (final s in list)
              FilterChip(
                key: Key('admin-skill-${s.name}'),
                label: Text(s.negative
                    ? '×${s.label}'
                    : (s.gold ? '金${s.label}' : s.label)),
                selected: have.contains(s),
                onSelected: (on) => controller.admin((g) =>
                    g.adminSetSkills(on ? {...have, s} : ({...have}..remove(s)))),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(
              key: const Key('admin-tips-max'),
              onPressed: () => controller.admin((g) {
                for (final s in open) {
                  g.adminSetSkillTips(s, maxSkillTips);
                }
              }),
              child: const Text('コツを全部満タン'),
            ),
            OutlinedButton(
              key: const Key('admin-tips-clear'),
              onPressed: () => controller.admin((g) {
                for (final s in open) {
                  g.adminSetSkillTips(s, 0);
                }
              }),
              child: const Text('コツを全部0'),
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
          Text('能力 (${roleLabel(p.role)})と天賦(右のスライダー -2〜+2)',
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
              // 天賦(-2〜+2)
              SizedBox(
                width: 110,
                child: Slider(
                  key: Key('admin-gift-${a.name}'),
                  value: p.gift(a).toDouble(),
                  min: giftMin.toDouble(),
                  max: giftMax.toDouble(),
                  divisions: giftMax - giftMin,
                  label: '天賦 ${p.gift(a)}',
                  onChanged: (x) =>
                      controller.admin((g) => g.adminSetGift(a, x.round())),
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
