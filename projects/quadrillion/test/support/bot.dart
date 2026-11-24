import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:quadrillion/game/game.dart';

/// tool/trace.js と同じ乱数（Park-Miller）
class ParkMiller implements math.Random {
  int s;
  ParkMiller(this.s);
  @override
  double nextDouble() {
    s = s * 16807 % 2147483647;
    return (s - 1) / 2147483646;
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextDouble() < .5;
}

/// 自動プレイとテストの物差し（1.1.0+25 で毎月の「手」をやめ、社長の時間にした）。
/// [ap] は「ふつうに使える残りの時間で、8時間の行動があといくつ打てるか」。[apMax] は会議を引いた月の初めの数。
/// 仕組みの側には「手」はもう無い（game_real.dart の hoursOf と hLeft）
extension HoursCompat on Game {
  int get ap => down > 0 ? 0 : (hNormalLeft() / hoursOf['act']!).floor();
  int get apMax => down > 0 ? 0 : (math.max(0.0, hoursNormal - hMeet()) / hoursOf['act']!).floor();
  bool canAP(int n) => ap >= n;

  /// テストで「手をn個残す」：8時間の行動がちょうどn個打てるだけの時間を残す。0 なら無理をしても1時間も残さない
  set ap(int n) {
    down = 0;
    hUsed = n <= 0 ? hoursMax - hMeet() : math.max(0.0, hoursNormal - hMeet() - n * hoursOf['act']! - 1);
  }
}

/// 1.1.0+25 で横向きの骨組み（左の切り替え66・真ん中の余白16）にした。縦の幅（320・390）で書かれた画面のテストは、
/// 真ん中の幅が前と同じになるよう、その分を足した幅で見る（右の帯は幅760未満なので出ない）
Size centerAs(Size s) => s.width < 700 ? Size(s.width + 82, s.height) : s;

final _choice = RegExp('断る|謝罪|送り出す|上げる|自社株|ホワイト');

/// 出来事は決まった選び方で片付ける（試作の自動プレイと同じ）
void resolveEvents(Game s) {
  while (s.events.isNotEmpty) {
    final e = s.events.removeAt(0);
    final ch = e.choices.where((c) => _choice.hasMatch(txIn(c.l, 'ja'))).firstOrNull ?? e.choices.last;
    ch.f();
  }
}

/// tool/trace.js の1か月ぶんの手（試作の sim.js の素直な版）。
/// [units] を立てると、打ち手を現金の割合ではなく1単位の手（店をn個・商品の大きさ・人をn人）で打つ（1.0.0+12 の画面と同じ遊び方）
///
/// [mine] を渡すと、事業を伸ばす手（人・店や工場・商品）は、それが true の事業にだけ打つ（責任者に任せた事業は責任者が打つので、社長は打たない。1.0.0+20）
///
/// [borrow] は借金の打ち方（1.1.0+25）: 'none' 借りない（つなぎの融資は自動で入る）/ 'max' 毎月、借りられるだけ借りる / 'some' 現金が元手に足りないときだけ半分まで
void botMonth(Game s, {bool units = false, bool Function(Biz)? mine, String borrow = 'none'}) {
  int tot(Person p) => Game.totOf(p);
  resolveEvents(s);
  // 会議で社長の時間が埋まってきたら、責任者のいる事業を任せる（1.1.0+25。人が遊ぶときと同じ）
  if (mine == null && s.hNormalLeft() < 40) s.delegAll();
  if (borrow == 'max' && s.borrowRoom() > 1e6) {
    s.borrow(s.borrowRoom(), 60);
  } else if (borrow == 'some' && s.biz.isNotEmpty && s.cash < s.capexOf(indm[s.biz.first.ind]!) && s.borrowRoom() > 1e6) {
    s.borrow(s.borrowRoom() * .5, 60);
  }
  if (s.biz.isEmpty) {
    final l = s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => b.mg.compareTo(a.mg));
    if (l.isNotEmpty) s.startBiz(l[0].id);
  }
  if (s.staff.length < s.biz.length && s.cands.isNotEmpty && s.pre > s.cands[0].salary * 3) {
    s.hire((s.cands.toList()..ssort((a, b) => tot(b) - tot(a)))[0]);
  }
  for (final b in s.biz) {
    if (b.mgr == null) {
      final free = s.staff.where((p) => !s.biz.any((x) => x.mgr == p.id)).firstOrNull;
      if (free != null && s.biz.where((x) => x.mgr == null).length > 2) b.mgr = free.id;
    }
  }
  if (s.canIPO()) s.ipo();
  if (!s.listed && s.sh.own > 60 && s.cap > s.cash * 20 && s.ap > 0) s.vcRaise();
  if (s.listed && s.sh.own > 45 && s.cap > s.cash * 15 && s.ap > 0) s.publicOffer();
  final top = (s.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).firstOrNull;
  if (top != null && s.ap > 0) {
    final cs = CTRY.where((x) => !s.ctryOf(top).contains(x.c)).toList()
      ..ssort((p, q) => cw(q.c, s.year.toDouble()).compareTo(cw(p.c, s.year.toDouble())));
    for (final x in cs.take(3)) {
      final ms = s.entryModes(top, x.c);
      final m = ms.contains('solo') ? 'solo' : ms.firstOrNull;
      if (m != null && s.cash > s.entryCost(top, x.c, m) * 2) {
        s.enterCountry(top, x.c, m);
        break;
      }
    }
  }
  final cand = s.liveInds().where((i) => !s.biz.any((b) => b.ind == i.id) && s.capexOf(i) < s.cash * .8).toList()
    ..ssort((a, b) => (b.mg * b.size).compareTo(a.mg * a.size));
  if (cand.isNotEmpty && s.ap > 0 && s.biz.length < 12) s.startBiz(cand[0].id);
  // 事業を伸ばす手は月に3つまで（時間が残っていても。人の手で遊ぶ速さに近づける）
  for (var k = 0; k < 3 && s.ap > 0; k++) {
    double score(Biz y) => (y.profit / (y.rev + 1)) * (1 - y.share);
    final b = ((mine == null ? s.biz.toList() : s.biz.where(mine).toList())..ssort((x, y) => score(y).compareTo(score(x)))).firstOrNull;
    if (b == null) break;
    if (units) {
      if (!_unitMove(s, b, k)) break;
      continue;
    }
    if (s.cash > s.capexOf(indm[b.ind]!) * .3) {
      if (s.crewEff(b) < b.power * 1.05) {
        s.addCrew(b, .2);
      } else if (k == 0) {
        s.build(b, .4);
      } else {
        s.develop(b, .2);
      }
    } else {
      break;
    }
  }
  if (s.ap > 0 && s.cash > s.cap * .3) {
    final tg = (s.cos.where((c) => c.alive && c.parent != 'player' && s.tobCost(c, 50.1) < s.cash * .7 && s.tobChance(c, 50.1) > .4).toList()
          ..ssort((a, b) => b.cap.compareTo(a.cap)))
        .firstOrNull;
    if (tg != null) s.tob(tg, 50.1);
  }
  // 合併するのは買った会社だけ（自分で分社した子会社は戻さない。1.1.0+25 で月に打てる手が増え、分社した子会社をすぐ戻していた）
  for (final c in s.subs()) {
    if (c.fromStaff == null && s.canMerge(c) && s.ap > 0) s.merge(c);
  }
  if (s.sh.rivMax > 20 && s.ap > 0) s.doWhiteKnight();
  s.nextQuarter();
}

