import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

import '../app/progress.dart';
import '../engine/puzzle.dart';
import '../engine/rules.dart';
import '../game/session.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import 'figures.dart';
import 'palette.dart';

const _tapMove = Duration(milliseconds: 320);
const _crossMove = Duration(milliseconds: 900);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, required this.progress});
  final Level level;
  final Progress progress;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Phase { play, moving, escaping, failed, won }

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late Session s = Session(widget.level);
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  _Phase phase = _Phase.play;

  /// 舟の見た目の位置の上書き（渡っている途中・逃げられたとき）。null なら s.boat。
  Offset? _boatOverride;
  Duration _moveDuration = _tapMove;

  /// 逃げた人の行き先。
  final Map<int, Offset> _flee = {};
  bool _fleeing = false;
  Set<int> _hinted = {};
  Place? _hintTo;
  String? _toast;
  Timer? _toastTimer;
  int _earnedStars = 0;
  final List<Timer> _timers = [];

  Level get level => widget.level;
  bool get _tutorial => level.id == '1-1' && !widget.progress.cleared(level);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeIntro());
  }

  @override
  void dispose() {
    _idle.dispose();
    _confetti.dispose();
    _toastTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) => _timers.add(Timer(d, () {
        if (mounted) f();
      }));

  Future<void> _maybeIntro() async {
    final w = worldOf(level);
    final first = widget.progress.levels.firstWhere((l) => l.world == level.world);
    if (first != level || widget.progress.seenIntro(w.no)) return;
    await showIntro(context, w);
    await widget.progress.markIntro(w.no);
  }

  void _say(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _clearHint() {
    _hinted = {};
    _hintTo = null;
  }

  AppLocalizations get t => context.l10n;

  void _tap(Person p) {
    if (phase != _Phase.play) return;
    final r = s.tap(p);
    switch (r) {
      case TapResult.boarded:
      case TapResult.left:
        HapticFeedback.selectionClick();
        _clearHint();
      case TapResult.boatElsewhere:
        HapticFeedback.lightImpact();
        _say(t.boatIsAt(t.place(s.boat)));
      case TapResult.full:
        HapticFeedback.lightImpact();
        _say(p.role == Role.cuffed ? t.boatSeatsCuffed(level.capacity) : t.boatSeats(level.capacity));
      case TapResult.locked:
        return;
    }
    setState(() => _moveDuration = _tapMove);
  }

  void _depart(Place to) {
    if (phase != _Phase.play) return;
    final r = s.check(to);
    switch (r) {
      case Refused(:final reason):
        HapticFeedback.lightImpact();
        _say(switch (reason) {
          RefuseReason.empty => t.needSomeone,
          RefuseReason.noRower => t.noRower,
          RefuseReason.overCapacity => t.boatSeats(level.capacity),
          RefuseReason.notAdjacent => t.notAdjacent,
        });
        return;
      case Crossed():
        _clearHint();
        HapticFeedback.mediumImpact();
        setState(() {
          phase = _Phase.moving;
          _moveDuration = _crossMove;
          _boatOverride = _geo!.boatAt(to);
        });
        _later(_crossMove, () {
          s.depart(to);
          setState(() {
            _boatOverride = null;
            _moveDuration = _tapMove;
            phase = _Phase.play;
          });
          if (s.cleared) _later(const Duration(milliseconds: 450), _win);
        });
      case Escaped(:final where):
        _clearHint();
        final from = s.boat;
        setState(() {
          phase = _Phase.escaping;
          _moveDuration = _crossMove;
          // 岸で逃げられるときは舟が離れていく途中、舟の上なら川の真ん中で止まる
          final a = _geo!.boatAt(from), b = _geo!.boatAt(to);
          _boatOverride = where == null ? Offset.lerp(a, b, 0.5) : Offset.lerp(a, b, 0.35);
        });
        _later(Duration(milliseconds: where == null ? 700 : 450), () {
          s.depart(to);
          HapticFeedback.heavyImpact();
          setState(() => _moveDuration = _tapMove);
          _later(const Duration(milliseconds: 650), () {
            final g = _geo!;
            setState(() {
              _moveDuration = const Duration(milliseconds: 1000);
              for (final p in s.escaped) {
                final cur = g.personPos(s, p, _boatOverride);
                _flee[p.id] = where == null
                    ? cur + Offset(0, g.size.height * 0.35)
                    : Offset(cur.dx < g.size.width / 2 ? -g.s * 2 : g.size.width + g.s, cur.dy + g.s * 0.5);
              }
              _fleeing = true;
            });
            _later(const Duration(milliseconds: 1100), () => setState(() => phase = _Phase.failed));
          });
        });
    }
  }

  Future<void> _win() async {
    _earnedStars = s.stars;
    await widget.progress.record(level, _earnedStars);
    HapticFeedback.mediumImpact();
    _confetti.forward(from: 0);
    setState(() => phase = _Phase.won);
    // Web のテスト版には評価の仕組みが無いので出さない
    if (!kIsWeb && widget.progress.shouldAskReview(level, _earnedStars)) {
      await widget.progress.markReviewAsked(level.world);
      _later(const Duration(milliseconds: 1400), () async {
        final review = InAppReview.instance;
        if (await review.isAvailable()) await review.requestReview();
      });
    }
  }

  void _undo() {
    if (!s.canUndo || phase == _Phase.moving || phase == _Phase.escaping) return;
    setState(() {
      s.undo();
      _resetVisual();
    });
  }

  void _reset() {
    if (phase == _Phase.moving || phase == _Phase.escaping) return;
    setState(() {
      s.reset();
      _resetVisual();
    });
  }

  void _resetVisual() {
    phase = _Phase.play;
    _boatOverride = null;
    _flee.clear();
    _fleeing = false;
    _moveDuration = _tapMove;
    _clearHint();
    _confetti.reset();
  }

  void _hint() {
    if (phase != _Phase.play) return;
    final m = s.hint();
    if (m == null) {
      _say(t.unsolvable);
      return;
    }
    setState(() {
      _hinted = s.aboard.map((p) => p.id).toSet();
      _hintTo = m.to;
      _moveDuration = _tapMove;
    });
    final load = m.load.entries.map((e) => '${t.role(e.key)}${e.value > 1 ? '×${e.value}' : ''}').join(t.hintJoin);
    _say(t.hintSay(load, t.place(m.to)));
  }

  _Geo? _geo;

  @override
  Widget build(BuildContext context) {
    final w = worldOf(level);
    return Scaffold(
      backgroundColor: Palette.sky,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: '${level.id}  ${t.world(w.no)}',
              trips: s.trips,
              par: level.par,
              onBack: () => Navigator.of(context).pop(),
              onRules: () => showRules(context, level),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(child: ChunkyButton(label: t.undo, icon: Icons.undo_rounded, onPressed: s.canUndo ? _undo : null, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: ChunkyButton(label: t.restart, icon: Icons.refresh_rounded, onPressed: _reset, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: ChunkyButton(label: t.hint, icon: Icons.lightbulb_rounded, onPressed: phase == _Phase.play ? _hint : null, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Palette.ink, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LayoutBuilder(builder: (context, c) {
                      final g = _geo = _Geo(c.biggest, level);
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: CustomPaint(painter: _ScenePainter(g, _idle))),
                          ..._tallies(g),
                          AnimatedPositioned(
                            duration: _moveDuration,
                            curve: Curves.easeInOut,
                            left: (_boatOverride ?? g.boatAt(s.boat)).dx - g.boatW / 2,
                            top: (_boatOverride ?? g.boatAt(s.boat)).dy,
                            width: g.boatW,
                            height: g.boatH,
                            child: AnimatedBuilder(
                              animation: _idle,
                              builder: (_, child) => Transform.rotate(
                                angle: math.sin(_idle.value * math.pi * 2) * 0.012,
                                child: child,
                              ),
                              child: const CustomPaint(painter: BoatPainter()),
                            ),
                          ),
                          for (final p in _sortedPeople()) _person(g, p),
                          if (_toast != null) _toastView(),
                          if (_tutorial && phase == _Phase.play && s.trips == 0) _coach(g),
                          if (phase == _Phase.won) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_confetti)))),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            _GoBar(
              destinations: s.destinations,
              hintTo: _hintTo,
              enabled: phase == _Phase.play && s.aboard.isNotEmpty,
              onGo: _depart,
            ),
          ],
        ),
      ),
    ).withOverlay( // 結果の札は画面全体にかぶせる
      phase == _Phase.failed
          ? _ResultCard.fail(t: t, message: _failMessage(), onUndo: _undo, onReset: _reset)
          : phase == _Phase.won
              ? _ResultCard.win(
                  t: t,
                  total: widget.progress.levels.length,
                  stars: _earnedStars,
                  trips: s.trips,
                  par: level.par,
                  usedHint: s.usedHint,
                  hasNext: widget.progress.levels.last != level,
                  onNext: _next,
                  onRetry: _reset,
                  onMenu: () => Navigator.of(context).pop(),
                )
              : null,
    );
  }

  void _next() {
    final ls = widget.progress.levels;
    final next = ls[ls.indexOf(level) + 1];
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => GameScreen(level: next, progress: widget.progress),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  String _failMessage() {
    final f = s.failure!;
    if (f.where == null) return t.failBoat(f.guard, f.weight);
    final place = t.place(f.where!);
    if (f.guard == 0) return t.failAlone(place);
    return t.failBank(place, f.guard, f.weight);
  }

  List<Person> _sortedPeople() {
    // 奥（上）の人から描く
    final g = _geo!;
    return [...s.people]..sort((a, b) => g.personPos(s, a, _boatOverride).dy.compareTo(g.personPos(s, b, _boatOverride).dy));
  }

  Widget _person(_Geo g, Person p) {
    final flee = _fleeing ? _flee[p.id] : null;
    final pos = flee ?? g.personPos(s, p, _boatOverride);
    final w = g.figureW(p.role), h = g.figH;
    final alert = (phase == _Phase.escaping || phase == _Phase.failed) && s.escaped.contains(p);
    final happy = phase == _Phase.won && p.role.guard > 0;
    return AnimatedPositioned(
      key: ValueKey(p.id),
      duration: _moveDuration,
      curve: flee != null ? Curves.easeIn : Curves.easeInOut,
      left: pos.dx - w / 2,
      top: pos.dy - h,
      width: w,
      height: h,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 900),
        opacity: flee != null ? 0 : 1,
        child: Semantics(
          button: true,
          label: t.personLabel('${t.role(p.role)}${p.role.weight > 0 ? p.order + 1 : ''}', p.aboard ? t.onBoat : t.place(p.place)),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tap(p),
            child: AnimatedBuilder(
              animation: _idle,
              builder: (_, _) => DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: _hinted.contains(p.id)
                      ? [BoxShadow(color: Palette.gold.withValues(alpha: 0.35 + 0.35 * math.sin(_idle.value * math.pi * 6).abs()), blurRadius: 14, spreadRadius: 2)]
                      : null,
                ),
                child: Figure(
                  role: p.role,
                  order: p.order,
                  mood: alert ? Mood.alert : happy ? Mood.happy : Mood.calm,
                  bob: _idle.value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _tallies(_Geo g) {
    final places = level.island ? Place.values : [Place.left, Place.right];
    return [
      for (final pl in places)
        Positioned(
          left: g.tallyAt(pl).dx,
          top: g.tallyAt(pl).dy,
          child: _Tally(
            guard: s.at(pl).fold(0, (a, p) => a + p.role.guard),
            weight: s.at(pl).fold(0, (a, p) => a + p.role.weight),
            label: t.place(pl),
            t: t,
          ),
        ),
    ];
  }

  Widget _toastView() => Positioned(
        left: 0,
        right: 0,
        top: _geo!.riverTop + 8,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(99)),
            child: Text(_toast!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      );

  Widget _coach(_Geo g) {
    final text = s.aboard.isEmpty ? t.coachTap : t.coachGo(t.goTo(t.placeRight));
    return Positioned(
      left: 16,
      right: 16,
      top: (g.riverTop + g.riverBottom) / 2 - 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  /// 画面全体にかぶせる札（null なら何もしない）。
  Widget withOverlay(Widget? overlay) => overlay == null
      ? this
      : Stack(children: [this, Positioned.fill(child: overlay)]);
}

/// 場の寸法。手前の岸（Place.left）が下、向こう岸（Place.right）が上。
class _Geo {
  _Geo(this.size, this.level) {
    final units = math.max(guardUnits, captiveUnits).toDouble();
    s = math.min(size.width / (units + 1.2), 78.0);
    // 中州は幅の 58% しかないので、1列が中州に収まる大きさまで縮める
    if (level.island) s = math.min(s, (size.width * 0.58 - 16) / (units * 0.95));
    // 高さ: 岸2つ（各 2.5s+34）＋舟の通り道（中州の面は中州 2.5s+24 も）
    s = math.min(s, (size.height - (level.island ? 110 : 80)) / (level.island ? 10.6 : 7.8));
    figH = s * 1.25;
    bankH = figH * 2 + 34;
    boatW = math.min(level.capacity * s * 0.82 + s * 0.5, laneW - 12);
    boatH = s * 0.5;
  }

  final Size size;
  final Level level;
  late double s;
  late double figH;
  late double bankH;
  late double boatW;
  late double boatH;

  static const _guards = [Role.police, Role.chief, Role.dog];
  static const _captives = [Role.prisoner, Role.boss, Role.cuffed];

  int get guardUnits => _guards.fold(0, (a, r) => a + level.count(r));
  int get captiveUnits => _captives.fold(0, (a, r) => a + level.count(r) * r.seats);

  double figureW(Role r) => r == Role.cuffed ? s * 2 * 0.8 * 1.0 : s * 0.8;

  double get riverTop => bankH;
  double get riverBottom => size.height - bankH;

  /// 中州（ある面だけ）。左 58% に島、右が舟の通り道。
  Rect get island {
    final h = figH * 2 + 24;
    final cy = (riverTop + riverBottom) / 2;
    return Rect.fromLTWH(0, cy - h / 2, size.width * 0.58, h);
  }

  double get laneLeft => level.island ? size.width * 0.58 : 0;
  double get laneW => size.width - laneLeft;
  double get laneCx => laneLeft + laneW / 2;

  Rect region(Place p) => switch (p) {
        Place.left => Rect.fromLTWH(0, size.height - bankH, size.width, bankH),
        Place.right => Rect.fromLTWH(0, 0, size.width, bankH),
        Place.island => island,
      };

  /// 舟の左上ではなく「上辺の中央」。
  Offset boatAt(Place p) {
    final riderRoom = figH * 0.62;
    return switch (p) {
      Place.left => Offset(laneCx, riverBottom - boatH - 6),
      Place.right => Offset(laneCx, riverTop + math.min(riderRoom * 0.35, 14)),
      Place.island => Offset(laneCx, island.center.dy - boatH / 2 + riderRoom / 2),
    };
  }

  Offset tallyAt(Place p) {
    final r = region(p);
    return switch (p) {
      Place.left => Offset(8, r.bottom - 21),
      Place.right => Offset(8, 3),
      Place.island => Offset(6, r.top + 2),
    };
  }

  /// 人の足元の位置（x は中央）。
  Offset personPos(Session sess, Person p, Offset? boatOverride) {
    if (p.aboard) {
      final top = boatOverride ?? boatAt(sess.boat);
      final riders = sess.aboard;
      final seatW = s * 0.82;
      final used = riders.fold(0, (a, x) => a + x.role.seats);
      var x = top.dx - used * seatW / 2;
      for (final r in riders) {
        if (r == p) break;
        x += r.role.seats * seatW;
      }
      return Offset(x + p.role.seats * seatW / 2, top.dy + boatH * 0.38);
    }
    final r = region(p.place);
    final guardRow = p.role.guard > 0;
    final roles = guardRow ? _guards : _captives;
    var slot = 0;
    for (final role in roles) {
      if (role == p.role) break;
      slot += level.count(role) * role.seats;
    }
    slot += p.order * p.role.seats;
    final total = guardRow ? guardUnits : captiveUnits;
    final pitch = math.min(s * 0.95, (r.width - 16) / math.max(total, 1));
    final x0 = r.center.dx - total * pitch / 2;
    final x = x0 + (slot + p.role.seats / 2) * pitch;
    final rowTop = switch (p.place) { Place.right => r.top + 24, Place.left => r.top + 6, Place.island => r.top + 18 };
    final y = rowTop + figH * (guardRow ? 1 : 2) + (guardRow ? 0 : 2);
    return Offset(x, y);
  }
}

/// 背景（空・岸・川・中州）。川の波だけ動かす。
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.g, this.t) : super(repaint: t);
  final _Geo g;
  final Animation<double> t;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    // 川
    c.drawRect(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom), Paint()..color = Palette.river);
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Palette.riverDeep.withValues(alpha: 0.6), Palette.river.withValues(alpha: 0), Palette.river.withValues(alpha: 0), Palette.riverDeep.withValues(alpha: 0.6)],
        stops: const [0, 0.15, 0.85, 1],
      ).createShader(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom));
    c.drawRect(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom), edge);
    // 流れ（左から右へ流れる白い筋）
    final wave = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final y = g.riverTop + 10 + rnd.nextDouble() * (g.riverBottom - g.riverTop - 20);
      final speed = 0.5 + rnd.nextDouble();
      final x = ((rnd.nextDouble() + t.value * speed) % 1.0) * (w + 60) - 30;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 18 + rnd.nextDouble() * 14, height: 3), const Radius.circular(2)), wave);
    }
    // 岸
    void bank(Rect r, bool top) {
      c.drawRect(r, Paint()..color = Palette.sand);
      final lip = top ? Rect.fromLTWH(0, r.bottom - 5, w, 5) : Rect.fromLTWH(0, r.top, w, 5);
      c.drawRect(lip, Paint()..color = Palette.sandEdge);
      final grass = top ? Rect.fromLTWH(0, 0, w, 14) : Rect.fromLTWH(0, r.bottom - 14, w, 14);
      c.drawRect(grass, Paint()..color = Palette.grass);
      c.drawRect(top ? Rect.fromLTWH(0, 14, w, 3) : Rect.fromLTWH(0, r.bottom - 17, w, 3), Paint()..color = Palette.grassDark);
    }

    bank(Rect.fromLTWH(0, 0, w, g.bankH), true);
    bank(Rect.fromLTWH(0, size.height - g.bankH, w, g.bankH), false);
    if (g.level.island) {
      final r = g.island;
      final rr = RRect.fromRectAndCorners(r, topRight: const Radius.circular(26), bottomRight: const Radius.circular(26));
      c.drawRRect(rr.inflate(4), Paint()..color = Palette.sandEdge);
      c.drawRRect(rr, Paint()..color = Palette.sand);
      // 桟橋
      c.drawRect(Rect.fromLTWH(r.right - 2, r.center.dy - 5, 12, 10), Paint()..color = const Color(0xFF9C6B3F));
    }
    // 旗（ゴール）
    final pole = Offset(w - 22, 20);
    c.drawLine(pole, pole + const Offset(0, 26), Paint()
      ..color = Palette.ink
      ..strokeWidth = 2);
    final flag = Path()
      ..moveTo(pole.dx, pole.dy)
      ..lineTo(pole.dx - 16, pole.dy + 6)
      ..lineTo(pole.dx, pole.dy + 12)
      ..close();
    c.drawPath(flag, Paint()..color = Palette.bad);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.g.size != g.size || old.g.level != g.level;
}

