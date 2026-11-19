import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atPreseason(int seed, {int season = 2}) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (!(c.phase == Phase.preseason && c.season >= season)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 20000) fail('シーズン前に着かない');
  }
  return c;
}

Message? _msg(Career c, MsgKind k) => c.inbox.where((m) => m.kind == k && m.season == c.season).firstOrNull;

void _toEnd(Career c) {
  while (c.phase != Phase.seasonEnd) {
    botStep(c);
  }
}

void main() {
  test('スポンサー: 選んだ契約の額がシーズンの終わりに収入に入る。選ばなければ入らない', () {
    for (final deal in [0, 1, 2]) {
      final a = _atPreseason(3);
      final b = _atPreseason(3);
      a.answer(_msg(a, MsgKind.sponsor)!.id, deal);
      expect(a.sponsorNow, deal + 1);
      final copy = Career.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(copy.sponsorNow, deal + 1);
      _toEnd(a);
      _toEnd(b);
      expect(a.me.wins, b.me.wins, reason: 'スポンサーは試合の結果を変えない');
      final (base, bonus) = a.sponsorTerms(deal + 1);
      final hit = switch (deal) { 1 => a.me.wins >= a.target, 2 => a.history.last.result >= 1, _ => false };
      expect(a.incomeBy[Income.sponsor.index] - b.incomeBy[Income.sponsor.index], base + (hit ? bonus : 0));
      expect(a.sponsorDeal, 0);
    }
  });

  test('答えないまま開幕すると、スポンサーは断ったことになる', () {
    final c = _atPreseason(4);
    c.startSeason();
    expect(_msg(c, MsgKind.sponsor)!.needsAnswer, isFalse);
    expect(c.sponsorNow, 0);
  });

  test('命名権: 2年目から3年ごとに申し出。売ると人気-4で、毎シーズン額が入り続ける', () {
    final a = _atPreseason(5);
    final b = _atPreseason(5);
    expect(a.season % 3, 2);
    final m = _msg(a, MsgKind.naming);
    expect(m, isNotNull);
    final hype = a.hype;
    a.answer(m!.id, 0);
    expect(a.namingSold, isTrue);
    expect(a.arenaName, endsWith('アリーナ'));
    expect(a.hype, (hype - 4).clamp(0, 100));
    _toEnd(a);
    _toEnd(b);
    expect(a.incomeBy[Income.sponsor.index] - b.incomeBy[Income.sponsor.index], a.namingIncome);
    final copy = Career.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect(copy.arenaName, a.arenaName);
    // 売ったあとは、もう申し出が来ない
    final c = _atPreseason(6, season: 3);
    expect(_msg(c, MsgKind.naming), isNull, reason: '3年目は申し出が無い');
  });
}
