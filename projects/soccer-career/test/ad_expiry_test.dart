import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_career/monetize/ad_service.dart';

/// 読み込んだ広告の期限の扱いの検査。
///
/// **AdMob の広告は1時間で期限切れになる**（公式が「捨てて読み直せ」と書いて
/// いる）。持ち続けると、出そうとしたときには期限切れで失敗する。
/// `soccer-manager` はこれで、実測7日のリクエスト231回に対して表示6回だった。
/// 利用者から見ると「シーズンが終わったのに広告が出ない」、こちらから見ると
/// 収入が立たない。どちらも例外を出さないので、測るまで気づけない。
///
/// 経緯は `docs/app-pitfalls.md` の3番。
void main() {
  group('期限の判定', () {
    test('読み込み直後は出せる', () {
      final now = DateTime(2026, 9, 28, 12, 0);
      expect(AdMobAdService.adExpired(now, now: now), isFalse);
    });

    test('1時間の手前までは出せる', () {
      final loaded = DateTime(2026, 9, 28, 12, 0);
      expect(
        AdMobAdService.adExpired(loaded,
            now: loaded.add(const Duration(minutes: 50))),
        isFalse,
      );
    });

    test('期限を過ぎたら出せない', () {
      final loaded = DateTime(2026, 9, 28, 12, 0);
      expect(
        AdMobAdService.adExpired(loaded,
            now: loaded.add(const Duration(minutes: 56))),
        isTrue,
      );
    });

    test('読み込んでいなければ出せない', () {
      expect(AdMobAdService.adExpired(null), isTrue);
    });

    test('AdMob の1時間より手前で切る', () {
      // ちょうど1時間にすると、こちらの判定と実際の期限が競る。
      expect(AdMobAdService.adLifetime, lessThan(const Duration(hours: 1)));
    });
  });

  group('読む場所', () {
    final source = File('lib/monetize/ad_service.dart').readAsStringSync();

    /// [name] で始まるメソッドの本文を取り出す。
    ///
    /// `lastIndexOf` なのは、同じ名前が抽象宣言・`NoAdService`・`AdMobAdService`
    /// の3つに出てくるため。見たいのは最後にある AdMob の実装。
    String bodyOf(String name) {
      final at = source.lastIndexOf(name);
      expect(at, greaterThan(0), reason: '$name が見つからない');
      final rest = source.substring(at);
      // メソッドの閉じ括弧まで。伸ばすと次の宣言まで拾ってしまう。
      return rest.substring(0, rest.indexOf('\n  }'));
    }

    test('起動時に先読みしない', () {
      // 広告が出るのはシーズンの切れ目だけで、1シーズンは38節ある。
      // 起動時に読んでも、出す頃には必ず期限切れになっている。
      expect(bodyOf('Future<void> initialize()').contains('_load('), isFalse,
          reason: '起動時に読むと、出す頃には期限切れになっている');
    });

    test('出す直前に読み、読めなければ進む', () {
      final body = bodyOf('Future<bool> showInterstitial()');
      expect(body.contains('_load()'), isTrue,
          reason: 'シーズンの切れ目で読み直していない');
      expect(body.contains('loadTimeout'), isTrue,
          reason: '読めないときに進行が止まる');
    });

    test('閉じた後に先読みしない', () {
      // 次のシーズンは38節先。ここで読んでも期限切れになる。
      expect(bodyOf('void finish(Ad ad)').contains('_load('), isFalse,
          reason: '閉じた直後に読んでも、次に出す頃には期限切れ');
    });

    test('読み込みの待ち合わせを自分で持っている', () {
      // **`InterstitialAd.load` を `await` しても広告は待てない。** 返るのは
      // 「ネイティブ側に頼み終えた」時点で、広告は `onAdLoaded` で後から届く。
      // `await` しただけで在庫を見ると必ず空なので、出す直前に読む作りが
      // 成り立たなくなる（待ったつもりで、毎回「在庫なし」になる）。
      expect(source.contains('await InterstitialAd.load('), isFalse,
          reason: 'これを await しても広告は届かない。Completer で待ち合わせる');
      expect(source.contains('Completer<void>? _pendingLoad'), isTrue,
          reason: '読み込みの完了を待ち合わせる口が無い');
    });
  });
}
