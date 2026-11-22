import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 節送りのお知らせに、その節に起きたことが漏れなく入っているかの検査。
///
/// お知らせは「1件ならスナックバー、複数なら要約ダイアログ」にまとめて
/// 出す仕組みが既にある。新しい出来事を足したときに、その仕組みへ載せ忘れる
/// と、画面を開いた人だけが気づける情報になる。実際、ユースの流出は
/// ユース画面にしか出ておらず、その週にユースを開かないと名簿から静かに
/// 消えるだけだった。
///
/// 2026-11-23 から、お知らせの組み立ては lib/screens/matchday_notices.dart
/// (ホームの _showMatchdayNotifications がそれを呼ぶ)。
void main() {
  String noticesSource() =>
      File('lib/screens/matchday_notices.dart').readAsStringSync();

  test('ホームの節送りのお知らせは、組み立てを matchday_notices に任せている', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    final start = source.indexOf('void _showMatchdayNotifications');
    expect(start, greaterThan(0), reason: 'お知らせの組み立て場所が見つからない');
    expect(source.substring(start).contains('routeMatchdayNotices(gameState)'),
        isTrue);
  });

  test('節送りのお知らせが、ユースの流出も拾っている', () {
    expect(noticesSource().contains('lastYouthDepartures'), isTrue,
        reason: 'ユースの流出が節送りのお知らせに入っていない');
  });

  test('拾ったお知らせは、その場で空にしている', () {
    // 空にしないと、次の節にも同じお知らせが出続ける。
    final body = noticesSource();
    for (final field in const [
      'lastYouthDepartures',
      'lastContractExpirations',
      'lastLoanEndings',
      'lastLoanReturns',
    ]) {
      expect(body.contains('gameState.$field = '), isTrue,
          reason: '$field を読んだあと空にしていない(同じ知らせが出続ける)');
    }
  });
}
