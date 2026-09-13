import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/monetization/ad_service.dart';

void main() {
  group('広告IDの警告', () {
    test('いま動いているプラットフォームのIDだけを見る', () {
      // 4つ全部を見ていたため、iOS ビルドでは Android 用の --dart-define が
      // 渡らず既定のテストIDが残り、iOS のIDを正しく渡していても
      // 「広告がテスト用IDのままです」が実機に出た。
      //
      // テストは --dart-define を渡さずに走るので、どのIDも既定の
      // テスト用IDのまま。つまりこの環境では true が正しい。ここで見るのは
      // 「落ちずに判定できること」と、判定が1プラットフォームに閉じて
      // いることの2つ。
      expect(AdMobAdService.isUsingTestUnitId, isA<bool>());

      final source =
          File('lib/monetization/ad_service.dart').readAsStringSync();
      final body = source.substring(source.indexOf('isUsingTestUnitId {'));
      final check = body.substring(0, body.indexOf('}'));
      // 判定の中で、両プラットフォームのIDを同時に並べていないこと。
      final mentionsIos = check.contains('_iosUnitId');
      final mentionsAndroid = check.contains('_androidUnitId');
      expect(mentionsIos && mentionsAndroid, isTrue,
          reason: '両方の分岐がある想定');
      expect(check, contains('_isIOS'),
          reason: 'プラットフォームで分岐していない');
      expect(check, contains('kIsWeb'),
          reason: 'Web を除外していない(Platform 参照で落ちる)');
    });

    test('Web でも落ちずに判定できる', () {
      // 設定画面はこの値を素で読む。Platform を直接触ると Web で
      // UnsupportedError になり、設定画面ごと開けなくなる。
      expect(() => AdMobAdService.isUsingTestUnitId, returnsNormally);
    });

    test('4つの広告ユニットIDが、それぞれ別の環境変数から来ている', () {
      // 同じ名前を2箇所で使っていると、片方を差し替えたつもりで
      // もう片方がテスト用のまま残る。
      final source =
          File('lib/monetization/ad_service.dart').readAsStringSync();
      for (final name in const [
        'ADMOB_REWARDED_ANDROID',
        'ADMOB_REWARDED_IOS',
        'ADMOB_INTERSTITIAL_ANDROID',
        'ADMOB_INTERSTITIAL_IOS',
      ]) {
        expect("'$name'".allMatches(source).length, 1,
            reason: '$name の参照が1箇所でない');
      }
    });
  });
}
