import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/profile.dart';
import '../art/title_art.dart';
import '../gm_controller.dart';
import '../howto_screen.dart';
import '../layout.dart';
import '../settings_screen.dart';
import 'hub_screen.dart';
import 'style.dart';

/// アプリの名前(ホーム画面とタイトル)。
const appTitle = 'バスケ編成室';

/// はじめの画面。新しく任される・続きから・記録と実績・遊び方・設定。
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
    final s = await showModalBottomSheet<Scenario>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('どのチームを任される?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('どれも${teamDefs[Career.mine].city}・${teamDefs[Career.mine].nick}のGM。チームの状態が違う。', style: const TextStyle(color: GmColors.sub)),
            const SizedBox(height: 10),
            for (final s in Scenario.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(s.text, style: const TextStyle(height: 1.4)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(ctx, s),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (s == null || !context.mounted) return;
    if (!c.howtoSeen) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => HowToScreen(onStart: () => Navigator.pop(ctx))));
      await c.markHowtoSeen();
    }
    c.newCareer(s);
  }

  @override
  Widget build(BuildContext context) {
    final p = c.profile;
    final car = c.career;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Stack(children: [
                  const TitleArt(height: 210),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Column(children: [
                      Text(appTitle,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10)],
                          )),
                      Text('GMとして、トレードとドラフトで頂点へ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)],
                          )),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                if (car != null) ...[
                  FilledButton.icon(
                    onPressed: c.resume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('続きから(${car.season}年目・${phaseLabel(car)})'),
                  ),
                  const SizedBox(height: 10),
                ],
                (car == null ? FilledButton.icon : OutlinedButton.icon)(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.badge_rounded),
                  label: const Text('GMに就任する'),
                ),
                const SizedBox(height: 16),
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
              ],
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
