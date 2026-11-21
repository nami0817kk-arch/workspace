import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み A-5: ドラフトの年ごとの差。
void main() {
  test('年ごとの顔ぶれの割合(豊作・不作が約4分の1ずつ、目玉は7割ほどの年)', () {
    var good = 0, bad = 0, star = 0, pos = 0;
    const n = 2000;
    for (var s = 0; s < n; s++) {
      final c = draftClassOf(7 + s ~/ 20, s % 20);
      if (c.quality == 1) good++;
      if (c.quality == -1) bad++;
      if (c.star) star++;
      if (c.strongPos != null) pos++;
    }
    expect(good / n, closeTo(0.25, 0.05));
    expect(bad / n, closeTo(0.25, 0.05));
    expect(star / n, closeTo(0.7, 0.06));
    expect(pos / n, closeTo(0.5, 0.06));
  });

  test('豊作の年は上の候補の伸びしろが大きく、得意なポジションが多く、目玉は飛び抜ける', () {
    var id = 0;
    int next() => ++id;
    double avgPot(List<Prospect> l) => l.map((p) => p.player.pot).reduce((a, b) => a + b) / l.length;
    final good = makeProspects(Rng(5), next, 40, cls: const DraftClass(1, Pos.c, true));
    final bad = makeProspects(Rng(5), next, 40, cls: const DraftClass(-1, null, false));
    final plain = makeProspects(Rng(5), next, 40);
    expect(avgPot(good), greaterThan(avgPot(plain)));
    expect(avgPot(bad), lessThan(avgPot(plain)));
    final centers = good.where((p) => p.player.pos == Pos.c).length;
    expect(centers, greaterThanOrEqualTo(10));
    final bestGood = good.map((p) => p.player.pot).reduce((a, b) => a > b ? a : b);
    final bestPlain = plain.map((p) => p.player.pot).reduce((a, b) => a > b ? a : b);
    expect(bestGood, greaterThan(bestPlain));
    // 見える幅は、いつも本当の値を含む
    for (final p in [...good, ...bad]) {
      expect(p.potLo, lessThanOrEqualTo(p.player.pot));
      expect(p.potHi, greaterThanOrEqualTo(p.player.pot));
    }
  });

  test('うわさはシーズンの初めに届き、その年の指名権の値打ちが顔ぶれで変わる', () {
    final c = careerAt(3, 12);
    final before = c.inbox.length;
    c.startSeason();
    expect(c.inbox.skip(before).where((m) => m.title == 'ドラフトのうわさ'), isNotEmpty);
    final cls = draftClassOf(c.seed, c.season);
    final now = c.picks.firstWhere((p) => p.season == c.season && p.round == 1);
    final later = c.picks.firstWhere((p) => p.season == c.season + 1 && p.round == 1);
    expect(now.classScale, cls.valueScale);
    expect(later.classScale, 1.0);
    final v = pickValue(now, TeamMode.balanced, 10, c.season);
    now.classScale = 1.0;
    expect(v, closeTo(pickValue(now, TeamMode.balanced, 10, c.season) * cls.valueScale, 1e-9));
    // 読み込み直しても、同じ倍率
    final y = Career.fromJson(c.toJson());
    expect(y.picks.firstWhere((p) => p.season == c.season && p.round == 1).classScale, cls.valueScale);
  });
}
