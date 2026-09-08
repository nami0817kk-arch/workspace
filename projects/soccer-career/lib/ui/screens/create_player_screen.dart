import 'dart:math';

import 'package:flutter/material.dart';

import 'guide_screen.dart';
import '../../game/career_engine.dart';
import '../../models/agent.dart';
import '../../models/attributes.dart';
import '../../models/physique.dart';
import '../../state/career_controller.dart';
import '../readable_width.dart';

/// キャリアの最初の画面。名前・ポジション・年齢・代理人を決める。
///
/// ポテンシャルと特性はここでは見せない。始めてから分かるのがキャリアもの。
class CreatePlayerScreen extends StatefulWidget {
  const CreatePlayerScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final _name = TextEditingController();
  Position _position = Position.st;
  Side _side = Side.right;
  int _age = 17;
  Foot _foot = Foot.right;
  int _height = Physique.baseHeight;
  int _weight = Physique.baseWeight;
  final Map<AttributeKey, int> _tweaks = {};
  late final List<Agent> _agents = Agent.candidates(Random());
  Agent? _agent;
  bool _busy = false;

  /// 1カテゴリを動かせる幅。
  static const int tweakLimit = 6;

  /// 割り振りの合計。0 でないと始められない（増やしたぶんは削る）。
  int get _tweakSum => _tweaks.values.fold(0, (a, b) => a + b);

