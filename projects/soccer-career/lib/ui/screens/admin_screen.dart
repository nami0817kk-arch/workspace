/// 管理画面（開発用）。**公開ビルドには入らない**（`kAdmin` を参照）。
///
/// 稀な特性は20人に1人、超越の能力が効くのは 89 以上、引退は33歳から——
/// 作った仕組みの多くは、普通に遊んで確かめようとすると数十シーズンかかる。
/// ここは「作ったものを見に行くための入口」であって、遊びの一部ではない。
library;

import 'package:flutter/material.dart';

import '../../dev/admin.dart';
import '../../game/scenarios.dart';
import '../../models/attributes.dart';
import '../../models/traits.dart';
import '../../state/career_controller.dart';
import '../readable_width.dart';
import 'match_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state == null) return const SizedBox.shrink();
        final admin = AdminActions(controller);
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('管理'),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: ReadableWidth(
                  child: TabBar(
                    tabs: [
                      Tab(text: '特性'),
                      Tab(text: '状態'),
                      Tab(text: '局面'),
                      Tab(text: '時間'),
                    ],
                  ),
                ),
              ),
            ),
            body: ReadableWidth(
              child: TabBarView(
                children: [
                  _TraitsTab(controller: controller, admin: admin),
                  _StateTab(controller: controller, admin: admin),
                  _ScenarioTab(controller: controller, admin: admin),
                  _TimeTab(controller: controller, admin: admin),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 75種を名指しで付け外しする。
///
/// 天才 5%・ガラスの身体 2%・イーグルアイに至っては引くまで何百人。
/// ここが無いと、自分で作った特性を自分で見られない。
class _TraitsTab extends StatelessWidget {
  const _TraitsTab({required this.controller, required this.admin});

  final CareerController controller;
  final AdminActions admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = controller.state!.player;
    final has = player.traits.toSet();
    Widget group(String label, List<Trait> traits, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('$label（${traits.length}）',
                  style: theme.textTheme.labelLarge?.copyWith(color: color)),
            ),
            for (final trait in traits)
              CheckboxListTile(
                dense: true,
                value: has.contains(trait),
                onChanged: (_) => admin.toggleTrait(trait),
                title: Text(trait.label),
                subtitle: Text(
                  [
                    if (!trait.fitsPosition(player.position)) 'このポジションでは効かない',
                    ...trait.effects,
                  ].join('、'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('付いている ${player.traits.length}件',
                    style: theme.textTheme.bodyMedium),
              ),
              TextButton(
                onPressed: admin.clearTraits,
                child: const Text('全部外す'),
              ),
            ],
          ),
        ),
        group('稀', Trait.rares, theme.colorScheme.tertiary),
        group('長所', Trait.strengths, theme.colorScheme.primary),
        group('欠点', Trait.flaws, theme.colorScheme.error),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// 能力・気持ち・お金・規律を直接いじる。
class _StateTab extends StatelessWidget {
  const _StateTab({required this.controller, required this.admin});

  final CareerController controller;
  final AdminActions admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state!;
    final player = state.player;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('総合力 ${player.overall} ・ ポテンシャル ${player.potential}',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('能力を全部'),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () => admin.bumpAll(-5), child: const Text('-5')),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () => admin.bumpAll(5), child: const Text('+5')),
          ],
        ),
        const Divider(height: 32),
        _Stepper(
          label: 'ポテンシャル',
          value: player.potential,
          onChanged: admin.setPotential,
          step: 5,
        ),
        _Stepper(label: '年齢', value: player.age, onChanged: admin.setAge),
        _Stepper(
          label: 'コンディション',
          value: player.condition,
          onChanged: admin.setCondition,
          step: 10,
        ),
        _Stepper(
          label: '気持ち',
          value: state.morale.value,
          onChanged: admin.setMorale,
          step: 10,
        ),
        _Stepper(
          label: '疲労',
          value: state.fatigue.value,
          onChanged: admin.setFatigue,
          step: 10,
        ),
        _Stepper(
          label: '監督の信頼',
          value: state.relations.manager,
          onChanged: admin.setManagerTrust,
          step: 10,
        ),
        _Stepper(
          label: '知名度',
          value: state.reputation.fame,
          onChanged: admin.setFame,
          step: 10,
        ),
        _Stepper(
          label: '貯蓄（万円）',
          value: state.finances.savings,
          onChanged: admin.setSavings,
          step: 1000,
        ),
        _Stepper(
          label: '今季の警告',
          value: state.yellowCards,
          onChanged: admin.setYellowCards,
        ),
        _Stepper(
          label: '出場停止',
          value: state.suspension,
          onChanged: admin.setSuspension,
        ),
        _Stepper(
          label: '離脱試合',
          value: state.injury?.matchesOut ?? 0,
          onChanged: admin.setInjury,
          step: 3,
        ),
        const Divider(height: 32),
        Text('詳細能力', style: theme.textTheme.titleSmall),
        for (final detail in Detail.values)
          _Stepper(
            label: '${detail.label}（${detail.category.label}）',
            value: player.attributes.detail(detail),
            onChanged: (v) =>
                admin.bumpDetail(detail, v - player.attributes.detail(detail)),
          ),
      ],
    );
  }
}

