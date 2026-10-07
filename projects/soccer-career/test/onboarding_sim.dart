// ignore_for_file: avoid_print
/// **新規の人の最初の30分**に何が起きるかを測る。
///
/// 1試合は2〜6局面で、手で選べば1局面 10〜20秒。週の操作を入れると
/// 1節あたり 1〜3分なので、30分はおおよそ **12〜15節**にあたる。
/// ここでは 15節ぶんを、自動進行と同じ選び方で回して並べる。
///
///     flutter test test/onboarding_sim.dart
///
/// **何が問題かを決めてから直す。** 1季目が「何をしても報われない」なら
/// 画面をいくら磨いても離脱する。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

class _Repo implements SaveRepository {
  CareerState? _saved;
  @override
  Future<CareerState?> load() async => _saved;
  @override
  Future<void> save(CareerState state) async => _saved = state;
  @override
  Future<void> clear() async => _saved = null;
}

class _Hall implements HallRepository {
  Hall _saved = const Hall();
  @override
  Future<Hall> load() async => _saved;
  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

/// 30分ぶんの目安。
const weeks = 15;

class Run {
  final ratings = <double>[];
  int started = 0;
  int benched = 0;
  int injured = 0;
  int goals = 0;
  int assists = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int events = 0;
  int news = 0;
  int scenarios = 0;
  int overallStart = 0;
  int overallEnd = 0;
  int position = 0;
  int clubs = 0;

  /// 節ごとの出方。'先' 先発 / '途' 途中 / 'ベ' ベンチ外 / '傷' 離脱。
  final byWeek = <String>[];

  /// 節ごとの評価点（出ていなければ null）。
  final ratingByWeek = <double?>[];

  /// 最初の4節で、画面が「次に出られるか」を何と言っていたか。
  final outlook = <String>[];
}

Future<Run> playFirstWeeks(int seed, Position position) async {
  final controller = CareerController(
    repository: _Repo(),
    hallRepository: _Hall(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await controller.startCareer(
    name: '新人',
    position: position,
    age: 18,
    agent: Agent.pool.first,
  );
  final run = Run()..overallStart = controller.state!.player.overall;

  var played = 0;
  for (var i = 0; i < 60 && played < weeks; i++) {
    final state = controller.state!;
    if (state.seasonFinished || state.retired) break;
    if (controller.pendingEvent != null) {
      run.events++;
      await controller.resolveEvent(controller.pendingEvent!.choices.first);
      continue;
    }
    // 節の前に、画面が何と言っているかを控える。
    if (played < 4) {
      final look = controller.outlook;
      if (look != null) run.outlook.add('第${played + 1}節: ${look.headline}');
    }
    final before = state.leagueResults.length;
    controller.startNextMatch();
    final match = controller.currentMatch;
    if (match != null && !match.isFinished) {
      run.scenarios += match.scenarios.length;
    }
    await controller.simulateMatch();
    final results = controller.state!.leagueResults;
    if (results.length > before) {
      played++;
      final r = results.last;
      if (r.rating != null) {
        run.ratings.add(r.rating!);
        run.ratingByWeek.add(r.rating);
        if (r.appearance == Appearance.start) {
          run.started++;
          run.byWeek.add('先');
        } else {
          run.benched++;
          run.byWeek.add('途');
        }
        run.goals += r.goals;
        run.assists += r.assists;
        if (r.scored > r.conceded) {
          run.won++;
        } else if (r.scored == r.conceded) {
          run.drawn++;
        } else {
          run.lost++;
        }
      } else {
        run.ratingByWeek.add(null);
        if (controller.state!.injury != null) {
          run.injured++;
          run.byWeek.add('傷');
        } else {
          run.benched++;
          run.byWeek.add('ベ');
        }
      }
    }
  }
  run.overallEnd = controller.state!.player.overall;
  run.news = controller.state!.news.length;
  run.position = controller.state!.leaguePosition;
  run.clubs = controller.state!.league.length;
  return run;
}

String _f(num v, [int d = 1]) => v.toStringAsFixed(d);

void main() {
  test('最初の30分', () async {
    const seeds = 24;
    for (final position in [Position.st, Position.cm, Position.cb]) {
      final runs = <Run>[];
      for (var seed = 1; seed <= seeds; seed++) {
        runs.add(await playFirstWeeks(seed, position));
      }
      double avg(num Function(Run) f) =>
          runs.map(f).reduce((a, b) => a + b) / runs.length;
      final ratings = runs.expand((r) => r.ratings).toList()..sort();
      final all = runs.expand((r) => r.ratings).toList();
      final low = all.where((r) => r < 6.0).length;

      print('');
      print('== ${position.name.toUpperCase()}（$weeks節・$seeds人）==');
      print('  先発 ${_f(avg((r) => r.started))} / '
          'ベンチ・離脱 ${_f(avg((r) => r.benched + r.injured))}');
      print('  評価点 平均 ${_f(avg((r) => r.ratings.isEmpty ? 0 : r.ratings.reduce((a, b) => a + b) / r.ratings.length), 2)}'
          ' / 中央 ${_f(ratings.isEmpty ? 0 : ratings[ratings.length ~/ 2], 2)}'
          ' / 6.0未満 ${_f(low * 100 / (all.isEmpty ? 1 : all.length), 0)}%');
      print('  ゴール ${_f(avg((r) => r.goals))} / '
          'アシスト ${_f(avg((r) => r.assists))}');
      print('  勝 ${_f(avg((r) => r.won))} 分 ${_f(avg((r) => r.drawn))} '
          '敗 ${_f(avg((r) => r.lost))}  → 順位 ${_f(avg((r) => r.position))} / '
          '${runs.first.clubs}');
      print('  総合力 ${_f(avg((r) => r.overallStart))} → '
          '${_f(avg((r) => r.overallEnd))}'
          '（+${_f(avg((r) => r.overallEnd - r.overallStart))}）');
      print('  引いた局面 ${_f(avg((r) => r.scenarios))} / '
          '出来事 ${_f(avg((r) => r.events))} / 見出し ${_f(avg((r) => r.news))}');
      final head = [
        for (var w = 1; w <= weeks; w++) w.toString().padLeft(5),
      ].join();
      print('  節   $head');
      for (final kind in ['先', '途', 'ベ', '傷']) {
        final row = <String>[];
        for (var w = 0; w < weeks; w++) {
          final n = runs.where((r) => w < r.byWeek.length && r.byWeek[w] == kind).length;
          row.add('${(n * 100 ~/ seeds).toString().padLeft(4)}%');
        }
        print('  $kind  ${row.join()}');
      }
      final rowR = <String>[];
      for (var w = 0; w < weeks; w++) {
        final xs = runs
            .where((r) => w < r.ratingByWeek.length && r.ratingByWeek[w] != null)
            .map((r) => r.ratingByWeek[w]!)
            .toList();
        rowR.add(xs.isEmpty
            ? '    -'
            : _f(xs.reduce((a, b) => a + b) / xs.length, 2).padLeft(5));
      }
      print('  評価${rowR.join()}');
      for (var i = 0; i < 4; i++) {
        final says = <String, int>{};
        for (final r in runs) {
          if (i < r.outlook.length) {
            says[r.outlook[i]] = (says[r.outlook[i]] ?? 0) + 1;
          }
        }
        final top = says.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final line = top.take(3).map((e) => '${e.key}×${e.value}').join('  ');
        print('    $line');
      }
    }
  });
}