  /// そのポジションで意味のあるカテゴリ。GK 能力は GK だけ。
  List<AttributeKey> get _keys => [
        for (final key in AttributeKey.values)
          if (key != AttributeKey.goalkeeping || _position == Position.gk) key,
      ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _agent != null &&
      _tweakSum == 0 &&
      !_busy;

  /// ポジションを変えると、基準値も割り振れる項目も変わる。
  void _selectPosition(Position position) {
    setState(() {
      _position = position;
      _tweaks.clear();
      if (!position.hasSide) _side = Side.center;
      if (position.hasSide && _side == Side.center) {
        _side = _foot == Foot.left ? Side.left : Side.right;
      }
      _height = _defaultHeightFor(position);
      _weight = _weightFor(_height);
    });
  }

  static int _defaultHeightFor(Position position) => switch (position) {
        Position.gk => 189,
        Position.cb => 187,
        Position.st => 182,
        Position.dm => 180,
        Position.cm => 177,
        Position.sb => 176,
        Position.am => 174,
        Position.wg => 173,
      };

  /// 身長なりの体重。スライダーの初期値に使う。
  static int _weightFor(int height) => ((height - 100) * 0.86).round();

  Future<void> _start() async {
    if (!_ready) return;
    setState(() => _busy = true);
    await widget.controller.startCareer(
      name: _name.text.trim(),
      position: _position,
      age: _age,
      agent: _agent!,
      side: _side,
      physique: Physique(
        heightCm: _height,
        weightKg: _weight,
        foot: _foot,
        // 逆足の精度は自分では選べない。始めてから分かるもののひとつ。
        weakFoot: 1 + Random().nextInt(3),
      ),
      tweaks: _tweaks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: ReadableWidth.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('選手キャリア', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '2部の下位クラブから始まる。38試合すべてに出て、'
                    '評価点を積み上げて上を目指す。'
                    'ポテンシャルと特性は、始めてから分かる。',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const GuideScreen()),
                      ),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('遊び方ガイドを読む'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '選手名',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  Text('ポジション', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in Position.values)
                        ChoiceChip(
                          label: Text(p.label),
                          selected: _position == p,
                          onSelected: (_) => _selectPosition(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_position.fullName, style: muted),
                  if (_position.hasSide) ...[
                    const SizedBox(height: 12),
                    Text('立つ側', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      '利き足と同じ側なら、逆足で対応する局面が減る。'
                      '逆サイドは逆足の局面が増える代わりに、'
                      '内へ切り込んで利き足で打てる。',
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final side in [Side.left, Side.right])
                          ChoiceChip(
                            label: Text(side.label),
                            selected: _side == side,
                            onSelected: (_) => setState(() => _side = side),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _side.matches(_foot)
                          ? '${_side.label}サイドの${_foot.label}。'
                              '外を向いたまま蹴れる。'
                          : '${_side.label}サイドの${_foot.label}。'
                              '内へ切り込む形になる。',
                      style: muted,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('年齢  $_age', style: theme.textTheme.labelLarge),
                  Slider(
                    value: _age.toDouble(),
                    min: 16,
                    max: 21,
                    divisions: 5,
                    label: '$_age',
                    onChanged: (v) => setState(() => _age = v.round()),
                  ),
                  Text(
                    _age <= 17
                        ? '育成年代からの出発。一番下の部で、無名のまま始まる。'
                            '伸びしろは長い。'
                        : '若く始めるほど伸びしろは長いが、初期能力は低い。',
                    style: muted,
                  ),
                  const SizedBox(height: 24),
                  Text('身体', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '練習では動かない。高さは競り合いに、体重は当たりの強さと'
                    'キレの入れ替えに効く。',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final foot in [Foot.right, Foot.left])
                        ChoiceChip(
                          label: Text(foot.label),
                          selected: _foot == foot,
                          onSelected: (_) => setState(() {
                            _foot = foot;
                            if (_position.hasSide) {
                              _side = foot == Foot.left ? Side.left : Side.right;
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('身長  $_height cm', style: theme.textTheme.bodyMedium),
                  Slider(
                    value: _height.toDouble(),
                    min: 165,
                    max: 200,
                    divisions: 35,
                    label: '$_height',
                    onChanged: (v) => setState(() => _height = v.round()),
                  ),
                  Text('体重  $_weight kg', style: theme.textTheme.bodyMedium),
                  Slider(
                    value: _weight.toDouble(),
                    min: 58,
                    max: 98,
                    divisions: 40,
                    label: '$_weight',
                    onChanged: (v) => setState(() => _weight = v.round()),
                  ),
                  Text(
                    Physique(heightCm: _height, weightKg: _weight, foot: _foot)
                        .buildLabel,
                    style: muted,
                  ),
                  const SizedBox(height: 24),
                  Text('能力の割り振り', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'ポジションの基準値から、$tweakLimit まで動かせる。'
                    '増やしたぶんはどこかを削る（合計を0にすると始められる）。'
                    'ポテンシャルと特性は、始めてから分かる。',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  for (final key in _keys)
                    _TweakRow(
                      label: key.label,
                      base: CareerEngine.startingBaseFor(_position)[key] ?? 0,
                      value: _tweaks[key] ?? 0,
                      limit: tweakLimit,
                      onChanged: (v) => setState(() => _tweaks[key] = v),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _tweakSum == 0
                        ? '割り振りは釣り合っている。'
                        : '合計 ${_tweakSum > 0 ? '+' : ''}$_tweakSum。'
                            '0にすると始められる。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _tweakSum == 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('代理人', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '契約交渉と移籍先の開拓を任せる。交渉力・人脈・手数料が違う。',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  for (final agent in _agents) ...[
                    _AgentCard(
                      agent: agent,
                      selected: _agent == agent,
                      onTap: () => setState(() => _agent = agent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ready ? _start : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('キャリアを始める'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 能力を1つ、基準値から動かす行。
class _TweakRow extends StatelessWidget {
  const _TweakRow({
    required this.label,
    required this.base,
    required this.value,
    required this.limit,
    required this.onChanged,
  });

  final String label;

  /// ポジションの基準値。動かした結果がいくつになるかを見せる。
  final int base;

  final int value;
  final int limit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > -limit ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${base + value}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < limit ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
          SizedBox(
            width: 34,
            child: Text(
              value == 0 ? '' : '${value > 0 ? '+' : ''}$value',
              style: theme.textTheme.labelMedium?.copyWith(
                color: value > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final Agent agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${agent.name} ・ ${agent.style}',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(agent.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }
}
