import 'dart:async';

import 'package:flutter/material.dart';

import '../app/progress.dart';
import '../engine/puzzle.dart';
import '../engine/rules.dart';
import '../l10n/l10n_ext.dart';
import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';
import 'figures.dart';
import 'game_screen.dart';
import 'palette.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

/// 面の札の2度押しよけ（同じ画面が2枚積まれないように）。押してから少しの間は受け付けない。
bool _tileCooling = false;
bool _tapOk() {
  if (_tileCooling) return false;
  _tileCooling = true;
  Timer(const Duration(milliseconds: 600), () => _tileCooling = false);
  return true;
}

Route<void> _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

/// はじめの画面。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.progress, required this.money});
  final Progress progress;
  final Monetization money;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.skyTop, Palette.sky, Palette.river]),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: progress,
              builder: (context, _) => LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(children: [
                      IconButton(
                        tooltip: context.l10n.records,
                        icon: const Icon(Icons.emoji_events_rounded, color: Palette.ink),
                        onPressed: () => Navigator.of(context).push(_fade(RecordsScreen(progress: progress))),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.l10n.settingsTitle,
                        icon: const Icon(Icons.settings_rounded, color: Palette.ink),
                        onPressed: () => Navigator.of(context).push(_fade(SettingsScreen(progress: progress, money: money))),
                      ),
                    ]),
                    const Spacer(flex: 2),
                    // 名前は合わせ技（2026-09-27 ユーザー決定）: ストアの検索は「脱獄させるな！」で拾い、
                    // ホーム画面とアプリの中では「護送ボート」で覚えてもらう
                    Transform.rotate(
                      angle: -0.04,
                      child: Text(context.l10n.kicker, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.bad)),
                    ),
                    const SizedBox(height: 2),
                    Text(context.l10n.appTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Palette.ink, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Text(context.l10n.tagline, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.dim)),
                    const Spacer(),
                    const _TitleArt(),
                    const Spacer(),
                    Text(
                      [context.l10n.rankName(progress.rank), if (progress.starsToNextRank != null) context.l10n.rankNext(progress.starsToNextRank!)].join(context.l10n.sep),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.dim),
                    ),
                    const SizedBox(height: 2),
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
                        label: progress.totalStars == 0 ? context.l10n.start : context.l10n.continueAt(progress.nextLevel.id),
                        color: Palette.gold,
                        shadow: Palette.goldDeep,
                        fontSize: 22,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: () => Navigator.of(context).push(_fade(GameScreen(level: progress.nextLevel, progress: progress, money: money))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ChunkyButton(
                        label: context.l10n.chooseStage,
                        fontSize: 17,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onPressed: () => Navigator.of(context).push(_fade(StageSelectScreen(progress: progress, money: money))),
                      ),
                    ),
                    _Daily(progress: progress, money: money),
                    const SizedBox(height: 14),
                    _RemoveAds(money: money),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
                    ),
                  ),
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
class StageSelectScreen extends StatefulWidget {
  const StageSelectScreen({super.key, required this.progress, required this.money});
  final Progress progress;
  final Monetization money;

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  /// 舞台ごとの札。開いたときに、次に遊ぶ面のある舞台まで送るために使う。
  final _keys = {for (final w in worlds) w.no: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.progress.nextLevel.world]?.currentContext;
      if (ctx != null && widget.progress.nextLevel.world > 1) {
        Scrollable.ensureVisible(ctx, alignment: 0.05, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    return Scaffold(
      backgroundColor: Palette.sky,
      appBar: AppBar(
        backgroundColor: Palette.sky,
        foregroundColor: Palette.ink,
        elevation: 0,
        title: Text(context.l10n.stages, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // 全体の進み具合
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: Palette.gold, size: 22),
                const SizedBox(width: 4),
                Text('${progress.totalStars} / ${progress.maxStars}', style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.ink)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress.maxStars == 0 ? 0 : progress.totalStars / progress.maxStars,
                      minHeight: 10,
                      backgroundColor: Palette.card,
                      color: Palette.gold,
                    ),
                  ),
                ),
              ]),
            ),
            for (final w in worlds) _WorldCard(key: _keys[w.no], world: w, progress: progress, money: widget.money),
          ],
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({super.key, required this.world, required this.progress, required this.money});
  final WorldInfo world;
  final Progress progress;
  final Monetization money;

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
              if (world.role != null)
                SizedBox(width: 30, height: 38, child: Figure(role: world.role!)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${world.no}. ${context.l10n.world(world.no)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.ink)),
              ),
              if (!open) const Icon(Icons.lock_rounded, color: Palette.dim, size: 18),
              const Icon(Icons.star_rounded, color: Palette.gold, size: 18),
              Text(' $got/${ls.length * 3}', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
            ],
          ),
          if (!open) ...[
            const SizedBox(height: 4),
            Text(
              world.no == 8 && !progress.nightmareOpen
                  ? context.l10n.nightmareLock(Progress.nightmareStars, progress.starsBeforeNightmare)
                  : context.l10n.lockedHint,
              style: const TextStyle(fontSize: 12, color: Palette.dim, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [for (final l in ls) _LevelTile(level: l, progress: progress, money: money)],
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.progress, required this.money});
  final Level level;
  final Progress progress;
  final Monetization money;

  @override
  Widget build(BuildContext context) {
    final open = progress.unlocked(level);
    final stars = progress.stars(level);
    final current = open && stars == 0;
    return Semantics(
      button: true,
      enabled: open,
      label: !open ? context.l10n.levelLocked(level.id) : stars > 0 ? context.l10n.levelStars(level.id, stars) : level.id,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open
            ? () {
                if (_tapOk()) Navigator.of(context).push(_fade(GameScreen(level: level, progress: progress, money: money)));
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: current ? Palette.gold : open ? Colors.white : const Color(0xFFE3E8EE),
            border: Border.all(color: Palette.ink, width: 2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: open ? const [BoxShadow(color: Palette.ink, offset: Offset(0, 2))] : null,
          ),
          // 小さい画面や大きい文字では、はみ出さずに縮める（iPhone SE・文字1.3倍で 2.8px はみ出していた）
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}

/// 「広告を消す（¥370）」と「購入を復元」。ストアが使えない所（Web版・テスト）では出さない。
class _RemoveAds extends StatefulWidget {
  const _RemoveAds({required this.money});
  final Monetization money;

  @override
  State<_RemoveAds> createState() => _RemoveAdsState();
}

class _RemoveAdsState extends State<_RemoveAds> {
  bool _available = false;
  String? _price;
  bool _busy = false;
  late final AppLifecycleListener _life;
  Timer? _retry;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // 電波の悪い所で起動して値段が取れなかったとき、アプリに戻ってきたら取り直す
    _life = AppLifecycleListener(onResume: () {
      if (_price == null) _load();
    });
  }

  @override
  void dispose() {
    _life.dispose();
    _retry?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _retry?.cancel();
    final ok = await widget.money.store.isAvailable();
    final price = ok ? await widget.money.price : null;
    if (!mounted) return;
    setState(() {
      _available = ok;
      _price = price;
    });
    // 値段が取れなければ、間を空けて何度か取り直す（アプリを出入りしなくても電波が戻れば買えるように）
    if (ok && price == null && _tries < 3) {
      _retry = Timer(Duration(seconds: 5 * (1 << (_tries * 2))), _load); // 5秒→20秒→80秒
      _tries++;
    }
  }

  Future<void> _run(Future<PurchaseOutcome> Function() f, {required bool restore}) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    PurchaseOutcome r;
    try {
      r = await f();
    } catch (_) {
      r = PurchaseOutcome.failed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final msg = switch (r) {
      PurchaseOutcome.purchased => restore ? t.purchaseRestored : t.purchaseThanks,
      PurchaseOutcome.pending => t.purchasePending,
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => restore ? t.purchaseNothing : t.purchaseFailed,
      PurchaseOutcome.failed => restore ? t.restoreFailed : t.purchaseFailed,
    };
    if (msg != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return ListenableBuilder(
      listenable: widget.money,
      builder: (context, _) {
        if (widget.money.adFree) {
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Palette.ok),
            const SizedBox(width: 4),
            Text(t.adFreeOn, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
          ]);
        }
        if (!_available) return const SizedBox.shrink();
        return Column(children: [
          // 値段が取れないとき（商品情報の取得に失敗）は買うボタンだけ隠し、復元は残す
          if (_price != null)
            ChunkyButton(
              label: t.removeAds(_price!),
              icon: Icons.block_rounded,
              fontSize: 14,
              onPressed: _busy ? null : () => _run(widget.money.buy, restore: false),
            ),
          TextButton(
            onPressed: _busy ? null : () => _run(widget.money.restore, restore: true),
            child: Text(t.restorePurchases, style: const TextStyle(color: Palette.dim, fontWeight: FontWeight.w700)),
          ),
        ]);
      },
    );
  }
}

/// 今日の1問。まだ1面も解いていなければ出さない。
class _Daily extends StatelessWidget {
  const _Daily({required this.progress, required this.money});
  final Progress progress;
  final Monetization money;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final now = DateTime.now();
    final level = progress.dailyLevel(now);
    if (level == null) return const SizedBox.shrink();
    final done = progress.dailyDone(now);
    final streak = progress.dailyStreak(now);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ChunkyButton(
          label: [done ? t.dailyDoneLabel : t.daily(level.id), if (streak > 0) t.dailyStreak(streak)].join(t.sep),
          icon: done ? Icons.check_circle_rounded : Icons.today_rounded,
          color: done ? Palette.card : const Color(0xFFFFF1C2),
          fontSize: 15,
          padding: const EdgeInsets.symmetric(vertical: 10),
          onPressed: () => Navigator.of(context).push(_fade(GameScreen(level: level, progress: progress, money: money))),
        ),
      ),
    );
  }
}

