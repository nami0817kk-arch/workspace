import 'package:quadrillion/game/game.dart';

import 'bot.dart';

/// 海外に出る打ち方の結果（1.1.0+28。段5の比べ）
class AbroadRun {
  final int seed;
  final bool off;
  bool broke = false, bank = false;
  int months = 0;
  double cap = 0, peakCap = 0, abroadShare = 0, tradeCost = 0, adapt = 0, trapped = 0;
  Set<String> ctry = {};
  int news = 0;
  AbroadRun(this.seed, this.off);
}

/// 1980年の日本から始め（借りない）、1995年から稼ぎ頭の事業で韓国と米国へ出る打ち方。
/// 出る前に視察し、その国の言葉ができる部下がいれば責任者にし、部品や品物を外から買う事業は仕入れ先を2か国に分ける。
/// ほかは自動プレイ（botMonth）と同じ。[off] で段5を切って比べる
AbroadRun playAbroad(int seed, {bool off = false, int years = 30, List<String> targets = const ['kr', 'us']}) {
  final r = AbroadRun(seed, off);
  final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: const ['charm', 'careful'], home: 'jp'), rng: ParkMiller(seed));
  g.trade.off = off;
  for (var m = 0; m < years * 12; m++) {
    resolveEvents(g);
    final top = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).firstOrNull;
    if (g.year >= 1995 && top != null && top.profit > 0 && !top.pipe.any((x) => x.k == 'enter')) {
      for (final c in targets) {
        if (g.ctryOf(top).contains(c)) continue;
        if (!off && !g.knowsCtry(c) && g.cash > g.inspectCost(c) * 20 && g.canT('inspect')) g.inspect(c);
        final ms = g.entryModes(top, c);
        final mode = ms.contains('solo') ? 'solo' : ms.firstOrNull;
        if (mode != null && g.cash > g.entryCost(top, c, mode) * 1.5 && g.canT('enter')) {
          g.enterCountry(top, c, mode);
          break;
        }
      }
    }
    // その国の言葉ができる部下を、海外に出た事業の責任者に
    if (!off) {
      for (final b in g.biz) {
        final abroad = g.ctryOf(b).where((c) => c != g.home).toList();
        if (abroad.isEmpty) continue;
        final best = g.helperOf(b, abroad.first);
        final p = best.$2;
        if (p != null && b.mgr != p.id && !g.biz.any((x) => x.mgr == p.id) && g.langHelp(p, abroad.first) >= .6) b.mgr = p.id;
      }
      // 仕入れ先を2か国に分ける（お金に余裕があるとき）
      for (final b in g.biz) {
        if (g.inputOf(b) == null) continue;
        final l = g.supOf(b);
        if (l.length >= 2 || g.cash < g.supplierCost(b) * 10 || !g.canT('supply')) continue;
        final alt = g.srcList(b).where((s) => !l.contains(s)).toList();
        if (alt.isNotEmpty) g.addSupplier(b, alt.first);
      }
    }
    botMonth(g, units: true, borrow: 'none', focus: true);
    if (g.won != null) {
      g.mode = 'endless';
      g.won = null;
    }
    r.news += g.lastNews.where((n) => msgKey(n.m).contains('関税') || msgKey(n.m).contains('仕入れ') || msgKey(n.m).contains('為替')).length;
    if (g.cap > r.peakCap) r.peakCap = g.cap;
    if (g.bankDone) r.bank = true;
    r.months = m + 1;
    if (g.over != null) {
      r.broke = true;
      break;
    }
  }
  r.cap = g.cap;
  r.ctry = {for (final b in g.biz) ...g.ctryOf(b)};
  var ab = 0.0, ad = 0.0, n = 0;
  for (final b in g.biz) {
    for (final c in g.ctryOf(b)) {
      if (c == g.home) continue;
      ab += b.rev * g.revShare(b, c);
      ad += g.adaptOf(b, c);
      n++;
    }
    final v = g.trade.view[b.id];
    if (v != null) r.tradeCost += (v['tariff'] ?? 0) + (v['freight'] ?? 0);
  }
  r.abroadShare = g.rev > 0 ? ab / g.rev : 0;
  r.adapt = n > 0 ? ad / n : 0;
  r.trapped = g.trade.trapped.values.fold(0.0, (a, x) => a + x);
  return r;
}
