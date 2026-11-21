import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/rating_words.dart';

void main() {
  test('総合力を、どの部で通用するかの言葉にする', () {
    final before = Tr.language;
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = before);
    expect(Tr.isEnglish, isFalse);
    expect(RatingWords.forOverall(95), '世界的な選手');
    expect(RatingWords.forOverall(89), '1部の主力級');
    expect(RatingWords.forOverall(83), '1部で通用する');
    expect(RatingWords.forOverall(80), '2部の主力級');
    // 部の幅は重なっている。上の部で通用するなら、そちらを言う。
    expect(RatingWords.forOverall(66), '3部で通用する');
    // 3部制(2026-11-22)。3部の幅(65〜)に届かなければ控え。
    expect(RatingWords.forOverall(58), '3部でも控え');
    expect(RatingWords.forOverall(40), '3部でも控え');
  });
}
