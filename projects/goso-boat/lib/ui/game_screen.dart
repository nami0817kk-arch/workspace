import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

import '../app/achievements.dart';
import '../app/progress.dart';
import '../app/settings.dart';
import '../engine/puzzle.dart';
import '../engine/rules.dart';
import '../game/session.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../monetization/monetization.dart';
import 'figures.dart';
import 'palette.dart';

const _tapMove = Duration(milliseconds: 320);
const _crossMove = Duration(milliseconds: 900);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, required this.progress, required this.money});
  final Level level;
  final Progress progress;
  final Monetization money;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Phase { play, moving, escaping, failed, won }

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late Session s = Session(widget.level);
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  /// 5. 逃げられたときの画面の揺れ
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  /// 7. 岸に着いた人が跳ねる
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Set<int> _hopIds = {};

  /// 1. タイム（アプリを閉じている間は止める）
  final Stopwatch _clock = Stopwatch();
  int _baseMs = 0;
  int get _elapsedMs => _baseMs + _clock.elapsedMilliseconds;
  int _resultMs = 0;
  int? _bestMs;
  bool _fastest = false;

  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  _Phase phase = _Phase.play;

  /// 舟の見た目の位置の上書き（渡っている途中・逃げられたとき）。null なら s.boat。
  Offset? _boatOverride;
  Duration _moveDuration = _tapMove;

  /// 逃げた人の行き先。
  final Map<int, Offset> _flee = {};

  /// 川に飛び込んだ所（水しぶきを出す）。
  final List<Offset> _splashes = [];
  bool _fleeing = false;
  Set<int> _hinted = {};
  Place? _hintTo;
  String? _toast;
  Timer? _toastTimer;
  int _earnedStars = 0;

  // 結果の札に出す値（クリアした時点で控える）
  int _resultTrips = 0;
  bool _resultUsedHint = false;
  int? _best;
  bool _newRecord = false;

  /// 結果の札に添える知らせ（今日の1問の達成・新しく取れた実績）。
  List<String> _notes = [];

  /// 面の始まりの札（面番号・目標）を出しているか。
  bool _banner = false;
  bool _resumed = false;
  final DateTime _openedAt = DateTime.now();

  /// 逃げる囚人の捨てぜりふ。
  String? _taunt;
  Offset? _tauntAt;
  final List<Timer> _timers = [];

  Level get level => widget.level;
  bool get _tutorial => level.id == '1-1' && !widget.progress.cleared(level);

  @override
  void initState() {
    super.initState();
    // 10. アプリを閉じても、途中まで渡した盤面から続ける
    final saved = widget.progress.resumeFor(level);
    if (saved != null) {
      _resumed = s.restore(saved);
      if (_resumed && saved['ms'] is int) _baseMs = saved['ms']! as int;
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeIntro();
      if (!mounted) return;
      // 時計は紹介を読み終えてから動かす
      _clock.start();
      setState(() => _banner = true);
      _later(const Duration(milliseconds: 1900), () => setState(() => _banner = false));
    });
  }

  void _saveResume() {
    if (s.trips > 0 && !s.failed && !s.cleared) {
      widget.progress.saveResume(level, {...s.toJson(), 'ms': _elapsedMs});
    } else {
      widget.progress.clearResume(level);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 端末の「視差効果を減らす」が入っていれば、待機の揺れを止める
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle
        ..stop()
        ..value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (phase != _Phase.won && phase != _Phase.failed) _clock.start();
    } else {
      _clock.stop();
      if (phase == _Phase.play) _saveResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shake.dispose();
    _hop.dispose();
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
  GameSettings get fx => AppScope.of(context);

  void _tap(Person p) {
    if (phase != _Phase.play) return;
    final r = s.tap(p);
    switch (r) {
      case TapResult.boarded:
        fx.buzz(Buzz.select);
        fx.play(Sfx.board);
        _clearHint();
      case TapResult.left:
        fx.buzz(Buzz.select);
        fx.play(Sfx.unboard);
        _clearHint();
      case TapResult.boatElsewhere:
        fx.buzz(Buzz.light);
        fx.play(Sfx.nope);
        _say(t.boatIsAt(t.place(s.boat)));
      case TapResult.full:
        fx.buzz(Buzz.light);
        fx.play(Sfx.nope);
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
        fx.buzz(Buzz.light);
        fx.play(Sfx.nope);
        _say(switch (reason) {
          RefuseReason.empty => t.needSomeone,
          RefuseReason.noRower => t.noRower,
          RefuseReason.overCapacity => t.boatSeats(level.capacity),
          RefuseReason.notAdjacent => t.notAdjacent,
        });
        return;
      case Crossed():
        _clearHint();
        fx.buzz(Buzz.medium);
        fx.play(Sfx.depart);
        setState(() {
          phase = _Phase.moving;
          _moveDuration = _crossMove;
          _boatOverride = _geo!.boatAt(to);
        });
        final riders = s.aboard.map((p) => p.id).toSet();
        _later(_crossMove, () {
          s.depart(to);
          _hopIds = riders;
          _hop.forward(from: 0);
          widget.progress.bump('trips');
          _saveResume();
          fx.play(Sfx.arrive);
          setState(() {
            _boatOverride = null;
            _moveDuration = _tapMove;
            // 渡りきったら結果の札が出るまで操作させない（その隙の「最初から」で記録が壊れた）
            phase = s.cleared ? _Phase.moving : _Phase.play;
          });
          if (s.cleared) _win();
        });
      case Escaped(:final where):
        _clearHint();
        _clock.stop();
        _countEscape();
        fx.play(Sfx.depart);
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
          fx.buzz(Buzz.heavy);
          fx.play(Sfx.escape);
          if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
          final g0 = _geo!;
          setState(() {
            _moveDuration = _tapMove;
            if (s.escaped.isNotEmpty) {
              final taunts = [t.taunt1, t.taunt2, t.taunt3, t.taunt4];
              _taunt = taunts[math.Random().nextInt(taunts.length)];
              _tauntAt = g0.personPos(s, s.escaped.first, _boatOverride) - Offset(0, g0.figH + 6);
            }
          });
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
            if (where == null) {
              fx.play(Sfx.splash);
              setState(() {
                for (final p in s.escaped) {
                  _splashes.add(g.personPos(s, p, _boatOverride) + Offset(0, g.boatH));
                }
              });
            }
            _later(const Duration(milliseconds: 1100), () => setState(() => phase = _Phase.failed));
          });
        });
    }
  }

  Future<void> _countEscape() async {
    await widget.progress.clearResume(level);
    await widget.progress.addTry(level);
    await widget.progress.bump('escapes');
    await widget.progress.bump('trips');
    final fresh = await collectNewAchievements(widget.progress);
    if (!mounted) return;
    _notes = [for (final a in fresh) t.achUnlocked(t.achName(a))];
  }

  bool _winning = false;

  Future<void> _win() async {
    if (!s.cleared || _winning) return;
    _winning = true;
    _clock.stop();
    _resultMs = _elapsedMs;
    final rankBefore = widget.progress.rank;
    final firstClear = !widget.progress.cleared(level);
    final tries = await widget.progress.addTry(level);
    await widget.progress.clearResume(level);
    _earnedStars = s.stars;
    _resultTrips = s.trips;
    _resultUsedHint = s.usedHint;
    _newRecord = await widget.progress.record(level, _earnedStars, trips: s.trips);
    _best = widget.progress.best(level);
    _fastest = await widget.progress.recordTime(level, _resultMs);
    _bestMs = widget.progress.bestTime(level);
    if (tries == 1 && _earnedStars == 3) await widget.progress.bump('firstTryThree');
    if (level.world == 8 && !s.usedUndo) await widget.progress.bump('nightmareNoUndo');
    // 今日の1問は、面を開いた日の問題として数える（日付をまたいで解いても達成になる）
    final now = _openedAt;
    final daily = await widget.progress.recordDaily(level, _earnedStars, now);
    final fresh = await collectNewAchievements(widget.progress);
    // 記録は済ませてから、舟が着いた余韻のあとで札を出す
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final worldLevels = widget.progress.levels.where((l) => l.world == level.world).toList();
    final worldDone = firstClear && worldLevels.last == level;
    final p = widget.progress;
    _notes = [
      if (firstClear) t.triesClear(tries),
      if (!s.usedUndo) t.noUndoClear,
      if (widget.progress.rank > rankBefore) t.rankUp(t.rankName(widget.progress.rank)),
      if (worldDone) t.worldClear(level.world, t.world(level.world), worldLevels.fold(0, (a, l) => a + p.stars(l)), worldLevels.length * 3),
      if (worldDone && level.world == 7 && !p.nightmareOpen) t.nightmareNeed(Progress.nightmareStars - p.starsBeforeNightmare),
      if (daily) t.dailyCleared(p.dailyStreak(now)),
      for (final a in fresh) t.achUnlocked(t.achName(a)),
    ];
    fx.buzz(Buzz.medium);
    fx.play(Sfx.clear);
    // 星の数だけ「きらっ」を鳴らす（結果の札に星が並ぶのに合わせる）
    for (var i = 0; i < _earnedStars; i++) {
      _later(Duration(milliseconds: 550 + i * 220), () => fx.play(Sfx.star));
    }
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

  /// 一手戻すのは、逃げられるまでの途中だけ。逃げられたら最初からやり直す
  /// （2026-09-27 ユーザー決定。失敗の直前に戻れると、挑戦の回数が減るため）。
  bool get _canUndo => s.canUndo && phase == _Phase.play;

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      s.undo();
      _resetVisual();
    });
    _saveResume();
  }

  void _reset() {
    if (phase == _Phase.moving || phase == _Phase.escaping) return;
    setState(() {
      s.reset();
      _resetVisual();
    });
    _baseMs = 0;
    _clock
      ..reset()
      ..start();
    widget.progress.clearResume(level);
  }

  void _resetVisual() {
    phase = _Phase.play;
    _boatOverride = null;
    _flee.clear();
    _splashes.clear();
    _notes = [];
    _taunt = null;
    _fleeing = false;
    _moveDuration = _tapMove;
    _clearHint();
    _confetti.reset();
  }

  bool _hintBusy = false;

  Future<void> _hint() async {
    if (phase != _Phase.play || _hintBusy) return;
    // 広告を消していなければ、動画を1本見てからヒントを出す
    _hintBusy = true;
    _clock.stop();
    final gate = await widget.money.beforeHint();
    if (phase == _Phase.play) _clock.start();
    _hintBusy = false;
    if (!mounted || phase != _Phase.play) return;
    if (gate == HintGate.declined) {
      _say(t.hintDeclined);
      return;
    }
    if (gate == HintGate.unavailable) {
      _say(t.hintNoAd);
      return;
    }
    final m = s.hint();
    if (m == null) {
      _say(t.unsolvable);
      return;
    }
    fx.play(Sfx.hint);
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
      backgroundColor: SceneTheme.forWorld(level.world).background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: '${level.id}  ${t.world(w.no)}',
              trips: s.trips,
              par: level.par,
              stars: s.stars,
              onBack: () => Navigator.of(context).pop(),
              onRules: () => showRules(context, level),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(child: ChunkyButton(label: t.undo, icon: Icons.undo_rounded, onPressed: _canUndo ? _undo : null, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: ChunkyButton(label: t.restart, icon: Icons.refresh_rounded, onPressed: _reset, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: ChunkyButton(
                      label: widget.money.hintNeedsAd ? t.hintWithAd : t.hint,
                      icon: widget.money.hintNeedsAd ? Icons.smart_display_rounded : Icons.lightbulb_rounded, onPressed: phase == _Phase.play ? _hint : null, fontSize: 13)),
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
                      return AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(math.sin(_shake.value * math.pi * 10) * 8 * (1 - _shake.value), 0),
                          child: child,
                        ),
                        child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: CustomPaint(painter: _ScenePainter(g, _idle, SceneTheme.forWorld(level.world)))),
                          if (_boatOverride != null && _moveDuration == _crossMove) _wake(g),
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
                              builder: (_, _) => Transform.rotate(
                                angle: math.sin(_idle.value * math.pi * 2) * 0.012,
                                child: CustomPaint(
                                  painter: BoatPainter(oar: _boatOverride != null && _moveDuration == _crossMove ? _idle.value : null),
                                ),
                              ),
                            ),
                          ),
                          ..._seatMarks(g),
                          if (s.aboard.isNotEmpty) _boatTally(g),
                          for (final p in _sortedPeople()) _person(g, p),
                          for (final o in _splashes) _splash(o),
                          if (_toast != null) _toastView(),
                          if (_taunt != null && _tauntAt != null && (phase == _Phase.escaping || phase == _Phase.failed)) _tauntBubble(),
                          _startBanner(g),
                          if (_tutorial && phase == _Phase.play && s.trips == 0) _coach(g),
                          if (phase == _Phase.won) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_confetti)))),
                        ],
                      ),
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
          ? _ResultCard.fail(t: t, message: _failMessage(), notes: _notes, onReset: _reset)
          : phase == _Phase.won
              ? _ResultCard.win(
                  t: t,
                  total: widget.progress.levels.length,
                  stars: _earnedStars,
                  trips: _resultTrips,
                  par: level.par,
                  usedHint: _resultUsedHint,
                  best: _best,
                  newRecord: _newRecord,
                  notes: _notes,
                  timeMs: _resultMs,
                  bestMs: _bestMs,
                  fastest: _fastest,
                  hasNext: _nextLevel != null,
                  isLast: widget.progress.levels.last == level,
                  onNext: _next,
                  onRetry: _reset,
                  onMenu: () => Navigator.of(context).pop(),
                )
              : null,
    );
  }

  /// 次の面。開いていなければ null（鬼門は星が要るので、舞台7の最後から先へ進めないことがある）。
  Level? get _nextLevel {
    final ls = widget.progress.levels;
    final i = ls.indexOf(level);
    if (i < 0 || i + 1 >= ls.length) return null;
    final n = ls[i + 1];
    return widget.progress.unlocked(n) ? n : null;
  }

  bool _leaving = false;

  Future<void> _next() async {
    final next = _nextLevel;
    // 2度押しで広告の数えや画面が二重にならないように
    if (next == null || _leaving) return;
    _leaving = true;
    // 面と面の間の全画面広告（3面に1回。舞台1と、広告を消した人には出ない）
    await widget.money.afterClear(level);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => GameScreen(level: next, progress: widget.progress, money: widget.money),
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
            onLongPress: () {
              fx.buzz(Buzz.light);
              _say('${t.role(p.role)}${t.colon}${t.roleDesc(p.role)}');
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_idle, _hop]),
              builder: (_, _) => Transform.translate(
                offset: Offset(0, _hopIds.contains(p.id) && _hop.isAnimating ? -math.sin(_hop.value * math.pi) * 10 : 0),
                child: DecoratedBox(
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

  /// 舟の上の人数（出す前に、乗っている見張りと囚人を数えやすくする）。
  /// 岸の人と重ならないよう、舟の白い船体の上に書く。
  Widget _boatTally(_Geo g) {
    final at = _boatOverride ?? g.boatAt(s.boat);
    final riders = s.aboard;
    final guard = riders.fold(0, (a, p) => a + p.role.guard);
    final weight = riders.fold(0, (a, p) => a + p.role.weight);
    return AnimatedPositioned(
      duration: _moveDuration,
      curve: Curves.easeInOut,
      left: at.dx - g.boatW * 0.36,
      width: g.boatW * 0.72,
      top: at.dy + g.boatH * 0.3,
      height: g.boatH * 0.5,
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: t.tallyGuard(guard), style: const TextStyle(color: Color(0xFF2B4FA8))),
              const TextSpan(text: ' ・ '),
              // 多い・少ないの色分けはしない（出す前に逃げると分かってしまう。2026-09-27 ユーザー指示「人のやる回数を減らすものはやめて」）
              TextSpan(text: t.tallyPrisoner(weight), style: const TextStyle(color: Color(0xFF444444))),
            ]),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Palette.ink),
          ),
        ),
      ),
    );
  }

  /// 渡っている舟の後ろに残る航跡。
  Widget _wake(_Geo g) {
    final from = g.boatAt(s.boat), to = _boatOverride!;
    final up = to.dy < from.dy;
    return AnimatedPositioned(
      duration: _moveDuration,
      curve: Curves.easeInOut,
      left: to.dx - g.boatW / 2,
      width: g.boatW,
      top: up ? to.dy + g.boatH : to.dy - 40,
      height: 40,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _crossMove,
          builder: (_, v, _) => CustomPaint(painter: _WakePainter(v, up)),
        ),
      ),
    );
  }

  /// 飛び込んだ所に広がる輪。
  Widget _splash(Offset o) => Positioned(
        left: o.dx - 40,
        top: o.dy - 16,
        width: 80,
        height: 32,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, _) => CustomPaint(painter: _SplashPainter(v)),
          ),
        ),
      );

  /// 3. 舟の空いている席の印（定員がひと目で分かるように）。
  List<Widget> _seatMarks(_Geo g) {
    final at = _boatOverride ?? g.boatAt(s.boat);
    final used = s.seatsUsed;
    final x0 = at.dx - level.capacity * g.seatW / 2;
    return [
      for (var k = used; k < level.capacity; k++)
        AnimatedPositioned(
          key: ValueKey('seat$k'),
          duration: _moveDuration,
          curve: Curves.easeInOut,
          left: x0 + (k + 0.5) * g.seatW - g.seatW * 0.28,
          top: at.dy - g.boatH * 0.02,
          width: g.seatW * 0.56,
          height: g.boatH * 0.3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                border: Border.all(color: Palette.ink.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
    ];
  }

  /// 5. 逃げる囚人の捨てぜりふ。
  Widget _tauntBubble() => Positioned(
        left: _tauntAt!.dx - 60,
        width: 120,
        top: _tauntAt!.dy - 30,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Palette.ink, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_taunt!, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.bad, fontSize: 14)),
            ),
          ),
        ),
      );

  /// 2. 面の始まりの札（面番号・舞台・目標）。
  Widget _startBanner(_Geo g) => Positioned(
        left: 24,
        right: 24,
        top: (g.riverTop + g.riverBottom) / 2 - 48,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _banner ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Palette.card,
                border: Border.all(color: Palette.ink, width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${level.id}  ${t.world(level.world)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.ink)),
                const SizedBox(height: 4),
                Text(_resumed ? '${t.resumed}${t.sep}${t.tripsCount(s.trips)}' : t.startGoal(level.par),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.goldDeep)),
              ]),
            ),
          ),
        ),
      );

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
  /// 舟の1席の幅。定員ぶんが船体に収まるようにする。
  double get seatW => math.min(s * 0.82, (boatW - s * 0.3) / level.capacity);

  Offset personPos(Session sess, Person p, Offset? boatOverride) {
    if (p.aboard) {
      final top = boatOverride ?? boatAt(sess.boat);
      final riders = sess.aboard;
      var x = top.dx - level.capacity * seatW / 2;
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
  _ScenePainter(this.g, this.t, this.th) : super(repaint: t);
  final _Geo g;
  final Animation<double> t;
  final SceneTheme th;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    // 川
    c.drawRect(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom), Paint()..color = th.river);
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [th.riverDeep.withValues(alpha: 0.6), th.river.withValues(alpha: 0), th.river.withValues(alpha: 0), th.riverDeep.withValues(alpha: 0.6)],
        stops: const [0, 0.15, 0.85, 1],
      ).createShader(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom));
    c.drawRect(Rect.fromLTRB(0, g.riverTop, w, g.riverBottom), edge);
    // 8. ときどき魚が跳ねる（6秒に1回、場所は回ごとに変える）
    final now = DateTime.now().millisecondsSinceEpoch;
    final cycle = now ~/ 6000;
    final ph = (now % 6000) / 6000;
    if (t.isAnimating && ph < 0.18) {
      final k = ph / 0.18;
      final fr = math.Random(cycle);
      final x0 = w * (0.15 + fr.nextDouble() * 0.6);
      final y0 = g.riverTop + 20 + fr.nextDouble() * (g.riverBottom - g.riverTop - 40);
      final fx = x0 + k * 34, fy = y0 - math.sin(k * math.pi) * 22;
      c.save();
      c.translate(fx, fy);
      c.rotate(-math.cos(k * math.pi) * 0.9);
      final fish = Paint()..color = th.riverDeep.withValues(alpha: 0.85);
      c.drawOval(const Rect.fromLTWH(-8, -3.5, 16, 7), fish);
      c.drawPath(Path()..moveTo(-7, 0)..lineTo(-13, -4)..lineTo(-13, 4)..close(), fish);
      c.restore();
      if (k > 0.85) c.drawOval(Rect.fromCenter(center: Offset(x0 + 34, y0 + 2), width: 18, height: 5), Paint()..color = Colors.white.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    // 流れ（左から右へ流れる白い筋）
    // 夜は川面に星を映す
    if (th.stars) {
      final sr = math.Random(11);
      for (var i = 0; i < 26; i++) {
        final p = Offset(sr.nextDouble() * w, g.riverTop + 6 + sr.nextDouble() * (g.riverBottom - g.riverTop - 12));
        final tw = 0.35 + 0.35 * math.sin((t.value + i * 0.13) * math.pi * 2).abs();
        c.drawCircle(p, 1 + sr.nextDouble() * 1.2, Paint()..color = Colors.white.withValues(alpha: tw));
      }
    }
    final wave = Paint()..color = Colors.white.withValues(alpha: th.wave);
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final y = g.riverTop + 10 + rnd.nextDouble() * (g.riverBottom - g.riverTop - 20);
      final speed = 0.5 + rnd.nextDouble();
      final x = ((rnd.nextDouble() + t.value * speed) % 1.0) * (w + 60) - 30;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 18 + rnd.nextDouble() * 14, height: 3), const Radius.circular(2)), wave);
    }
    // 岸
    void bank(Rect r, bool top) {
      c.drawRect(r, Paint()..color = th.sand);
      final lip = top ? Rect.fromLTWH(0, r.bottom - 5, w, 5) : Rect.fromLTWH(0, r.top, w, 5);
      c.drawRect(lip, Paint()..color = th.sandEdge);
      final grass = top ? Rect.fromLTWH(0, 0, w, 14) : Rect.fromLTWH(0, r.bottom - 14, w, 14);
      c.drawRect(grass, Paint()..color = th.grass);
      c.drawRect(top ? Rect.fromLTWH(0, 14, w, 3) : Rect.fromLTWH(0, r.bottom - 17, w, 3), Paint()..color = th.grassDark);
    }

    bank(Rect.fromLTWH(0, 0, w, g.bankH), true);
    bank(Rect.fromLTWH(0, size.height - g.bankH, w, g.bankH), false);
    if (g.level.island) {
      final r = g.island;
      final rr = RRect.fromRectAndCorners(r, topRight: const Radius.circular(26), bottomRight: const Radius.circular(26));
      c.drawRRect(rr.inflate(4), Paint()..color = th.sandEdge);
      c.drawRRect(rr, Paint()..color = th.sand);
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
  bool shouldRepaint(_ScenePainter old) => old.g.size != g.size || old.g.level != g.level || old.th != th;
}

