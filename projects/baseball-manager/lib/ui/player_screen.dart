import 'package:flutter/material.dart';

import '../game/flavor.dart';

import '../game/career.dart';
import '../game/exp.dart';
import '../game/game.dart';
import '../game/life_log.dart';
import '../game/path.dart' show overall;
import '../game/player.dart';
import '../game/snapshot.dart';
import 'art/avatar.dart';
import 'art/radar.dart';
import 'labels.dart';
import 'records_screen.dart';
import 'widgets.dart';

/// 選手情報: プロフィール・成績・経歴。育成中の選手も、殿堂に残った過去の選手も見られる。
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.snapshot,
    this.game,
    this.initialTab = 0,
  });

  final PlayerSnapshot snapshot;

  /// 育成中の選手なら渡す(体力・やる気・まわりの人たちも出す)。
  final Game? game;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(snapshot.name),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('tab-profile'), text: 'プロフィール'),
              Tab(key: Key('tab-records'), text: '成績'),
              Tab(key: Key('tab-career'), text: '経歴'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(snapshot: snapshot, game: game),
            _Scroll(child: RecordsView(snapshot: snapshot)),
            _Scroll(child: _CareerTab(snapshot: snapshot)),
          ],
        ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(12), children: [child]),
      ),
    );
  }
}

/// 総合評価(能力の平均)。二刀流は得意なほう。
double overallOf(PlayerSnapshot s) => overall(Player(
      name: s.name,
      role: s.role,
      age: s.age,
      potential: s.potential,
      abilities: s.abilities,
    ));

/// 素質を星5つで。
String potentialStars(int potential) {
  final n = (potential / 20).ceil().clamp(1, 5);
  return '★' * n + '☆' * (5 - n);
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.snapshot, required this.game});
  final PlayerSnapshot snapshot;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final p = Player(
      name: s.name,
      role: s.role,
      age: s.age,
      potential: s.potential,
      abilities: s.abilities,
      traits: s.traits,
    );
    final ov = overallOf(s).round();
    final proYears = s.records.where((r) => r.stage == Stage.pro).length;
    return _Scroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: PlayerAvatar(
                    stage: s.stage == Stage.retired ? Stage.pro : s.stage,
                    role: s.role,
                    mood: Mood.happy,
                    height: 110,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                          '${s.age}歳  ${s.endingTitle == null ? stageNameOf(s.stage) : '引退'}'),
                      Text(roleNameOf(s.role)),
                      Text(
                          affiliationOf(
                              s.stage == Stage.retired ? Stage.pro : s.stage,
                              s.name,
                              proTeam: s.overseasTeam ?? s.proTeam),
                          key: const Key('profile-affiliation')),
                      Text(
                          playerCardLine(
                              s.stage == Stage.retired ? Stage.pro : s.stage,
                              Player(
                                  name: s.name,
                                  role: s.role,
                                  age: s.age,
                                  potential: s.potential,
                                  abilities: s.abilities),
                              position: s.position),
                          key: const Key('profile-card'),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RankBadge(value: ov),
                            Text('総合評価 $ov',
                                style: Theme.of(context).textTheme.titleSmall),
                          ]),
                      Text('素質 ${potentialStars(s.potential)}',
                          key: const Key('potential-stars')),
                      if (s.endingTitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('称号: ${s.endingTitle}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 22, runSpacing: 10, children: [
                _Fact('年齢', '${s.age}歳'),
                _Fact(
                    'プロ入り', s.proStartAge == null ? 'なし' : '${s.proStartAge}歳'),
                _Fact('プロ年数', '$proYears年'),
                _Fact('記録された年', '${s.records.length}年'),
                _Fact('難しさ', s.difficulty.label),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          _Traits(snapshot: s),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('能力', style: Theme.of(context).textTheme.titleSmall),
                    AbilityRadar(player: p),
                    for (final a in abilitiesOf(s.role))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          RankBadge(value: s.of(a)),
                          const SizedBox(width: 6),
                          SizedBox(
                              width: 60,
                              child: Tooltip(
                                  message: abilityHint(a),
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Text(abilityLabel(a)))),
                          SizedBox(
                              width: 28,
                              child: Text('${s.of(a)}',
                                  textAlign: TextAlign.right)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: s.of(a) / 99,
                              minHeight: 10,
                              color: rankColor(rankOf(s.of(a))),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ]),
                      ),
                  ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            key: const Key('aptitude-card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ポジション適性',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                        '守っているのは「${positionOf(p, s.position)}」。'
                        '適性は、そのポジションに必要な能力から決まります。',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final pos in positionsFor(s.role))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                rankColor(rankOf(aptitudeOf(p, pos))),
                            child: Text(rankOf(aptitudeOf(p, pos)),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          label: Text(pos.label),
                          side: pos == effectivePosition(p, s.position)
                              ? BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2)
                              : null,
                        ),
                    ]),
                  ]),
            ),
          ),
          if (game != null) ...[
            const SizedBox(height: 8),
            _Condition(game: game!),
            const SizedBox(height: 8),
            CastCard(game: game!),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

class _Traits extends StatelessWidget {
  const _Traits({required this.snapshot});
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ts = snapshot.traits.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('特性 (${ts.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (ts.isEmpty) const Text('特性はまだありません。コーチに教わると習得できます。'),
          for (final t in ts)
            ListTile(
              key: Key('trait-${t.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                t.positive ? Icons.auto_awesome : Icons.warning_amber_rounded,
                color: t.positive
                    ? const Color(0xFFF9A825)
                    : const Color(0xFF607D8B),
              ),
              title: Text(t.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(t.description),
            ),
        ]),
      ),
    );
  }
}

