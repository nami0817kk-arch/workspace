import 'package:flutter/material.dart' hide Action, Route;

import '../game/game.dart';
import '../game/life.dart';
import '../game/match.dart';
import '../game/player.dart';
import 'art/court.dart';
import 'controller.dart';
import 'history_screen.dart';
import 'labels.dart';

/// 局面(季節 / 進路 / 引退)に合わせて画面を切り替える。
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.player.name}  ${game.player.age}歳'),
        actions: [
          IconButton(
            tooltip: '殿堂・実績',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(controller: controller))),
          ),
          if (game.phase != Phase.retired)
            IconButton(
              tooltip: '最初からやり直す',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _confirmRestart(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch (game.phase) {
              Phase.season => _SeasonView(controller: controller, game: game),
              Phase.event => _EventView(controller: controller, game: game),
              Phase.path => _PathView(controller: controller, game: game),
              Phase.retired => _EndingView(controller: controller, game: game),
            },
          ),
        ),
      ),
    );
  }
}

extension on GameScreen {
  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('最初からやり直しますか?'),
        content: const Text('いまの選手の記録は消えます(殿堂には残りません)。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('やり直す')),
        ],
      ),
    );
    if (ok == true) controller.reset();
  }
}

const _seasonNames = ['春', '夏', '秋', '冬'];

// ── 育成(季節) ──

class _SeasonView extends StatelessWidget {
  const _SeasonView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final g = game;
    final cond = g.condition;
    final summer = g.slot == 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: g),
        const SizedBox(height: 12),
        _PlayerCard(game: g),
        const SizedBox(height: 12),
        if (c.pathMessage != null) ...[
          _Note(text: c.pathMessage!),
          const SizedBox(height: 12),
        ],
        if (c.recent.isNotEmpty) ...[
          _RecentCard(lines: c.recent),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_seasonNames[g.slot]}の過ごし方',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (summer || (g.slot == 3 && g.hasWinterCup))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(summer ? 'この季節に大会がある。' : 'この季節に冬の全国選手権がある。'),
                  ),
                const SizedBox(height: 12),
                const Text('重点にする能力'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final a in Ability.values)
                      ChoiceChip(
                        label: Text(a.label),
                        selected: c.focus == a,
                        onSelected: (_) => c.setFocus(a),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('勝負どころの方針'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('おまかせ'),
                      selected: c.clutchPolicy == null,
                      onSelected: (_) => c.setClutchPolicy(null),
                    ),
                    for (final k in Clutch.values)
                      ChoiceChip(
                        label: Text(k.label),
                        selected: c.clutchPolicy == k,
                        onSelected: (_) => c.setClutchPolicy(k),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final a in Action.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.tonal(
                      onPressed:
                          canChoose(a, cond) ? () => c.act(a) : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(a.description,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: c.autoYear,
                  child: const Text('おすすめで1年進める'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AbilityCard(game: g),
        if (g.canGoAbroad) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: c.goAbroad,
            child: const Text('海外に挑戦する'),
          ),
        ],
        if (g.track == Track.pro) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmRetire(context, c),
            child: const Text('現役を引退する'),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRetire(BuildContext context, GameController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('引退しますか?'),
        content: const Text('この選手の物語は、ここで終わります。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('引退する')),
        ],
      ),
    );
    if (ok == true) c.retire();
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final cond = game.condition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trackLabel(game)}  ${p.position.label}  '
                '${p.heightCm.toStringAsFixed(1)}cm  総合 ${p.overall.round()}'),
            if (p.traits.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in p.traits)
                    Tooltip(
                      message: t.description,
                      child: Chip(
                        label: Text(t.label),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: t.positive
                            ? Colors.orange.shade100
                            : Colors.blueGrey.shade100,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _Meter(label: '疲れ', value: cond.fatigue, bad: true),
            _Meter(label: '気持ち', value: cond.morale),
            if (cond.injured)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('怪我中(あと${cond.injuredTerms}ターン)',
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('能力', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final a in Ability.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 108, child: Text(a.label)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: p.of(a) / abilityCap,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text('${p.of(a)} ${rankOf(p.of(a))}',
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.bad = false});
  final String label;
  final int value;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final warn = bad ? value >= 70 : value < 35;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              color: warn ? Colors.red : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('いまの結果',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(l),
                ),
            ],
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
      );
}

