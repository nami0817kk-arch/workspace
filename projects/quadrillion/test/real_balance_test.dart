// 借金の釣り合い（1.1.0+25）：同じ種で「借りまくる」と「借りない」を30年回して比べる。
// 目安は「借りまくると速く大きくなれることもあるが、時々倒れる（または銀行の管理に入る）」。どちらかが一方的に勝つ作りにしない
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

class Run {
  final String how;
  final int seed;
  bool broke = false, bank = false;
  int months = 0, bridges = 0, calls = 0;
  double cap = 0, peakDebtX = 0, maxDebt = 0;
  int peakRank = 999;
  Run(this.how, this.seed);
  @override
  String toString() =>
      '$how seed$seed: ${broke ? '倒産 ${months ~/ 12}年目' : '30年生存'}${bank ? '・銀行の管理' : ''} 時価${yen(cap)} 最高${peakRank}位 借金最大${yen(maxDebt)}(利益の${peakDebtX.toStringAsFixed(1)}倍) つなぎ$bridges回 貸しはがし$calls回';
}

Run play(String how, int seed, {int years = 30, int start = 1980, String home = 'jp'}) {
  final r = Run(how, seed);
  final g = Game.newGame(SetupConfig(mode: 'world', year: start, traits: const ['charm', 'careful'], home: home), rng: ParkMiller(seed));
  for (var m = 0; m < years * 12; m++) {
    botMonth(g, units: true, borrow: how);
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
    final maxHurt = maxRuns.where((r) => r.broke || r.bank).length;
    // 借りまくると、6回のうち少なくとも1回は倒れるか銀行の管理に入る。ただし全部ではない
    expect(maxHurt, inInclusiveRange(1, 5), reason: lines);
    // 借りないと、ほとんど倒れない
    expect(none.where((r) => r.broke).length, lessThanOrEqualTo(2), reason: lines);
    // 借金は利益の何倍かで上限が決まる（現金に連動しない）。借りまくっても、利益の十数倍を大きく超えない
    for (final r in maxRuns) {
      expect(r.peakDebtX, lessThan(40), reason: r.toString());
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
