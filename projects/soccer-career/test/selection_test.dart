/// 起用のされ方。ベンチに落ちたあとの戻り道と、途中出場。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

MatchResult played(double? rating, {Appearance appearance = Appearance.start}) =>
    MatchResult(
      matchday: 1,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 1,
      appearance: appearance,
      rating: rating,
      goals: 0,
      assists: 0,
    );

MatchResult benched() =>
    played(null, appearance: Appearance.benched);

void main() {
  group('ベンチからの戻り道', () {
    test('デビュー戦の1試合だけでは干されない', () {
      // 4.9 の1試合だけで翌節ベンチ外になっていた。足りないぶんは基準点で埋める。
      expect(MatchEngine.decideAppearance([played(4.9)]), Appearance.sub);
      expect(MatchEngine.formAverage([4.9]),
          closeTo((4.9 + 4 * Formulas.baseRating) / 5, 1e-9));
      // 5試合そろえば埋めない。
      expect(MatchEngine.formAverage([4.9, 4.9, 4.9, 4.9, 4.9]),
          closeTo(4.9, 1e-9));
    });

    test('評価点が低いとベンチ外になる', () {
      final recent = [for (var i = 0; i < 5; i++) played(4.6)];
      expect(MatchEngine.decideAppearance(recent), Appearance.benched);
    });

    test('外れ続けると、必ず一度は声がかかる', () {
      // ここが無かったせいで、一度ベンチに落ちた選手は
      // 評価点が更新されず、永久に出られなかった。
      final recent = [for (var i = 0; i < 5; i++) played(4.6)];
      for (var i = 0; i < Formulas.benchPatience; i++) {
        recent.add(benched());
      }
      expect(MatchEngine.decideAppearance(recent), Appearance.sub);
    });

    test('外れている間は、評価が少しずつ甘く見られる', () {
      final base = [for (var i = 0; i < 5; i++) played(5.4)];
      expect(MatchEngine.decideAppearance(base), Appearance.benched);

      // 1試合ではまだ戻らない。外れ続けるほど甘く見られる。
      final once = [...base, benched()];
      expect(MatchEngine.idleRun(once), 1);
      expect(MatchEngine.decideAppearance(once), Appearance.benched);

      final twice = [...once, benched()];
      expect(MatchEngine.idleRun(twice), 2);
      expect(MatchEngine.decideAppearance(twice), Appearance.sub);
    });

    test('甘く見てもらえる量には上限がある', () {
      final recent = [for (var i = 0; i < 5; i++) played(4.2)];
      for (var i = 0; i < 30; i++) {
        recent.add(benched());
      }
      // 干され続けるほど有利、にはならない（上限で止まる）。
      expect(Formulas.benchRecoveryMax, lessThan(1.5));
      expect(MatchEngine.decideAppearance(recent), Appearance.sub);
    });

    test('離脱明けは、まずベンチから戻る', () {
      final recent = [for (var i = 0; i < 5; i++) played(7.6)];
      for (var i = 0; i < Formulas.benchPatience; i++) {
        recent.add(played(null, appearance: Appearance.injured));
      }
      // 好調でも、長く離れていれば先発とは限らない。
      expect(MatchEngine.idleRun(recent), Formulas.benchPatience);
    });

    test('出れば評価点が更新され、そこから積み直せる', () {
      final recent = [for (var i = 0; i < 5; i++) played(4.6)];
      recent.addAll([benched(), benched(), benched()]);
      expect(MatchEngine.decideAppearance(recent), Appearance.sub);

      // 途中出場で結果を出すと、窓の中身が入れ替わって戻っていく。
      for (var i = 0; i < 5; i++) {
        recent.add(played(7.4, appearance: Appearance.sub));
      }
      expect(MatchEngine.decideAppearance(recent), Appearance.start);
    });
  });

  group('途中出場', () {
    test('疲れているほど休まされやすい', () {
      int rotations({required int condition, required int fatigue}) {
        final engine = MatchEngine(random: Random(4));
        var count = 0;
        for (var i = 0; i < 500; i++) {
          if (engine.rotates(condition: condition, fatigue: fatigue)) count++;
        }
        return count;
      }

      final fresh = rotations(condition: 100, fatigue: 0);
      final tired = rotations(condition: 30, fatigue: 80);
      expect(tired, greaterThan(fresh));
      // 万全なら、ほとんどの試合で先発できる。
      expect(fresh, lessThan(60));
    });
  });

  group('1シーズン通しての起用', () {
    test('ベンチが何試合も続いたまま終わらない', () async {
      final controller = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(5)),
        matchEngine: MatchEngine(random: Random(5)),
        random: Random(5),
      );
      await controller.startCareer(
        name: 'B',
        position: Position.cb,
        age: 18,
        agent: Agent.pool.first,
      );

      var streak = 0;
      var worst = 0;
      var subs = 0;
      while (!controller.state!.seasonFinished) {
        final result = await controller.simulateMatch();
        if (result == null) continue;
        if (result.international) continue;
        if (result.appearance == Appearance.benched) {
          streak++;
          worst = max(worst, streak);
        } else {
          streak = 0;
          if (result.appearance == Appearance.sub) subs++;
        }
      }

      // 3試合外れたら必ず一度は声がかかるので、連続ベンチはそこで切れる。
      expect(worst, lessThanOrEqualTo(Formulas.benchPatience + 1),
          reason: '連続$worst試合ベンチのまま');
      expect(controller.state!.seasonStats.appearances, greaterThan(20));
      // 途中出場は「たまにあること」。半分を超えると、
      // 主力として扱われている実感が無くなる。
      expect(subs, greaterThan(0), reason: '途中出場が一度も無い');
      expect(subs, lessThan(controller.state!.fixtures.length ~/ 2),
          reason: '途中出場が多すぎる（$subs試合）');
    });
  });
}