/// 局面を名指しで出す。条件が揃わないと来ない局面を直接見るため。
class _ScenarioTab extends StatelessWidget {
  const _ScenarioTab({required this.controller, required this.admin});

  final CareerController controller;
  final AdminActions admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state!;
    final scenarios = admin.scenarios;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('${state.player.position.label} の局面 ${scenarios.length}件',
            style: theme.textTheme.titleSmall),
        Text('選ぶと、その局面だけで1試合に入る。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final scenario in scenarios)
          Card(
            child: ListTile(
              title: Text(scenario.situation),
              subtitle: Text(
                  '${scenario.id} ・ ${_tempoLabel(scenario.tempo)} ・ '
                  '${scenario.options.map((o) => o.label).join(' / ')}'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () {
                admin.startMatchWith(scenario);
                if (controller.currentMatch == null) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MatchScreen(controller: controller),
                ));
              },
            ),
          ),
      ],
    );
  }

  static String _tempoLabel(ScenarioTempo tempo) => switch (tempo) {
        ScenarioTempo.any => '骨格',
        ScenarioTempo.chase => '追いかける',
        ScenarioTempo.hold => '守り切る',
      };
}

/// 時間を飛ばす。引退・帰化・違約金は、普通に遊ぶと数十シーズンかかる。
class _TimeTab extends StatefulWidget {
  const _TimeTab({required this.controller, required this.admin});

  final CareerController controller;
  final AdminActions admin;

  @override
  State<_TimeTab> createState() => _TimeTabState();
}

class _TimeTabState extends State<_TimeTab> {
  bool _running = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _running = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state!;
    final admin = widget.admin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('${state.year}シーズン ・ 第${state.matchday}節 / ${state.fixtures.length}',
            style: theme.textTheme.titleSmall),
        Text('${state.player.age}歳 ・ ${state.club.name} ・ 契約 残り${state.contractYears}年',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (_running) const LinearProgressIndicator(),
        FilledButton.tonal(
          onPressed:
              _running ? null : () => _run(admin.finishSeasonNow),
          child: const Text('今season の残りを消化する'),
        ),
        const SizedBox(height: 8),
        for (final years in [1, 3, 5, 10])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _running ? null : () => _run(() => admin.skipYears(years)),
              child: Text('$years年進める'),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '契約更改は残留で自動的に受ける。引退したら止まる。',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 値を1つ、段階で動かす行。
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final void Function(int) onChanged;
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            onPressed: () => onChanged(value - step),
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 56,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall),
          ),
          IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
