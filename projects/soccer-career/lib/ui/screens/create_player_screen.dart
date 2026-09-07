import 'package:flutter/material.dart';

import '../../models/attributes.dart';
import '../../state/career_controller.dart';

/// キャリアの最初の画面。名前とポジションを決める。
class CreatePlayerScreen extends StatefulWidget {
  const CreatePlayerScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final _name = TextEditingController();
  Position _position = Position.fw;
  int _age = 17;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    await widget.controller
        .startCareer(name: name, position: _position, age: _age);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    '評価点を積み上げて上を目指す。',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '選手名',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _start(),
                  ),
                  const SizedBox(height: 24),
                  Text('ポジション', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<Position>(
                    segments: [
                      for (final p in Position.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_position},
                    onSelectionChanged: (s) =>
                        setState(() => _position = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _position.fullName,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
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
                    '若く始めるほど伸びしろは長いが、初期能力は低い。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed:
                        _name.text.trim().isEmpty || _busy ? null : _start,
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
