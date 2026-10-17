import 'package:flutter/material.dart';

import '../game/player.dart';
import 'controller.dart';
import 'history.dart';
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
      appBar: AppBar(
        title: const Text('野球育成'),
        actions: [
          IconButton(
            key: const Key('help'),
            tooltip: 'あそびかた',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHelp(context),
          ),
        ],
      ),
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
          if (widget.controller.history.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('殿堂(これまでの選手)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final h in widget.controller.history) _HistoryTile(entry: h),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final tags = [
      roleLabel(e.role),
      if (e.madePro) 'プロ${e.proYears}年' else 'プロ入りならず',
      if (e.championships > 0) '優勝${e.championships}回',
      if (e.wasTwoWay) '二刀流',
      if (e.married) '結婚',
    ];
    return Card(
      child: ListTile(
        dense: true,
        title: Text('${e.name}  ―  ${e.title}'),
        subtitle: Text('${tags.join(' / ')}   最高評価 ${e.peakOverall}'),
      ),
    );
  }
}

/// あそびかた。
Future<void> showHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('あそびかた'),
      content: const SingleChildScrollView(
        child: Text(
          '6歳から、プロを引退するまでを育てます。\n\n'
          '・季節(高校とプロは月)ごとに、練習・休養などを選びます。\n'
          '・練習すると「経験点」が貯まります。好きな能力に振り分けて強くします。\n'
          '・体力が減ると怪我しやすくなります。休養や交流で回復しましょう。\n'
          '・やる気が高いほど、経験点がたくさん貯まります。\n'
          '・仲間と組むと友情タッグ練習、コーチに教わると特性を習得できます。\n'
          '・夏の大会の成績がドラフトの評価になります。高校卒業時に指名されなければ、大学か社会人で1度だけ再挑戦できます。\n'
          '・プロになったら二刀流にいつでも挑戦できます(伸びは0.6倍)。\n'
          '・引退までの一生が、あなたの選手の物語です。',
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
    ),
  );
}
