import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/services/review_prompt.dart';

/// ストアの評価を頼む仕組みの検査。
///
/// 公開から10日で評価が0件だった。星が1つも無いページは、入れるか迷って
/// いる人の後押しにならない。
///
/// ただし**頼み方を誤ると逆効果**になる。遊んでいる最中に割り込む、うまく
/// いっていない人に求める、断られても毎回出す——どれも悪い評価を呼ぶ。
/// 出す条件をここで固定する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('目標を達成していなければ頼まない', () async {
    final fake = _FakeReview();
    final asked = await ReviewPrompt(review: fake)
        .maybeAsk(season: 2, metBoardTarget: false);

    expect(asked, isFalse);
    expect(fake.requests, 0, reason: 'うまくいっていない人に評価を求めている');
  });

  test('目標を達成したら頼む', () async {
    final fake = _FakeReview();
    final asked = await ReviewPrompt(review: fake)
        .maybeAsk(season: 2, metBoardTarget: true);

    expect(asked, isTrue);
    expect(fake.requests, 1);
  });

  test('間を空けずに続けて頼まない', () async {
    final fake = _FakeReview();
    final prompt = ReviewPrompt(review: fake);
    await prompt.maybeAsk(season: 2, metBoardTarget: true);
    final again = await prompt.maybeAsk(season: 3, metBoardTarget: true);

    expect(again, isFalse, reason: '毎シーズン出すと嫌われる');
    expect(fake.requests, 1);
  });

  test('間を空ければまた頼む', () async {
    final fake = _FakeReview();
    final prompt = ReviewPrompt(review: fake);
    await prompt.maybeAsk(season: 2, metBoardTarget: true);
    final again = await prompt.maybeAsk(
        season: 2 + ReviewPrompt.seasonsBetweenAsks, metBoardTarget: true);

    expect(again, isTrue);
    expect(fake.requests, 2);
  });

  test('上限を超えたら二度と頼まない', () async {
    final fake = _FakeReview();
    final prompt = ReviewPrompt(review: fake);
    var season = 2;
    for (var i = 0; i < ReviewPrompt.maxAsks + 2; i++) {
      await prompt.maybeAsk(season: season, metBoardTarget: true);
      season += ReviewPrompt.seasonsBetweenAsks;
    }
    expect(fake.requests, ReviewPrompt.maxAsks);
  });

  test('窓が出せない端末では、黙って諦める', () async {
    final fake = _FakeReview(available: false);
    final asked = await ReviewPrompt(review: fake)
        .maybeAsk(season: 2, metBoardTarget: true);

    expect(asked, isFalse);
    expect(fake.requests, 0);
  });

  test('出せなかった回は、数に入れない', () async {
    // 出せていないのに回数だけ減ると、出せる端末になったときに頼めない。
    final fake = _FakeReview(available: false);
    final prompt = ReviewPrompt(review: fake);
    await prompt.maybeAsk(season: 2, metBoardTarget: true);

    fake.available = true;
    final asked = await prompt.maybeAsk(season: 3, metBoardTarget: true);
    expect(asked, isTrue, reason: '出せなかった回を数えている');
  });

  test('OS の窓を出すのはシーズンの区切りだけ(差し込み場所の確認)', () {
    // 遊んでいる最中に窓を出すと、むしろ悪い評価を呼ぶ。呼び出しが
    // シーズン更新の処理の中にあることを原文で見る。
    //
    // **見るのは `maybeAsk` の数。** `ReviewPrompt(` の数ではない。
    // ストアのページを開くだけの `openStoreListing` は割り込みではなく、
    // 設定や昇格のダイアログに置いてよい(置いてある)。構築の数で縛ると、
    // 割り込まない導線まで足せなくなる。
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _startNextSeason');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 2000);
    expect(body.contains('maybeAsk('), isTrue,
        reason: 'シーズンの区切り以外から窓を出している');

    var asks = 0;
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      asks += file.readAsStringSync().split('.maybeAsk(').length - 1;
    }
    expect(asks, 1, reason: '窓を出す場所が2か所以上ある');
  });
  group('評価への道', () {
    // OS の窓は年3回までに絞られ、出ないこともある。公開から10日で
    // 評価0件だったので、自分で書きに行ける道を別に用意してある。
    // **道が消えても例外は出ない**ので、ここで見ておく。
    test('設定から評価とお問い合わせに行ける', () {
      final settings =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(settings, contains('openStoreListing()'),
          reason: '設定からストアのページへ行けない');
      expect(settings, contains('legal/support.html'),
          reason: '設定にお問い合わせの窓口が無い');
    });

    test('昇格・優勝のダイアログにも評価への道がある', () {
      final home = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(home, contains('openStoreListing()'),
          reason: 'いちばん機嫌のいい瞬間に評価への道が無い');
    });

    test('アプリIDが掲載情報と合っている', () {
      // 違う ID を書くと、別のアプリのページが開く。
      final listing = File('STORE_LISTING.md').readAsStringSync();
      expect(listing, contains(ReviewPrompt.appStoreId),
          reason: 'STORE_LISTING.md に無いアプリIDを指している');
    });
  });
}

/// OS の窓を出さない差し替え。出した回数だけ数える。
class _FakeReview implements InAppReview {
  _FakeReview({this.available = true});

  bool available;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (!available) throw StateError('出せない');
    requests++;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}

}
