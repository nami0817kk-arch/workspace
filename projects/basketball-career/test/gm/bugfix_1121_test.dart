import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/promise.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の3回目の点検(ユーザー「他に、バグとかない？」)で見つかった不具合の確かめ。
Career _until(int seed, bool Function(Career) done) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (!done(c)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('着かない');
  }
  return c;
}

void main() {
  test('金額の表示: 2億ドルのまわりを丸めない', () {
    expect(money(1960), '1.96億ドル');
    expect(money(2000), '2億ドル');
    expect(money(2040), '2.04億ドル');
    expect(money(2004), '2.004億ドル');
    expect(money(1400), '1.4億ドル');
    expect(money(490), '4900万ドル');
  });

  test('チームの得点は、チームとして取った点の合計', () {
    final c = careerAt(1, 12)..startSeason();
    c.playBlock();
    final mine = c.seasonLog.fold(0, (n, g) => n + g[2]);
    expect(c.me.pointsFor, mine);
    expect(c.me.ppg, closeTo(mine / (c.me.wins + c.me.losses), 1e-9));
    final g = c.lastGames.last;
    expect(g.homeMaxLead + g.awayMaxLead, greaterThan(0));
  });

  test('1試合ずつ進めても、まとめて進めたときと収支がほぼ同じ', () {
    final a = careerAt(2, 12)..startSeason();
    final b = careerAt(2, 12)..startSeason();
    a.playBlock();
    final end = a.roundAt;
    while (b.roundAt < end) {
      b.playDays(1);
    }
    expect((a.revenue - b.revenue).abs(), lessThanOrEqualTo(Income.values.length));
    expect((a.costs - b.costs).abs(), lessThanOrEqualTo(1));
  });

  test('収支の見込み: 閉じたあとは税を二重に引かない。シーズン前はコーチの違約金も入れる', () {
    final c = _until(3, (c) => c.phase == Phase.seasonEnd);
    expect(c.projectedProfit, c.profit);
    final p = _until(4, (c) => c.phase == Phase.preseason && c.season >= 2);
    final before = p.projectedProfit;
    p.staffDebt += 100;
    expect(p.projectedProfit, before - 100);
  });

  test('記者の質問は、シーズンの外では答えられない', () {
    final c = careerAt(5, 12);
    final m = Message(id: 77777, season: c.season, from: Sender.press, title: '記者', body: '', kind: MsgKind.press, choices: const ['強気', '慎重', 'はぐらかす']);
    c.inbox.add(m);
    final hype = c.hype;
    c.answer(m.id, 0);
    expect(m.needsAnswer, isTrue);
    expect(c.hype, hype);
  });

  test('「先発に入れる」で、先発を約束した選手を押し出さない', () {
    final c = careerAt(6, 12)..startSeason();
    final o = c.me.order;
    final a = o[4];
    final b = o[7];
    c.promises.add(Promise(kind: PromiseKind.starter, season: c.season, due: 99, player: a.id, name: a.name));
    final m = Message(id: 66666, season: c.season, from: Sender.player, title: '出番', body: '', kind: MsgKind.minutes, choices: const ['先発に入れる', '今のまま'], player: b.id);
    c.inbox.add(m);
    c.answer(m.id, 0);
    final five = c.me.order.take(5).map((p) => p.id).toList();
    expect(five, contains(a.id));
    expect(five, contains(b.id));
  });

  test('プレーオフに入ったら練習の強さは変えられない', () {
    final c = _until(7, (c) => c.phase == Phase.playoffs);
    final t = c.me.training;
    c.setTraining(t == 2 ? 0 : 2);
    expect(c.me.training, t);
  });

  test('誘いを受けると、前のチームに采配を残さず、前の成績で年俸の求めが上がらない', () {
    final c = _until(8, (c) => c.phase == Phase.seasonEnd);
    final old = c.mine;
    c.me
      ..rotation = [for (final p in c.me.roster) p.id].reversed.toList()
      ..training = 2;
    c.hype = 10;
    c.fired = true;
    final to = (old + 3) % c.teams.length;
    c.jobOffers = [to];
    c.takeJob(to);
    expect(c.mine, to);
    expect(c.teams[old].rotation, isEmpty);
    expect(c.teams[old].training, 1);
    expect(c.hype, 50);
    expect(c.stintStart, c.season + 1);
  });
}
