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
import 'package:soccer_career/game/match_engine.dart';
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

const _stakesName = {
  MatchStakes.none: 'ふだん',
  MatchStakes.chasing: '追う',
  MatchStakes.leveling: '同点の終盤',
  MatchStakes.protecting: '守り切る',
};

void main() {
  test('最善手が入れ替わるか', () async {
    const seeds = 8;

    // 対象は `--dart-define=POS=gk,cb` で絞れる。`DETAIL=true` なら、
    // 答えが決まっている局面を全部、最善の手と割合つきで並べる。
    const only = String.fromEnvironment('POS', defaultValue: 'st,cm,cb');
    const detail = bool.fromEnvironment('DETAIL');
    // `QUICK=true` なら育て方は「平均」だけ（データを直しながら回す用）。
    const quick = bool.fromEnvironment('QUICK');
    final positions = [
      for (final name in only.split(',')) Position.values.byName(name),
    ];
    for (final position in positions) {
      // 育て方 -> 局面 -> 最善だった手 -> 回数
      final byBuild = <String, Map<String, Map<String, int>>>{};
      // 状況 -> [出会った回数, 状況が無かったときと最善手が違った回数]
      final byStakes = <MatchStakes, List<int>>{};
      // 局面 -> 手 -> [見積もりの合計, 回数]（平均の育て方）
      final evs = <String, Map<String, List<double>>>{};

      for (final build in _builds.entries) {
        if (quick && build.key != '平均') continue;
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
              // **同じ局面を「状況が何も変えていなかったら」で比べる。**
              // 局面ごとに数えると、序盤に出た回と終盤に出た回が混ざって
              // 状況の効きが薄まって見える。1回ずつ、その場で比べる。
              if (build.key == '平均') {
                final evRow = evs.putIfAbsent(match.current.id, () => {});
                for (final o in options) {
                  final e = evRow.putIfAbsent(o.label, () => [0, 0]);
                  e[0] += match.expectedDelta(o);
                  e[1] += 1;
                }
                final plain = options.reduce(
                  (a, b) =>
                      match.expectedDelta(b, asIf: MatchStakes.none) >
                          match.expectedDelta(a, asIf: MatchStakes.none)
                      ? b
                      : a,
                );
                final row = byStakes.putIfAbsent(match.stakes, () => [0, 0]);
                row[0]++;
                if (!identical(plain, best)) row[1]++;
              }
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
        if (detail) {
          final row = evs[entry.key] ?? {};
          print(
            '    ${entry.key.padRight(18)} ${top.key}'
            '（${(top.value * 100 / n).toStringAsFixed(0)}%・$n回）  見積もり: '
            '${[for (final e in row.entries) '${e.key} ${(e.value[0] / e.value[1]).toStringAsFixed(3)}'].join(' ／ ')}',
          );
        }
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
      final total = byStakes.values.fold(0, (a, r) => a + r[0]);
      final parts = [
        for (final s in MatchStakes.values)
          if (byStakes[s] != null)
            '${_stakesName[s]} ${byStakes[s]![0]}回'
                '（${(byStakes[s]![0] * 100 / total).toStringAsFixed(1)}%）'
                '・答えが変わる '
                '${(byStakes[s]![1] * 100 / byStakes[s]![0]).toStringAsFixed(0)}%',
      ];
      print('    状況ごと（平均の育て方）: ${parts.join(' ／ ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 90)));
}