/// 1単位の手を1つ打つ（打てなければ false）。割合の版と同じ考え方で、
/// 人が足りなければ足りない分を雇い、1手目は店・工場を（現金の4割まで）、2手目からは商品を（現金の2割まで）、払える一番大きな単位で打つ
bool _unitMove(Game s, Biz b, int k) {
  final need = s.crewNeedPeople(b);
  if (need > 0) {
    if (s.hireCost(b, need) > s.cash) return false;
    s.hireN(b, need);
    return true;
  }
  if (k == 0) {
    final n = buildUnits.reversed.where((n) => s.buildCost(b, n) <= s.cash * .4).firstOrNull;
    if (n == null) return false;
    s.buildN(b, n);
    return true;
  }
  final sz = [2, 1, 0].where((i) => s.devCost(b, i) <= s.cash * .2).firstOrNull;
  if (sz == null) return false;
  s.developN(b, sz);
  return true;
}

/// 記録する数字（tool/trace.js の rows と同じ並び）
List<double> row(Game s) => [
      s.year.toDouble(),
      s.q.toDouble(),
      s.cash,
      s.cap,
      s.rev,
      s.pre,
      s.debt,
      s.biz.length.toDouble(),
      s.staff.length.toDouble(),
      s.cos.where((c) => c.alive).length.toDouble(),
      s.ap.toDouble(),
      s.rank.toDouble(),
      s.biz.fold(0.0, (a, b) => a + b.power),
      s.log.length.toDouble(),
      s.sh.own,
    ];
