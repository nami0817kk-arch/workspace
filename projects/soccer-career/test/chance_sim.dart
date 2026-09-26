// ignore_for_file: avoid_print
/// **能力値を上げると、成功率は実際どれだけ上がるのか。**
///
/// `successChance` は 能力−難易度 に `attributeChanceSlope` を掛けるが、
/// 伸びるほど上のリーグへ行くので、**相手の格が同じぶんだけ引いていく**。
/// 式の傾きではなく、**キャリアを通して実際に手元に残る量**を測る。
///
/// 最初に回して分かったのは、**効きが弱いのではなく効き切ってしまう**こと:
/// 18歳 40% → 22歳 78% に着いたあと、**15年で +6% しか動かなかった**。
///
/// `flutter test test/chance_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

class Bucket {
  int n = 0;
  double attribute = 0;
  double difficulty = 0;
  double base = 0;
  double total = 0;
  double opponent = 0;
  double overall = 0;
  int won = 0;

  void add({
    required int attribute,
    required int difficulty,
    required double base,
    required double total,
    required double opponent,
    required int overall,
  }) {
    n++;
    this.attribute += attribute;
    this.difficulty += difficulty;
    this.base += base;
    this.total += total;
    this.opponent += opponent;
    this.overall += overall;
  }
}

void main() {
  test('能力値が成功率にどれだけ残るか', () async {
    const seeds = 24;
    // 年齢ごとに束ねる。18〜36。
    final byAge = <int, Bucket>{};

    for (var seed = 0; seed < seeds; seed++) {
      await runCareer(
        Playstyle(
          name: 'x',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
        ),
        seed,
        onDecision: (match, option) {
          final factors = match.factorsFor(option);
          final opponent = factors
              .where((f) => f.label == '格上の相手' || f.label == '格下の相手')
              .fold<double>(0, (s, f) => s + f.value);
          byAge
              .putIfAbsent(match.player.age, Bucket.new)
              .add(
                attribute: match.attributeFor(option),
                difficulty: option.difficulty,
                base: match.baseChanceFor(option),
                total: match.chanceFor(option),
                opponent: opponent,
                overall: match.player.overall,
              );
        },
      );
    }

    print('--- 能力値は、成功率としてどれだけ手元に残るか（$seeds キャリア）---');
    print(
      '${'歳'.padLeft(3)}  ${'総合力'.padLeft(6)}  ${'使う能力'.padLeft(8)}  '
      '${'難易度'.padLeft(6)}  ${'地力'.padLeft(6)}  ${'相手の格'.padLeft(8)}  '
      '${'成功率'.padLeft(6)}  局面数',
    );
    final ages = byAge.keys.toList()..sort();
    for (final age in ages) {
      final b = byAge[age]!;
      if (b.n < 50) continue;
      print(
        '${age.toString().padLeft(3)}  '
        '${(b.overall / b.n).toStringAsFixed(1).padLeft(6)}  '
        '${(b.attribute / b.n).toStringAsFixed(1).padLeft(8)}  '
        '${(b.difficulty / b.n).toStringAsFixed(1).padLeft(6)}  '
        '${(b.base / b.n * 100).toStringAsFixed(1).padLeft(6)}%  '
        '${(b.opponent / b.n * 100).toStringAsFixed(1).padLeft(7)}%  '
        '${(b.total / b.n * 100).toStringAsFixed(1).padLeft(6)}%  '
        '${b.n}',
      );
    }

    // 18歳と、ピーク（28歳）の差。
    final young = byAge[19];
    final peak = byAge[28];
    if (young != null && peak != null) {
      final grew = peak.attribute / peak.n - young.attribute / young.n;
      final baseUp = (peak.base / peak.n - young.base / young.n) * 100;
      final totalUp = (peak.total / peak.n - young.total / young.n) * 100;
      final oppDown = (peak.opponent / peak.n - young.opponent / young.n) * 100;
      print('');
      print('19歳 → 28歳:');
      print('  使う能力 +${grew.toStringAsFixed(1)}');
      print('  地力     ${baseUp >= 0 ? '+' : ''}${baseUp.toStringAsFixed(1)}%');
      print('  相手の格 ${oppDown >= 0 ? '+' : ''}${oppDown.toStringAsFixed(1)}%');
      print(
        '  成功率   ${totalUp >= 0 ? '+' : ''}${totalUp.toStringAsFixed(1)}%'
        '  ← 20年育てて手元に残るのはこれ',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
