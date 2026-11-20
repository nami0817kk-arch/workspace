import 'package:baseball_manager/game/marks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ライバルとの1年の勝負は、通算を添えて流れで言い方が変わる(2026-11-03)', () {
    expect(rivalYearLine('朝倉', won: true, wins: 1, losses: 0),
        'ライバルの朝倉との初めての勝負は、こちらの勝ち! (通算1勝0敗)');
    expect(rivalYearLine('朝倉', won: true, wins: 2, losses: 2),
        contains('五分に戻した'));
    expect(rivalYearLine('朝倉', won: true, wins: 3, losses: 2),
        contains('抜き返した'));
    expect(rivalYearLine('朝倉', won: true, wins: 5, losses: 0),
        contains('5年続けて勝った'));
    expect(rivalYearLine('朝倉', won: false, wins: 2, losses: 3),
        contains('抜かれた'));
    expect(rivalYearLine('朝倉', won: false, wins: 0, losses: 5),
        contains('5年続けて敗れた'));
    expect(rivalYearLine('朝倉', won: true, wins: 9, losses: 3),
        endsWith('(通算9勝3敗)'));
  });

  test('連勝・連敗が続いても、同じ一文ばかり並ばない', () {
    String body(String s) => s.split(' (').first;
    final wins = {
      for (var w = 2; w <= 9; w++)
        body(rivalYearLine('朝倉', won: true, wins: w, losses: 0))
    };
    final losses = {
      for (var l = 2; l <= 9; l++)
        body(rivalYearLine('朝倉', won: false, wins: 0, losses: l))
    };
    expect(wins.length, greaterThanOrEqualTo(3));
    expect(losses.length, greaterThanOrEqualTo(3));
  });
}
