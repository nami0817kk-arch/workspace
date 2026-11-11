import 'package:flutter/material.dart';

import '../../gm/difficulty.dart';
import '../../gm/profile.dart';
import '../art/title_art.dart';
import '../gm_controller.dart';
import '../howto_screen.dart';
import '../layout.dart';
import '../settings_screen.dart';
import 'style.dart';
import 'team_pick_screen.dart';

/// アプリの名前(ホーム画面とタイトル)。
const appTitle = 'バスケGM';

/// ストアの名前("バスケGM：球団を勝たせろ")。
const appFullName = 'バスケGM：球団を勝たせろ';

/// タイトルの画面(横画面)。左に絵と「続きから」「GMに就任する」、右に記録・実績・遊び方・設定。
class GmHomeScreen extends StatelessWidget {
  const GmHomeScreen({super.key, required this.c});
  final GmController c;

  Future<void> _start(BuildContext context) async {
    final car = c.career;
    if (car != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新しく任される?'),
          content: const Text('いまの任期の続きは消える。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('消して始める')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final seed = c.newSeed();
    final pick = await Navigator.of(context).push<(int, Difficulty)>(MaterialPageRoute(builder: (_) => TeamPickScreen(seed: seed)));
    if (pick == null || !context.mounted) return;
    final (team, difficulty) = pick;
    if (!c.howtoSeen) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => HowToScreen(onStart: () => Navigator.pop(ctx))));
      await c.markHowtoSeen();
    }
    c.newCareer(team, seed: seed, difficulty: difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final p = c.profile;
    final car = c.career;
    final left = Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(children: [
        const TitleArt(height: 190),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Column(children: [
            Text(appTitle,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10)],
                )),
            Text('球団を勝たせろ',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)],
                )),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      if (car != null) ...[
        FilledButton.icon(
          onPressed: c.resume,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('続きから(${car.season}年目・${car.me.def.short})', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 8),
      ],
      (car == null ? FilledButton.icon : OutlinedButton.icon)(
        onPressed: () => _start(context),
        icon: const Icon(Icons.badge_rounded),
        label: const Text('GMに就任する'),
      ),
    ]);
    final right = ListView(
      padding: EdgeInsets.zero,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('これまでの記録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(spacing: 18, runSpacing: 6, children: [
                _stat('任期', '${p.careers}回'),
                _stat('優勝', '${p.titles}回'),
                _stat('1任期の最多優勝', '${p.bestTitles}回'),
                _stat('最多勝', '${p.bestWins}勝'),
                _stat('最高の格', p.bestLevel == 0 ? '-' : 'Lv${p.bestLevel}'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('実績 ${p.done.length}/${Achievement.values.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              for (final a in Achievement.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(p.has(a) ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                        size: 18, color: p.has(a) ? GmColors.gold : GmColors.sub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: a.title, style: TextStyle(fontWeight: FontWeight.bold, color: p.has(a) ? null : GmColors.sub)),
                        TextSpan(text: '  ${a.text}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                      ])),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HowToScreen())),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('遊び方'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(money: c.money))),
              icon: const Icon(Icons.settings_rounded),
              label: const Text('設定'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 820)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 5, child: left),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: right),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]);
}
