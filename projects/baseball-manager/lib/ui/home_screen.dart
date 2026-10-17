import 'package:flutter/material.dart';

import '../game/calendar.dart';
import '../game/career.dart';
import '../game/difficulty.dart';
import '../game/player.dart';
import 'art/avatar.dart';
import 'art/scene.dart';
import '../game/achievements.dart';
import 'achievements_screen.dart';
import 'controller.dart';
import 'history.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
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
  Difficulty difficulty = Difficulty.normal;

  /// タイトルを素早く7回タップすると、管理者モードの入/切が切り替わる。
  void _tapTitle() {
    if (widget.controller.tapTitle()) {
      showAdminToggled(context, widget.controller);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('title'),
          behavior: HitTestBehavior.opaque,
          onTap: _tapTitle,
          child: const Text('野球育成'),
        ),
        actions: [
          IconButton(
            key: const Key('settings-open'),
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: widget.controller),
              ),
            ),
          ),
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
          SceneBanner(
            season: Season.spring,
            stage: Stage.youth,
            role: role,
            mood: Mood.happy,
            label: '6歳',
          ),
          const SizedBox(height: 16),
          Text('6歳から、プロを引退するまで。',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('1人の選手を育てて、その一生を見届けるゲームです。'),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            decoration: const InputDecoration(
                labelText: '選手の名前', border: OutlineInputBorder()),
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
          const SizedBox(height: 16),
          const Text('難しさ'),
          const SizedBox(height: 8),
          SegmentedButton<Difficulty>(
            key: const Key('difficulty'),
            segments: [
              for (final d in Difficulty.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {difficulty},
            onSelectionChanged: (s) => setState(() => difficulty = s.first),
          ),
          const SizedBox(height: 8),
          Text(difficulty.description,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                widget.controller.newGame(name.text, role, difficulty),
            child: const Text('はじめる'),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const Key('achievements-open'),
              leading:
                  const Icon(Icons.military_tech, color: Color(0xFFE53935)),
              title: const Text('実績'),
              subtitle: Text(
                  '${widget.controller.unlocked.length} / ${achievements.length} 解除'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AchievementsScreen(controller: widget.controller),
                ),
              ),
            ),
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
      if (e.snapshot != null && e.snapshot!.difficulty != Difficulty.normal)
        e.snapshot!.difficulty.label,
      if (e.married) '結婚',
    ];
    return Card(
      child: ListTile(
        dense: true,
        title: Text('${e.name}  ―  ${e.title}'),
        subtitle: Text('${tags.join(' / ')}   最高評価 ${e.peakOverall}'
            '${e.summary.isEmpty ? '' : '\n${e.summary}'}'),
        isThreeLine: e.summary.isNotEmpty,
        trailing: e.snapshot == null ? null : const Icon(Icons.chevron_right),
        onTap: e.snapshot == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerScreen(snapshot: e.snapshot!),
                  ),
                ),
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
          '・夏の大会(プロは10月のシーズン終了)のあとに、成績が記録されます。右上のグラフのボタンで、成績表を見られます。\n'
          '・右上の人型ボタンで選手情報(プロフィール・成績・経歴)を、歯車で設定(管理者モードなど)を開けます。殿堂の選手をタップすると、過去の選手の情報も見られます。\n'
          '・引退までの一生が、あなたの選手の物語です。',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))
      ],
    ),
  );
}

/// 管理者モードを切り替えた知らせ。
void showAdminToggled(BuildContext context, GameController c) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('管理者モード: ${c.adminMode ? 'オン' : 'オフ'}')),
  );
}
