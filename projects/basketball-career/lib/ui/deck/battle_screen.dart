import 'package:flutter/material.dart';

import '../../deck/battle.dart';
import '../../deck/cards.dart';
import '../../deck/opponents.dart';
import '../../deck/run.dart';
import '../deck_controller.dart';
import '../layout.dart';
import '../team_colors.dart';
import 'card_view.dart';
import 'style.dart';

/// 試合の画面。上に点数と会場、まん中に相手の予告とこちらの状態、下に手札。
class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final b = run.battle!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: Column(
              children: [
                Scoreboard(battle: b, opponent: run.opponent!),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ArenaView(battle: b, opponent: run.opponent!, stage: run.stage),
                        const SizedBox(height: 10),
                        IntentPanel(battle: b),
                        const SizedBox(height: 8),
                        StatusRow(battle: b),
                        const SizedBox(height: 10),
                        HandView(battle: b, onPlay: c.play),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: b.over
                      ? FilledButton.icon(
                          onPressed: c.finishBattle,
                          icon: Icon(b.won ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
                          label: Text(b.won ? '勝った! 次へ' : '負けた… 次へ'),
                          style: FilledButton.styleFrom(
                              backgroundColor: b.won ? DeckColors.good : DeckColors.bad),
                        )
                      : FilledButton.icon(
                          onPressed: c.endRound,
                          icon: const Icon(Icons.sports_rounded),
                          label: Text(b.isLastRound ? 'ラウンド終了(試合終了)' : 'ラウンド終了'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 点数板。自分の学校・相手・クォーター・ラウンドごとの点。
class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key, required this.battle, required this.opponent});
  final Battle battle;
  final Opponent opponent;

  @override
  Widget build(BuildContext context) {
    final b = battle;
    Widget side(String name, int score, Color color, CrossAxisAlignment a) => Expanded(
          child: Column(
            crossAxisAlignment: a,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              Text('$score',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.bold, height: 1.1, color: DeckColors.text)),
            ],
          ),
        );
    final ours = teamPrefixColors['朝日']!;
    final theirs = opponentColor(opponent.name, ours);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DeckColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              side(homeTeam, b.mine, ours.jersey, CrossAxisAlignment.start),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: b.over ? DeckColors.line : DeckColors.ball, borderRadius: BorderRadius.circular(8)),
                    child: Text(b.over ? '試合終了' : b.periodLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 4),
                  if (!b.over)
                    Text('ラウンド ${b.round + 1}/${b.totalRounds}',
                        style: const TextStyle(fontSize: 11, color: DeckColors.sub)),
                  Text(opponent.tag, style: const TextStyle(fontSize: 11, color: DeckColors.gold)),
                ],
              ),
              side(opponent.name, b.theirs, theirs.jersey, CrossAxisAlignment.end),
            ],
          ),
          if (b.rounds.isNotEmpty) ...[
            const SizedBox(height: 4),
            _QuarterTable(battle: b),
          ],
        ],
      ),
    );
  }
}

class _QuarterTable extends StatelessWidget {
  const _QuarterTable({required this.battle});
  final Battle battle;

  @override
  Widget build(BuildContext context) {
    final r = battle.rounds;
    final cols = <(String, int, int)>[];
    for (var q = 0; q * 2 < r.length && q < 4; q++) {
      final a = r.skip(q * 2).take(2);
      cols.add(('${q + 1}Q', a.fold(0, (s, x) => s + x.mine), a.fold(0, (s, x) => s + x.theirs)));
    }
    for (var i = Battle.regulationRounds; i < r.length; i++) {
      cols.add(('延長', r[i].mine, r[i].theirs));
    }
    const st = TextStyle(fontSize: 11, color: DeckColors.sub);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (label, m, t) in cols)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [
              Text(label, style: st),
              Text('$m-$t', style: st.copyWith(color: DeckColors.text, fontWeight: FontWeight.bold)),
            ]),
          ),
      ],
    );
  }
}

/// 会場の絵と、向かい合う2人の選手。最後に出したカードで姿勢が変わる。
class ArenaView extends StatelessWidget {
  const ArenaView({super.key, required this.battle, required this.opponent, required this.stage, this.height = 96});
  final Battle battle;
  final Opponent opponent;
  final int stage;
  final double height;

