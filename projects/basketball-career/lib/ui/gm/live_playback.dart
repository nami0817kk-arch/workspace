import 'dart:math' as math;
import 'dart:ui';

import '../../gm/game_sim.dart';
import '../../gm/player.dart';

/// 采配の画面で、試合を「流して」見せるための動き(2026-11-21、ユーザー「コートに選手マークつけて動くようにしたい。試合がわかるように」「パスとか」)。
///
/// 試合の結果は [simulateGame] がもう決めている。ここでは、記録した攻めごとの出来事([PlayEvent])から、
/// 10人とボールの動きを作るだけ(見せ方のための乱数は、攻めの番号から決める。試合の乱数は使わない)。
/// 長さはメートル。コートは 28×15、ホームは左のゴール、アウェーは右のゴールを攻める。

const courtLen = 28.0;
const courtWid = 15.0;

/// 選手のしるし(チーム 0 ホーム・1 アウェーと、order の番号)。
typedef Who = (int, int);

/// ベンチ(交代で出入りする場所。下のサイドラインの外)。
const benchSpot = Offset(courtLen / 2, courtWid + 0.7);

/// [side] が攻めるゴール。
Offset basketOf(int side) => side == 0 ? const Offset(1.6, courtWid / 2) : const Offset(courtLen - 1.6, courtWid / 2);

/// 左のゴールを攻めるときの位置 [p] を、[side] の向きに直す。
Offset _toSide(int side, Offset p) => side == 0 ? p : Offset(courtLen - p.dx, p.dy);

/// 攻めの5つの持ち場(左のゴールを攻めるとき)。ポジションの順に、トップ・右のウイング・左のウイング・ひじ・ゴール下。
/// 攻めの重点で変わる: 外のシュートなら角(コーナー)まで広がり、中の得点なら大きい2人がゴール下に構える。
const _slotsByFocus = [
  // 外のシュート: トップ・両ウイングを広く、パワーフォワードは角、センターは高い位置(ゴール下を空ける)
  [Offset(9.4, 7.5), Offset(7.4, 1.8), Offset(7.4, 13.2), Offset(1.2, 14.0), Offset(5.9, 3.6)],
  // バランス
  [Offset(8.8, 7.5), Offset(6.6, 2.4), Offset(6.6, 12.6), Offset(4.6, 10.2), Offset(2.5, 5.6)],
  // 中の得点: 外の3人は近く、大きい2人はゴール下の両側
  [Offset(8.0, 7.5), Offset(5.8, 3.0), Offset(5.8, 12.0), Offset(2.4, 9.6), Offset(2.4, 5.4)],
];

