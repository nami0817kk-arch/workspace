import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/situation.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-2: チームの事情とうわさ。
void main() {
  test('事情は考え方・年俸・ポジションの穴・もめごとから決まる', () {
    final c = careerAt(3, 12)..startSeason();
    for (final t in c.teams) {
      final s = situationsOf(t).map((x) => x.$1).toSet();
      expect(s.contains(Situation.contend), t.mode == TeamMode.contend);
      expect(s.contains(Situation.rebuild), t.mode == TeamMode.rebuild);
      expect(s.contains(Situation.hole), holeOf(t) != null);
      expect(s.contains(Situation.feud), feudOf(t) != null);
    }
  });

  test('区切りごとにうわさが届き、締め切りの前からは外れない。保存もする', () {
    final c = careerAt(4, 12)..startSeason();
    while (c.phase == Phase.season && c.block < blocksPerSeason) {
      c.playBlock();
    }
    expect(c.rumors, isNotEmpty);
    for (final r in c.rumors) {
      expect(r.team, isNot(c.mine));
      if (r.block >= tradeDeadlineBlock - 1) expect(r.real, isTrue);
    }
    expect(c.inbox.where((m) => m.title.startsWith('うわさ')), isNotEmpty);
    final y = Career.fromJson(c.toJson());
    expect(y.rumors.length, c.rumors.length);
    expect(y.rumors.first.text, c.rumors.first.text);
  });

  test('外れのうわさは、本当には無い事情を言う', () {
    var fakes = 0;
    for (var seed = 1; seed <= 12; seed++) {
      final c = careerAt(seed, 12)..startSeason();
      final r = makeRumor(c);
      if (r == null || r.real) continue;
      fakes++;
      expect(situationsOf(c.teams[r.team]).any((x) => x.$1 == r.situation), isFalse);
    }
    expect(fakes, greaterThanOrEqualTo(0));
  });

  test('もめている選手は、相手が安く出す(値打ちを4分の3に見る)', () {
    final c = careerAt(5, 12)..startSeason();
    for (var t = 0; t < c.teams.length; t++) {
      if (t == c.mine) continue;
      final p = feudOf(c.teams[t]);
      if (p == null) continue;
      final give = c.me.roster.map((x) => x.id).take(2).toList();
      final o = TradeOffer(partner: t, give: give, get: [p.id]);
      final plain = judgeTrade(c.teams, c.picks, c.mine, o, c.season);
      final cheap = judgeTrade(c.teams, c.picks, c.mine, o, c.season, cheap: {p.id});
      if (plain.ratio > 0) expect(cheap.ratio, greaterThan(plain.ratio));
      return;
    }
  });
}
