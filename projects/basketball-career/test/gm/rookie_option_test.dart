import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選択権の年が来る選手([years] 年の契約の最後の2年が選択権)を入れて、シーズンを終えてオフへ。
(Career, Player) _atOffseason({int years = 3, int optionYears = 2}) {
  final c = careerAt(6, 8);
  final p = c.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b)
    ..years = years
    ..optionYears = optionYears
    ..age = 21;
  var guard = 0;
  while (c.phase != Phase.seasonEnd && guard++ < 200) {
    botStep(c);
  }
  c.toOffseason();
  return (c, p);
}

void _toContracts(Career c) {
  var guard = 0;
  while (c.phase != Phase.contracts && guard++ < 200) {
    botStep(c);
  }
}

void main() {
  group('新人の契約と選択権', () {
    test('1巡目は4年(最後の2年は選択権)・年俸は指名順。2巡目は2年・最低年俸', () {
      var last = 1 << 30;
      for (var k = 0; k < teamDefs.length; k++) {
        final (sal, yrs) = rookieContract(k);
        expect(yrs, 4, reason: '${k + 1}番目');
        expect(rookieOptionYears(k), 2);
        expect(sal, lessThanOrEqualTo(last), reason: '指名が遅いほど年俸は低い');
        last = sal;
      }
      expect(rookieContract(0).$1, 140, reason: '1番目は1,400万ドル');
      expect(rookieContract(teamDefs.length - 1).$1, inInclusiveRange(34, 38), reason: '30番目は360万ドルほど');
      expect(rookieContract(teamDefs.length), (minSalary, 2));
      expect(rookieOptionYears(teamDefs.length), 0);
    });

    test('ドラフトで1巡目に指名した新人は、4年・選択権2年で入る', () {
      final c = careerAt(5, 28);
      var guard = 0;
      while (c.phase != Phase.draft && guard++ < 400) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.phase, Phase.draft);
      while (c.phase == Phase.draft && guard++ < 800) {
        botStep(c);
      }
      final mineRookies = c.me.roster.where((p) => c.draftedIds.contains(p.id) && p.exp == 0).toList();
      expect(mineRookies, isNotEmpty);
      for (final p in mineRookies) {
        final firstRound = p.optionYears == 2;
        expect(p.years, firstRound ? 4 : 2);
      }
      expect(mineRookies.any((p) => p.optionYears == 2), isTrue, reason: '1巡目で指名している');
    });

    test('残りの年数が選択権の年数と同じになるオフに、使うか決める(自分の選手は保留に入る)', () {
      final (c, p) = _atOffseason();
      expect(p.years, 2);
      expect(c.optionPending, contains(p.id));
      // 契約の画面までは、まだ決まっていない
      _toContracts(c);
      expect(c.phase, Phase.contracts);
      expect(c.optionPending, contains(p.id));
    });

    test('選択権を使う: 年俸が上がり、選択権が1年減り、契約の年数は変わらない', () {
      final (c, p) = _atOffseason();
      _toContracts(c);
      final before = p.salary;
      final expected = c.optionSalary(p);
      expect(expected, greaterThan(before));
      c.exerciseOption(p.id);
      expect(c.optionPending, isEmpty);
      expect(p.salary, expected);
      expect(p.optionYears, 1);
      expect(p.years, 2);
      expect(c.expiring, isNot(contains(p.id)));
    });

    test('選択権を使わない: 契約が切れた扱いになり、再契約か自由契約を話し合う', () {
      final (c, p) = _atOffseason();
      _toContracts(c);
      c.declineOption(p.id);
      expect(c.optionPending, isEmpty);
      expect(p.years, 0);
      expect(p.optionYears, 0);
      expect(c.expiring, contains(p.id));
      // 話し合いで残すことも、放すこともできる
      c.letGo(p.id);
      expect(c.me.roster, isNot(contains(p)));
      expect(c.freeAgents, contains(p));
    });

    test('決めないままオフを終えると、使ったことになる(選手を失わない)', () {
      final (c, p) = _atOffseason();
      _toContracts(c);
      final expected = c.optionSalary(p);
      c.finishContracts();
      expect(c.me.roster, contains(p));
      expect(p.salary, expected);
      expect(c.optionPending, isEmpty);
    });

    test('2年続けて使うと、最後の年のあと契約が切れる', () {
      final (c, p) = _atOffseason(years: 3, optionYears: 2);
      _toContracts(c);
      c.exerciseOption(p.id);
      c.finishContracts();
      // 次のシーズンを終えると、残り1年=選択権の最後の1年
      var guard = 0;
      while (c.phase != Phase.seasonEnd && guard++ < 200) {
        botStep(c);
      }
      c.toOffseason();
      expect(p.years, 1);
      expect(p.optionYears, 1);
      expect(c.optionPending, contains(p.id));
      _toContracts(c);
      c.exerciseOption(p.id);
      expect(p.optionYears, 0);
      c.finishContracts();
      guard = 0;
      while (c.phase != Phase.seasonEnd && guard++ < 200) {
        botStep(c);
      }
      c.toOffseason();
      _toContracts(c);
      expect(c.expiring, contains(p.id), reason: '4年が終わって、契約切れ');
    });

    test('保留中の選手はトレードに出せない。保存しても保留は残る', () {
      final (c, p) = _atOffseason();
      _toContracts(c);
      final them = c.teams.firstWhere((t) => t.index != c.mine);
      final v = c.judge(TradeOffer(partner: them.index, give: [p.id], get: [them.roster.first.id]));
      expect(v.ok, isFalse);
      expect(v.reason, contains('契約の話し合い中'));
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.optionPending, c.optionPending);
      final q = copy.me.roster.firstWhere((x) => x.id == p.id);
      expect(q.optionYears, p.optionYears);
    });

    test('前の版の保存(選択権の欄が無い)は、選択権なしで読める', () {
      final p = Player(id: 1, name: 'a', pos: Pos.pg, age: 22, ovr: 60, pot: 70, salary: 50, years: 3, optionYears: 2);
      final j = p.toJson()..remove('op');
      expect(Player.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>).optionYears, 0);
    });
  });
}