class _WakePainter extends CustomPainter {
  _WakePainter(this.v, this.up);
  final double v;
  final bool up;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * (1 - v * 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = up ? 6.0 + i * 11 : s.height - 6 - i * 11;
      final spread = s.width * (0.2 + i * 0.12);
      final path = Path()
        ..moveTo(s.width / 2 - spread, y + (up ? 6 : -6))
        ..quadraticBezierTo(s.width / 2, y, s.width / 2 + spread, y + (up ? 6 : -6));
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_WakePainter old) => old.v != v;
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.v);
  final double v;

  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final k = (v - i * 0.2).clamp(0.0, 1.0);
      if (k == 0) continue;
      c.drawOval(
        Rect.fromCenter(center: center, width: s.width * k, height: s.height * k),
        Paint()
          ..color = Colors.white.withValues(alpha: 1 - k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.v != v;
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
  const _TopBar({required this.title, required this.trips, required this.par, required this.stars, required this.onBack, required this.onRules});
  final String title;
  final int trips;
  final int par;

  /// 今のままなら取れる星の上限（最短を超えると減る。ヒントを使うと2まで）。
  final int stars;
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
                TweenAnimationBuilder<double>(
                  key: ValueKey(trips),
                  tween: Tween(begin: trips == 0 ? 1 : 1.35, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.centerRight, child: child),
                  child: Text(context.l10n.tripsCount(trips), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()])),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  StarRow(stars, size: 13),
                  const SizedBox(width: 4),
                  Text(context.l10n.par(par), style: const TextStyle(fontSize: 11, color: Palette.dim, fontWeight: FontWeight.w700)),
                ]),
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
                silent: true,
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

  factory _ResultCard.fail({required AppLocalizations t, required String message, required List<String> notes, required VoidCallback onReset}) => _ResultCard._(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.escaped, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Palette.bad)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.dim)),
            ..._noteChips(notes),
            const SizedBox(height: 16),
            ChunkyButton(label: t.restart, icon: Icons.refresh_rounded, color: Palette.gold, fontSize: 18, onPressed: onReset),
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
    required int? best,
    required bool newRecord,
    required List<String> notes,
    required int timeMs,
    required int? bestMs,
    required bool fastest,
    required bool hasNext,
    required bool isLast,
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
          _StarPop(stars),
          const SizedBox(height: 6),
          Text('${t.crossedIn(trips)}\n$note', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.dim)),
          if (best != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t.personalBest(best), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Palette.ink)),
              if (newRecord) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Palette.bad, borderRadius: BorderRadius.circular(99)),
                  child: Text(t.newRecord, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ]),
          ],
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t.timeLine(_clockText(timeMs)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Palette.ink)),
            if (bestMs != null && !fastest) ...[
              const SizedBox(width: 10),
              Text(t.bestTimeLine(_clockText(bestMs)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.dim)),
            ],
            if (fastest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Palette.bad, borderRadius: BorderRadius.circular(99)),
                child: Text(t.fastest, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ]),
          ..._noteChips(notes),
          const SizedBox(height: 16),
          if (hasNext) ChunkyButton(label: t.nextLevel, color: Palette.gold, fontSize: 18, onPressed: onNext),
          if (isLast) Text(t.allCleared(total), style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.ink)),
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
              constraints: BoxConstraints(maxWidth: 340, maxHeight: MediaQuery.sizeOf(context).height * 0.86),
              decoration: BoxDecoration(
                color: Palette.card,
                border: Border.all(color: Palette.ink, width: 2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 6))],
              ),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
}

/// 結果の札に添える知らせ（金色の札）。
String _clockText(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

List<Widget> _noteChips(List<String> notes) => [
      for (final n in notes) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1C2),
            border: Border.all(color: Palette.goldDeep, width: 1.5),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, size: 16, color: Palette.goldDeep),
            const SizedBox(width: 6),
            Flexible(child: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Palette.ink))),
          ]),
        ),
      ],
    ];

/// 6. 結果の札の星を、効果音に合わせて1つずつはじけるように出す。
class _StarPop extends StatefulWidget {
  const _StarPop(this.stars);
  final int stars;

  @override
  State<_StarPop> createState() => _StarPopState();
}

class _StarPopState extends State<_StarPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return StarRow(widget.stars, size: 44);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Transform.scale(
            // 結果の札が出てから 550ms＋220ms ずつ（Sfx.star と同じ間隔）
            scale: i >= widget.stars
                ? 1
                : Curves.elasticOut.transform(((_c.value * 1400 - 250 - i * 220) / 450).clamp(0.0, 1.0)),
            child: Icon(Icons.star_rounded, size: 44, color: i < widget.stars ? Palette.gold : Palette.starOff),
          ),
      ]),
    );
  }
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
