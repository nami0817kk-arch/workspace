import 'dart:math' as math;

import 'package:quadrillion/game/game.dart';

import 'bot.dart';

/// 「ふつうの上手な人」の打ち方（1.1.0+30。段6の釣り合いを測る自動プレイ）。
///
/// botMonth（試作の素直な版）は、稼ぎ頭の事業が上限に届いても「空いた店長を埋める」手が打てるあいだは新しい事業に出ず、
/// 手元のお金を毎月8割まで使い切って蓄えを持たず、売れない新商品を作り続けていた。人が遊ぶときの打ち方に寄せて、
/// - 毎月の支払いの2か月分と、この先3か月の返済を蓄えとして残し、残りで伸ばす
/// - 店などを開ける事業（客が余っていて上限に届いていない）があれば、1円あたりの稼ぎが良い順に開く
/// - どの事業も開けなくなったら（上限・客が足りない）、これから伸びる業種で新しい事業を始める
/// - 赤字が続く事業・沈んでいく業種の赤字の事業は売る。大口の客に頼りすぎたら客を広げる
/// - 給料は相場に合わせ、責任者のいない事業には部下を置く
///
/// [borrow] は借金の打ち方：'none' 借りない（つなぎの融資は自動で入る）/ 'some' 伸ばすお金が足りないときに、借金が利益の2倍までに収まる分だけ /
/// 'max' 毎月、借りられるだけ借りる。[abroad] を立てると、1995年から稼ぎ頭の事業で外国にも出る。
/// [keepSubs] を立てると、買った会社を合併せずに子会社のまま持ち続け、次々に買う（子会社を多く持つ打ち方。1.1.0+35 の測り）
void proMonth(Game s, {String borrow = 'some', bool abroad = false, bool keepSubs = false}) {
  _resolve(s);
  if (s.hNormalLeft() < 40 && s.biz.length >= 3) s.delegAll();
  final y = s.yr();
  // 蓄え：原価を除いた毎月の支払い（家賃・人件費・本社・利息など）の半月分と、この先2か月の返済
  final cogs = s.cogsOf.values.fold(0.0, (a, x) => a + x);
  final fixed = math.max(0.0, s.rev - s.pre - cogs);
  // （借りまくる人は蓄えを持たず、借りたお金を全部伸ばすのに使う）
  double reserve() => borrow == 'max' ? 0 : fixed * .5 + s.loanPrincipal() * 3;
  double room() => math.max(0.0, s.cash - reserve());

  // 借金
  if (borrow == 'max' && s.borrowRoom() > 1e6) {
    s.borrow(s.borrowRoom(), 60);
  } else if (borrow == 'some' && s.ratingIdx() == 0 && s.borrowRoom() > 1e6 && _wantsMoney(s, room())) {
    final ap = math.max(0.0, s.annualProfit());
    // 借金は年の利益の1.5倍まで（5年で返すので、毎月の返済が税引き後の利益の半分ほどに収まる）
    final cap = ap <= 0 ? 0.0 : ap * 1.5 - s.debt;
    final a = math.min(s.borrowRoom() * .6, cap);
    if (a > 1e6) s.borrow(a, 60);
  }

  // 最初の事業：元手で始められる業種のうち、これから伸びて利益率の良いもの
  if (s.biz.isEmpty) {
    final l = s.liveInds().where((i) => s.capexOf(i) <= s.cash && s.licMissing(i.id) == null && !(i.f != 0 && y + 5 > i.f)).toList()
      ..ssort((a, b) => b.mg.compareTo(a.mg));
    if (l.isNotEmpty) s.startBiz(l.first.id);
  }

  // 人：事業より1人多くまで雇い、給料は相場に合わせ、責任者のいない事業に置く
  // （事業が1つのうちは社長が見る。部下の給料は本社の経費なので、利益が給料の4倍を超えてから）
  final afford = s.cands.where((p) => s.hireFeeOf(p) <= room() * .5 && s.pre > p.salary * 4).toList()
    ..ssort((a, b) => Game.totOf(b) - Game.totOf(a));
  if (s.biz.length >= 2 && s.staff.length < s.biz.length && afford.isNotEmpty) s.hire(afford.first);
  for (final p in s.staff.toList()) {
    if (p.real && s.payRatio(p) < .95 && s.pre > p.salary) s.raisePay(p);
  }
  // 部下の給料が利益を食っているときは、責任者を任せていない人から辞めてもらう（相棒は残す）
  if (s.staff.isNotEmpty && s.annualProfit() < s.salaries() * 12 * 1.5) {
    final idle = s.staff.where((p) => !p.partner && !s.biz.any((b) => b.mgr == p.id)).toList();
    if (idle.isNotEmpty) s.fire(idle.first, 'fired');
  }
  if (s.staff.length > s.biz.length + 1) {
    final idle = s.staff.where((p) => !p.partner && !s.biz.any((b) => b.mgr == p.id)).toList();
    if (idle.isNotEmpty) s.fire(idle.first, 'fired');
  }
  for (final b in s.biz) {
    if (b.mgr == null) {
      final free = s.staff.where((p) => !s.biz.any((x) => x.mgr == p.id) && p.away == 0).firstOrNull;
      if (free != null) b.mgr = free.id;
    }
  }

  // 大口の客に頼りすぎたら、客を広げる
  for (final b in s.biz) {
    final cl = s.corp.clients[b.id];
    if (cl != null && cl.share > .35 && room() > s.spreadCost(b) * 3 && s.ap > 0) s.spreadClients(b);
  }

  // 赤字が続く事業・沈んでいく業種の稼げない事業を売る（ひとつは残す）
  if (s.biz.length > 1 && s.ap > 0) {
    // （稼ぎ頭は売らない。沈んでいく業種でも、利益が出ているうちは持ち続ける）
    final head = (s.biz.toList()..ssort((a, b) => b.profit.compareTo(a.profit))).first;
    final bad = s.biz.where((b) {
      final ind = indm[b.ind]!;
      final yo = s.yoy(b);
      final losing = b.profit < 0 && b.age > 30 && (yo == null || yo < .05) && b.rh.length >= 13 && b.rh.every((r) => r <= b.rh.first * 1.1);
      final sinking = ind.f != 0 && y > ind.f + 3 && b.profit < 0 && b.age > 24;
      // （売るのは売上の1割5分に満たない小さな事業だけ。大きな事業の赤字は、店を開いた直後などで一時のことが多い）
      return b != head && b.rev < s.rev * .15 && (losing || sinking) && b.pipe.isEmpty;
    }).toList();
    if (bad.isNotEmpty) s.sellBiz(bad.first);
  }

  // 赤字の店などを閉める（育ちきって赤字の立地の3分の1。客の取り合いも和らぐ）・古い設備と技術を新しくする・当たり前になったITを入れる（1.1.0+30）
  for (final b in s.biz.toList()) {
    if (b.age < 24 || s.ap <= 0) continue;
    final ls = s.losingSites(b);
    if (ls.isNotEmpty && s.unitTotal(b) > 2) {
      final n = math.max(1, (b.sites[ls.first]!.n / 3).floor());
      if (s.closeCost(b, ls.first, n) < room()) s.closeUnits(b, ls.first, n);
    }
    if (s.eqOver(b) > .3 && s.renewCost(b) < room() * .5 && b.profit > 0) s.renewEquip(b);
    if (s.techBehind(b) > 0 && s.techCost(b) < room() * .5 && b.profit > 0) s.upgradeTech(b);
  }
  if (s.itBehind() > 0 && s.itCost() < room() * .4 && s.ap > 0) s.adoptIT();

  // 上場（条件を満たしたら準備を始め、整ったら上場する）
  if (s.unitsOn && s.canIpoPrep() && s.annualProfit() >= 3e8 * s.nom() && s.turn >= 24 && s.ap > 0) s.ipoPrepStart();
  if (s.canIPO()) s.ipo();
  // 株でお金を集める（伸ばす先があるときだけ。持ち株は過半を保つ）
  //（投資家からは集めない。「3年以内に上場」の約束が、小さな会社には重い）
  final opens = s.biz.any((b) => _canOpen(s, b));
  if (opens && s.listed && s.sh.own > 51 && s.cap > s.cash * 15 && s.ap > 0) s.publicOffer();

  // 外国へ（abroad のときだけ。稼ぎ頭の事業で、市場の大きい国から）
  if (abroad && y >= 1995) {
    final top = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).firstOrNull;
    if (top != null && top.profit > 0 && s.ap > 0 && !top.pipe.any((x) => x.k == 'enter')) {
      final cs = CTRY.where((x) => !s.ctryOf(top).contains(x.c)).toList()..ssort((p, q) => cw(q.c, y).compareTo(cw(p.c, y)));
      for (final x in cs.take(3)) {
        final ms = s.entryModes(top, x.c);
        final m = ms.contains('solo') ? 'solo' : ms.firstOrNull;
        if (m != null && room() > s.entryCost(top, x.c, m) * 2) {
          if (!s.knowsCtry(x.c) && s.canT('inspect')) s.inspect(x.c);
          s.enterCountry(top, x.c, m);
          break;
        }
      }
    }
  }

  // 伸ばす：店などを開ける事業から、1円あたりの稼ぎが良い順に（月に3手まで）
  // 新しい事業：どの事業も店などを開けない（上限・客が足りない）とき、または稼ぎ頭の業種が8年のうちに沈み始めるとき
  final top = (s.biz.toList()..ssort((a, b) => b.profit.compareTo(a.profit))).firstOrNull;
  if (top != null && s.biz.length < 12 && s.ap > 0) {
    final ti = indm[top.ind]!;
    final stuck = !s.biz.any((b) => _canOpen(s, b));
    final sinking = ti.f != 0 && y + 8 > ti.f && !s.biz.any((b) => indm[b.ind]!.f == 0 || y + 8 <= indm[b.ind]!.f);
    final i = stuck || sinking ? _bestInd(s, room() * .4) : null;
    if (i != null) s.startBiz(i.id);
  }

  // 伸ばす（月に3手まで）：1手目は、客が余っている事業のうち1単位あたりの稼ぎが良いものに店などを開く（お金が足りなければ貯める）。
  // 2手目からは、稼ぎの良い事業で現場の人を足し、商品を作る（客を増やす）
  for (var k = 0; k < 3 && s.ap > 0; k++) {
    double score(Biz b) => (b.profit / (b.rev + 1)) * (1 - b.share);
    final list = s.biz.toList()..ssort((a, b) => score(b).compareTo(score(a)));
    final b = list.firstOrNull;
    if (b == null) break;
    if (k == 0) {
      final full = list.where((x) => (s.capKOf[x.id] ?? 1) < .97 && x.lic == 0).toList()..ssort((a, c) => s.unitRoi(c).compareTo(s.unitRoi(a)));
      if (full.isNotEmpty) {
        s.growOpt(full.first, room() * .8, want: 10, time: true)?.run();
        continue;
      }
    }
    // 現場の人と商品は客を増やす手なので、店などが売り切れている（客が余っている）事業には打たない（人件費だけが増える）
    if ((s.capKOf[b.id] ?? 1) < .97) {
      final go = s.growOpt(b, room() * .8, want: 10, time: true);
      if (go == null) break;
      go.run();
      continue;
    }
    final need = s.crewNeedPeople(b);
    if (need > 0) {
      if (s.hireCost(b, need) > room()) break;
      s.hireN(b, need);
      continue;
    }
    final go = k == 0 ? s.growOpt(b, room() * .8, want: 10, time: true) : null;
    if (go != null) {
      go.run();
      continue;
    }
    final sz = [2, 1, 0].where((i) => s.devCost(b, i) <= room() * .2).firstOrNull;
    if (sz == null) break;
    s.developN(b, sz);
  }

  // 買う話は、蓄えを残してもお金が余るときだけ（1件ずつ）
  // （利益の出ている会社だけ。買う値段は蓄えの外のお金の3割まで）
  // （keepSubs のときは、蓄えの外のお金の6割までで買えるなら買う）
  if (s.ap > 0 && (keepSubs || room() > s.cap * .3) && s.corp.deals.isEmpty && s.pre > 0) {
    final tg = (s.cos.where((c) => c.alive && c.parent != 'player' && c.profit > 0 && s.tobCost(c, 50.1) < room() * (keepSubs ? .6 : .3) && s.tobChance(c, 50.1) > .4).toList()
          ..ssort((a, b) => b.cap.compareTo(a.cap)))
        .firstOrNull;
    if (tg != null) s.maStart(tg);
  }
  if (!keepSubs) {
    for (final c in s.subs()) {
      if (c.fromStaff == null && s.canMerge(c) && s.ap > 0) s.merge(c);
    }
  }
  if (s.sh.rivMax > 20 && s.ap > 0) s.doWhiteKnight();
  s.nextQuarter();
}

