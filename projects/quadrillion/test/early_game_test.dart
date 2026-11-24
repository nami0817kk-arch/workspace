import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';
import 'support/early.dart';

/// 序盤の遊びやすさ（1.0.0+17）。1980・2000・2025年開始 × 難しさ3段で、はじめの3年（36か月）を自動プレイして、
/// 「買えるものが何も無い月」「事業を育てる手が払えない月」「1手も打てない月」を数える。数え方は test/support/early.dart。
/// 「広げる」（元手の4分の1）を足す前（small: false）と後を並べて出す
void main() {
  String f(double v) => v.toStringAsFixed(1);
  test('はじめの3年に、事業に打てる手が無い月が続きすぎない', () {
    for (final year in const [1980, 2000, 2025]) {
      for (final diff in const ['easy', 'normal', 'hard']) {
        final a = earlyAvg(year, diff, small: false), b = earlyAvg(year, diff);
        // ignore: avoid_print
        print('[early] $year $diff: 何も買えない月 ${f(a.noBuy)}→${f(b.noBuy)}・育てる手が払えない月 ${f(a.noGrow)}→${f(b.noGrow)}'
            '（続く長さ 平均 ${f(a.streak)}→${f(b.streak)}・最長 ${a.worst}→${b.worst}）・1手も打てない月 ${f(a.noMove)}→${f(b.noMove)}'
            '・日銭だけの月 ${f(a.workOnly)}→${f(b.workOnly)}・最初の事業から育てる手まで ${f(a.firstGrow)}→${f(b.firstGrow)}か月'
            '・3年後の月の売上 ${yen(a.rev)}→${yen(b.rev)}・倒産 ${a.over}→${b.over}/12');
        // 直したあと: 育てる手が払えない月は3年で平均3か月まで、続いても4か月まで。1手も打てない月は無い
        // 1.1.0+25 から物価・賃金が統計で動く（1980年の日本は物価の伸びが大きく、元手が早く上がる）ので、線を3→4か月に引き直した
        expect(b.noGrow, lessThanOrEqualTo(4), reason: '$year $diff');
        expect(b.worst, lessThanOrEqualTo(4), reason: '$year $diff');
        expect(b.noMove, 0, reason: '$year $diff');
        expect(b.noBuy, lessThanOrEqualTo(a.noBuy), reason: '$year $diff');
        expect(b.over, 0, reason: '$year $diff');
      }
    }
  });

  test('「広げる」は元手の4分の1の固定額で、現金では変わらない。効き目は店を増やすのと同じ式', () {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: const []), rng: ParkMiller(5));
    s.startBiz((s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => b.mg.compareTo(a.mg))).first.id);
    final b = s.biz.first;
    final capex = s.capexOf(indm[b.ind]!);
    expect(s.extendCost(b), capex * extendMult);
    expect(extendMult, .25);
    final c0 = s.extendCost(b);
    s.cash *= 50;
    expect(s.extendCost(b), c0, reason: '現金が増えても値段は同じ');
    // 払えなければ、お金も手も減らない
    s.cash = c0 * .9;
    final ap0 = s.ap;
    expect(txIn(s.extendN(b), 'ja'), 'お金が足りません');
    expect(s.cash, c0 * .9);
    expect(s.ap, ap0);
    // 払えば、その額が仕掛かりに入り、手を1つ使い、1か月で開く
    s.cash = c0 * 3;
    s.extendN(b);
    expect(s.cash, closeTo(c0 * 2, 1e-6));
    expect(s.ap, ap0 - 1);
    expect(b.pipe.single.k, 'build');
    expect(b.pipe.single.cost, c0);
    expect(b.pipe.single.left, 1);
    final p0 = b.power, up0 = b.upkeep;
    s.nextQuarter();
    expect(b.pipe, isEmpty);
    expect(b.power, greaterThan(p0));
    expect(b.upkeep, greaterThan(up0));
    // 英語の文がある
    s.cash = c0 * 3;
    s.ap = 3;
    expect(RegExp('[぀-ヿ㐀-鿿]').hasMatch(txIn(s.extendN(b), 'en')), isFalse);
  });
}
