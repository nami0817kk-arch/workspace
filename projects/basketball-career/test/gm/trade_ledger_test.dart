import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-6: トレードの勝ち負けの記録帳。
void main() {
  MyTrade lopsided(Career c, int season) {
    final t = (c.mine + 3) % 30;
    final star = [...c.teams[t].roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final worst = [...c.me.roster]..sort((a, b) => a.ovr.compareTo(b.ovr));
    return MyTrade(season: season, partner: t, give: [(worst.first.id, worst.first.name, worst.first.ovr)], get: [(star.first.id, star.first.name, star.first.ovr)]);
  }

  test('1年たつまでは「まだ」。たったら勝ち・五分・負けがつく', () {
    final c = careerAt(3, 12);
    final t = lopsided(c, c.season);
    expect(tradeVerdict(c, t), isNull);
    final old = lopsided(c, c.season - 1);
    expect(tradeVerdict(c, old), 1);
  });

  test('開幕に答え合わせが届き、通算と、いちばんの勝ち、名前を残す(保存も)', () {
    final c = careerAt(4, 12);
    c.myTrades = [lopsided(c, c.season - 1)];
    final before = c.inbox.length;
    c.startSeason();
    expect(c.inbox.skip(before).where((m) => m.title.startsWith('トレードの答え合わせ')), isNotEmpty);
    expect(c.tradeRecord, (1, 0, 0));
    expect(c.tradeBestWorst.$1, 0);
    c.nameTrade(0, '世紀の大泥棒');
    final y = Career.fromJson(c.toJson());
    expect(y.tradeNames[0], '世紀の大泥棒');
    expect(y.tradeLastVerdict, c.tradeLastVerdict);
    // 同じ判定のままなら、次の開幕には知らせない
    int answers() => c.inbox.where((m) => m.title.startsWith('トレードの答え合わせ')).length;
    final n = answers();
    c.phase = Phase.preseason;
    c.startSeason();
    expect(answers(), n);
  });
}