class _Tally extends StatelessWidget {
  const _Tally({required this.guard, required this.weight, required this.label, required this.t});
  final AppLocalizations t;
  final int guard;
  final int weight;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          border: Border.all(color: Palette.ink, width: 1.5),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label  ', style: const TextStyle(color: Palette.dim)),
            TextSpan(text: t.tallyGuard(guard), style: const TextStyle(color: Color(0xFF2B4FA8))),
            const TextSpan(text: ' ・ '),
            TextSpan(text: t.tallyPrisoner(weight), style: const TextStyle(color: Color(0xFF444444))),
          ]),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Palette.ink),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.trips, required this.par, required this.onBack, required this.onRules});
  final String title;
  final int trips;
  final int par;
  final VoidCallback onBack;
  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Row(
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Palette.ink), tooltip: context.l10n.backToStages),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.ink)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(context.l10n.tripsCount(trips), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()])),
                Text(context.l10n.par(par), style: const TextStyle(fontSize: 11, color: Palette.dim, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 6),
            IconButton(onPressed: onRules, icon: const Icon(Icons.help_outline_rounded, color: Palette.ink), tooltip: context.l10n.rulesTitle),
          ],
        ),
      );
}

class _GoBar extends StatelessWidget {
  const _GoBar({required this.destinations, required this.hintTo, required this.enabled, required this.onGo});
  final List<Place> destinations;
  final Place? hintTo;
  final bool enabled;
  final void Function(Place) onGo;

