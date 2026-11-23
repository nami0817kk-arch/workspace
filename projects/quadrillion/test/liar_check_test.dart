import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 社長が「二枚舌」のとき、株の裏工作がばれると味方の持ち株が市場に戻る。
/// 味方が5%未満でも市場に5%を足していて、株主の割合の合計が100%を超えていた。
void main() {
  double total(Game s) => s.sh.own + s.sh.vc + s.sh.float + s.sh.ally + s.sh.pt + s.sh.rivSum;

  Game liar({bool extras = true}) {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'noble']), rng: ParkMiller(7), extras: extras);
    if (!s.pres.traits.contains('liar')) s.pres.traits.add('liar');
    return s;
  }

  /// ばれるまで liarCheck を呼ぶ（15%）。ばれたら true
  bool untilCaught(Game s, void Function() reset) {
    for (var i = 0; i < 400; i++) {
      reset();
      s.scandal = 0;
      s.liarCheck();
      if (s.scandal > 0) return true;
    }
    return false;
  }

  test('味方が5%未満でも、ばれたあとの合計は100%のまま', () {
    final s = liar();
    void reset() {
      s.sh.own = 68;
      s.sh.vc = 0;
      s.sh.pt = 0;
      s.sh.riv.clear();
      s.sh.float = 30;
      s.sh.ally = 2;
    }

    expect(untilCaught(s, reset), isTrue);
    expect(s.sh.ally, 0);
    expect(s.sh.float, closeTo(32, 1e-9));
    expect(total(s), closeTo(100, 1e-9));
  });

  test('味方が5%以上なら、5%が市場に戻る', () {
    final s = liar();
    void reset() {
      s.sh.own = 60;
      s.sh.vc = 0;
      s.sh.pt = 0;
      s.sh.riv.clear();
      s.sh.float = 30;
      s.sh.ally = 10;
    }

    expect(untilCaught(s, reset), isTrue);
    expect(s.sh.ally, closeTo(5, 1e-9));
    expect(s.sh.float, closeTo(35, 1e-9));
    expect(total(s), closeTo(100, 1e-9));
  });

  test('extras を切ると試作と同じ（5%を足す）', () {
    final s = liar(extras: false);
    void reset() {
      s.sh.float = 30;
      s.sh.ally = 2;
    }

    expect(untilCaught(s, reset), isTrue);
    expect(s.sh.float, closeTo(35, 1e-9));
  });
}
