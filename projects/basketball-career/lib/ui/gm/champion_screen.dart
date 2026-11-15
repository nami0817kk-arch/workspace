import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../sound/sound.dart';
import 'common.dart';
import 'motion.dart';
import 'style.dart';

/// 優勝の祝い(2026-11-15、ユーザー「更に調査」。2K の MyGM を遊ぶ実況者2人が
/// 「優勝してもパレードも場面も無い」と不満を言っていたので、ここで越える)。
/// 紙吹雪の中で優勝の札が出て、ファイナルMVP・勝ち上がりの道・その年の足跡・オーナーの言葉を順に見せる。
/// 動きは約4.5秒で止まる(繰り返さない)。
class ChampionScreen extends StatefulWidget {
  const ChampionScreen({super.key, required this.car});
  final Career car;

  @override
  State<ChampionScreen> createState() => _ChampionScreenState();
}

class _ChampionScreenState extends State<ChampionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));

  @override
  void initState() {
    super.initState();
    Sfx.play(SoundEffect.cheer);
    _a.forward();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// 全体の時間のうち [from]〜[to] の区間で 0→1。
  double _seg(double from, double to) => Curves.easeOutCubic.transform(((_a.value - from) / (to - from)).clamp(0.0, 1.0));

  Widget _fade(double from, Widget child) => AnimatedBuilder(
    animation: _a,
    builder: (context, c) {
      final t = _seg(from, from + 0.12);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c),
      );
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final me = car.me;
    final f = car.finals;
    final mvp = car.awardsOf(car.season).where((a) => a.kind == AwardKind.finalsMvp).firstOrNull;
    final path = [for (final s in car.playoffs) if (s.high == car.mine || s.low == car.mine) s]..sort((a, b) => a.round.compareTo(b.round));
    final titles = car.champs.where((c) => c[1] == car.mine).length;
    final drafted = [for (final p in me.order.take(9)) if (car.draftedIds.contains(p.id)) p];
    final words = switch (car.ownerType) {
      OwnerType.winNow => '「これを待っていた。来年も、その次も、頂点に立とう」',
      OwnerType.steady => '「勝って、しかも帳簿も健全だ。理想の球団になった」',
      OwnerType.youth => '「若い力で勝ち取った優勝だ。この先が楽しみでならない」',
      OwnerType.popular => '「街じゅうが沸いている。チケットはもう来季まで売り切れだ」',
    };
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 0.45, child: Image.asset('assets/art/scene_final.jpg', fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0xEE0B1020)]),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) => CustomPaint(painter: _Confetti(_a.value, seed: car.season * 31 + car.mine)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左: 優勝の札とファイナルMVP
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PopIn(ms: 1200, child: TeamBadge(team: car.mine, size: 96)),
                        const SizedBox(height: 6),
                        _fade(
                          0.1,
                          Text(
                            '${car.season}年目 優勝',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: GmColors.gold, letterSpacing: 2),
                          ),
                        ),
                        _fade(
                          0.15,
                          Text(
                            '${me.name}${titles > 1 ? '・任期で$titles回目' : ''}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (f != null)
                          _fade(
                            0.2,
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ファイナル ${math.max(f.highWins, f.lowWins)}勝${math.min(f.highWins, f.lowWins)}敗 ${car.teams[f.loser].name}を破る',
                                style: const TextStyle(fontSize: 12, color: GmColors.sub),
                              ),
                            ),
                          ),
                        if (mvp != null)
                          _fade(
                            0.32,
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: GmColors.panel.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: GmColors.gold),
                              ),
                              child: Column(
                                children: [
                                  const Text('ファイナルMVP', style: TextStyle(fontSize: 11, color: GmColors.gold, fontWeight: FontWeight.bold)),
                                  Text(mvp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  Text(mvp.line, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 右: 勝ち上がりの道・その年の足跡・オーナーの言葉
                  Expanded(
                    flex: 6,
                    child: ListView(
                      children: [
                        _fade(0.4, const Text('勝ち上がりの道', style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball))),
                        for (final (i, s) in path.indexed)
                          _fade(
                            0.45 + i * 0.06,
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(width: 64, child: Text(s.label, style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                                  TeamBadge(team: s.high == car.mine ? s.low : s.high, size: 20),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      car.teams[s.high == car.mine ? s.low : s.high].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    s.need == 1 ? '勝ち' : '${math.max(s.highWins, s.lowWins)}-${math.min(s.highWins, s.lowWins)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.good),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        _fade(0.72, const Text('この年の足跡', style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball))),
                        _fade(
                          0.75,
                          Text(
                            [
                              'レギュラーシーズン ${record(me)}(${me.east ? '東' : '西'}地区${car.confRank}位)',
                              if (car.tradesDone > 0) 'この任期のトレード ${car.tradesDone}回',
                              if (drafted.isNotEmpty) '自分で指名した主力: ${drafted.map((p) => p.name).join('・')}',
                            ].join('\n'),
                            style: const TextStyle(fontSize: 12, height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _fade(0.85, Text('オーナー(${car.ownerType.label})', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball))),
                        _fade(0.88, Text(words, style: const TextStyle(fontSize: 13, height: 1.5))),
                        const SizedBox(height: 14),
                        _fade(
                          0.9,
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('祝勝会を終える'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 紙吹雪。種から位置と色を決め、[t](0→1)で落ちる。最後は消える。
class _Confetti extends CustomPainter {
  _Confetti(this.t, {required this.seed});
  final double t;
  final int seed;

  static const _colors = [GmColors.gold, GmColors.ball, Colors.white, Color(0xFF8FD3FF), GmColors.good];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final r = math.Random(seed);
    final fade = t > 0.8 ? (1 - t) / 0.2 : 1.0;
    for (var i = 0; i < 90; i++) {
      final x0 = r.nextDouble() * size.width;
      final delay = r.nextDouble() * 0.35;
      final speed = 0.8 + r.nextDouble() * 0.7;
      final sway = 10 + r.nextDouble() * 24;
      final spin = r.nextDouble() * 12;
      final c = _colors[r.nextInt(_colors.length)];
      final k = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final y = -20 + k * speed * (size.height + 40);
      final x = x0 + math.sin(k * 9 + i) * sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(k * spin);
      canvas.drawRect(const Rect.fromLTWH(-3, -5, 6, 10), Paint()..color = c.withValues(alpha: 0.9 * fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
