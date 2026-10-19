import 'dart:math';

import 'package:flutter/material.dart';

import '../game/calendar.dart';
import '../game/career.dart';
import '../game/difficulty.dart';
import '../game/marks.dart';
import '../game/player.dart';
import 'art/avatar.dart';
import 'art/scene.dart';
import '../game/achievements.dart';
import 'achievements_screen.dart';
import 'controller.dart';
import 'game_screen.dart' show contentMaxWidth;
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

  /// 二世として始めるときの親(殿堂の、結婚した選手)。なければ ふつうに始める。
  HistoryEntry? heir;

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

  /// 二世の親にできる、殿堂の選手(結婚して引退した選手)。
  List<HistoryEntry> get _heirCandidates => [
        for (final e in widget.controller.history)
          if (e.snapshot != null && e.snapshot!.married) e
      ];

  int _tipShift = 0;
  bool _byScore = false;

  List<HistoryEntry> get _sortedHistory {
    final h = [...widget.controller.history];
    if (_byScore) h.sort((a, b) => b.peakOverall.compareTo(a.peakOverall));
    return h;
  }

  Future<void> _confirmDelete(BuildContext context, HistoryEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${e.name}を殿堂から消しますか?'),
        content: const Text('この選手の記録が消えます。元には戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              key: const Key('history-delete-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('消す')),
        ],
      ),
    );
    if (ok == true) widget.controller.deleteHistory(e);
  }

  void _start() =>
      widget.controller.newGame(name.text, role, difficulty, heir?.snapshot);

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
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentMaxWidth),
              child: ListView(
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
                    key: const Key('name-field'),
                    controller: name,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _start(),
                    decoration: InputDecoration(
                      labelText: '選手の名前',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const Key('random-name'),
                        tooltip: '名前をおまかせ',
                        icon: const Icon(Icons.casino),
                        onPressed: () =>
                            setState(() => name.text = randomNameOf(Random())),
                      ),
                    ),
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
                    onSelectionChanged: (s) =>
                        setState(() => difficulty = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(difficulty.description,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_heirCandidates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('二世として始める'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<HistoryEntry?>(
                      key: const Key('heir-select'),
                      initialValue: heir,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem<HistoryEntry?>(
                            value: null, child: Text('ふつうに始める')),
                        for (final e in _heirCandidates)
                          DropdownMenuItem<HistoryEntry?>(
                              value: e,
                              child: Text('${e.name}(${e.title})の子',
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => heir = v),
                    ),
                    const SizedBox(height: 4),
                    Text('親の素質を受け継ぎ、良い特性をもらえることがあります。',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('start'),
                    onPressed: _start,
                    child: const Text('はじめる'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    key: const Key('daily-tip'),
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb_outline,
                          color: Color(0xFFF9A825)),
                      title: const Text('今日のヒント'),
                      subtitle: Text(
                          tipOf(DateTime.now().add(Duration(days: _tipShift)))),
                      trailing: const Icon(Icons.refresh),
                      onTap: () => setState(() => _tipShift++),
                    ),
                  ),
                  if (widget.controller.history.isNotEmpty) ...[
                    _LifeStats(history: widget.controller.history),
                    _TitleBook(history: widget.controller.history),
                  ],
                  Card(
                    child: ListTile(
                      key: const Key('achievements-open'),
                      leading: const Icon(Icons.military_tech,
                          color: Color(0xFFE53935)),
                      title: const Text('実績'),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${widget.controller.unlocked.length} / ${achievements.length} 解除'),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              key: const Key('achievements-progress'),
                              value: widget.controller.unlocked.length /
                                  achievements.length,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ]),
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
                    Row(children: [
                      Expanded(
                        child: Text('殿堂(これまでの選手)',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (widget.controller.history.length >= 2)
                        SegmentedButton<bool>(
                          key: const Key('history-sort'),
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(value: false, label: Text('新しい順')),
                            ButtonSegment(value: true, label: Text('評価順')),
                          ],
                          selected: {_byScore},
                          onSelectionChanged: (s) =>
                              setState(() => _byScore = s.first),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    for (final h in _sortedHistory)
                      _HistoryTile(
                          entry: h, onDelete: () => _confirmDelete(context, h)),
                  ],
                ],
              ))),
    );
  }
}

/// 殿堂の通算(これまでの人生の合計)。
class _LifeStats extends StatelessWidget {
  const _LifeStats({required this.history});
  final List<HistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final pros = history.where((h) => h.madePro).length;
    final best =
        history.fold<int>(0, (a, h) => h.peakOverall > a ? h.peakOverall : a);
    final titles = history.fold<int>(0, (a, h) => a + h.championships);
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('life-stats'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('これまでの通算', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 18, runSpacing: 6, children: [
              Text('育てた選手 ${history.length}人'),
              Text('プロ入り $pros人(${(pros * 100 / history.length).round()}%)'),
              Text('最高の総合評価 $best'),
              Text('優勝 合計$titles回'),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 称号の図鑑。手に入れた称号は色がつく。
class _TitleBook extends StatelessWidget {
  const _TitleBook({required this.history});
  final List<HistoryEntry> history;

  static const all = ['レジェンド', '一流選手', 'レギュラー', '無名の選手', 'プロにはなれなかった'];

  @override
  Widget build(BuildContext context) {
    final got = {for (final h in history) h.title};
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('title-book'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('称号図鑑 (${all.where(got.contains).length}/${all.length})',
                style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final a in all)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(got.contains(a) ? a : '???'),
                  backgroundColor: got.contains(a)
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : null,
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, this.onDelete});
  final HistoryEntry entry;

  /// 長押しで、殿堂から消す。
  final VoidCallback? onDelete;

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
        onLongPress: onDelete,
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
          '・プロになったら二刀流にいつでも挑戦できます(伸びは0.6倍、年俸と人気は上がる)。\n'
          '・夏の大会(プロは10月のシーズン終了)のあとに、成績が記録されます。右上のグラフのボタンで、成績表を見られます。\n'
          '・右上の人型ボタンで選手情報(プロフィール・成績・経歴)を、歯車で設定(管理者モードなど)を開けます。殿堂の選手をタップすると、過去の選手の情報も見られます。\n'
          '・毎年「今年の目標」が出ます。達成すると経験点と気持ちがもらえます。\n'
          '・プロは長いので、「おすすめで年末まで進める」で1年を一気に進められます(出来事や節目では止まります)。\n'
          '・12歳・15歳・18歳(U-12・U-15・U-18)、大学・社会人の21歳(U-23)、プロは22歳から4年おきに「世界大会」があります。実力があると日本代表に選ばれ、世界一を目指します。\n'
          '・中学・高校・進路の最初の年と、プロの毎年のはじめに、ポジションを決められます。ポジションごとに必要な能力が違い、適性はランクで見えます。適性の低い所を選ぶとチーム力が下がります。\n'
          '・特性は27種類。打者・投手向けのものは、その役割の選手にだけつきます。成績の「指標」(OPS+・WHIPなど)は、項目をタップすると意味が出ます。\n'
          '・同じ能力を重点に練習を続けると、経験点が少し増え、ときどき「開眼」します。重点を変えると連続は戻ります。\n'
          '・プロでは、シーズン中の成績で月間MVPやオールスターに選ばれ、年の終わりに新人王・ベストナインなどの表彰があります。8年目からは一度だけ「FA権」で移籍を決められます。\n'
          '・一生を通した達成は「実績」に残ります。ホームの実績カードから見られます。\n'
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