  static String sceneFor(int stage, {bool boss = false}) {
    if (boss) return 'assets/art/scene_final.jpg';
    return switch (stage) {
      0 => 'assets/art/scene_high.jpg',
      1 => 'assets/art/scene_university.jpg',
      _ => 'assets/art/scene_national.jpg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ours = teamPrefixColors['朝日']!;
    final theirs = opponentColor(opponent.name, ours);
    final last = battle.events.isEmpty ? null : battle.events.last;
    final lastCard = last == null ? null : allCards.where((c) => last.text.startsWith(c.name)).firstOrNull;
    final pose = switch (lastCard?.kind) {
      CardKind.shot => lastCard!.tag == ShotTag.inside ? 'adult_dunk' : 'adult_shoot',
      CardKind.defense => 'adult_defense',
      _ => 'adult',
    };
    final theirPose = battle.intent.kind == IntentKind.press ? 'adult_defense' : 'adult_shoot';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: DeckColors.panelHi),
            Image.asset(sceneFor(stage, boss: opponent.boss),
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                color: Colors.black.withValues(alpha: 0.25),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Positioned(
              left: 24,
              bottom: 2,
              height: height * 0.92,
              child: Image.asset('assets/art/players/${pose}_${ours.sprite}.png',
                  fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            Positioned(
              right: 24,
              bottom: 2,
              height: height * 0.92,
              child: Transform.flip(
                flipX: true,
                child: Image.asset('assets/art/players/${theirPose}_${theirs.sprite}.png',
                    fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            if (last != null)
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(10)),
                    child: Text(_eventText(last),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _eventText(PlayEvent e) {
    if (e.points < 0) return e.text;
    final parts = [e.text, if (e.points > 0) '+${e.points}点', if (e.guard > 0) '守備+${e.guard}'];
    return parts.join('  ');
  }
}

/// 相手の予告と、守備を引いたあとの見込み。
class IntentPanel extends StatelessWidget {
  const IntentPanel({super.key, required this.battle});
  final Battle battle;

  @override
  Widget build(BuildContext context) {
    final b = battle;
    if (b.over) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            b.won ? '${b.mine}対${b.theirs}で勝った!' : '${b.mine}対${b.theirs}で負けた。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: b.won ? DeckColors.good : DeckColors.bad),
          ),
        ),
      );
    }
    final it = b.intent;
    final proj = b.projectedTheirs;
    return Card(
      color: const Color(0xFF2A1F2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DeckColors.bad.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: DeckColors.bad),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('相手の予告', style: TextStyle(fontSize: 11, color: DeckColors.sub)),
                  Text(it.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (it.kind == IntentKind.drive || it.kind == IntentKind.fast)
                    const Text('チャージングで止められる', style: TextStyle(fontSize: 11, color: DeckColors.sub)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('このままだと', style: TextStyle(fontSize: 11, color: DeckColors.sub)),
                Text(b.stopped ? '止めた' : '-$proj点',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: proj == 0 ? DeckColors.good : DeckColors.bad)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// スタミナ・守備・リズム・次のシュートの上乗せ・山札の枚数。
class StatusRow extends StatelessWidget {
  const StatusRow({super.key, required this.battle});
  final Battle battle;

  @override
  Widget build(BuildContext context) {
    final b = battle;
    Widget chip(IconData icon, String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
          ]),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(Icons.bolt_rounded, 'スタミナ ${b.stamina}', DeckColors.gold),
        chip(Icons.shield_rounded, '守備 ${b.guard}', DeckColors.kind(CardKind.defense)),
        if (b.rhythm > 0) chip(Icons.music_note_rounded, 'リズム +${b.rhythm}', DeckColors.ball),
        if (b.setup > 0) chip(Icons.trending_up_rounded, '次のシュート +${b.setup}', DeckColors.kind(CardKind.play)),
        if (b.passThisRound) chip(Icons.sync_alt_rounded, 'パス済み', DeckColors.kind(CardKind.play)),
        chip(Icons.layers_rounded, '山札 ${b.drawPile.length}・捨て札 ${b.discard.length}', DeckColors.sub),
      ],
    );
  }
}

/// 手札。押すと出す。長押しで説明。
class HandView extends StatelessWidget {
  const HandView({super.key, required this.battle, required this.onPlay});
  final Battle battle;
  final void Function(CardInstance c) onPlay;

  @override
  Widget build(BuildContext context) {
    final b = battle;
    if (b.over) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 600 ? 5 : 3;
      final w = (box.maxWidth - (cols - 1) * 8) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final h in b.hand)
            CardView(
              key: ValueKey(h.uid),
              card: h,
              width: w,
              aspect: CardView.handAspect,
              enabled: b.canPlay(h),
              points: h.def.kind == CardKind.shot || h.stats.points > 0 ? b.pointsOf(h) : null,
              guard: b.guardOf(h),
              onTap: b.canPlay(h) ? () => onPlay(h) : null,
              onLongPress: () => showCardDetail(context, h),
            ),
          if (b.hand.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('手札はもう無い。「ラウンド終了」で相手の攻め。', style: TextStyle(color: DeckColors.sub)),
            ),
        ],
      );
    });
  }
}
