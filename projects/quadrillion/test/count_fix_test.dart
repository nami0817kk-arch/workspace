// 数え方の直し（1.1.0+35）: 子会社の利益は現金にならず配当だけが入る・時価総額は社債を1回だけ引く・決算書の費用と負債の増加は赤
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/fin_screens.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/pro.dart';

/// 数年遊ばせた会社（事業と利益がある）
Game _played({int seed = 5, int months = 60}) {
  final g = Game.newGame(SetupConfig(year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
  for (var m = 0; m < months && g.over == null; m++) {
    proMonth(g, borrow: 'none');
  }
  resolveEvents(g);
  g.calcAll();
  return g;
}

/// 利益の出ている CPU の会社を1つ、持ち分 [pct]% の子会社にする
Company _makeSub(Game g, double pct) {
  final c = (g.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null && c.profit > 0 && c.cash > c.profit).toList()
        ..ssort((a, b) => b.profit.compareTo(a.profit)))
      .first;
  c.parent = 'player';
  c.stakePlayer = pct;
  g.calcAll();
  return c;
}

void main() {
  test('子会社の利益の持ち分は現金にならず、現金に入るのは配当（利益の4割の持ち分）だけ', () {
    final g = _played();
    expect(g.over, isNull);
    _makeSub(g, 60);
    expect(g.subP, greaterThan(0), reason: '子会社の利益の持ち分がある');
    for (var m = 0; m < 6; m++) {
      g.events.clear();
      g.nextQuarter();
      resolveEvents(g);
      final r = g.books.months.last;
      final v = r.v;
      final eq = r.g('eqInc'), div = r.g('c:div'), tax = r.g('tax');
      expect(eq, greaterThan(0), reason: '${r.y}年${r.q}月 損益に入る子会社の利益の持ち分');
      expect(div, greaterThan(0), reason: '${r.y}年${r.q}月 配当が入る');
      // 配当は利益の持ち分の4割まで（利益の全部が2回入ることはない）
      expect(div, lessThanOrEqualTo(eq * .4 + 2), reason: '${r.y}年${r.q}月 配当$div 持ち分の利益$eq');
      // 損益の税の前の利益（利息のあと）＝売上−費用−利息。そのうち現金に入るのは、子会社の利益の持ち分を除いた分だけ
      final costs = ['cogs', 'labor', 'rent', 'util', 'logi', 'ad', 'insur', 'repair', 'hq', 'subc', 'oth'].fold(0.0, (s, k) => s + r.g(k));
      final p0 = r.g('rev') - costs - r.g('intr');
      final opCash = r.g('c:op') + r.g('c:tax') + r.g('c:intr');
      expect((opCash - (p0 - eq - tax)).abs(), lessThan(10 + p0.abs() * 1e-9), reason: '${r.y}年${r.q}月 本業の現金$opCash 利益$p0 持ち分$eq 税$tax');
      // 経常利益に配当を足さない（足すと、営業利益に入った持ち分の利益と2回数える）
      expect(finNonOp(v), closeTo(r.g('c:nonop') - r.g('intr'), 1));
      // 資産＝負債＋純資産のまま
      final a = finAssets(v);
      expect((a - finLiabs(v) - finEquity(v)).abs(), lessThan(40 + a.abs() * 1e-9), reason: '${r.y}年${r.q}月');
      expect(r.g('b:gap').abs(), lessThan(40 + a.abs() * 1e-9), reason: '${r.y}年${r.q}月 合わない差');
    }
  });

  test('現金になる月の利益は、子会社の利益の持ち分を除き、配当（利益の4割の持ち分）を足したもの', () {
    final g = _played(seed: 6);
    final c = _makeSub(g, 60);
    final want = c.profit * .4 * .6;
    expect(g.subDivs(), closeTo(want, 1));
    expect(g.subP, closeTo(c.profit * .6, 1));
    expect(g.cashPre(), closeTo(g.pre - g.subP + want, 1));
    expect(g.cashPre(), lessThan(g.pre), reason: '持ち分の利益の6割は現金にならない');
  });

  test('時価総額は借金（社債を含む）を1回だけ引く：社債を出して現金が増えても、時価総額は変わらない', () {
    final g = _played(seed: 7);
    expect(g.over, isNull);
    g.calcAll();
    final cap0 = g.cap;
    expect(cap0, greaterThan(1e7));
    const a = 5e8;
    // 利息0の社債（利息で利益が減る分を除いて、借金の引き方だけを見る）
    g.loans.add(Loan(id: g.loanSeq + 1000, lender: 'bond', amt: a, orig: a, rate: 0, left: 60, term: 60, bullet: true, at: g.turn));
    g.cash += a;
    expect(g.bond, a);
    g.calcAll();
    expect(g.cap, closeTo(cap0, cap0 * 1e-9 + 1), reason: '社債の分を2回引くと ${cap0 - a} になる');
    // 銀行から同じだけ借りても同じ
    g.loans.add(Loan(id: g.loanSeq + 1001, lender: 'main', amt: a, orig: a, rate: 0, left: 60, term: 60, at: g.turn));
    g.cash += a;
    g.calcAll();
    expect(g.cap, closeTo(cap0, cap0 * 1e-9 + 1));
  });

  test('決算書の色：費用・負債が増えたら赤、減ったら緑。資産・売上・利益は増えたら緑', () {
    FinLine line(List<FinLine> ls, String id) => ls.firstWhere((l) => l.id == id);
    // 損益：費用の行
    for (final id in ['cogs', 'sga', 'labor', 'rent', 'util', 'logi', 'ad', 'insur', 'repair', 'hq', 'subc', 'oth', 'grow', 'misc', 'dep', 'intr', 'spl', 'gwImp', 'spm', 'unc', 'tax']) {
      final l = line(plLines, id);
      expect(finDiffCol(100, l.good), Pal.down, reason: '$id が増えたら赤');
      expect(finDiffCol(-100, l.good), Pal.up, reason: '$id が減ったら緑');
    }
    // 損益：売上・利益の行
    for (final id in ['rev', 'gross', 'op', 'ord', 'pretax', 'ni', 'spg']) {
      expect(finDiffCol(100, line(plLines, id).good), Pal.up, reason: '$id が増えたら緑');
    }
    // 貸借対照表：負債は増えたら赤、資産・純資産は増えたら緑
    for (final id in ['loan', 'bond', 'liabs']) {
      expect(finDiffCol(100, line(bsLiabLines, id).good), Pal.down, reason: '$id が増えたら赤');
      expect(finDiffCol(-100, line(bsLiabLines, id).good), Pal.up, reason: '$id が減ったら緑');
    }
    for (final id in ['cash', 'assets']) {
      expect(finDiffCol(100, line(bsAssetLines, id).good), Pal.up);
    }
    expect(finDiffCol(100, line(bsLiabLines, 'equity').good), Pal.up);
    // キャッシュフロー：支払い（マイナスの数）が増える＝数が下がると赤。借り入れが増えると赤、返済が増えると緑
    for (final id in ['intr', 'tax', 'grow', 'misc', 'ar']) {
      final l = line(cfLines, id);
      expect(finDiffCol(-100, l.good), Pal.down, reason: '$id の支払いが増えたら赤');
      expect(finDiffCol(100, l.good), Pal.up, reason: '$id の支払いが減ったら緑');
    }
    expect(finDiffCol(100, line(cfLines, 'borrow').good), Pal.down, reason: '借り入れが増えたら赤（負債の増加）');
    expect(finDiffCol(-100, line(cfLines, 'repay').good), Pal.up, reason: '返済が増えたら緑（負債の減少）');
    for (final id in ['cfop', 'op', 'div', 'delta']) {
      expect(finDiffCol(100, line(cfLines, id).good), Pal.up, reason: '$id が増えたら緑');
    }
  });
}
