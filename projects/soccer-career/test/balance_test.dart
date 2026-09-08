/// バランスの見張り。
///
/// 200人ぶんのシミュレーション（`test/balance_sim.dart`）で決めた値が、
/// その後の変更で壊れていないかを数人ぶんで確かめる。
/// 数字そのものではなく「桁が変わっていないか」を見るための幅にしてある。
///
/// ここが落ちたら、まず `flutter test test/balance_sim.dart` を回して
/// 全体の数字を見ること。1つの定数を動かすと、だいたい他所に出る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  group('キャリア1本を通した数字', () {
    late List<Career> careers;

    setUpAll(() async {
      careers = [
        for (var seed = 0; seed < 3; seed++)
          await runCareer(
            Playstyle(
              name: '標準',
              position: Position.cm,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool[0],
            ),
            seed,
          ),
        for (var seed = 0; seed < 3; seed++)
          await runCareer(
            Playstyle(
              name: '前線',
              position: Position.st,
              startAge: 18,
              sim: SimStyle.aggressive,
              agent: Agent.pool[1],
            ),
            100 + seed,
          ),
      ];
    });

    test('プロとして一通りの長さを戦える', () {
      for (final c in careers) {
        expect(c.seasons, greaterThanOrEqualTo(8),
            reason: 'キャリアが短すぎる');
        expect(c.retireAge, greaterThanOrEqualTo(30));
        expect(c.appearances, greaterThan(100), reason: '出場が少なすぎる');
      }
    });

    test('伸びるが、上限には簡単には届かない', () {
      for (final c in careers) {
        expect(c.growth, greaterThan(6), reason: '伸びなさすぎる');
        expect(c.peakOverall, inInclusiveRange(65, 95));
        // 若いうちは1回で2つ伸びるので、上限を1つ跨ぐことはある。
        expect(c.peakOverall, lessThanOrEqualTo(c.potential + 2),
            reason: 'ポテンシャル(${c.potential})を超えている(${c.peakOverall})');
      }
      // 全員が上限まで行けてしまうと、ポテンシャルが飾りになる。
      final reached = careers.where((c) => c.reachedPotential).length;
      expect(reached, lessThan(careers.length));
    });

    test('評価点が現実的な範囲に収まる', () {
      for (final c in careers) {
        expect(c.averageRating, inInclusiveRange(6.0, 8.0),
            reason: '評価点が偏っている（${c.style.name}）');
      }
    });

    test('怪我で1シーズンの大半を失わない', () {
      for (final c in careers) {
        final perSeason = c.injuries / c.seasons;
        expect(perSeason, lessThan(3.5), reason: '怪我が多すぎる');
        expect(c.missedMatches / c.seasons, lessThan(16),
            reason: '離脱で試合の半分近くを失っている');
      }
    });

    test('年俸が指数で膨らまない', () {
      for (final c in careers) {
        // 契約更改で前年の年俸に倍率を掛け続けていた頃は、
        // 100シーズンで平均11億円、最大200億円になっていた。
        expect(c.peakSalary, lessThan(60000),
            reason: '年俸が膨らんでいる（${c.peakSalary}万円）');
        expect(c.peakSalary, greaterThan(500));
      }
    });

    test('得点が1試合1点を超え続けない', () {
      // 1人ずつ見ると、稀に出る大当たりのキャリアで落ちる。
      // 見たいのは「前線の選手が平均してどれくらい取るか」なので平均で見る。
      final strikers =
          careers.where((c) => c.style.position == Position.st).toList();
      final perMatch = strikers.fold<double>(
              0, (s, c) => s + c.goals / c.appearances) /
          strikers.length;
      expect(perMatch, lessThan(0.95),
          reason: '1試合あたり${perMatch.toStringAsFixed(2)}点は多すぎる');
      expect(perMatch, greaterThan(0.15), reason: '前線の選手が点を取れていない');
    });

    test('移籍の話が届く', () {
      // 契約が減らずオファーが一度も来なかった不具合の見張り。
      expect(careers.fold(0, (s, c) => s + c.offersSeen), greaterThan(0));
    });
  });

  group('数値の関係', () {
    test('決定機は必ず点になるわけではない', () {
      expect(Formulas.goalConversion, lessThan(1.0));
      expect(Formulas.goalConversion, greaterThan(0.3));
      // アシストは「この後に味方が決める」ことが条件なので、実際の確率は
      // assistConversionAt で必ず 1 を切る（scoreline_test で見ている）。
      expect(Formulas.assistConversion, lessThanOrEqualTo(1.0));
    });

    test('成功より失敗のほうが評価点を動かす', () {
      expect(Formulas.ratingPerFailure.abs(),
          greaterThan(Formulas.ratingPerSuccess));
    });

    test('若いほど伸びる', () {
      expect(Formulas.growthByAge(18), greaterThan(Formulas.growthByAge(24)));
      expect(Formulas.growthByAge(24), greaterThan(Formulas.growthByAge(29)));
      expect(Formulas.growthByAge(33), lessThan(1.0));
    });

    test('ポジションの重みで成長を割り戻す', () {
      // GK は総合力の6割が GK 能力なので、割り戻さないと伸びが速すぎる。
      final gk = Formulas.growthShareFactor(
          Attributes.weightShare(Position.gk, AttributeKey.goalkeeping));
      final cm = Formulas.growthShareFactor(
          Attributes.weightShare(Position.cm, AttributeKey.passing));
      expect(gk, lessThan(cm));
      expect(gk, greaterThanOrEqualTo(Formulas.growthShareMin));
    });
  });
}
