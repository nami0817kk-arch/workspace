import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('区切りのあとに見出しが出て、保存しても残る。ファンの声は人気と勝率で変わる', () {
    final c = careerAt(6, 8)..startSeason();
    expect(c.headlines, isEmpty);
    c.playBlock();
    expect(c.headlines, isNotEmpty);
    expect(c.headlines.first, contains('${c.season}年目'));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.headlines, c.headlines);
    expect(c.fanVoice, isNotEmpty);
    for (var i = 0; i < 20; i++) {
      c.headlines.insert(0, 'x');
    }
    c.playBlock();
    expect(c.headlines.length, lessThanOrEqualTo(12));
  });

  test('記者の質問が届き、答えで人気と信頼が動く', () {
    Career? c;
    Message? q;
    for (var seed = 1; seed <= 12 && q == null; seed++) {
      final x = careerAt(seed, 12)..startSeason();
      var guard = 0;
      while (x.phase == Phase.season && guard++ < 5 && q == null) {
        x.playBlock();
        q = x.inbox.where((m) => m.kind == MsgKind.press).firstOrNull;
      }
      c = x;
    }
    expect(q, isNotNull, reason: '数シーズンのうちに記者の質問が届く');
    final car = c!;
    expect(q!.needsAnswer, isTrue);
    expect(q.choices, hasLength(3));
    final hype = car.hype, trust = car.trust;
    car.answer(q.id, 0);
    expect(car.hype, hype + 3);
    expect(car.trust, anyOf(trust + 1, trust - 2));
    expect(q.needsAnswer, isFalse);
    botStep(car);
  });
}
