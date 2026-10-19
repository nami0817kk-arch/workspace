import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import '../game/legacy.dart';
import 'art/title_art.dart';
import 'controller.dart';
import 'history_screen.dart';
import 'howto_screen.dart';
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

  /// はじめて始めるときは、先に遊び方を見せる。
  void _start() {
    final c = widget.controller;
    if (c.howtoSeen) {
      c.newGame(_name.text, _difficulty);
      return;
    }
    final name = _name.text;
    final difficulty = _difficulty;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => HowToScreen(
        onStart: () {
          c.markHowtoSeen();
          Navigator.of(ctx).pop();
          c.newGame(name, difficulty);
        },
      ),
    ));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const TitleArt(),
                const SizedBox(height: 16),
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
                if (legacyBonusFor(widget.controller.unlocked.length) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        '殿堂からの引き継ぎ: 全能力 +${legacyBonusFor(widget.controller.unlocked.length)}(実績 ${widget.controller.unlocked.length}個)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                FilledButton(
                  onPressed: _start,
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
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const HowToScreen())),
                  child: const Text('遊び方'),
                ),
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
