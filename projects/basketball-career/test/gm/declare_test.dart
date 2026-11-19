import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atPreseason(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (!(c.phase == Phase.preseason && c.season >= 2)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('シーズン前に着かない');
  }
  return c;
}

Message _ask(Career c) => c.inbox.firstWhere((m) => m.kind == MsgKind.declare && m.season == c.season);

void _toEnd(Career c) {
  while (c.phase != Phase.seasonEnd) {
    botStep(c);
  }
}

void main() {
  test('宣言: 優勝を狙うとすぐ人気+3、立て直すと人気-3。若手・立て直しは勝ち数の目標が下がる', () {
    final base = _atPreseason(2);
    base.startSeason();
    for (final (choice, hypeD, targetD) in [(0, 3, 0), (1, 0, -3), (2, -3, -6)]) {
      final c = _atPreseason(2);
      final hype = c.hype;
      c.answer(_ask(c).id, choice);
      expect(c.declaredNow, choice + 1);
      expect(c.hype, (hype + hypeD).clamp(0, 100));
      c.startSeason();
      expect(c.target, base.target + targetD);
    }
  });

  test('宣言しない・答えないまま開幕すると、何も変わらず閉じる', () {
    final a = _atPreseason(3);
    final b = _atPreseason(3);
    a.answer(_ask(a).id, 3);
    expect(a.declaredNow, 0);
    b.startSeason();
    expect(_ask(b).needsAnswer, isFalse);
    expect(b.declaredNow, 0);
  });

  test('シーズンの終わりに答え合わせ: 優勝を狙うは2回戦に届けば信頼+5、届かなければ-5', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final a = _atPreseason(seed);
      final b = _atPreseason(seed);
      a.answer(_ask(a).id, 0);
      _toEnd(a);
      _toEnd(b);
      expect(a.me.wins, b.me.wins, reason: '宣言は試合の結果を変えない');
      final res = a.history.last.result;
      final d = res >= 2 ? 5 : -5;
      // 信頼は0〜100で止まり、減るときは難しさの倍率が掛かるので、向きだけ見る
      if (d > 0) {
        expect(a.trust, greaterThanOrEqualTo(b.trust));
      } else {
        expect(a.trust, lessThanOrEqualTo(b.trust));
      }
      expect(a.inbox.any((m) => m.title == '「優勝を狙う」の答え合わせ'), isTrue);
    }
  });
}
