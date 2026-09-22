/// **上のクラブは、高く払う。**
///
/// 移籍の話の年俸は `salaryFor` の素の値で、今季の出来も相手の強さも
/// 見ていなかった。契約更改だけが出来を見ていたので、25歳以降に来た
/// 「上のクラブからの話」403件で**残留 9985万に対して上 8480万（−15%）**。
/// 上へ行くと損をするので、移籍が 25歳以降 1〜7% に落ちていた（`arc_sim`）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/season.dart';

void main() {
  group('上のクラブの上乗せ', () {
    test('強いクラブほど多く払う（主力でいられる格まで）', () {
      // 総合力 85 の選手。今のクラブは 70。
      expect(
        CareerEngine.stepUpFactor(70, 80, 85),
        greaterThan(CareerEngine.stepUpFactor(70, 75, 85)),
      );
      expect(CareerEngine.stepUpFactor(70, 75, 85), greaterThan(1.0));
    });

    test('主力でいられない格より上は、それ以上払わない', () {
      // 総合力 75 の選手に、84 のクラブ（主力の線 78 より上、控えの線 85 以下）は
      // 78 のクラブと同じ額しか払わない。
      // **ここを開けると、身の丈より上へ行って登録から外れる選手が4.5倍になる。**
      expect(
        CareerEngine.stepUpFactor(70, 84, 75),
        CareerEngine.stepUpFactor(70, 75 + Formulas.stepUpStarterMargin, 75),
      );
    });

    test('控えとして呼ぶクラブは、割り引いて払う', () {
      // 総合力 70 の選手に、強さ 85 のクラブ（控えの線より上）。
      expect(
        CareerEngine.stepUpFactor(70, 70 + Formulas.benchOfferGap + 1, 70),
        lessThan(CareerEngine.stepUpFactor(70, 73, 70)),
      );
    });

    test('格下や同格からの話には何も足さない（下げもしない）', () {
      expect(CareerEngine.stepUpFactor(70, 70, 80), 1.0);
      expect(CareerEngine.stepUpFactor(70, 60, 80), 1.0);
    });

    test('大きく格上でも青天井にはならない', () {
      expect(
        CareerEngine.stepUpFactor(40, 99, 99),
        closeTo(1 + Formulas.stepUpPayCap, 1e-9),
      );
    });
  });

  group('出来の倍率', () {
    SeasonStats season({required int apps, required double rating}) =>
        SeasonStats(
          appearances: apps,
          goals: 0,
          assists: 0,
          averageRating: rating,
        );

    test('出ていなければ下がる', () {
      expect(
        CareerEngine.performanceFactor(season(apps: 0, rating: 0)),
        lessThan(1.0),
      );
    });

    test('良いシーズンほど高く、上下に上限がある', () {
      final poor = CareerEngine.performanceFactor(season(apps: 30, rating: 5.5));
      final good = CareerEngine.performanceFactor(season(apps: 30, rating: 7.5));
      final great = CareerEngine.performanceFactor(season(apps: 30, rating: 9.9));
      expect(good, greaterThan(poor));
      expect(great, 1.4);
      expect(
        CareerEngine.performanceFactor(season(apps: 30, rating: 3.0)),
        0.7,
      );
    });
  });
}
