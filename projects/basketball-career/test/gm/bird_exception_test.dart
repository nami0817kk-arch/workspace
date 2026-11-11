import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts() {
  final c = careerAt(6, 8);
  var guard = 0;
  while (c.phase != Phase.seasonEnd && guard++ < 200) {
    botStep(c);
  }
  c.toOffseason();
  guard = 0;
  while (c.phase != Phase.contracts && guard++ < 200) {
    botStep(c);
  }
  return c;
}

/// 自分の年俸の合計が [target] になるように、デッドキャップで合わせる。
void _setPayroll(Career c, int target) {
  c.me.deadCap = 0;
  c.me.deadCap = target - c.me.payroll;
}

void main() {
  group('バード権', () {
    test('在籍3年以上はフル、2年はアーリー、それ未満はなし', () {
      final c = careerAt(6, 8);
      final p = c.me.roster.first;
      p.tenure = 3;
      expect(c.birdOf(p), Bird.full);
      p.tenure = 2;
      expect(c.birdOf(p), Bird.early);
      p.tenure = 1;
      expect(c.birdOf(p), Bird.none);
      p.tenure = 0;
      expect(c.birdOf(p), Bird.none);
    });

    test('上限を超える再契約: フルは制限なし、アーリーは前の年俸の175%、なしは120%＋100万ドルまで', () {
      final c = _atContracts();
      final p = c.me.roster.first
        ..salary = 200
        ..morale = 70;
      p.tenure = 3;
      expect(c.birdLimit(p), isNull);
      p.tenure = 2;
      expect(c.birdLimit(p), 350);
      p.tenure = 1;
      expect(c.birdLimit(p), 250);
      // 上限に空きがあるなら、制限は無い
      _setPayroll(c, 0);
      expect(c.resignProblem(p, salary: 450), isNull);
      // 上限を超えるなら、制限に当たる
      _setPayroll(c, salaryCap + 300);
      expect(c.resignProblem(p, salary: 450), isNotNull);
      expect(c.resignProblem(p, salary: 240), isNull);
      p.tenure = 3;
      expect(c.resignProblem(p, salary: 450), isNull);
    });

    test('トレードで来た選手と自由契約で取った選手は在籍0から', () {
      final c = _atContracts();
      final p = c.freeAgents.first;
      p.tenure = 5;
      c.signFreeAgent(p.id, 1);
      if (c.me.roster.contains(p)) expect(p.tenure, 0);
    });
  });

  group('例外枠', () {
    test('上限を超えていても、中くらいの例外枠で取れる。1年に1つだけ', () {
      final c = _atContracts();
      c.expiring = [];
      while (c.me.roster.length > 12) {
        c.me.roster.removeLast();
      }
      _setPayroll(c, salaryCap + 100);
      final fa = c.freeAgents.toList();
      final a = fa[0]..salary = 120;
      final b = fa[1]..salary = 120;
      for (final x in [a, b]) {
        x
          ..ovr = 66 // 最低年俸より高く、中くらいの例外枠に収まる額を求める
          ..age = 26
          ..morale = 60;
      }
      // オフの契約中は大物は申し込み制。シーズン前に進めて、直接取る
      c.phase = Phase.preseason;
      c.expiring = [];
      final ask = c.askOf(a, c.me).salary;
      expect(ask, greaterThan(minSalary));
      final ex = c.exceptionFor(ask);
      expect(ex, isNotNull);
      expect(c.signProblem(a), ask <= mleSalary ? isNull : isNotNull);
      if (ask <= mleSalary && ask > biennialSalary) {
        c.signFreeAgent(a.id, 3);
        expect(c.me.roster, contains(a));
        expect(c.mleUsed, isTrue);
        // 2つ目の中くらいの例外枠は使えない
        expect(c.exceptionFor(ask), isNull);
        expect(c.signProblem(b), isNotNull);
      }
    });

    test('第1の壁を超えるなら課税者用だけ、第2の壁を超えると使えない', () {
      final c = careerAt(6, 8);
      _setPayroll(c, firstApron + 50);
      expect(c.exceptionFor(taxMleSalary), CapException.taxMle);
      expect(c.exceptionFor(taxMleSalary + 1), isNull);
      _setPayroll(c, secondApron - 10);
      expect(c.exceptionFor(taxMleSalary), isNull);
    });

    test('2年ごとの例外枠は、使うと次の年は使えず、その次の年に戻る', () {
      final c = careerAt(6, 8);
      _setPayroll(c, salaryCap + 100);
      c.capYear = 5;
      expect(c.biennialReady, isTrue);
      expect(c.exceptionFor(biennialSalary), CapException.biennial);
      c.biennialYear = c.capYear;
      expect(c.biennialReady, isFalse);
      c.capYear = 6;
      expect(c.biennialReady, isFalse);
      c.capYear = 7;
      expect(c.biennialReady, isTrue);
    });

    test('保存して読み直しても、在籍年数と例外枠の使用が残る', () {
      final c = _atContracts();
      c.mleUsed = true;
      c.biennialYear = c.capYear;
      c.me.roster.first.tenure = 2;
      final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.mleUsed, isTrue);
      expect(back.biennialYear, c.capYear);
      expect(back.capYear, c.capYear);
      expect(back.me.roster.first.tenure, 2);
    });
  });
}
