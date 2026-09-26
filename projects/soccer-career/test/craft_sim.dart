// ignore_for_file: avoid_print
/// **コツと個人技は、その選手のものになっているか。**
///
/// 「コツの種類と個人技の仕組みを見直して。試合への影響度をあげて」への
/// 手がかり。何を覚え、何を掴み、それが**選手ごとに違うのか**を測る。
/// 全員が同じものを揃えるなら、それは「その選手にしか無いもの」ではない。
///
/// `flutter test test/craft_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/models/traits.dart';

import 'support/career_sim.dart';

void main() {
  test('コツと個人技は、選手ごとに違うか', () async {
    const seeds = 40;

    Future<void> run(String name, Position position) async {
      final signatures = <Signature, int>{};
      final knacks = <Trait, int>{};
      var owned = 0;
      var learned = 0;
      var careers = 0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            effort: TrainingEffort.hard,
          ),
          seed,
        );
        careers++;
        owned += career.signatures;
        for (final s in career.finalSignatures) {
          signatures[s] = (signatures[s] ?? 0) + 1;
        }
        final knack = career.knack;
        if (knack != null) {
          learned++;
          knacks[knack] = (knacks[knack] ?? 0) + 1;
        }
      }

      String top(Map<Object, int> counts) {
        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return entries
            .take(4)
            .map((e) {
              final label = e.key is Signature
                  ? (e.key as Signature).label
                  : (e.key as Trait).label;
              return '$label ${e.value * 100 ~/ careers}%';
            })
            .join(' / ');
      }

      print(
        '${name.padRight(4)} '
        '個人技 ${(owned / careers).toStringAsFixed(2)}個'
        '（上限 ${Signature.maxOwned}、種類 ${signatures.length}）  '
        'コツ ${learned * 100 ~/ careers}%（種類 ${knacks.length}）',
      );
      print('     よく覚える個人技: ${top(signatures)}');
      print('     よく掴むコツ:     ${knacks.isEmpty ? 'なし' : top(knacks)}');
    }

    print('--- $seeds キャリア・追い込む（コツが掴める踏み込み方）---');
    for (final position in [
      Position.st,
      Position.cm,
      Position.cb,
      Position.gk,
    ]) {
      await run(position.label, position);
    }

    print('');
    print(
      '用意してある数: 個人技 ${Signature.values.length}種 / '
      'コツ ${Trait.knacks.length}種',
    );
  }, timeout: const Timeout(Duration(minutes: 60)));
}
