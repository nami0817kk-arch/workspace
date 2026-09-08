import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/agent.dart';
import '../../models/attributes.dart';
import '../../state/career_controller.dart';

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
  int _age = 17;
  late final List<Agent> _agents = Agent.candidates(Random());
  Agent? _agent;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty && _agent != null && !_busy;

  Future<void> _start() async {
    if (!_ready) return;
    setState(() => _busy = true);
    await widget.controller.startCareer(
      name: _name.text.trim(),
      position: _position,
      age: _age,
      agent: _agent!,
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
              constraints: const BoxConstraints(maxWidth: 460),
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
                  const SizedBox(height: 28),
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
                          onSelected: (_) => setState(() => _position = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_position.fullName, style: muted),
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
                    Text('${agent.name}  ·  ${agent.style}',
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
