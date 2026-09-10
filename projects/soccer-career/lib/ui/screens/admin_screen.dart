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
  /// 直前の操作で動いた行。「何をしたら何が変わったのか」を出すため。
  ///
  /// **null は「まだ触っていない」、空は「触ったが何も動かなかった」。**
  /// 一緒くたにすると、効かない操作をしたのか押せていないのか分からない
  /// （天才を付けても今の数字は動かない——効くのは成長のときなので）。
  List<String>? _changes;

  /// 操作を、前後の「効き」を挟んで走らせる。
  ///
  /// 値をいじれるだけでは、それがゲームの何に効くのか分からなかった。
  /// 押した直後に差分を出すのが、一番短い答えになる。
  Future<void> run(Future<void> Function() action) async {
    final before = AdminImpact.of(widget.controller);
    await action();
    if (!mounted) return;
    final after = AdminImpact.of(widget.controller);
    setState(() => _changes = AdminImpact.diff(before, after));
  }

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
              child: Column(
                children: [
                  // どのタブに居ても、効き先は常に見えている場所に置く。
                  _ImpactPanel(
                    impact: AdminImpact.of(controller),
                    changes: _changes,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TraitsTab(
                            controller: controller, admin: admin, run: run),
                        _StateTab(
                            controller: controller, admin: admin, run: run),
                        _ScenarioTab(controller: controller, admin: admin),
                        _TimeTab(controller: controller, admin: admin, run: run),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// いま何が効いているか。畳んであり、開くと全部の行が読める。
///
/// 閉じているときは「総合力 / 次の試合」と、直前の操作で動いた行だけを出す。
class _ImpactPanel extends StatelessWidget {
  const _ImpactPanel({required this.impact, required this.changes});

  final AdminImpact impact;

  /// null は未操作、空は「触ったが動かなかった」。
  final List<String>? changes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (impact.lines.isEmpty) return const SizedBox.shrink();
    // 局所変数に取る。public のフィールドは null 昇格が効かない。
    final changes = this.changes;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text('ゲームへの効き', style: theme.textTheme.titleSmall),
          subtitle: changes == null
              ? Text(impact.lines.first.value,
                  style: theme.textTheme.bodySmall, maxLines: 1)
              : Text(
                  changes.isEmpty
                      ? '直前の操作では、ここの数字は動かなかった'
                      : '直前の操作で ${changes.length}件が動いた',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: changes.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary)),
          children: [
            if (changes != null && changes.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '直前の操作では、ここの数字は動かなかった。'
                  '効くのが先（成長・移籍・シーズン末）の項目もある。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const Divider(height: 16),
            ],
            if (changes != null && changes.isNotEmpty) ...[
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: theme.colorScheme.primary),
                      ),
                      Expanded(
                        child: Text(change,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 16),
            ],
            for (final line in impact.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(line.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child:
                          Text(line.value, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 75種を名指しで付け外しする。
///
/// 天才 5%・ガラスの身体 2%・イーグルアイに至っては引くまで何百人。
/// ここが無いと、自分で作った特性を自分で見られない。
class _TraitsTab extends StatelessWidget {
  const _TraitsTab(
      {required this.controller, required this.admin, required this.run});

  final CareerController controller;
  final AdminActions admin;

  /// 操作を前後の「効き」で挟んで走らせる。
  final Future<void> Function(Future<void> Function()) run;

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
                onChanged: (_) => run(() => admin.toggleTrait(trait)),
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
                onPressed: () => run(admin.clearTraits),
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
  const _StateTab(
      {required this.controller, required this.admin, required this.run});

  final CareerController controller;
  final AdminActions admin;

  /// 操作を前後の「効き」で挟んで走らせる。
  final Future<void> Function(Future<void> Function()) run;

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
                onPressed: () => run(() => admin.bumpAll(-5)),
                child: const Text('-5')),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () => run(() => admin.bumpAll(5)),
                child: const Text('+5')),
          ],
        ),
        const Divider(height: 32),
        _Stepper(
          label: 'ポテンシャル',
          value: player.potential,
          onChanged: (v) => run(() => admin.setPotential(v)),
          step: 5,
        ),
        _Stepper(
            label: '年齢',
            value: player.age,
            onChanged: (v) => run(() => admin.setAge(v))),
        _Stepper(
          label: 'コンディション',
          value: player.condition,
          onChanged: (v) => run(() => admin.setCondition(v)),
          step: 10,
        ),
        _Stepper(
          label: '気持ち',
          value: state.morale.value,
          onChanged: (v) => run(() => admin.setMorale(v)),
          step: 10,
        ),
        _Stepper(
          label: '疲労',
          value: state.fatigue.value,
          onChanged: (v) => run(() => admin.setFatigue(v)),
          step: 10,
        ),
        _Stepper(
          label: '監督の信頼',
          value: state.relations.manager,
          onChanged: (v) => run(() => admin.setManagerTrust(v)),
          step: 10,
        ),
        _Stepper(
          label: '知名度',
          value: state.reputation.fame,
          onChanged: (v) => run(() => admin.setFame(v)),
          step: 10,
        ),
        _Stepper(
          label: '貯蓄（万円）',
          value: state.finances.savings,
          onChanged: (v) => run(() => admin.setSavings(v)),
          step: 1000,
        ),
        _Stepper(
          label: '今季の警告',
          value: state.yellowCards,
          onChanged: (v) => run(() => admin.setYellowCards(v)),
        ),
        _Stepper(
          label: '出場停止',
          value: state.suspension,
          onChanged: (v) => run(() => admin.setSuspension(v)),
        ),
        _Stepper(
          label: '離脱試合',
          value: state.injury?.matchesOut ?? 0,
          onChanged: (v) => run(() => admin.setInjury(v)),
          step: 3,
        ),
        const Divider(height: 32),
        Text('詳細能力', style: theme.textTheme.titleSmall),
        for (final detail in Detail.values)
          _Stepper(
            label: '${detail.label}（${detail.category.label}）',
            value: player.attributes.detail(detail),
            onChanged: (v) => run(() => admin.bumpDetail(
                detail, v - player.attributes.detail(detail))),
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
  const _TimeTab(
      {required this.controller, required this.admin, required this.run});

  final CareerController controller;
  final AdminActions admin;

  /// 操作を前後の「効き」で挟んで走らせる。
  final Future<void> Function(Future<void> Function()) run;

  @override
  State<_TimeTab> createState() => _TimeTabState();
}

class _TimeTabState extends State<_TimeTab> {
  bool _running = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _running = true);
    try {
      await widget.run(action);
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
