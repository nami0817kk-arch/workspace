// ignore_for_file: avoid_print
/// **同じ局面で、最善手は入れ替わるか。**
///
/// `flutter test test/choice_sim.dart` で明示的に走らせる。
///
/// 3つの手の「通りやすさの差」を測っても、それは設計そのもの
/// （安全＝通る・低い見返り／勝負＝通らない・高い見返り）を数えているだけで、
/// 選択の深さにはならない。**知りたいのは、同じ局面が毎回同じ答えかどうか**。
///
/// さらに、1つの育て方だけで測っても足りない。「答えが決まっている」ように
/// 見えても、**育て方を変えたら別の手が最善になる**なら、その局面は
/// 育成の見返りが出る場所であって、死んだ選択肢ではない。
/// 育て方を4つ並べて、局面ごとの最善手が入れ替わるかまで見る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

final _builds = <String, List<Detail>>{
  '平均': [],
  'シュート': [Detail.finishing, Detail.shotPower, Detail.longShots],
  'パス': [Detail.shortPassing, Detail.longPassing, Detail.vision],
  'ドリブル': [Detail.dribbling, Detail.agility, Detail.ballControl],
  '守備': [Detail.tackling, Detail.marking, Detail.interceptions],
};

void main() {
  test('最善手が入れ替わるか', () async {
    const seeds = 8;

    for (final position in [Position.st, Position.cm, Position.cb]) {
      // 育て方 -> 局面 -> 最善だった手 -> 回数
      final byBuild = <String, Map<String, Map<String, int>>>{};

      for (final build in _builds.entries) {
        final byScenario = <String, Map<String, int>>{};
        for (var seed = 0; seed < seeds; seed++) {
          await runCareer(
            Playstyle(
              name: build.key,
              position: position,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool.first,
              focus: build.value,
            ),
            seed,
            onDecision: (match, picked) {
              final options = match.current.options;
              if (options.length < 2) return;
              final best = options.reduce(
                (a, b) =>
                    match.expectedDelta(b) > match.expectedDelta(a) ? b : a,
              );
              final counts = byScenario.putIfAbsent(match.current.id, () => {});
              counts[best.label] = (counts[best.label] ?? 0) + 1;
            },
          );
        }
        byBuild[build.key] = byScenario;
      }

      // 「平均」で答えが決まっていた局面のうち、育て方を変えると
      // 別の手が最善になるものがいくつあるか。
      final flat = byBuild['平均']!;
      var fixed = 0;
      var revived = 0;
      final dead = <String>[];
      for (final entry in flat.entries) {
        final n = entry.value.values.fold(0, (a, b) => a + b);
        if (n < 20) continue;
        final top = entry.value.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        if (top.value / n < 0.9) continue;
        fixed++;
        final others = <String>{};
        for (final build in byBuild.entries) {
          if (build.key == '平均') continue;
          final counts = build.value[entry.key];
          if (counts == null || counts.isEmpty) continue;
          final best = counts.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          if (best.key != top.key) others.add(build.key);
        }
        if (others.isNotEmpty) {
          revived++;
        } else if (dead.length < 5) {
          dead.add(entry.key);
        }
      }
      print(
        '${position.name.toUpperCase().padRight(3)} '
        '平均で答えが決まっている局面 $fixed  '
        '／ 育て方を変えると別の手になる $revived  '
        '／ どう育てても同じ ${fixed - revived}'
        '${dead.isEmpty ? '' : '  例: ${dead.join(' ')}'}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 90)));
}
