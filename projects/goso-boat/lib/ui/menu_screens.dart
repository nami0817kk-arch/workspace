import 'package:flutter/material.dart';

import '../app/progress.dart';
import '../engine/puzzle.dart';
import '../engine/rules.dart';
import 'figures.dart';
import 'game_screen.dart';
import 'palette.dart';

Route<void> _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

/// はじめの画面。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.skyTop, Palette.sky, Palette.river]),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: progress,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const Text('護送ボート', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Palette.ink, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('囚人を向こう岸へ。逃がすな。', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.dim)),
                    const Spacer(),
                    const _TitleArt(),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Palette.gold, size: 26),
                        Text(' ${progress.totalStars} / ${progress.maxStars}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.ink)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ChunkyButton(
                        label: progress.totalStars == 0 ? 'はじめる' : 'つづきから（${progress.nextLevel.id}）',
                        color: Palette.gold,
                        shadow: Palette.goldDeep,
                        fontSize: 22,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: () => Navigator.of(context).push(_fade(GameScreen(level: progress.nextLevel, progress: progress))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ChunkyButton(
                        label: 'ステージを選ぶ',
                        fontSize: 17,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onPressed: () => Navigator.of(context).push(_fade(StageSelectScreen(progress: progress))),
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _TitleArt extends StatelessWidget {
  const _TitleArt();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Positioned(bottom: 0, width: 210, height: 40, child: CustomPaint(painter: BoatPainter())),
            Positioned(
              bottom: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in [Role.police, Role.prisoner, Role.chief, Role.boss])
                    SizedBox(width: 48, height: 60, child: Figure(role: r)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 舞台ごとに10面を並べる。
class StageSelectScreen extends StatelessWidget {
  const StageSelectScreen({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Palette.sky,
        appBar: AppBar(
          backgroundColor: Palette.sky,
          foregroundColor: Palette.ink,
          elevation: 0,
          title: const Text('ステージ', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListenableBuilder(
          listenable: progress,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final w in worlds) _WorldCard(world: w, progress: progress),
            ],
          ),
        ),
      );
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world, required this.progress});
  final WorldInfo world;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final ls = progress.levels.where((l) => l.world == world.no).toList();
    final got = ls.fold(0, (s, l) => s + progress.stars(l));
    final open = progress.unlocked(ls.first);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: open ? Palette.card : Palette.card.withValues(alpha: 0.6),
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (world.intro?.role != null)
                SizedBox(width: 30, height: 38, child: Figure(role: world.intro!.role!)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${world.no}. ${world.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.ink)),
              ),
              const Icon(Icons.star_rounded, color: Palette.gold, size: 18),
              Text(' $got/${ls.length * 3}', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [for (final l in ls) _LevelTile(level: l, progress: progress)],
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.progress});
  final Level level;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final open = progress.unlocked(level);
    final stars = progress.stars(level);
    final current = open && stars == 0;
    return Semantics(
      button: true,
      enabled: open,
      label: '${level.id}${open ? '' : '、まだ遊べない'}${stars > 0 ? '、星$stars' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open ? () => Navigator.of(context).push(_fade(GameScreen(level: level, progress: progress))) : null,
        child: Container(
          decoration: BoxDecoration(
            color: current ? Palette.gold : open ? Colors.white : const Color(0xFFE3E8EE),
            border: Border.all(color: Palette.ink, width: 2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: open ? const [BoxShadow(color: Palette.ink, offset: Offset(0, 2))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              open
                  ? Text(level.id.split('-').last, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.ink))
                  : const Icon(Icons.lock_rounded, size: 18, color: Palette.dim),
              const SizedBox(height: 2),
              StarRow(stars, size: 11),
            ],
          ),
        ),
      ),
    );
  }
}
