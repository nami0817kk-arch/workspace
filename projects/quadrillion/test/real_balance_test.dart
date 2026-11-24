// 借金の釣り合い（1.1.0+25）：同じ種で「借りまくる」と「借りない」を30年回して比べる。
// 目安は「借りまくると速く大きくなれることもあるが、時々倒れる（または銀行の管理に入る）」。どちらかが一方的に勝つ作りにしない
//
// 1.1.0+26（段2：店・ライン・拠点の数）で数字が大きく変わった。店などは上限・責任者・本部・物流・開くまでの月で頭打ちになり、
// 開いてから1〜2年は固定費が売上を食うので、借りたお金を寝かせたまま5年で返す打ち方は返済に追われる。
// 線は「借りまくるが30年勝ち続けることは無い」「借りないで必ず倒れることは無い」「借りると一度は借りない人より大きくなる」に引き直した。
// 前後の数字（6つの種）は PR の本文にある
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

class Run {
  final String how;
  final int seed;
  bool broke = false, bank = false;
  int months = 0, bridges = 0, calls = 0;
  double cap = 0, peakDebtX = 0, maxDebt = 0, peakCap = 0;
  int peakRank = 999;
  Run(this.how, this.seed);
  @override
  String toString() =>
      '$how seed$seed: ${broke ? '倒産 ${months ~/ 12}年目' : '30年生存'}${bank ? '・銀行の管理' : ''} 時価${yen(cap)} 時価の最高${yen(peakCap)} 最高$peakRank位 借金最大${yen(maxDebt)}(利益の${peakDebtX.toStringAsFixed(1)}倍) つなぎ$bridges回 貸しはがし$calls回';
}

Run play(String how, int seed, {int years = 30, int start = 1980, String home = 'jp'}) {
  final r = Run(how, seed);
  final g = Game.newGame(SetupConfig(mode: 'world', year: start, traits: const ['charm', 'careful'], home: home), rng: ParkMiller(seed));
  for (var m = 0; m < years * 12; m++) {
    botMonth(g, units: true, borrow: how, focus: true);
    if (g.won != null) {
      g.mode = 'endless';
      g.won = null;
    }
    for (final n in g.lastNews) {
      final k = msgKey(n.m);
      if (k.startsWith('資金が足りず、銀行からつなぎ')) r.bridges++;
      if (k.startsWith('不況で銀行が貸しはがし')) r.calls++;
    }
    if (g.debt > r.maxDebt) r.maxDebt = g.debt;
    if (g.cap > r.peakCap) r.peakCap = g.cap;
    final x = g.debtMultiple();
    if (x < 99 && x > r.peakDebtX) r.peakDebtX = x;
    if (g.bankDone) r.bank = true;
    r.months = m + 1;
    if (g.over != null) {
      r.broke = true;
      break;
    }
  }
  r.cap = g.cap;
  r.peakRank = g.peakRank;
  return r;
}

void main() {
  test('社長の時間：会社が大きくなるほど会議に取られ、任せると減る。無理が続くと倒れ、数か月動けない', () {
    final g = Game.newGame(SetupConfig(year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(9));
    final small = g.hMeet();
    for (var m = 0; m < 96; m++) {
      botMonth(g, units: true, borrow: 'some');
    }
    resolveEvents(g);
    final big = g.hMeet();
    final lines = ['創業時: 会議 ${small}h・ふつうに使える残り ${hoursNormal - small}h',
        '8年後（事業${g.biz.length}・部下${g.staff.length}・子会社${g.subs().length}）: 会議 ${big}h・残り ${math.max(0, hoursNormal - big)}h'];
    expect(big, greaterThan(small));
    for (final b in g.biz) {
      if (b.mgr != null) b.deleg = true;
    }
    final dl = g.hMeet();
    lines.add('任せられる事業を全部任せると: 会議 ${dl}h');
    expect(dl, lessThanOrEqualTo(big));
    // 毎月300時間まで働くと、何か月で倒れるか
    final h = Game.newGame(SetupConfig(year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(9));
    var months = 0;
    while (h.down == 0 && months < 24) {
      h.hUsed = hoursMax - h.hMeet();
      h.nextQuarter();
      h.events.clear();
      months++;
    }
    lines.add('毎月300時間働くと $months か月目に倒れ、${h.down}か月休む');
    expect(h.down, greaterThan(0));
    expect(h.hLeft(), 0, reason: '倒れているあいだは何もできない');
    // ignore: avoid_print
    print(lines.join('\n'));
    final f = Platform.environment['QUAD_BALANCE'];
    if (f != null) File('$f.hours').writeAsStringSync(lines.join('\n'));
  });

  test('借りまくる／借りないを同じ種で30年回して比べる（1980年・日本）', () {
    final out = <Run>[];
    for (final seed in [11, 22, 33, 44, 55, 66]) {
      out.add(play('max', seed));
      out.add(play('some', seed));
      out.add(play('none', seed));
    }
    final lines = out.map((r) => r.toString()).join('\n');
    // 数字は報告に使う（QUAD_BALANCE にファイルを渡すと書き出す）
    final f = Platform.environment['QUAD_BALANCE'];
    if (f != null) File(f).writeAsStringSync(lines);
    // ignore: avoid_print
    print(lines);
    final maxRuns = out.where((r) => r.how == 'max').toList(), none = out.where((r) => r.how == 'none').toList();
    final some = out.where((r) => r.how == 'some').toList();
    Run noneOf(int seed) => none.firstWhere((r) => r.seed == seed);
    // 借りまくると、6回のうち少なくとも1回は倒れるか銀行の管理に入る
    expect(maxRuns.where((r) => r.broke || r.bank).length, greaterThanOrEqualTo(1), reason: lines);
    // 借りまくるが30年勝ち続ける（倒れずに、借りないより大きく終わる）のは、6回のうち全部ではない
    expect(maxRuns.where((r) => !r.broke && r.cap > noneOf(r.seed).cap).length, lessThan(6), reason: lines);
    // 借りないと、ほとんど倒れない。
    // 1.1.0+27（段3：人）から、給料が世の中の賃金と腕に合わせて毎年上がり、店長や部下が辞めるので、
    // 人件費を見直さない自動プレイは、稼ぎ頭の業種が沈んだあと（20年目過ぎ）に倒れることがある。線を半分までに引き直した
    expect(none.where((r) => r.broke).length, lessThanOrEqualTo(3), reason: lines);
    // 借りると速く大きくなれることがある（どこかの種で、借りた会社の時価の最高が、借りない会社の最後の時価を超える）
    expect([...maxRuns, ...some].any((r) => r.peakCap > noneOf(r.seed).cap), isTrue, reason: lines);
    // 借金は利益の何倍かで上限が決まる（現金に連動しない）。借りまくっても、利益の十数倍を大きく超えない
    for (final r in maxRuns) {
      expect(r.peakDebtX, lessThan(40), reason: r.toString());
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
