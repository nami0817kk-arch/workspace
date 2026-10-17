import 'package:flutter/material.dart';

import '../game/player.dart';
import 'controller.dart';
import 'labels.dart';

/// はじまりの画面: 名前と、打者か投手かを選ぶ。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final name = TextEditingController(text: '');
  Role role = Role.batter;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('野球育成')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('6歳から、プロを引退するまで。', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('1人の選手を育てて、その一生を見届けるゲームです。'),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '選手の名前', border: OutlineInputBorder()),
            maxLength: 10,
          ),
          const SizedBox(height: 8),
          const Text('最初のポジション'),
          const SizedBox(height: 8),
          SegmentedButton<Role>(
            segments: const [
              ButtonSegment(value: Role.batter, label: Text('打者')),
              ButtonSegment(value: Role.pitcher, label: Text('投手')),
            ],
            selected: {role},
            onSelectionChanged: (s) => setState(() => role = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            '二刀流は、プロになってからいつでも選べます。(いまは${roleLabel(role)}から)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => widget.controller.newGame(name.text, role),
            child: const Text('はじめる'),
          ),
        ],
      ),
    );
  }
}