// ── 出来事 ──

class _EventView extends StatelessWidget {
  const _EventView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final e = game.pendingEvent!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: game, height: 110),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.body),
                const SizedBox(height: 16),
                for (var i = 0; i < e.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () => controller.chooseEvent(i),
                      child: Text(e.options[i].label),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (controller.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: controller.recent),
        ],
        const SizedBox(height: 12),
        _PlayerCard(game: game),
        const SizedBox(height: 12),
        _AbilityCard(game: game),
      ],
    );
  }
}

// ── 進路 ──

class _PathView extends StatelessWidget {
  const _PathView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final c = controller;
    final first = !g.secondChance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first ? '卒業、そして進路' : '卒業のとき',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(first
                    ? '高校を卒業する。スカウトは、能力と実績と身長を見ている。'
                    : '最後の挑戦。プロ契約を取れなければ、競技人生はここまで。'),
                const SizedBox(height: 8),
                Text('総合 ${g.player.overall.round()} / '
                    '身長 ${g.player.heightCm.toStringAsFixed(1)}cm / '
                    '実績 ${g.achievement.round()}(${achievementWord(g.achievement)})'),
              ],
            ),
          ),
        ),
        if (g.proRejected) ...[
          const SizedBox(height: 12),
          const _Note(text: 'プロ契約には届かなかった。大学か実業団で力をつけよう。'),
        ],
        const SizedBox(height: 12),
        for (final r in g.availableRoutes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              onPressed: () => c.chooseRoute(r),
              child: Text(r.label),
            ),
          ),
        TextButton(
          onPressed: c.giveUp,
          child: const Text('競技の道を離れる'),
        ),
      ],
    );
  }
}

// ── エンディング ──

class _EndingView extends StatelessWidget {
  const _EndingView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final p = g.player;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: g, height: 120),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.name}の物語',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${p.age}歳。${g.retiredReason ?? '現役を退いた'}。'),
                const SizedBox(height: 8),
                Text(_epilogue(g)),
                const Divider(height: 24),
                Text('最終身長 ${p.heightCm.toStringAsFixed(1)}cm / '
                    'ポジション ${p.position.label} / 総合 ${p.overall.round()}'),
                Text('通算 ${g.totalGames}試合 平均${g.careerPpg.toStringAsFixed(1)}得点'
                    ' / 優勝 ${g.titles}回'),
                if (g.abroad) const Text('海外プロでプレーした。'),
                if (p.traits.isNotEmpty)
                  Text('特性: ${p.traits.map((t) => t.label).join('・')}'),
              ],
            ),
          ),
        ),
        if (controller.newlyUnlocked.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('実績解除!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final a in controller.newlyUnlocked)
                    Text('${a.title}: ${a.description}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('年ごとの成績',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (final r in g.records)
                  Text('${r.age}歳 ${leagueLabel(r.league)}${r.winter ? '(冬)' : ''} '
                      '${r.wins}勝${r.games - r.wins}敗'
                      '${r.champion ? ' 優勝' : ''}  '
                      '${r.ppg.toStringAsFixed(1)}点 '
                      '${r.rpg.toStringAsFixed(1)}R '
                      '${r.apg.toStringAsFixed(1)}A'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.reset,
          child: const Text('新しい選手を育てる'),
        ),
      ],
    );
  }

  /// 結末の一文。到達点で決める。
  String _epilogue(Game g) {
    if (g.abroad && g.titles > 0) return '世界の舞台で戦い、勝ち取った栄光。語り継がれる選手になった。';
    if (g.abroad) return '海を渡り、世界最高峰に挑んだ。その経験は消えない。';
    if (g.track == Track.pro) {
      return g.titles > 0
          ? 'プロとして頂点を知った。ファンの記憶に残る選手だった。'
          : 'プロの世界で戦い抜いた。コートに立ち続けた誇りがある。';
    }
    if (g.records.isEmpty) return '大きな舞台には届かなかった。それでも、バスケは好きなままだ。';
    return 'プロの扉は開かなかった。それでも、仲間とコートを駆けた日々は本物だった。';
  }
}