/// 見せ方の乱数(攻めの番号と、何回目に引くかから決める)。0〜1。
double _hash(int a, int b) {
  var x = (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995;
  x = (x ^ (x >> 13)) * 0x5bd1e995 & 0x7fffffff;
  x ^= x >> 15;
  return (x & 0xffff) / 0xffff;
}

/// ある時刻の、10人とボールの位置。
class CourtFrame {
  CourtFrame(this.pos, this.alpha, this.ball, this.lift, this.holder);
  final Map<Who, Offset> pos;

  /// 交代で下がる選手は薄くなる(1 はふつう)。
  final Map<Who, double> alpha;
  final Offset ball;

  /// ボールの高さ(0〜1。シュートとパスの弧)。
  final double lift;
  final Who? holder;
}

/// 動きのひと区間。[carrier] がいれば、ボールはその選手が持つ(ドリブル)。いなければ [ballFrom] から [ballTo] へ飛ぶ。
class _Seg {
  _Seg(this.t0, this.t1, this.from, this.to, {this.carrier, this.ballFrom = Offset.zero, this.ballTo = Offset.zero, this.arc = 0, this.fade = const {}});
  final int t0, t1;
  final Map<Who, Offset> from, to;
  final Who? carrier;
  final Offset ballFrom, ballTo;
  final double arc;

  /// この区間で消えていく選手(交代)。
  final Set<Who> fade;
}

/// 時刻つきの出来事(点が入る・ネットが揺れる・シュートの場所の印・実況の1行)。
class Cue {
  Cue.score(this.t, this.side, this.points)
      : kind = CueKind.score,
        at = Offset.zero,
        made = false;
  Cue.mark(this.t, this.side, this.at, this.made)
      : kind = CueKind.mark,
        points = 0;
  final int t;
  final CueKind kind;
  final int side;
  final int points;
  final Offset at;
  final bool made;
}

enum CueKind { score, mark }

/// 1回の攻めの動き。
class PossessionScript {
  PossessionScript._(this._segs, this.cues, this.end, this.line, this.big);
  final List<_Seg> _segs;
  final List<Cue> cues;

  /// 終わったときの位置(次の攻めの始まり)。
  final Map<Who, Offset> end;

  /// 実況の1行。
  final String line;

  /// 大きなプレー(逆転・終了間際)。ゆっくり見せて、色を変える。
  final bool big;

  int get duration => _segs.isEmpty ? 0 : _segs.last.t1;

  CourtFrame frameAt(int t) {
    final s = _segs.firstWhere((x) => t < x.t1, orElse: () => _segs.last);
    final span = math.max(1, s.t1 - s.t0);
    final u = ((t - s.t0) / span).clamp(0.0, 1.0);
    final e = u < 0.5 ? 2 * u * u : 1 - math.pow(-2 * u + 2, 2) / 2;
    final pos = <Who, Offset>{};
    final alpha = <Who, double>{};
    for (final k in s.to.keys) {
      final a = s.from[k] ?? s.to[k]!;
      pos[k] = Offset.lerp(a, s.to[k]!, e)!;
      alpha[k] = s.fade.contains(k) ? 1 - u : 1;
    }
    if (s.carrier != null) {
      final p = pos[s.carrier!] ?? s.to.values.first;
      // ドリブル(足もとで少し弾む)
      final bounce = (math.sin(t / 55) + 1) / 2;
      return CourtFrame(pos, alpha, p + const Offset(0.35, 0.3), bounce * 0.12, s.carrier);
    }
    final b = Offset.lerp(s.ballFrom, s.ballTo, u)!;
    return CourtFrame(pos, alpha, b, s.arc * 4 * u * (1 - u), null);
  }
}

/// 攻めごとの動きを作る。[names] と [poss] は (チーム, 番号) の名前とポジション。
/// 動きは、その攻めのときの方針([PlayEvent.pace] など。試合中の采配も入る)で変わる(2026-11-22、ユーザー「動きは戦術とかで変わる？」)。
/// - 展開の速さ: 速攻はボールを速く運び、スティールやリバウンドからそのまま打つことが多い。じっくりは長く回す
/// - 攻めの重点: 外なら角まで広がり、中なら大きい2人がゴール下に構えてボールを入れる
/// - ボールの回し方: パスの本数(エース任せは少なく、パス回しは多く)
/// - 守り方: 前から当たるなら自陣の外から2人でボールを挟みに行き、中を固めるならゴール下に寄る
class PlaybackBuilder {
  PlaybackBuilder({required this.events, required this.names, required this.poss});
  final List<PlayEvent> events;
  final String Function(Who) names;
  final Pos Function(Who) poss;

  /// [i] 番目の攻めの動き。[start] は前の攻めの終わりの位置(はじめは null)。
  PossessionScript build(int i, Map<Who, Offset>? start) {
    final e = events[i];
    final prev = i > 0 ? events[i - 1] : null;
    final off = e.side, def = 1 - e.side;
    final basket = basketOf(off);
    var draw = 0;
    double rnd() => _hash(i, draw++);
    Offset jitter(Offset p, double m) => p + Offset((rnd() - 0.5) * 2 * m, (rnd() - 0.5) * 2 * m);

    // 攻める5人の持ち場(ポジションの順に、トップ・ウイング・ウイング・ひじ・ゴール下)
    final five = [...e.offCourt]..sort((a, b) {
        final c = poss((off, a)).index.compareTo(poss((off, b)).index);
        return c != 0 ? c : a.compareTo(b);
      });
    final slots = _slotsByFocus[e.focus.clamp(0, 2)];
    final spot = <int, Offset>{for (var k = 0; k < five.length && k < 5; k++) five[k]: _toSide(off, slots[k])};
    // 守る5人は、同じ順の相手につく
    final dfive = [...e.defCourt]..sort((a, b) {
        final c = poss((def, a)).index.compareTo(poss((def, b)).index);
        return c != 0 ? c : a.compareTo(b);
      });
    final markOf = <int, int>{for (var k = 0; k < dfive.length && k < five.length; k++) dfive[k]: five[k]};
    // 守る位置: ふつうは相手とゴールの間(相手寄り)。中を固めるとゴールへ下がる(外の相手からは離れる)。前から当たると相手に張りつく
    Offset guardSpot(Offset man) {
      switch (e.press) {
        case 0:
          final p = man + (basket - man) * 0.55;
          final d = p - basket;
          return d.distance > 4.6 ? basket + d / d.distance * 4.6 : p;
        case 2:
          return man + (basket - man) * 0.16;
        default:
          return man + (basket - man) * 0.3;
      }
    }

    final now = <Who, Offset>{};
    for (final x in five) {
      now[(off, x)] = jitter(spot[x]!, 0.7);
    }
    void follow() {
      for (final d in dfive) {
        final m = markOf[d];
        if (m != null) now[(def, d)] = guardSpot(now[(off, m)]!);
      }
    }

    follow();
    final segs = <_Seg>[];
    final cues = <Cue>[];
    var t = 0;
    Map<Who, Offset> snap() => Map.of(now);

    // --- 1. ボールを運び、持ち場につく。交代で出る選手はベンチへ、入る選手はベンチから
    final begin = <Who, Offset>{...?start};
    final leaving = <Who>{
      for (final k in begin.keys)
        if (!now.containsKey(k)) k,
    };
    for (final k in now.keys) {
      begin.putIfAbsent(k, () => benchSpot + Offset((rnd() - 0.5) * 4, 0));
    }
    final target = snap();
    for (final k in leaving) {
      target[k] = benchSpot;
    }
    // はじめにボールを持つ人: 前の攻めでリバウンドかスティールを取った人。点が入ったあとは司令塔
    Who holder = (off, five.first);
    if (prev != null && prev.steps.isNotEmpty) {
      final last = prev.steps.last;
      if (last.kind == PlayStepKind.defRebound && e.offCourt.contains(last.who)) holder = (off, last.who);
      if (last.kind == PlayStepKind.turnover && last.steal >= 0 && e.offCourt.contains(last.steal)) holder = (off, last.steal);
    }
    // 速攻: スティールのあとは必ず。速く攻める方針なら、守りのリバウンドのあとも半分くらい
    final stole = prev != null && prev.steps.isNotEmpty && prev.steps.last.kind == PlayStepKind.turnover && prev.steps.last.steal >= 0;
    final rebound = prev != null && prev.steps.isNotEmpty && prev.steps.last.kind == PlayStepKind.defRebound;
    final fastBreak = stole || (e.pace == 2 && rebound && rnd() < 0.5);
    final up = start == null ? 500 : (fastBreak ? 600 : const [1300, 950, 750][e.pace.clamp(0, 2)]);
    if (e.press == 2 && start != null && !fastBreak) {
      // 前から当たる: 半分まで運んだところで、守り2人がボールを挟む(ほかの守りも相手に張りつく)
      final mid = <Who, Offset>{for (final k in target.keys) k: Offset.lerp(begin[k] ?? target[k]!, target[k]!, 0.45)!};
      final carry = mid[holder]!;
      for (final d in dfive) {
        final m = markOf[d];
        if (m == null) continue;
        mid[(def, d)] = mid[(off, m)]! + (basket - mid[(off, m)]!) / math.max(1, (basket - mid[(off, m)]!).distance) * 0.9;
      }
      // ボールを持つ人に、もう1人の守り(いちばん近い人)が寄る
      final helpers = [
        for (final d in dfive)
          if (markOf[d] != holder.$2) d,
      ]..sort((a, b) => (mid[(def, a)]! - carry).distance.compareTo((mid[(def, b)]! - carry).distance));
      if (helpers.isNotEmpty) mid[(def, helpers.first)] = carry + const Offset(0, 1.0);
      final first = (up * 0.55).round();
      segs.add(_Seg(t, t + first, begin, mid, carrier: holder, fade: leaving));
      t += first;
      segs.add(_Seg(t, t + up - first + 150, mid, target, carrier: holder, fade: leaving));
      t += up - first + 150;
    } else {
      segs.add(_Seg(t, t + up, begin, target, carrier: holder, fade: leaving));
      t += up;
    }

    // --- 2. 出来事を順に
    final base = [(0, 2), (1, 3), (2, 5)][e.share.clamp(0, 2)];
    // じっくりは1本多く、速攻は1本少なく回す
    final extra = const [1, 0, -1][e.pace.clamp(0, 2)];
    var passesLeft = (math.max(0, base.$1 + extra), math.max(0, base.$2 + extra));
    var score = prev == null ? (0, 0) : (prev.homePts, prev.awayPts);
    var line = '';
    var big = false;
    // ボールが誰の手にもないとき(入った・外に出た・取る人のいない外れ)の場所
    Offset? loose;

    void move(int dur, {Who? carrier, Offset? bFrom, Offset? bTo, double arc = 0}) {
      final from = snap();
      // 攻めの選手は少しずつ動く。守りはついていく
      for (final x in five) {
        if (carrier != null && carrier == (off, x)) continue;
        now[(off, x)] = jitter(spot[x]!, 0.9);
      }
      follow();
      segs.add(_Seg(t, t + dur, from, snap(), carrier: carrier, ballFrom: bFrom ?? Offset.zero, ballTo: bTo ?? Offset.zero, arc: arc));
      t += dur;
    }

    void pass(int to) {
      final a = now[holder]!;
      final b = now[(off, to)]!;
      final d = (b - a).distance;
      move((220 + d * 22).round(), bFrom: a, bTo: b, arc: 0.25);
      holder = (off, to);
    }

    void addScore(int s, int pts) {
      score = s == 0 ? (score.$1 + pts, score.$2) : (score.$1, score.$2 + pts);
      cues.add(Cue.score(t, s, pts));
    }

    void freeThrows(int who, int made, int tries) {
      final line = _toSide(off, const Offset(5.8, courtWid / 2));
      final from = snap();
      now[(off, who)] = line;
      // ほかはレーンの横に並ぶ
      var k = 0;
      for (final x in five) {
        if (x == who) continue;
        now[(off, x)] = _toSide(off, Offset(2.8 + (k ~/ 2) * 1.4, k.isEven ? 5.2 : 9.8));
        k++;
      }
      k = 0;
      for (final d in dfive) {
        now[(def, d)] = _toSide(off, Offset(2.2 + (k ~/ 2) * 1.4, k.isEven ? 5.4 : 9.6));
        k++;
      }
      segs.add(_Seg(t, t + 450, from, snap(), carrier: (off, who)));
      t += 450;
      for (var n = 0; n < tries; n++) {
        final f = snap();
        segs.add(_Seg(t, t + 520, f, snap(), ballFrom: line, ballTo: basket, arc: 0.8));
        t += 520;
        if (n < made) addScore(off, 1);
        final g = snap();
        segs.add(_Seg(t, t + 160, g, snap(), carrier: (off, who)));
        t += 160;
      }
      holder = (off, who);
    }

    for (var si = 0; si < e.steps.length; si++) {
      final st = e.steps[si];
      switch (st.kind) {
        case PlayStepKind.turnover:
          final a = now[holder]!;
          if (st.steal >= 0 && now.containsKey((def, st.steal))) {
            final thief = (def, st.steal);
            now[thief] = a + (now[thief]! - a) * 0.3;
            move(380, bFrom: a, bTo: now[thief]!, arc: 0.05);
            holder = thief;
            loose = null;
            line = '${names(thief)}のスティール';
          } else {
            final out = Offset(a.dx, a.dy < courtWid / 2 ? -0.6 : courtWid + 0.6);
            move(420, bFrom: a, bTo: out, arc: 0.1);
            loose = out;
            line = '${names((off, st.who))}のミス';
          }
        case PlayStepKind.offRebound:
        case PlayStepKind.defRebound:
          break; // リバウンドは、外れたシュートのところで動かす
        case PlayStepKind.shot:
          final shooter = (off, st.who);
          // 前の出来事がリバウンドで、打つ人が取った人なら、そのまま打つ(押し込み)
          final putback = si > 0 && e.steps[si - 1].kind == PlayStepKind.offRebound && e.steps[si - 1].who == st.who;
          if (!putback) {
            // パスを回す(ボールの回し方で本数が変わる)。アシストがあれば、最後に渡すのはアシストした人
            final lo = fastBreak && si == 0 ? 0 : passesLeft.$1;
            final hi = fastBreak && si == 0 ? 1 : passesLeft.$2;
            var n = lo + (rnd() * (hi - lo + 1)).floor();
            passesLeft = (0, math.max(0, passesLeft.$2 - n));
            if (st.assist >= 0 && n == 0 && holder != (off, st.assist) && holder != shooter) n = 1;
            for (var k = 0; k < n; k++) {
              final last = k == n - 1;
              int to;
              if (last && st.assist >= 0) {
                to = st.assist;
              } else {
                final others = [
                  for (final x in five)
                    if ((off, x) != holder && x != st.who) x,
                ];
                final bigs = [
                  for (final x in five.skip(3))
                    if ((off, x) != holder && x != st.who) x,
                ];
                if (e.focus == 2 && bigs.isNotEmpty && rnd() < 0.6) {
                  to = bigs[(rnd() * bigs.length).floor().clamp(0, bigs.length - 1)];
                } else {
                  to = others.isEmpty ? st.who : others[(rnd() * others.length).floor().clamp(0, others.length - 1)];
                }
              }
              if ((off, to) != holder) pass(to);
            }
            if (holder != shooter) pass(st.who);
            // 打つ場所へ(3ポイントは線の外、2点はゴールへ切り込むか、中くらいの距離)
            final me = now[shooter]!;
            final dir = me - basket;
            final ang = math.atan2(dir.dy, dir.dx);
            final dist = st.three ? 7.35 : (st.fouled || rnd() < 0.62 ? 1.4 : 4.2);
            var spotAt = basket + Offset(math.cos(ang) * dist, math.sin(ang) * dist);
            spotAt = Offset(spotAt.dx.clamp(0.4, courtLen - 0.4), spotAt.dy.clamp(0.4, courtWid - 0.4));
            final from = snap();
            now[shooter] = spotAt;
            follow();
            // 打つ人についている守りは、前に立つ
            for (final d in dfive) {
              if (markOf[d] == st.who) now[(def, d)] = spotAt + (basket - spotAt) * (st.three ? 0.14 : 0.35);
            }
            segs.add(_Seg(t, t + 420, from, snap(), carrier: shooter));
            t += 420;
          }
          final at = now[shooter]!;
          // シュート
          final flight = st.three ? 640 : 480;
          final f = snap();
          segs.add(_Seg(t, t + flight, f, snap(), ballFrom: at, ballTo: basket, arc: st.three ? 1.0 : 0.6));
          t += flight;
          cues.add(Cue.mark(t, off, at, st.made));
          final who = names(shooter);
          if (st.made) {
            final before = score;
            addScore(off, st.three ? 3 : 2);
            final ast = st.assist >= 0 ? '(アシスト ${names((off, st.assist))})' : '';
            line = '$whoの${st.three ? '3ポイント' : st.fouled ? 'バスケットカウント' : putback ? '押し込み' : '2点'}$ast';
            final lead0 = (before.$1 - before.$2).sign, lead1 = (score.$1 - score.$2).sign;
            if (e.period >= 3 && lead0 != 0 && lead1 != 0 && lead0 != lead1) {
              big = true;
              line = '逆転！ $line';
            }
            if (e.clockEnd <= 2 && e.period >= 3) big = true;
            final g = snap();
            segs.add(_Seg(t, t + 260, g, snap(), ballFrom: basket, ballTo: basket + const Offset(0, 0.6)));
            t += 260;
            loose = basket + const Offset(0, 0.6);
            if (st.fouled) {
              freeThrows(st.who, st.ftMade, st.ftTry);
              loose = basket;
            }
          } else if (st.fouled) {
            line = '$whoがファウルをもらう(フリースロー${st.ftTry}本中${st.ftMade}本)';
            freeThrows(st.who, st.ftMade, st.ftTry);
            loose = basket;
          } else {
            // 外れた。ブロックなら手前で弾く。次の出来事のリバウンドの人へ
            line = st.block >= 0 ? '${names((def, st.block))}のブロック' : '$whoの${st.three ? '3ポイント' : 'シュート'}は外れ';
            final next = si + 1 < e.steps.length ? e.steps[si + 1] : null;
            Who? reb;
            if (next != null && next.kind == PlayStepKind.offRebound) reb = (off, next.who);
            if (next != null && next.kind == PlayStepKind.defRebound) reb = (def, next.who);
            final land = basket + Offset((rnd() - 0.5) * 4, (rnd() - 0.5) * 4) + (at - basket) * 0.15;
            final landAt = Offset(land.dx.clamp(0.3, courtLen - 0.3), land.dy.clamp(0.3, courtWid - 0.3));
            if (reb != null && now.containsKey(reb)) {
              final g = snap();
              now[reb] = landAt;
              segs.add(_Seg(t, t + 380, g, snap(), ballFrom: st.block >= 0 ? at + (basket - at) * 0.2 : basket, ballTo: landAt, arc: 0.3));
              t += 380;
              holder = reb;
              loose = null;
              if (next!.kind == PlayStepKind.offRebound) line = '$line・${names(reb)}がリバウンド';
            } else {
              final g = snap();
              segs.add(_Seg(t, t + 300, g, snap(), ballFrom: basket, ballTo: landAt, arc: 0.3));
              t += 300;
              loose = landAt;
            }
          }
      }
    }
    // 終わりに少し間を置く
    final g = snap();
    final rest = loose;
    segs.add(rest != null || !now.containsKey(holder)
        ? _Seg(t, t + 150, g, snap(), ballFrom: rest ?? basket, ballTo: rest ?? basket)
        : _Seg(t, t + 150, g, snap(), carrier: holder));
    t += 150;
    // 点のずれがあれば、最後に合わせる(起きないはず)
    if (score.$1 != e.homePts) cues.add(Cue.score(t, 0, e.homePts - score.$1));
    if (score.$2 != e.awayPts) cues.add(Cue.score(t, 1, e.awayPts - score.$2));
    if (line.isEmpty) line = '攻めが終わる';
    return PossessionScript._(segs, cues, snap(), line, big);
  }
}

/// 試合の時計の表示(「2Q 5:32」)。
String clockText(int period, int left) {
  final q = period < 4
      ? '${period + 1}Q'
      : period == 4
          ? '延長'
          : '延長${period - 3}';
  final m = left ~/ 60, s = left % 60;
  return '$q $m:${s.toString().padLeft(2, '0')}';
}

/// 試合の始めから [minuteOf] の時点までの分(点差の流れの線を、見ている所まで伸ばす)。
int minuteOf(int period, int left) => period < 4 ? period * 12 + (720 - left) ~/ 60 : 48 + (period - 4) * 5 + (300 - left) ~/ 60;

/// ここまで([upto] 番目の攻めまで)の、1人の今日の数字。
({int pts, int reb, int ast, int secs}) todayOf(List<PlayEvent> events, int upto, Who w) {
  var pts = 0, reb = 0, ast = 0, secs = 0;
  for (var i = 0; i < upto && i < events.length; i++) {
    final e = events[i];
    final onOff = e.side == w.$1;
    final court = onOff ? e.offCourt : e.defCourt;
    if (court.contains(w.$2)) secs += e.clockStart - e.clockEnd;
    for (final s in e.steps) {
      switch (s.kind) {
        case PlayStepKind.shot:
          if (onOff && s.who == w.$2) pts += (s.made ? (s.three ? 3 : 2) : 0) + s.ftMade;
          if (onOff && s.assist == w.$2) ast++;
        case PlayStepKind.offRebound:
          if (onOff && s.who == w.$2) reb++;
        case PlayStepKind.defRebound:
          if (!onOff && s.who == w.$2) reb++;
        case PlayStepKind.turnover:
          break;
      }
    }
  }
  return (pts: pts, reb: reb, ast: ast, secs: secs);
}

/// 一方のチームの続けて取った点(「8-0のラン」)。[upto] 番目までの攻めで、最後に点を取ったチームと、相手が取らずに続けた点。
(int side, int run) runOf(List<PlayEvent> events, int upto) {
  var side = -1, run = 0;
  for (var i = 0; i < upto && i < events.length; i++) {
    final p = events[i].points;
    if (p <= 0) continue;
    if (events[i].side == side) {
      run += p;
    } else {
      side = events[i].side;
      run = p;
    }
  }
  return (side, run);
}
