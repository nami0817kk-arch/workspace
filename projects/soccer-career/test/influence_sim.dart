// ignore_for_file: avoid_print
/// 何が実際に試合を動かしているかを測る。
///
/// 「積み上げと個人技があまり意味をなしていない」「その他の項目もゲームへの
/// 関与度が低い」という指摘を、当て推量ではなく数字で確かめるための道具。
///
/// `flutter test test/influence_sim.dart` で明示的に走らせる。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
///
/// 見るのは3つ:
/// - **効いた回数**: その仕組みが成功率に0でない値を出した局面の数
/// - **平均の大きさ**: 効いたときに何%動かしたか
/// - **持ち分**: キャリア全体で、成功率の増減のうち何%をその仕組みが占めたか
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

class Tally {
  int hits = 0;
  double sum = 0;
  double swing = 0;

  void add(double value) {
    hits++;
    sum += value;
    swing += value.abs();
  }
}

void main() {
  test('何が試合を動かしているか', () async {
    const seeds = 24;
    final tally = <String, Tally>{};
    var decisions = 0;
    var signatures = 0;
    var withIdentity = 0;
    var withSignature = 0;
    var careers = 0;

    for (var seed = 0; seed < seeds; seed++) {
      final style = Playstyle(
        name: 'x',
        position: Position.cm,
        startAge: 18,
        sim: SimStyle.balanced,
        agent: Agent.pool.first,
      );
      final career = await runCareer(
        style,
        seed,
        onDecision: (match, option) {
          decisions++;
          final development = match.development;
          if (development.identity != null) withIdentity++;
          if (development
              .signatureFactors(option.key, option.detail)
              .isNotEmpty) {
            withSignature++;
          }
          for (final f in match.factorsFor(option)) {
            if (f.value == 0) continue;
            tally.putIfAbsent(f.label, Tally.new).add(f.value);
          }
        },
      );
      signatures += career.signatures;
      careers++;
    }

    final total = tally.values.fold<double>(0, (a, t) => a + t.swing);
    final rows = tally.entries.toList()
      ..sort((a, b) => b.value.swing.compareTo(a.value.swing));

    print('$careers キャリア / $decisions 局面');
    print('個人技: 1人あたり ${(signatures / careers).toStringAsFixed(2)} 個');
    print(
      '型が付いている局面: '
      '${(withIdentity * 100 / decisions).toStringAsFixed(1)}%',
    );
    print(
      '個人技が効く局面: '
      '${(withSignature * 100 / decisions).toStringAsFixed(1)}%',
    );
    print('');
    print('${'仕組み'.padRight(20)} 効いた局面  平均   持ち分');
    for (final row in rows) {
      final t = row.value;
      print(
        '${row.key.padRight(20)} '
        '${(t.hits * 100 / decisions).toStringAsFixed(1).padLeft(6)}%  '
        '${(t.sum / t.hits * 100).toStringAsFixed(2).padLeft(6)}%  '
        '${(t.swing * 100 / total).toStringAsFixed(1).padLeft(5)}%',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
