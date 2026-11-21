import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/league_base.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み D-3: 始めるたびに違うリーグ。
void main() {
  test('チームの土台はリーグごとに変わる(同じリーグなら同じ)', () {
    final a = [for (var t = 0; t < 30; t++) leagueBaseOf(1, t)];
    final b = [for (var t = 0; t < 30; t++) leagueBaseOf(2, t)];
    expect(a.map((x) => x.market), isNot(b.map((x) => x.market)));
    expect([for (var t = 0; t < 30; t++) leagueBaseOf(1, t).market], a.map((x) => x.market));
    for (final x in [...a, ...b]) {
      expect(x.market, inInclusiveRange(0.75, 1.31));
      expect(x.facility, anyOf(1, 2));
    }
    expect({for (final x in a) x.fans}.length, greaterThan(1));
  });

  test('始める前の10年の歴史があり、強いチームほど優勝している。保存して読み直しても同じ', () {
    final c = Career.start(seed: 7);
    expect(c.prehistory.length, 10);
    final strong = [for (var t = 0; t < 30; t++) t]..sort((a, b) => c.strengthRank(a).compareTo(c.strengthRank(b)));
    for (final (ch, lo) in c.prehistory) {
      expect(strong.take(8), contains(ch));
      expect(ch, isNot(lo));
    }
    final y = Career.fromJson(c.toJson());
    expect(y.prehistory, c.prehistory);
    // 優勝してからの年と、ライバル
    final champ = c.prehistory.last.$1;
    expect(c.yearsSinceTitle(champ), isNotNull);
    expect(c.rivalsOf(champ), isA<List<int>>());
  });

  test('任されたチームの施設はリーグでの土台から。街の大きさが収入に掛かる', () {
    final c = Career.start(seed: 9, team: 4);
    final b = leagueBaseOf(9, 4);
    expect(c.facilities, List.filled(3, b.facility));
    expect(c.market, closeTo(marketSizes[4] * b.market, 1e-9));
  });
}
