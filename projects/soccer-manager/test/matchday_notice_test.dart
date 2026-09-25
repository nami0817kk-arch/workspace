import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 節送りのお知らせに、その節に起きたことが漏れなく入っているかの検査。
///
/// お知らせは「1件ならスナックバー、複数なら要約ダイアログ」にまとめて
/// 出す仕組みが既にある。新しい出来事を足したときに、その仕組みへ載せ忘れる
/// と、画面を開いた人だけが気づける情報になる。実際、ユースの流出は
/// ユース画面にしか出ておらず、その週にユースを開かないと名簿から静かに
/// 消えるだけだった。
void main() {
  test('節送りのお知らせが、ユースの流出も拾っている', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    final start = source.indexOf('void _showMatchdayNotifications');
    expect(start, greaterThan(0), reason: 'お知らせの組み立て場所が見つからない');

    final body = source.substring(start);
    expect(body.contains('lastYouthDepartures'), isTrue,
        reason: 'ユースの流出が節送りのお知らせに入っていない');
  });

  test('拾ったお知らせは、その場で空にしている', () {
    // 空にしないと、次の節にも同じお知らせが出続ける。
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    final start = source.indexOf('void _showMatchdayNotifications');
    final body = source.substring(start);

    for (final field in const [
      'lastYouthDepartures',
      'lastContractExpirations',
      'lastLoanReturns',
    ]) {
      expect(body.contains('gameState.$field = '), isTrue,
          reason: '$field を読んだあと空にしていない(同じ知らせが出続ける)');
    }
  });
}
