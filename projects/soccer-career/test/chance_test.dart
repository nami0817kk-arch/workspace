/// **能力値の高さが、どれだけ成功率になるか。**
///
/// 実測（`test/chance_sim.dart`）で、成功率は 22歳で 78% に着き、
/// そこから15年で +6% しか動いていなかった。能力の効き（1点あたり）が
/// 弱いのではなく、**世界の側が育たない**のが原因だった——局面の難易度は
/// 30〜80 で止まっているのに、選ぶ手の能力は 95 まで行く。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/ranking.dart';

double _opponent(int strength) =>
    (Formulas.opponentBaseline - strength) * Formulas.opponentChanceSlope;

void main() {
  group('能力値の効き', () {
    test('1点が、画面の丸めに埋もれない大きさある', () {
      // 1週間に伸びるのは1点。+0.9% だと「68%」が「69%」にしかならず、
      // 育てたことが試合の数字に出た瞬間が分からない。
      expect(Formulas.attributeChanceSlope, greaterThanOrEqualTo(0.010));
    });

    test('画面に出す傾きと、判定の傾きが同じ', () {
      // ここがずれると、そこから先の説明が全部嘘になる。
      final before = MatchInProgress.successChance(60, 60);
      final after = MatchInProgress.successChance(70, 60);
      expect(
        (after - before) * 100,
        closeTo(Ranking.chanceGainPercent(10), 0.001),
      );
      expect(Ranking.chancePerPoint, Formulas.attributeChanceSlope);
    });

    test('能力の効きが、相手の格の効きより大きい', () {
      // 主役は能力値のほう。ここが逆転すると、伸ばすより
      // 弱いリーグに留まるほうが正しくなる。
      expect(
        Formulas.attributeChanceSlope,
        greaterThan(Formulas.opponentChanceSlope),
      );
    });

    test('難易度ちょうどでも五分にはしない', () {
      // 難しい手にリスクを残さないと、一番おいしい手を押すだけになる。
      expect(MatchInProgress.successChance(60, 60), lessThan(0.5));
    });
  });

  group('世界の側も育つ', () {
    test('上のリーグほど、同じ手が通らない', () {
      expect(_opponent(80), lessThan(_opponent(50)));
      // 20点強い相手に移ったら、試合の中で分かる大きさで引かれる。
      // 実測で、キャリアを通して当たる相手は 52 → 68 に上がる。
      expect(
        _opponent(52) - _opponent(72),
        greaterThanOrEqualTo(0.10),
        reason: '上へ移っても、同じ手が同じ確率で通ってしまう',
      );
    });

    test('駆け出しの頃に下駄を履かせない', () {
      // **基準は実測に合わせる。** 60 のままで傾きだけ立てると、
      // 格下とばかり当たる若手が得をして、成功率が 40.3% → 45.0% に
      // 上がってしまった（実際にやって戻した）。
      expect(Formulas.opponentBaseline, lessThanOrEqualTo(55));
      expect(_opponent(52).abs(), lessThan(0.05));
    });

    test('天井が、何を選んでも通る高さにならない', () {
      // 能力 95・難易度 60（実測の平均）で、上のリーグの相手。
      final top = MatchInProgress.successChance(95, 60) + _opponent(68);
      expect(top, lessThan(0.85), reason: 'ピークで何をしても通る');
      expect(top, greaterThan(0.60), reason: '育てた意味が無い');
    });
  });
}
