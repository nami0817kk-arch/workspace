import 'dart:math';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GmController> _with(Career car) async {
  SharedPreferences.setMockInitialValues({});
  final c = GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(1));
  c.setCareer(car);
  c.pending.clear();
  return c;
}

Career _inSeason(int seed) {
  final car = careerAt(seed, 12)..startSeason();
  car.simStops = [];
  return car;
}

void main() {
  test('1節ずつ進める: 区切りをまたいでも、まとめて進めたのと同じ結果になる。1節ごとに結果が届く', () async {
    final a = await _with(_inSeason(1));
    final b = _inSeason(1);
    var calls = 0, seen = 0;
    final r = await a.simRounds(30, onRound: (games) async {
      calls++;
      seen += games.length;
    });
    b.playBlock();
    b.playDays(10);
    final car = a.career!;
    expect(calls, 30);
    expect(seen, 30, reason: '毎節に自分の試合が1つ');
    expect(car.roundAt, 30);
    expect(car.block, 1);
    expect((car.me.wins, car.me.losses), (b.me.wins, b.me.losses));
    expect(r!.played, 30);
  });

  test('止める: simCancel を立てると、その節で止まる。止まる場面: 申し込みが届いたら止まる', () async {
    final a = await _with(_inSeason(2));
    await a.simRounds(40, onRound: (_) async {
      if (a.career!.roundAt == 5) a.simCancel = true;
    });
    expect(a.career!.roundAt, 5);
    expect(a.simCancel, isFalse);

    // 申し込みは区切りの終わりに届く。届いたらその区切りの終わりで止まる
    for (final seed in [3, 4, 5, 6, 7]) {
      final car = _inSeason(seed)..simStops = [SimStop.offer.index];
      final c = await _with(car);
      await c.simRounds(gamesPerSeason);
      if (car.incoming == null) continue;
      expect(c.simStopReason, SimStop.offer);
      expect(car.roundAt, blockStart(car.block));
      return;
    }
  });

  test('roundsUntil: その節の手前までの数', () {
    final car = _inSeason(1);
    expect(car.roundsUntil(10), 10);
    car.playDays(4);
    expect(car.roundsUntil(10), 6);
    expect(car.roundsUntil(2), 0);
  });
}