  @override
  Widget build(BuildContext context) {
    // 上へ行く行き先を先に並べる
    final ds = [...destinations]..sort((a, b) => _up(b).compareTo(_up(a)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          for (final d in ds) ...[
            if (d != ds.first) const SizedBox(width: 10),
            Expanded(
              child: ChunkyButton(
                label: context.l10n.goTo(context.l10n.place(d)),
                icon: _up(d) > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: hintTo == d ? const Color(0xFFFFE08A) : Palette.gold,
                shadow: Palette.goldDeep,
                fontSize: 18,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: enabled ? () => onGo(d) : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 行き先が上（向こう岸側）なら正。中州から手前は下。
  static int _up(Place p) => switch (p) { Place.right => 2, Place.island => 1, Place.left => 0 };
}

class _ResultCard extends StatelessWidget {
  const _ResultCard._({required this.child});

  factory _ResultCard.fail({required AppLocalizations t, required String message, required VoidCallback onUndo, required VoidCallback onReset}) => _ResultCard._(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.escaped, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Palette.bad)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.dim)),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              ChunkyButton(label: t.undo, color: Palette.gold, onPressed: onUndo),
              const SizedBox(width: 10),
              ChunkyButton(label: t.restart, onPressed: onReset),
            ]),
          ],
        ),
      );

  factory _ResultCard.win({
    required AppLocalizations t,
    required int total,
    required int stars,
    required int trips,
    required int par,
    required bool usedHint,
    required bool hasNext,
    required VoidCallback onNext,
    required VoidCallback onRetry,
    required VoidCallback onMenu,
  }) {
    final note = usedHint && trips <= par
        ? t.noteHint
        : trips <= par
            ? t.noteBest
            : t.noteParFor3(par);
    return _ResultCard._(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.cleared, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Palette.ok)),
          const SizedBox(height: 6),
          StarRow(stars, size: 44),
          const SizedBox(height: 6),
          Text('${t.crossedIn(trips)}\n$note', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.dim)),
          const SizedBox(height: 16),
          if (hasNext) ChunkyButton(label: t.nextLevel, color: Palette.gold, fontSize: 18, onPressed: onNext),
          if (!hasNext) Text(t.allCleared(total), style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.ink)),
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ChunkyButton(label: t.again, onPressed: onRetry, fontSize: 13),
            const SizedBox(width: 10),
            ChunkyButton(label: t.stageSelect, onPressed: onMenu, fontSize: 13),
          ]),
        ],
      ),
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x661F2A44),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: Palette.card,
                border: Border.all(color: Palette.ink, width: 2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 6))],
              ),
              child: child,
            ),
          ),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t) : super(repaint: t);
  final Animation<double> t;
  static const colors = [Palette.gold, Palette.bad, Palette.river, Palette.grass, Colors.white];

  @override
  void paint(Canvas c, Size size) {
    final rnd = math.Random(3);
    for (var i = 0; i < 48; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * 0.3;
      final speed = 0.7 + rnd.nextDouble() * 0.6;
      final p = ((t.value - delay) / (1 - delay)).clamp(0.0, 1.0) * speed;
      if (p <= 0) continue;
      final y = -12 + p * (size.height + 24);
      final x = x0 + math.sin(p * 10 + i) * 14;
      c.save();
      c.translate(x, y);
      c.rotate(p * 12 + i);
      c.drawRect(const Rect.fromLTWH(-4, -6, 8, 12), Paint()..color = colors[i % colors.length]);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

/// 新しい役・仕掛けの紹介。
Future<void> showIntro(BuildContext context, WorldInfo w) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final t = ctx.l10n;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Palette.card,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (w.role != null)
                  SizedBox(
                    height: 90,
                    child: AspectRatio(aspectRatio: Figure.aspect(w.role!), child: Figure(role: w.role!)),
                  ),
                const SizedBox(height: 8),
                Text(t.introTitle(w.no), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.ink)),
                const SizedBox(height: 10),
                Text(t.introBody(w.no), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink)),
                const SizedBox(height: 18),
                ChunkyButton(label: t.gotIt, color: Palette.gold, fontSize: 17, onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
          ),
        );
      },
    );

/// 決まりの一覧（この面に出てくる役だけ）。
Future<void> showRules(BuildContext context, Level level) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        final t = ctx.l10n;
        final roles = Role.values.where((r) => level.count(r) > 0).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.rulesTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.ink)),
                const SizedBox(height: 8),
                Text(
                  [t.rulesBody(level.capacity), if (level.island) t.rulesIsland].join('\n'),
                  style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink),
                ),
                const SizedBox(height: 12),
                for (final r in roles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(height: 44, child: AspectRatio(aspectRatio: Figure.aspect(r), child: Figure(role: r))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${t.role(r)}  ', style: const TextStyle(fontWeight: FontWeight.w900)),
                            TextSpan(text: t.roleDesc(r)),
                          ])),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
