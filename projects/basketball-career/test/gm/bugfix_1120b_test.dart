import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-20 の2回目の点検(ユーザー「他にバグないかチェック」)で見つかった不具合の確かめ。
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
  test('ドラフト中に今の指名権をトレードで出しても、ドラフトが止まらない', () {
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final c = _until(seed, (c) => c.phase == Phase.draft || (c.phase == Phase.contracts && c.season >= 2));
      if (c.phase != Phase.draft || !c.myTurn) continue;
      final now = c.order[c.draftAt];
      final partner = (c.mine + 1) % c.teams.length;
      // 今の指名権を出し、相手の先の2巡目をもらう(相手に得な形)
      final later = [for (var i = 0; i < c.picks.length; i++) if (c.picks[i].owner == partner && c.picks[i].round == 2 && c.picks[i].season > c.season) i];
      if (later.isEmpty) continue;
      final o = TradeOffer(partner: partner, givePicks: [now], getPicks: [later.last]);
      if (!c.propose(o)) continue;
      expect(c.myTurn || c.phase != Phase.draft, isTrue, reason: '自分の番でないのにドラフトが進んでいない');
      return;
    }
    fail('どの種でも、自分の番でトレードできなかった');
  });

  test('使い終えた指名権と、順が決まった年の入れ替え権は出せない', () {
    final c = _until(2, (c) => c.phase == Phase.contracts && c.season >= 2);
    final partner = (c.mine + 1) % c.teams.length;
    final v = c.judge(TradeOffer(partner: partner, giveSwaps: [c.season]));
    expect(v.ok, isFalse);
    expect(c.swapFrom, c.season + 1);
  });

  test('最低年俸より上を求める選手は、2ウェイで取れない', () {
    final c = _until(3, (c) => c.phase == Phase.contracts && c.season >= 2);
    // 求める額の高い選手を、若手ということにする
    final rich = c.freeAgents.where((p) => c.askOf(p, c.me).salary > minSalary).firstOrNull?..exp = 1;
    expect(rich, isNotNull, reason: '求める額の高い選手が自由契約にいない');
    if (rich == null) return;
    expect(c.twoWayProblem(rich), isNotNull);
    c.signTwoWay(rich.id);
    expect(c.me.twoWay.contains(rich), isFalse);
  });

  test('放した選手は、延長の額と選択権の判断待ちを持ち越さない', () {
    final c = _until(4, (c) => c.phase == Phase.contracts && c.season >= 2);
    final p = c.me.roster.where((x) => !c.expiring.contains(x.id)).first;
    p.nextSalary = p.salary * 3;
    c.optionPending.add(p.id);
    final cost = c.releaseCost(p, ReleaseMode.full);
    if (p.years > 1) expect(cost.later.first, (p.salary * 3 * p.guarantee / 100).round());
    c.release(p.id);
    expect(p.nextSalary, isNull);
    expect(c.optionPending.contains(p.id), isFalse);
  });

  test('返事を待っている知らせは、受信箱の上限で消えない', () {
    final c = careerAt(5, 12);
    final m = Message(id: 88888, season: c.season, from: Sender.owner, title: '返事待ち', body: '', kind: MsgKind.info, choices: const ['はい', 'いいえ']);
    c.inbox.add(m);
    for (var i = 0; i < 120; i++) {
      c.inbox.insert(0, Message(id: 90000 + i, season: c.season, from: Sender.owner, title: 'x', body: ''));
    }
    c.startSeason();
    c.playDays(1);
    expect(c.inbox.contains(m), isTrue);
  });

  test('開幕で、自由契約の選手の成績も空になる', () {
    final c = careerAt(6, 12);
    final p = c.freeAgents.first;
    p.stats.gp = 70;
    c.startSeason();
    expect(p.stats.gp, 0);
    expect(p.prev.gp, 70);
  });

  test('出場時間を決めたとき、けがの選手は表に入らず、治れば自動の時間で出る', () {
    final c = careerAt(7, 12)..startSeason();
    final o = c.me.order;
    final star = o.first;
    star.injured = 5;
    final now = c.me.playMinutes();
    final ord = c.me.order;
    c.setMinutes({for (var i = 0; i < ord.length; i++) ord[i].id: now[i]});
    expect(c.me.minutes.containsKey(star.id), isFalse);
    star.injured = 0;
    final after = c.me.playMinutes();
    expect(after[c.me.order.indexOf(star)], greaterThan(20));
    expect(after.fold(0, (a, b) => a + b), totalMinutes);
  });

  test('目標の話し合いは、最初の区切りの途中でも効き、区切りを越えたら答えられない', () {
    final c = careerAt(8, 12)..startSeason();
    final m = c.inbox.where((x) => x.kind == MsgKind.ownerGoal && x.needsAnswer).firstOrNull;
    expect(m, isNotNull);
    if (m == null) return;
    final before = c.target;
    c.playDays(1);
    c.answer(m.id, 1);
    expect(c.target, before - 5);
  });
}
