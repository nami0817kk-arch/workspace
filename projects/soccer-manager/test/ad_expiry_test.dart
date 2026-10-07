import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/monetization/ad_service.dart';

/// 読み込んだ広告の期限の扱いの検査。
///
/// AdMob の広告は1時間で期限切れになり、公式が「捨てて読み直せ」と書いて
/// いる。起動時に読んだきり持ち続けていたため、出そうとしたときには
/// 期限切れで失敗していた。実測(7日)でリクエスト231回に対して表示6回。
/// 利用者から見ると「広告を見ようとしたのに出ない」、こちらから見ると
/// 収入が立たない。
void main() {
  group('期限の判定', () {
    test('読み込み直後は出せる', () {
      final now = DateTime(2026, 9, 28, 12, 0);
      expect(AdMobAdService.adExpired(now, now: now), isFalse);
    });

    test('1時間の手前までは出せる', () {
      final loaded = DateTime(2026, 9, 28, 12, 0);
      final now = loaded.add(const Duration(minutes: 50));
      expect(AdMobAdService.adExpired(loaded, now: now), isFalse);
    });

    test('期限を過ぎたら出せない', () {
      final loaded = DateTime(2026, 9, 28, 12, 0);
      final now = loaded.add(const Duration(minutes: 56));
      expect(AdMobAdService.adExpired(loaded, now: now), isTrue);
    });

    test('読み込んでいなければ出せない', () {
      expect(AdMobAdService.adExpired(null), isTrue);
    });

    test('AdMob の1時間より手前で切る', () {
      // ちょうど1時間にすると、こちらの判定と実際の期限が競る。
      expect(AdMobAdService.adLifetime, lessThan(const Duration(hours: 1)));
    });
  });

  group('読み込む場所', () {
    final source = File('lib/monetization/ad_service.dart').readAsStringSync();

    /// [name] で始まるメソッドの本文を取り出す。
    ///
    /// lastIndexOf なのは、同じ名前が抽象宣言・NoOp・AdMob の3つに出てくる
    /// ため。見たいのは最後にある AdMob の実装。
    String bodyOf(String name) {
      final at = source.lastIndexOf(name);
      expect(at, greaterThan(0), reason: '$name が見つからない');
      final rest = source.substring(at);
      // メソッドの閉じ括弧まで。伸ばすと次の宣言の名前まで拾ってしまう。
      return rest.substring(0, rest.indexOf('  }'));
    }

    test('起動時にインタースティシャルを先読みしない', () {
      // シーズンは38節あるので、起動時に読んでも出す頃には必ず期限切れ。
      // 1シーズンに1回の確実な表示を、そのたびに落としていた。
      expect(bodyOf('Future<void> initialize()').contains('_loadInterstitial('),
          isFalse,
          reason: '起動時に読むと、出す頃には期限切れになっている');
    });

    test('読み込みの待ち合わせを自分で持っている', () {
      // **`InterstitialAd.load` を `await` しても広告は待てない。** 返るのは
      // 「ネイティブ側に頼み終えた」時点で、広告は `onAdLoaded` で後から届く。
      // `await` しただけで在庫を見ると必ず空なので、「出す直前に読む」が
      // 成り立たない（待ったつもりで、毎回「在庫なし」になる）。
      expect(source.contains('await InterstitialAd.load('), isFalse,
          reason: 'これを await しても広告は届かない。Completer で待ち合わせる');
      expect(source.contains('Completer<void>? _pendingInterstitialLoad'),
          isTrue,
          reason: '読み込みの完了を待ち合わせる口が無い');
    });

    test('出す直前に読む', () {
      final body = bodyOf('Future<void> showInterstitialAd()');
      expect(body.contains('_loadInterstitial('), isTrue,
          reason: 'シーズンの切り替わりで読み直していない');
      expect(body.contains('timeout'), isTrue,
          reason: '読めないときに進行が止まる');
    });
  });
}
