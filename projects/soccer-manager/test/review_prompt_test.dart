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

  test('頼むのはシーズンの区切りだけ(差し込み場所の確認)', () {
    // 遊んでいる最中に出すと、むしろ悪い評価を呼ぶ。呼び出しが
    // シーズン更新の処理の中にあることを原文で見る。
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _startNextSeason');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 2000);
    expect(body.contains('ReviewPrompt('), isTrue,
        reason: 'シーズンの区切り以外から呼んでいる');
    expect(src.split('ReviewPrompt(').length - 1, 1,
        reason: '呼び出しが2か所以上ある');
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
