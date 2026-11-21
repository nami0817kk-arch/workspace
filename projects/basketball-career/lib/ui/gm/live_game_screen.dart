import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../gm/career.dart';
import '../../gm/combos.dart';
import '../../gm/policy.dart';
import '../../gm/game_review.dart';
import '../../gm/game_sim.dart';
import '../../gm/player.dart';
import 'box_score.dart';
import 'common.dart';
import 'live_court.dart';
import 'live_playback.dart';
import 'style.dart';

/// 次の自分の試合を見ながら采配する。区切りの間は、コートで10人とボールが動いて流れて見える(2026-11-21)。
/// 指示と交代ができるのは、クォーターの区切り(1Q・前半・3Qの終わり)と、自分でタイムアウトを取ったときだけ
/// (2026-11-21、ユーザー「タイムアウトとQごとに指示できる」)。
/// 確定すると、選んだ采配のリストを返す(呼ぶ側でその節を進める)。やめたら null。
Future<List<LiveCall>?> showLiveGame(BuildContext context, Career car) =>
    Navigator.of(context).push<List<LiveCall>>(MaterialPageRoute(builder: (_) => LiveGameScreen(car: car)));

/// 見せる速さ(倍)。最後は「結果だけ」(動かさずに区切りまで飛ばす)。
const _speeds = [1.0, 2.2, 6.0, 0.0];
const _speedNames = ['じっくり', 'ふつう', '速く', '結果だけ'];

/// 選んだ速さ(アプリを開いている間は覚えておく)。
int _speedPick = 1;

