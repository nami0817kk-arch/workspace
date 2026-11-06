import 'package:flutter/material.dart';

import '../../deck/cards.dart';
import '../../deck/opponents.dart';
import '../../deck/profile.dart';
import '../art/title_art.dart';
import '../deck_controller.dart';
import '../howto_screen.dart';
import '../layout.dart';
import '../settings_screen.dart';
import 'card_view.dart';
import 'style.dart';

/// はじめの画面。新しいシーズン・続きから・実績・図鑑・遊び方・設定。
class DeckHomeScreen extends StatefulWidget {
  const DeckHomeScreen({super.key, required this.c});
  final DeckController c;

  @override
  State<DeckHomeScreen> createState() => _DeckHomeScreenState();
}

class _DeckHomeScreenState extends State<DeckHomeScreen> {
  late int _difficulty = widget.c.profile.maxUnlockedDifficulty;

  Future<void> _start() async {
    final c = widget.c;
    if (!c.howtoSeen) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (ctx) => HowToScreen(onStart: () => Navigator.pop(ctx)),
      ));
      await c.markHowtoSeen();
    }
    c.newRun(difficulty: _difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final p = c.profile;
    final maxD = p.maxUnlockedDifficulty;
    if (_difficulty > maxD) _difficulty = maxD;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Stack(
                  children: [
                    const TitleArt(height: 210),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: Column(children: [
                        Text('バスケデッキ',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10)],
                            )),
                        Text('カードで勝ち抜く、バスケの1シーズン',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)],
                            )),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (maxD > 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Row(children: [
                        const Icon(Icons.local_fire_department_rounded, color: DeckColors.bad),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('難しさ $_difficulty${_difficulty >= 3 ? '(気持ち2で始まる)' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          tooltip: '難しさを下げる',
                          onPressed: _difficulty > 0 ? () => setState(() => _difficulty--) : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        IconButton(
                          tooltip: '難しさを上げる',
                          onPressed: _difficulty < maxD ? () => setState(() => _difficulty++) : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (c.run != null) ...[
                  FilledButton.icon(
                    onPressed: c.resume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('続きから(${c.run!.stageName})'),
                  ),
                  const SizedBox(height: 10),
                ],
                (c.run == null ? FilledButton.icon : OutlinedButton.icon)(
                  onPressed: () async {
                    if (c.run != null) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('新しいシーズンを始める?'),
                          content: const Text('いまのシーズンの続きは消える。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('始める')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                    }
                    await _start();
                  },
                  icon: const Icon(Icons.sports_basketball_rounded),
                  label: const Text('新しいシーズン'),
                ),
                const SizedBox(height: 18),
                _Records(profile: p),
                const SizedBox(height: 12),
                _MenuTile(
                  icon: Icons.military_tech_rounded,
                  title: '実績',
                  subtitle: '${p.unlocked.length}/${allAchievements.length}',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => AchievementsScreen(profile: p))),
                ),
                _MenuTile(
                  icon: Icons.style_rounded,
                  title: 'カード図鑑',
                  subtitle: '${p.seenCards.where(cardById.containsKey).length}/${rewardPool().length + 4}',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => CollectionScreen(profile: p))),
                ),
                _MenuTile(
                  icon: Icons.help_outline_rounded,
                  title: '遊び方',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HowToScreen())),
                ),
                _MenuTile(
                  icon: Icons.settings_rounded,
                  title: '設定',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(money: c.money))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final best = p.bestStage >= 3 ? '日本一' : stageNames[p.bestStage];
    Widget cell(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11, color: DeckColors.sub)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          cell('シーズン', '${p.seasons}'),
          cell('日本一', '${p.championships}'),
          cell('最高到達', p.seasons == 0 ? '-' : best),
          cell('最多得点', '${p.bestScore}'),
        ]),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: Icon(icon, color: DeckColors.ball),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: DeckColors.sub)),
              const Icon(Icons.chevron_right_rounded),
            ]),
            onTap: onTap,
          ),
        ),
      );
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('実績')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final a in allAchievements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            profile.unlocked.contains(a.id) ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                            color: profile.unlocked.contains(a.id) ? DeckColors.gold : DeckColors.line,
                          ),
                          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text([a.text, if (a.rewardText.isNotEmpty) a.rewardText].join('\n')),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cards = allCards.where((c) => c.rarity != Rarity.status).toList();
    final locked = profile.lockedCards;
    return Scaffold(
      appBar: AppBar(title: const Text('カード図鑑')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: LayoutBuilder(builder: (context, box) {
              final cols = (box.maxWidth / 120).floor().clamp(3, 8);
              final w = (box.maxWidth - 32 - (cols - 1) * 8) / cols;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in cards)
                      locked.contains(d.id)
                          ? SizedBox(
                              width: w,
                              height: w * CardView.aspect,
                              child: const Card(
                                child: Center(child: Icon(Icons.lock_outline_rounded, color: DeckColors.line)),
                              ),
                            )
                          : CardView(
                              card: CardInstance(d),
                              width: w,
                              enabled: profile.seenCards.contains(d.id) || d.rarity == Rarity.starter,
                              onTap: () => showCardDetail(context, CardInstance(d)),
                            ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
