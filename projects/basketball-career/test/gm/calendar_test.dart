import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

Career _started(int seed) {
  final c = careerAt(seed, 15);
  while (c.phase != Phase.season) {
    botStep(c);
  }
  return c;
}

void main() {
  test('今季の自分の試合を日程表のために残し、保存される', () {
    final c = _started(3);
    c.playBlock();
    expect(c.seasonLog.length, c.roundAt);
    expect(c.seasonLog.where((r) => r[2] > r[3]).length, c.me.wins);
    final back = Career.fromJson(c.toJson());
    expect(back.seasonLog, c.seasonLog);
  });

  test('順位が決まったら主力を休ませる: 決まるまでは休まず、決まったら先発が休む', () {
    for (var seed = 1; seed <= 40; seed++) {
      final b = _started(seed)..restWhenSettled = true;
      while (b.phase == Phase.season && !b.standingSettled) {
        expect(b.me.roster.fold(0, (n, p) => n + p.restGames), 0, reason: '決まる前は休まない');
        b.playWeek();
      }
      if (b.phase != Phase.season) continue;
      while (b.phase == Phase.season) {
        b.playWeek();
      }
      final rested = b.me.roster.fold(0, (n, p) => n + p.restGames);
      // ignore: avoid_print
      print('seed $seed rested $rested');
      expect(rested, greaterThan(0));
      return;
    }
    fail('順位が早く決まる経歴が見つからない');
  });
}