class LiveGameScreen extends StatefulWidget {
  const LiveGameScreen({super.key, required this.car});
  final Career car;

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen> with SingleTickerProviderStateMixin {
  final calls = <LiveCall>[];

  /// 1度でも先へ進めたか(1Qを見ただけなら、やめられる)。
  bool _started = false;

  /// 試合前の相手の調べを見終えて、試合を始めたか(試合画面の向上 3)。
  bool _go = false;

  /// 「ここからは任せて最後まで」を押したか。
  bool _toEnd = false;

  /// タイムアウトを取って止めているか(続けると、タイムアウトを1回使う)。
  bool _inTimeout = false;
  GameCall? picked;

  /// 交代で決めているコートの5人(止まっている間だけ)と、入れ替えようと選んだコートの1人。
  List<int>? _court;
  List<int> _courtAtStop = const [];
  int? _swapOut;
  SimResult? res;

  // --- 流して見せる
  late final Ticker _ticker;
  PlaybackBuilder? _builder;
  PossessionScript? _script;

  /// いま見せている攻めの番号と、その中の時刻(ミリ秒)。
  int _cur = 0;
  double _t = 0;
  Duration _last = Duration.zero;
  Map<Who, Offset>? _endPos;
  final _frame = ValueNotifier<CourtFrame?>(null);
  final _clock = ValueNotifier<String>('');
  final _marks = <Cue>[];
  final _log = <(String, bool)>[];
  int _homePts = 0, _awayPts = 0;
  int _appliedCues = 0;
  Who? _selected;

  /// ふりかえりの流れの線で押した印のひとこと。
  String? _mark;

  Career get car => widget.car;
  bool get _playing => res != null && _cur < res!.events.length;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _run();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// いまの時刻(止まっていればその時刻、はじめは試合の始め)。
  LiveStop get _now => res?.stop ?? (0, 720);

  /// [now] より後の、次のクォーターの区切り(無ければ null = 最後まで)。
  LiveStop? _nextBreak(LiveStop now) {
    for (var k = 0; k < liveBreaks.length; k++) {
      final s = breakStop(k);
      if (s.$1 > now.$1 || (s.$1 == now.$1 && s.$2 < now.$2)) return s;
    }
    return null;
  }

  bool _isBreak(LiveStop s) => [for (var k = 0; k < liveBreaks.length; k++) breakStop(k)].contains(s);

  /// 止まっている所の名前(「前半終了」「タイムアウト 3Q 4:12」)。
  String _stopName(LiveStop s) {
    for (var k = 0; k < liveBreaks.length; k++) {
      if (breakStop(k) == s) return liveBreaks[k];
    }
    return 'タイムアウト ${clockText(s.$1, s.$2)}';
  }

  void _run({LiveStop? stopAt}) {
    final target = stopAt ?? (_toEnd ? null : _nextBreak(_now));
    res = car.previewLive(calls, target);
    final r = res;
    if (r == null) return;
    _builder = PlaybackBuilder(
      events: r.events,
      names: (w) => _team(w).order[w.$2].name,
      poss: (w) => _team(w).order[w.$2].pos,
    );
    _startScript();
    if (!_go) {
      // 始める前は、最初の攻めの持ち場に並んだところを見せる
      final sc = _script;
      if (sc != null) _frame.value = sc.frameAt(math.min(700, sc.duration));
      _clock.value = '試合前';
      return;
    }
    if (_speeds[_speedPick] == 0) {
      _skip();
    } else if (_playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  SimTeam _team(Who w) => w.$1 == 0 ? res!.home : res!.away;

  void _startScript() {
    final r = res!;
    if (_cur >= r.events.length) {
      _script = null;
      // 得点板の時計は短く(区切りの名前か、止めた時刻)。タイムアウトの印は右の欄の見出しに出す
      final st = r.stop;
      _clock.value = st == null ? '試合終了' : (_isBreak(st) ? _stopName(st) : clockText(st.$1, st.$2));
      _prepareStop();
      return;
    }
    _script = _builder!.build(_cur, _endPos);
    _appliedCues = 0;
    _t = 0;
    final prev = _cur > 0 ? r.events[_cur - 1] : null;
    _homePts = prev?.homePts ?? 0;
    _awayPts = prev?.awayPts ?? 0;
    _frame.value = _script!.frameAt(0);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    final s = _script;
    if (s == null) {
      _ticker.stop();
      return;
    }
    _t += math.min(dt, 100) * _speeds[_speedPick] * (s.big ? 0.5 : 1);
    var changed = _applyCues(s);
    if (_t >= s.duration) {
      _finishScript(s);
      _cur++;
      _startScript();
      changed = true;
      if (!_playing) _ticker.stop();
    } else {
      _frame.value = s.frameAt(_t.round());
    }
    final e = _cur < res!.events.length ? res!.events[_cur] : null;
    if (e != null && _script != null) {
      final u = (_t / math.max(1, _script!.duration)).clamp(0.0, 1.0);
      _clock.value = clockText(e.period, (e.clockStart - (e.clockStart - e.clockEnd) * u).round());
    }
    if (changed) setState(() {});
  }

  bool _applyCues(PossessionScript s) {
    var changed = false;
    while (_appliedCues < s.cues.length && s.cues[_appliedCues].t <= _t) {
      final c = s.cues[_appliedCues++];
      switch (c.kind) {
        case CueKind.score:
          if (c.side == 0) {
            _homePts += c.points;
          } else {
            _awayPts += c.points;
          }
        case CueKind.mark:
          _marks.add(c);
      }
      changed = true;
    }
    return changed;
  }

  void _finishScript(PossessionScript s) {
    _t = s.duration.toDouble();
    _applyCues(s);
    _endPos = s.end;
    _frame.value = s.frameAt(s.duration);
    final e = res!.events[_cur];
    _homePts = e.homePts;
    _awayPts = e.awayPts;
    // 相手が方針を切り替えたクォーターに入ったら、知らせる
    final prev = _cur > 0 ? res!.events[_cur - 1] : null;
    if (prev != null && prev.period != e.period) {
      for (final (q, k, text) in res!.switches) {
        if (q == e.period && k == _oppSide) _log.insert(0, ('${clockText(q, q < 4 ? 720 : 300)}  相手が方針を切り替えた: $text', true));
      }
    }
    // 得点板と同じく、左がアウェー・右がホーム
    _log.insert(0, ('${clockText(e.period, e.clockEnd)}  ${s.line}  $_awayPts-$_homePts', s.big));
    if (_log.length > 30) _log.removeLast();
  }

  /// 区切りまで飛ばす(残りの攻めを、動かさずに数えきる)。
  void _skip() {
    final r = res!;
    while (_script != null && _cur < r.events.length) {
      _finishScript(_script!);
      _cur++;
      _startScript();
    }
    _ticker.stop();
    if (mounted) setState(() {});
  }

  int get _timeoutsLeft => liveTimeouts - calls.where((c) => c.timeout).length - (_inTimeout ? 1 : 0);

  SimTeam get _me => car.nextMyGame!.$1 == car.mine ? res!.home : res!.away;

  /// 止まったときに、交代の欄をいまのコートの5人で用意する。
  void _prepareStop() {
    final r = res;
    if (r == null || r.finished) return;
    _courtAtStop = [..._me.court]..sort();
    _court = List.of(_courtAtStop);
    _swapOut = null;
  }

  /// タイムアウトを取る(いま見せている攻めを終えたところで止める)。
  void _timeout() {
    final r = res!;
    final s = _script;
    if (s == null || _cur >= r.events.length || _timeoutsLeft <= 0) return;
    final e = r.events[_cur];
    _finishScript(s);
    _cur++;
    _ticker.stop();
    setState(() {
      _inTimeout = true;
      _run(stopAt: (e.period, e.clockEnd));
      // 試合の最後の攻めだったなら、タイムアウトは取らずに終わる
      if (res!.finished) _inTimeout = false;
    });
  }

  void _next({bool toEnd = false}) {
    setState(() {
      final st = res!.stop;
      if (st != null) {
        final court = _court;
        final changed = court != null && !(court.length == _courtAtStop.length && court.toSet().containsAll(_courtAtStop));
        if (picked != null || changed || _inTimeout) {
          calls.add(LiveCall(period: st.$1, clock: st.$2, call: picked, timeout: _inTimeout, five: changed ? List.of(court) : null));
        }
      }
      picked = null;
      _inTimeout = false;
      _court = null;
      _started = true;
      if (toEnd) _toEnd = true;
      _run();
    });
  }

  /// 采配の1行(「前半終了: 外から打つ・交代」)。
  String _callLine(LiveCall c) => [
        '${_stopName((c.period, c.clock))}:',
        if (c.call != null) c.call!.label,
        if (c.five != null) '交代',
        if (c.call == null && c.five == null) '流れを切る',
      ].join(' ');

  @override
  Widget build(BuildContext context) {
    final g = car.nextMyGame;
    final r = res;
    if (g == null || r == null) {
      return Scaffold(appBar: AppBar(title: const Text('試合の采配')), body: const Center(child: Text('采配できる試合がない')));
    }
    final home = car.teams[g.$1], away = car.teams[g.$2];
    final mineHome = g.$1 == car.mine;
    return PopScope(
      canPop: !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(List<LiveCall>.of(calls));
      },
      child: _page(context, home.def.short, away.def.short, r, g.$1, g.$2, mineHome),
    );
  }

  /// ここまで見せた分の、クォーターごとの点。
  (List<int>, List<int>) _periods(SimResult r) {
    final h = <int>[], a = <int>[];
    var ph = 0, pa = 0;
    for (var i = 0; i < _cur && i < r.events.length; i++) {
      final e = r.events[i];
      while (h.length <= e.period) {
        h.add(0);
        a.add(0);
      }
      h[e.period] += e.homePts - ph;
      a[e.period] += e.awayPts - pa;
      ph = e.homePts;
      pa = e.awayPts;
    }
    return (h, a);
  }

  /// 流れの見出し(続けて8点以上取ったラン・終盤の逆転)。
  (String, Color)? _headline(SimResult r, String homeName, String awayName, bool mineHome) {
    final run = runOf(r.events, _cur);
    if (run.$2 >= 8) {
      final mine = (run.$1 == 0) == mineHome;
      return ('${run.$1 == 0 ? homeName : awayName}が${run.$2}-0のラン', mine ? GmColors.good : GmColors.bad);
    }
    if (_log.isNotEmpty && _log.first.$2) return (_log.first.$1.split('  ')[1], GmColors.gold);
    return null;
  }

  Widget _page(BuildContext context, String homeName, String awayName, SimResult r, int homeId, int awayId, bool mineHome) {
    final my = mineHome ? _homePts : _awayPts, opp = mineHome ? _awayPts : _homePts;
    final diff = my - opp;
    final done = r.finished && !_playing;
    final per = _periods(r);
    final shownEvent = _cur < r.events.length ? r.events[_cur] : (r.events.isEmpty ? null : r.events.last);
    final minute = shownEvent == null ? 0 : minuteOf(shownEvent.period, _cur < r.events.length ? shownEvent.clockStart : shownEvent.clockEnd);
    final flow = [for (final d in r.flow.take(minute)) mineHome ? d : -d];
    final head = _headline(r, homeName, awayName, mineHome);
    final hc = colorOf(homeId).jersey, ac = colorOf(awayId).jersey;
    return Scaffold(
      appBar: AppBar(
        title: Text('$awayName @ $homeName', style: const TextStyle(fontSize: 16)),
        // 1Qを見ただけなら、やめられる。采配を始めたあとに閉じると、残りは任せて進める(結果を見てからやり直せないように)
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: !_started ? 'やめる' : '残りを任せて進める',
          onPressed: () => Navigator.of(context).pop(!_started ? null : List<LiveCall>.of(calls)),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
                children: [
                  LiveScoreboard(
                    home: homeId,
                    away: awayId,
                    homeName: homeName,
                    awayName: awayName,
                    homePts: _homePts,
                    awayPts: _awayPts,
                    homePeriods: per.$1,
                    awayPeriods: per.$2,
                    mineHome: mineHome,
                    clock: _clock,
                    headline: head?.$1,
                    headlineColor: head?.$2 ?? GmColors.gold,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CourtView(
                      key: const Key('moving-court'),
                      frame: _frame,
                      marks: List.of(_marks),
                      homeColor: hc,
                      awayColor: ac,
                      number: (w) => jerseyOf(_team(w).order[w.$2]),
                      mineSide: mineHome ? 0 : 1,
                      selected: _selected,
                      onTap: (w) => setState(() => _selected = w == _selected ? null : w),
                    ),
                  ),
                  if (_selected != null) _playerLine(r, _selected!),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: ListView(
                // 見ている・止まった・終わったで、いつも上から見せる(止まるたびに、指示の欄の頭から)
                key: ValueKey(_playing ? 'watch' : done ? 'done' : 'stop-${r.stop}'),
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 12),
                children: [
                  ...(!_go ? _scouting(r) : _playing ? _watching() : (done ? _finish(r, diff, mineHome, homeId, awayId) : _choices())),
                  if (_go && !done) ...[const SizedBox(height: 6), _oppNow(r)],
                  if (_go && !_playing && !done) _oppSoFar(r),
                  const SizedBox(height: 10),
                  if (!_playing && !done)
                    Text('${_stopName(r.stop!)}・${diff > 0 ? '$diff点リード' : diff < 0 ? '${-diff}点ビハインド' : '同点'}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: diff > 0 ? GmColors.good : diff < 0 ? GmColors.bad : GmColors.text)),
                  const Text('試合の流れ(上が自分のリード)', style: TextStyle(fontSize: 11, color: GmColors.sub)),
                  const SizedBox(height: 2),
                  MomentumBar(
                    diff: flow,
                    marks: done ? flowMarksOf(r, calls, _callLine) : const [],
                    onMark: (t) => setState(() => _mark = t),
                  ),
                  if (done && _mark != null) Text(_mark!, style: const TextStyle(fontSize: 12, color: GmColors.gold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  for (final l in _log.take(6))
                    Text(l.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.5, color: l.$2 ? GmColors.gold : GmColors.text, fontWeight: l.$2 ? FontWeight.bold : null)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 押した選手の、今日のここまで。
  Widget _playerLine(SimResult r, Who w) {
    final p = _team(w).order[w.$2];
    final d = todayOf(r.events, _cur, w);
    final min = d.secs ~/ 60;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '#${jerseyOf(p)} ${p.name}(${p.pos.short})  ${d.pts}点・${d.reb}リバウンド・${d.ast}アシスト・出場$min分${min >= 30 ? '・疲れが出てきた' : ''}',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  int get _mySide => car.nextMyGame!.$1 == car.mine ? 0 : 1;
  int get _oppSide => 1 - _mySide;
  int get _oppTeam => _mySide == 0 ? car.nextMyGame!.$2 : car.nextMyGame!.$1;

  static String _choiceName(PolicyAxis a, int c) => a.options[c.clamp(0, 2)];

  /// 相手の方針が前から分かっているか(今季もう対戦した)。
  bool get _oppKnown => (car.h2h[_oppTeam]?.take(2).fold<int>(0, (s, x) => s + x) ?? 0) > 0;

  /// 試合前の相手の調べ(試合画面の向上 3)。よく使う方針・中心の型・相性・慣れ。ここで方針を変えてから始められる。
  List<Widget> _scouting(SimResult r) {
    final them = car.teams[_oppTeam];
    final roles = {for (final p in them.order.take(5)) roleOf(p)};
    final known = _oppKnown;
    const head = TextStyle(fontSize: 12, color: GmColors.sub, fontWeight: FontWeight.bold);
    final my = car.me.policy, their = them.policy;
    // 分かっている相性のうち、いまの方針どうしで効くもの
    final hints = <(String, bool)>[];
    final found = car.matchupsFound;
    void hint(Matchup m, bool mineAttacks) {
      if (found.contains(m)) hints.add((m.label, (m.edge > 0) == mineAttacks));
    }

    if (known) {
      final tp = their[PolicyAxis.defense.index], mf = my[PolicyAxis.focus.index], ms = my[PolicyAxis.passing.index];
      if (tp == 0 && mf == 2) hint(Matchup.packVsInside, true);
      if (tp == 0 && mf == 0) hint(Matchup.packVsOutside, true);
      if (tp == 2 && ms == 0) hint(Matchup.pressVsAce, true);
      if (tp == 2 && ms == 2) hint(Matchup.pressVsPass, true);
      final md = my[PolicyAxis.defense.index], tf = their[PolicyAxis.focus.index], ts = their[PolicyAxis.passing.index];
      if (md == 0 && tf == 2) hint(Matchup.packVsInside, false);
      if (md == 0 && tf == 0) hint(Matchup.packVsOutside, false);
      if (md == 2 && ts == 0) hint(Matchup.pressVsAce, false);
      if (md == 2 && ts == 2) hint(Matchup.pressVsPass, false);
    }
    Widget pick(PolicyAxis a) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            SizedBox(width: 78, child: Text(a.label, style: const TextStyle(fontSize: 11.5, color: GmColors.sub))),
            for (var c = 0; c < 3; c++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  key: ValueKey('scout-${a.index}-$c'),
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  label: Text(a.options[c], style: const TextStyle(fontSize: 11)),
                  selected: car.me.policy[a.index] == c,
                  onSelected: (_) => setState(() => car.setPolicy(a.index, c)),
                ),
              ),
          ]),
        );
    return [
      const Text('試合前の相手の調べ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('相手のよく使う方針', style: head),
      Text(
        known
            ? [for (final a in [PolicyAxis.pace, PolicyAxis.focus, PolicyAxis.passing, PolicyAxis.defense]) '${a.label}: ${_choiceName(a, their[a.index])}'].join('・')
            : '？(今季まだ対戦していない。試合が進むと打ち方から見えてくる)',
        style: const TextStyle(fontSize: 12.5, height: 1.4),
      ),
      const SizedBox(height: 4),
      const Text('相手の中心の型(先発)', style: head),
      Text(roles.map((x) => x.label).join('・'), style: const TextStyle(fontSize: 12.5)),
      if (hints.isNotEmpty) ...[
        const SizedBox(height: 4),
        const Text('分かっている相性(図鑑)', style: head),
        for (final (t, good) in hints)
          Text('${good ? '有利' : '不利'}: $t', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: good ? GmColors.good : GmColors.bad)),
      ],
      const SizedBox(height: 4),
      Text('慣れ: +${car.familiarity.toStringAsFixed(1)}(方針を変えずに${car.policyGames}試合。変えるとゼロから)', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 4),
      const Text('こちらの方針(合わせるか、通すか)', style: head),
      pick(PolicyAxis.focus),
      pick(PolicyAxis.defense),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('live-start'),
        onPressed: () => setState(() {
          _go = true;
          _run();
        }),
        icon: const Icon(Icons.sports_basketball_rounded),
        label: const Text('試合を始める'),
      ),
    ];
  }

  /// 相手の今の方針(試合中。見た攻めから)。
  Widget _oppNow(SimResult r) {
    PlayEvent? att, dfn;
    var seen = 0;
    for (var i = 0; i < _cur && i < r.events.length; i++) {
      final e = r.events[i];
      if (e.side == _oppSide) {
        att = e;
        seen++;
      } else {
        dfn = e;
      }
    }
    if (att == null || dfn == null || (!_oppKnown && seen < 6)) {
      return const Text('相手の方針: 見ているところ', style: TextStyle(fontSize: 12, color: GmColors.sub));
    }
    return Text(
      '相手の今の方針: ${_choiceName(PolicyAxis.focus, att.focus)}・${_choiceName(PolicyAxis.passing, att.share)}・${_choiceName(PolicyAxis.pace, att.pace)}・守りは${_choiceName(PolicyAxis.defense, dfn.press)}',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.gold),
    );
  }

  /// 止まったときの、ここまでの相手の攻め方。
  Widget _oppSoFar(SimResult r) {
    var shots = 0, threes = 0, made = 0, tov = 0;
    for (var i = 0; i < _cur && i < r.events.length; i++) {
      final e = r.events[i];
      if (e.side != _oppSide) continue;
      for (final s in e.steps) {
        if (s.kind == PlayStepKind.shot && !(s.fouled && !s.made)) {
          shots++;
          if (s.three) threes++;
          if (s.made) made++;
        }
        if (s.kind == PlayStepKind.turnover) tov++;
      }
    }
    if (shots == 0) return const SizedBox.shrink();
    return Text(
      'ここまでの相手: シュート$shots本(3ポイント$threes本・${(threes * 100 / shots).round()}%)・入った${(made * 100 / shots).round()}%・ミス$tov',
      style: const TextStyle(fontSize: 12, height: 1.4),
    );
  }

  /// 流れている間(速さと、区切りまで飛ばす)。
  List<Widget> _watching() {
    final to = _toEnd ? null : _nextBreak(_now);
    return [
        Text(to != null ? '${_stopName(to)}まで見ている' : '最後まで見ている', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const Text('丸の数字は背番号。金の縁が自分のチーム。押すと今日の数字', style: TextStyle(fontSize: 11.5, color: GmColors.sub, height: 1.4)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < _speeds.length; i++)
            ChoiceChip(
              // 采配の選択肢と取り違えないよう、印を別にする(同じ場所の選択肢に、速さの印が一瞬残って見えた)
              key: ValueKey('speed-$i'),
              label: Text(_speedNames[i], style: const TextStyle(fontSize: 12.5)),
              selected: _speedPick == i,
              onSelected: (_) {
                setState(() => _speedPick = i);
                if (_speeds[i] == 0) _skip();
              },
            ),
        ]),
        const SizedBox(height: 10),
        // タイムアウト: 押すと、いまの攻めが終わったところで止まり、指示と交代ができる
        FilledButton.icon(
          key: const Key('live-timeout'),
          onPressed: _timeoutsLeft > 0 ? _timeout : null,
          icon: const Icon(Icons.pan_tool_rounded),
          label: Text(_timeoutsLeft > 0 ? 'タイムアウト(あと$_timeoutsLeft回)' : 'タイムアウトは使いきった'),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _skip,
          icon: const Icon(Icons.fast_forward_rounded),
          label: Text(to != null ? '${_stopName(to)}まで飛ばす' : '最後まで飛ばす'),
        ),
        if (calls.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('これまでの采配: ${calls.map(_callLine).join(' / ')}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        ],
      ];
  }

  List<Widget> _choices() {
    final st = res!.stop!;
    final to = _nextBreak(st);
    return [
      Text('${_inTimeout ? '' : '采配 '}${_stopName(st)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      Text(_inTimeout ? '続けると、3分のあいだ少し強くなる(流れを切る)。' : 'タイムアウトはあと$_timeoutsLeft回(試合の途中で押す)。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 6),
      const Text('指示(選ばなければ、そのまま)', style: TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in GameCall.values)
          ChoiceChip(
            key: ValueKey(c),
            label: Text(c.label, style: const TextStyle(fontSize: 12.5)),
            selected: picked == c,
            onSelected: (on) => setState(() => picked = on ? c : null),
          ),
      ]),
      if (picked != null) ...[
        const SizedBox(height: 4),
        Text(picked!.help, style: const TextStyle(fontSize: 12.5, height: 1.4)),
      ],
      const SizedBox(height: 10),
      ..._subs(),
      if (calls.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('これまでの采配: ${calls.map(_callLine).join(' / ')}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ],
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('live-next'),
        onPressed: () => _next(),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(to != null ? '${_stopName(to)}まで見る' : '最後まで見る'),
      ),
      TextButton(onPressed: () => _next(toEnd: true), child: const Text('ここからは任せて最後まで')),
    ];
  }

  /// 交代: コートの5人とベンチ。コートの1人を押してから、ベンチの1人を押すと入れ替わる。
  List<Widget> _subs() {
    final me = _me;
    final court = _court ?? _courtAtStop;
    final bench = [
      for (var i = 0; i < me.order.length; i++)
        if (me.mins[i] > 0 && !court.contains(i)) i,
    ];
    Widget chip(int i, {required bool onCourt}) {
      final p = me.order[i];
      final min = me.secs[i] ~/ 60;
      final tired = min >= 30;
      final sel = onCourt && _swapOut == i;
      return ChoiceChip(
        key: ValueKey('sub-$i'),
        showCheckmark: false,
        selected: sel,
        label: Text('#${jerseyOf(p)} ${p.name.split('・').last} ${p.pos.short} $min分 ${ptsAt(me, i)}点${tired ? ' 疲れ' : ''}',
            style: TextStyle(fontSize: 11.5, color: tired ? GmColors.bad : null)),
        onSelected: (_) => setState(() {
          if (onCourt) {
            _swapOut = sel ? null : i;
          } else if (_swapOut != null) {
            final c = List.of(court);
            c[c.indexOf(_swapOut!)] = i;
            _court = c..sort();
            _swapOut = null;
          }
        }),
      );
    }

    return [
      Text(_swapOut == null ? '交代: コートの選手を押して、次にベンチの選手を押す' : 'ベンチから入れる選手を押す', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 4),
      const Text('コートの5人', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: GmColors.gold)),
      const SizedBox(height: 2),
      Wrap(spacing: 4, runSpacing: 4, children: [for (final i in court) chip(i, onCourt: true)]),
      const SizedBox(height: 6),
      const Text('ベンチ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: GmColors.sub)),
      const SizedBox(height: 2),
      Wrap(spacing: 4, runSpacing: 4, children: [for (final i in bench) chip(i, onCourt: false)]),
    ];
  }

  /// 試合のあとのふりかえり: 勝因・敗因、采配の効き目、両チームの主役(2026-11-21、試合画面の向上 4)。
  List<Widget> _finish(SimResult r, int diff, bool mineHome, int homeId, int awayId) {
    final side = mineHome ? 0 : 1;
    final reasons = reasonsOf(r, side);
    final effects = callEffectsOf(r, calls, side);
    final stars = starsOf(r, side);
    const head = TextStyle(fontSize: 12, color: GmColors.sub, fontWeight: FontWeight.bold);
    String star((String, int, int, int) s) => '${s.$1}  ${s.$2}点・${s.$3}リバウンド・${s.$4}アシスト';
    return [
        Text('${diff > 0 ? '勝った' : '負けた'}  ${mineHome ? r.home.pts : r.away.pts}-${mineHome ? r.away.pts : r.home.pts}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: diff > 0 ? GmColors.good : GmColors.bad)),
        const SizedBox(height: 6),
        Text(diff > 0 ? '勝因' : '敗因', style: head),
        for (final x in reasons) Text('・${x.text}', style: const TextStyle(fontSize: 13, height: 1.5)),
        if (reasons.isEmpty) const Text('・大きな差は無かった', style: TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 6),
        const Text('采配の効き目(その後3分の点)', style: head),
        if (effects.isEmpty) const Text('采配はしなかった', style: TextStyle(fontSize: 13, height: 1.5)),
        for (final e in effects)
          Text('${_callLine(e.call)}  ${e.mine}-${e.theirs}(${e.diff > 0 ? '+' : ''}${e.diff})',
              style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold, color: e.diff > 0 ? GmColors.good : e.diff < 0 ? GmColors.bad : GmColors.text)),
        // この試合の発見(この試合で分かる組み合わせと方針の相性。B-3 の図鑑に載る)
        ...() {
          final me = side == 0 ? r.home : r.away;
          final found = [
            for (final x in Combo.values)
              if (car.comboSecs[x.index] < comboDiscoverSecs && car.comboSecs[x.index] + me.comboSecs[x.index] >= comboDiscoverSecs) '組み合わせ: ${x.label}',
            for (final x in Matchup.values)
              if (car.matchupSeen[x.index] < Career.matchupDiscoverCount && car.matchupSeen[x.index] + me.matchups[x.index] >= Career.matchupDiscoverCount) '相性: ${x.label}',
          ];
          if (found.isEmpty) return const <Widget>[];
          return [
            const SizedBox(height: 6),
            const Text('この試合の発見(図鑑に載る)', style: head),
            for (final f in found) Text(f, style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold, color: GmColors.gold)),
          ];
        }(),
        const SizedBox(height: 6),
        const Text('この試合の主役', style: head),
        Text('自分: ${star(stars.$1)}', style: const TextStyle(fontSize: 13, height: 1.5)),
        Text('相手: ${star(stars.$2)}', style: const TextStyle(fontSize: 13, height: 1.5, color: GmColors.sub)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showBoxScore(context, reviewResultOf(r, car.teams[homeId], car.teams[awayId], car.mine), car.mine),
          icon: const Icon(Icons.table_chart_rounded),
          label: const Text('ボックススコアを見る'),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(List<LiveCall>.of(calls)),
          icon: const Icon(Icons.check_rounded),
          label: const Text('この結果で進める'),
        ),
        const SizedBox(height: 4),
        const Text('進めると、この節のほかの試合も終わる。流れの線の印(金は采配・白は逆転)を押すと、その場面が出る。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
      ];
  }
}
