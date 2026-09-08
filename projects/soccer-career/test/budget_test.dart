/// お金の見通しと、毎週の練習の見え方。
///
/// 見込みを別の式で書くと、画面の数字とシーズン末の結果がずれる。
/// ここではその一致と、尽きる前に警告が出ることを縛る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/support.dart';
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

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.st, age: 24, agent: Agent.pool.first);
  return c;
}

void main() {
  group('収支の見込み', () {
    test('見込みの手取りと、実際に貯蓄が動く額が一致する', () {
      // 画面に出す式と引かれる式が別だと、シーズン末に話が違うことになる。
      const finances = Finances(savings: 5000, lifestyle: 2);
      for (final salary in [800, 3000, 12000, 30000]) {
        for (final staffCost in [0, 600, 2300]) {
          final budget = finances.budgetFor(
            salary: salary,
            agentFeePercent: 9,
            staffCost: staffCost,
            extraLivingRate: 0.04,
          );
          final after = finances.afterSeason(
            salary: salary,
            agentFeePercent: 9,
            staffCost: staffCost,
            extraLivingRate: 0.04,
          );
          expect(after.savings - finances.savings, budget.net,
              reason: '年俸$salary・専属$staffCost');
          expect(budget.outgoing,
              budget.agentFee + budget.tax + budget.living + budget.staff);
        }
      }
    });

    test('スポンサー収入は手取りに乗る', () {
      const finances = Finances(savings: 0);
      final without =
          finances.budgetFor(salary: 5000, agentFeePercent: 10);
      final with_ = finances.budgetFor(
          salary: 5000, agentFeePercent: 10, sponsor: 800);
      expect(with_.net - without.net, 800);
    });

    test('高すぎるスタッフを雇うと、尽きることが先に分かる', () async {
      final c = await started(seed: 31);
      final state = c.state!;
      state.salary = 1200;
      state.finances = const Finances(savings: 0, lifestyle: 1);
      expect(state.willRunOut, isFalse, reason: '誰も雇っていないのに尽きる');

      state.staff = const StaffTeam(coach: 3, trainer: 3, nutritionist: 3);
      expect(state.budget.staff, state.staff.costPerSeason);
      expect(state.willRunOut, isTrue, reason: '年俸を超える人件費でも警告が出ない');
      expect(state.projectedSavings, lessThan(0));
    });

    test('見込みの貯蓄が、実際のシーズン末とだいたい合う', () async {
      // 途中の出来事で前後するので、桁が合っていることだけを見る。
      final c = await started(seed: 32);
      c.state!.staff = const StaffTeam(coach: 1);
      final projected = c.state!.projectedSavings;
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);
      expect((c.state!.finances.savings - projected).abs(),
          lessThan(c.state!.salary),
          reason: '見込みと実際が年俸1年ぶん以上ずれている');
    });
  });

  group('貯蓄が尽きたとき', () {
    test('スタッフが離れたことを知らせる', () async {
      final c = await started(seed: 33);
      final state = c.state!;
      // 払えない額のスタッフを抱えたまま1年を終える。
      state.staff = const StaffTeam(coach: 3, trainer: 3, nutritionist: 3);
      state.finances = const Finances(savings: 0, lifestyle: 3);
      state.salary = 500;
      expect(state.willRunOut, isTrue);

      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);

      expect(c.state!.staff.isEmpty, isTrue, reason: 'スタッフが残っている');
      expect(
        c.news.any((n) => n.headline.contains('専属スタッフ')),
        isTrue,
        reason: '黙って全員消えている',
      );
    });

    test('払えていれば、何も言わない', () async {
      final c = await started(seed: 34);
      c.state!.staff = const StaffTeam(coach: 1);
      c.state!.finances = const Finances(savings: 20000);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);

      expect(c.state!.staff.isEmpty, isFalse);
      expect(c.news.any((n) => n.headline.contains('専属スタッフ')), isFalse);
    });
  });
}