/// 出来事は、人が遊ぶときによく選ぶ方で片付ける（社長の座は降りない・謝る・無理な話は断る）
final _prefer = [RegExp('あと1年待って'), RegExp('却下'), RegExp('謝罪'), RegExp('引き留める'), RegExp('断る'), RegExp('自社株|ホワイト'), RegExp('休む'), RegExp('様子を見る')];
void _resolve(Game s) {
  while (s.events.isNotEmpty) {
    final e = s.events.removeAt(0);
    Choice? ch;
    for (final r in _prefer) {
      ch = e.choices.where((c) => r.hasMatch(txIn(c.l, 'ja'))).firstOrNull;
      if (ch != null) break;
    }
    // （当てはまらなければ最後の選択肢。会議の提案なら「見送る」、ほかもたいてい何もしない方）
    (ch ?? e.choices.last).f();
  }
}

/// 伸ばすお金が足りないか（開ける事業があるのに、蓄えを除いた手元で開けない／新しい事業の元手に足りない）
bool _wantsMoney(Game s, double room) {
  if (s.biz.isEmpty) return false;
  for (final b in s.biz) {
    if (_canOpen(s, b) && room < s.unitCapexAvg(b) * 5) return true;
  }
  return !s.biz.any((b) => _canOpen(s, b)) && _bestInd(s, double.infinity) != null && room < s.capexOf(_bestInd(s, double.infinity)!);
}

/// 店などをまだ開ける（客が余っていて、上限に届いていない）
bool _canOpen(Game s, Biz b) {
  if (b.lic > 0 || b.age < 6) return true;
  final soldOut = (s.capKOf[b.id] ?? 1) < .97;
  return soldOut && s.unitTotal(b) + s.pendingUnits(b) < s.capUnits(b) - 1;
}

/// 新しく始める業種（元手が [budget] 以内・資格が要らない・まだ持っていない。これから8年の市場×利益率で選ぶ）
Industry? _bestInd(Game s, double budget) {
  final y = s.yr();
  // 利益率×市場の大きさ（8年後の市場で見る。沈み始める業種は割り引く）
  double score(Industry i) {
    final sink = i.f != 0 && y + 8 > i.f ? .3 : 1.0;
    return i.mg * i.size * eraF(i, y + 8) * sink;
  }

  final l = s.liveInds().where((i) => !s.biz.any((b) => b.ind == i.id) && s.licMissing(i.id) == null && s.capexOf(i) <= budget && score(i) > 0).toList()
    ..ssort((a, b) => score(b).compareTo(score(a)));
  return l.firstOrNull;
}
