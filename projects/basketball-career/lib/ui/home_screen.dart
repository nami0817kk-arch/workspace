import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import 'controller.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// はじめの画面。名前を決めて、6歳から始める。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  Difficulty _difficulty = Difficulty.normal;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(Icons.sports_basketball, size: 72, color: cs.primary),
                const SizedBox(height: 12),
                Text('バスケ育成',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  '6歳から、ひとりの選手を育てる。\nミニバス、中学、高校、そして進路。\n身長と才能と運が、行き先を決める。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _name,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: '選手の名前',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in Difficulty.values)
                      ChoiceChip(
                        label: Text(d.label),
                        selected: _difficulty == d,
                        onSelected: (_) => setState(() => _difficulty = d),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(_difficulty.description,
                      style: const TextStyle(fontSize: 12)),
                ),
                FilledButton(
                  onPressed: () =>
                      widget.controller.newGame(_name.text, _difficulty),
                  child: const Text('6歳から始める'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          HistoryScreen(controller: widget.controller))),
                  child: Text(
                      '殿堂・実績(${widget.controller.history.length}人)'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          SettingsScreen(money: widget.controller.money))),
                  child: const Text('設定(広告を消す・プライバシー)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