class _Condition extends StatelessWidget {
  const _Condition({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = game.condition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('いまの状態', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
              '体力 ${100 - c.fatigue}%   やる気 ${game.motivation.label}${c.injured ? '   怪我で安静中' : ''}'),
          Text('経験点  ${[
            for (final cat in Category.values)
              '${cat.label} ${game.exp.of(cat)}'
          ].join(' / ')}'),
        ]),
      ),
    );
  }
}

/// 経歴: 入学・進路・ドラフト・特性の習得・優勝・タイトル・引退を年表で。
class _CareerTab extends StatelessWidget {
  const _CareerTab({required this.snapshot});
  final PlayerSnapshot snapshot;

  static (IconData, Color) _style(String kind) => switch (kind) {
        'stage' => (Icons.school, const Color(0xFF2E7D32)),
        'route' => (Icons.alt_route, const Color(0xFF5E35B1)),
        'draft' => (Icons.star, const Color(0xFFFB8C00)),
        'trait' => (Icons.auto_awesome, const Color(0xFF7E57C2)),
        'role' => (Icons.swap_horiz, const Color(0xFF00897B)),
        'champion' => (Icons.emoji_events, const Color(0xFFF9A825)),
        'world' => (Icons.public, const Color(0xFFD32F2F)),
        'position' => (Icons.sports_baseball, const Color(0xFF2E7D32)),
        'overseas' => (Icons.flight, const Color(0xFF1E88E5)),
        'title' => (Icons.workspace_premium, const Color(0xFFD4AF37)),
        'retire' => (Icons.flag, const Color(0xFF546E7A)),
        _ => (Icons.circle, const Color(0xFF90A4AE)),
      };

  @override
  Widget build(BuildContext context) {
    final entries = timelineOf(snapshot.events, snapshot.records);
    if (entries.isEmpty) {
      return const Card(
          child:
              Padding(padding: EdgeInsets.all(16), child: Text('まだ経歴がありません。')));
    }
    return Card(
      key: const Key('timeline'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(children: [
          for (var i = 0; i < entries.length; i++)
            _row(context, entries[i],
                first: i == 0, last: i == entries.length - 1),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, TimelineEntry e,
      {required bool first, required bool last}) {
    final (icon, color) = _style(e.kind);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 44,
            child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('${e.age}歳',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Column(children: [
            Expanded(
                flex: 1,
                child: Container(
                    width: 2,
                    color: first
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.outlineVariant)),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            Expanded(
                flex: 3,
                child: Container(
                    width: 2,
                    color: last
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.outlineVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(e.text))),
      ]),
    );
  }
}
