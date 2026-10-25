import 'dart:math';

import 'package:flutter/material.dart';

import '../game/build.dart';
import '../game/dream.dart';
import '../game/game.dart';
import '../game/legacy.dart';
import '../game/traits.dart';
import 'art/title_art.dart';
import 'controller.dart';
import 'history_screen.dart';
import 'style_picker.dart';
import 'howto_screen.dart';
import 'settings_screen.dart';
import 'layout.dart';

/// はじめの画面。名前を決めて、6歳から始める。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  Dream _dream = Dream.pro;

  /// 生まれつきの特性の抽選(種)。「振り直す」で替わる。始めたときの特性は、いま見えているもの。
  int _traitSeed = DateTime.now().microsecondsSinceEpoch;
  Set<Trait> get _traits => rollInnateTraits(Random(_traitSeed));
  Build? _style;

  /// 選んだ背番号。null ならおまかせ。
  int? _number;

  /// はじめて始めるときは、先に遊び方を見せる。
  void _start() {
    final c = widget.controller;
    if (c.howtoSeen) {
      c.newGame(_name.text,
          number: _number, dream: _dream, style: _style, traits: _traits);
      return;
    }
    final name = _name.text;
    final traits = _traits;
    final number = _number;
    final dream = _dream;
    final style = _style;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => HowToScreen(
        onStart: () {
          c.markHowtoSeen();
          Navigator.of(ctx).pop();
          c.newGame(name,
              number: number, dream: dream, style: style, traits: traits);
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
            constraints:
                BoxConstraints(maxWidth: contentMaxWidth(context, phone: 480)),
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
                const SizedBox(height: 8),
                _TraitRoll(
                  traits: _traits,
                  onReroll: () => setState(
                      () => _traitSeed = Random().nextInt(1 << 30)),
                ),
                const SizedBox(height: 8),
                const Text('幼いころの夢(かなうとごほうび)',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final d in Dream.values)
                      ChoiceChip(
                        label: Text(d.label),
                        selected: _dream == d,
                        onSelected: (_) => setState(() => _dream = d),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text('${_dream.goalText}。かなうと全能力 +${Dream.rewardAbilityBonus}',
                      style: const TextStyle(fontSize: 12)),
                ),
                const Text('どんな選手を目指す?(育成中も変えられる)',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                StyleSelector(
                    value: _style,
                    onChanged: (b) => setState(() => _style = b)),
                const SizedBox(height: 8),
                const Text('背番号', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('おまかせ'),
                      selected: _number == null,
                      onSelected: (_) => setState(() => _number = null),
                    ),
                    for (final n in popularNumbers)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: _number == n,
                        onSelected: (_) => setState(() => _number = n),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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

/// 生まれつきの特性のくじ。いまの結果を見せ、気に入らなければ何度でも振り直せる。
class _TraitRoll extends StatelessWidget {
  const _TraitRoll({required this.traits, required this.onReroll});
  final Set<Trait> traits;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('生まれつきの特性(くじ引き)',
                  style: TextStyle(fontSize: 12)),
            ),
            TextButton.icon(
              onPressed: onReroll,
              icon: const Icon(Icons.casino_rounded, size: 18),
              label: const Text('振り直す'),
            ),
          ],
        ),
        if (traits.isEmpty)
          const Text('特性なし(育てるうちに出来事で身につくこともある)。',
              style: TextStyle(fontSize: 12))
        else
          for (final t in traits)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${t.label}: ${t.description}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: t.positive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error)),
            ),
      ],
    );
  }
}
