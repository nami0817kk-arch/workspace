import 'dart:math';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-11-20 の点検(ユーザー「バグがないか確認して」)で見つかった不具合の確かめ。
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
  test('指導役の片方を放出したら、組は無かったことになり、付け直せる', () {
    final c = _until(1, (c) => c.phase == Phase.preseason && c.season >= 2);
    final vet = c.me.roster.reduce((a, b) => a.age >= b.age ? a : b)..age = 31;
    final young = c.me.roster.where((p) => p != vet).reduce((a, b) => a.age <= b.age ? a : b)..age = 21;
    c.setMentor(vet.id, young.id);
    expect(c.mentorLive, isTrue);
    c.release(vet.id);
    expect(c.mentorLive, isFalse);
    final vet2 = c.me.roster.where((p) => p != young).reduce((a, b) => a.age >= b.age ? a : b)..age = 30;
    expect(c.mentorProblem(vet2, young), isNull);
    c.setMentor(vet2.id, young.id);
    expect(c.mentor, [vet2.id, young.id]);
  });

  test('個人練習に選んだ選手を放出したら、枠に数えない', () {
    final c = _until(2, (c) => c.phase == Phase.contracts && c.season >= 2);
    final ps = [for (final p in c.me.roster) if (c.campProblem(p) == null) p];
    for (final p in ps.take(c.campSlots)) {
      c.setCamp(p.id, Attr.values.first);
    }
    expect(c.campUsed, c.campSlots);
    final gone = ps.first;
    c.release(gone.id);
    expect(c.campUsed, c.campSlots - 1);
    final next = c.me.roster.where((p) => !c.camp.containsKey(p.id) && c.campProblem(p) == null).firstOrNull;
    if (next != null) {
      c.setCamp(next.id, Attr.values.first);
      expect(c.camp.containsKey(next.id), isTrue);
      expect(c.camp.containsKey(gone.id), isFalse);
    }
  });

  test('引退の知らせで「永久欠番にする」を選ぶと、本当に欠番になる', () {
    final c = _until(3, (c) => c.phase == Phase.contracts);
    final m = Message(
        id: 99999,
        season: c.season,
        from: Sender.owner,
        title: '山田 太郎の引退を、どう送り出すか',
        body: '山田 太郎(36歳)がこのチームで7シーズンを過ごし、引退した。',
        kind: MsgKind.offRetire,
        choices: const ['背番号を永久欠番にする', '記念の映像を流す'],
        player: 1234);
    c.inbox.add(m);
    final before = c.retiredNumbers.length;
    c.answer(m.id, 0);
    expect(c.retiredNumbers.length, before + 1);
    expect(c.retiredNumbers.last, [jerseyOfId(1234), c.season, 7]);
    expect(c.retiredNames.last, '山田 太郎');
  });

  test('記者の予想は開幕で閉じ、シーズン中には答えられない', () {
    final c = _until(4, (c) => c.phase == Phase.preseason && c.season >= 2);
    final m = c.inbox.where((x) => x.kind == MsgKind.forecast && x.needsAnswer).firstOrNull;
    expect(m, isNotNull);
    while (c.phase == Phase.preseason) {
      botStep(c);
    }
    expect(m!.needsAnswer, isFalse);
    expect(c.forecastBet, 0);
  });

  test('電話の申し込み: 指名権がもう相手の物でなければ成り立たない', () {
    final c = _until(5, (c) => c.phase == Phase.contracts && c.season >= 2);
    final i = c.picks.indexWhere((p) => p.owner != c.mine);
    expect(i, greaterThanOrEqualTo(0));
    final partner = c.picks[i].owner;
    final give = c.me.roster.first.id;
    final o = TradeOffer(partner: partner, give: [give], get: const [], getPicks: [i]);
    expect(c.callValid(o), isTrue);
    c.picks[i].owner = c.mine;
    expect(c.callValid(o), isFalse);
  });

  test('プレーオフでも、休ませると決めた疲れた選手は出ない', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final c = careerAt(seed, 2)..startSeason();
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      if (c.confRank > playInSeeds) continue;
      c.startPlayoffs();
      final star = c.me.order.first;
      star.wear = Career.settledRestLine + 40;
      c.restIds = [star.id];
      c.playPlayoffGame();
      final g = c.myLastPlayoffGame!;
      expect(g.box.any((l) => l.name == star.name && l.min > 0), isFalse, reason: '休ませた選手が出ている');
      return;
    }
  });

  test('まとめて進めても、トレードの締め切り前の最後の1試合の手前で止まる', () async {
    SharedPreferences.setMockInitialValues({});
    final g = GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(1));
    final car = careerAt(6, 12)..startSeason();
    car.simStops = [];
    g.setCareer(car);
    g.pending.clear();
    final last = blockStart(tradeDeadlineBlock) - 1;
    while (car.roundAt < last - 3) {
      car.playDays(1);
    }
    await g.simRounds(10);
    expect(car.roundAt, last);
    expect(g.simStopReason, SimStop.deadline);
    expect(car.canTrade, isTrue);
  });
}
