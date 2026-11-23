import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/l10n/tr.dart';

void main() {
  tearDown(() {
    Tr.language = AppLanguage.system;
    Tr.resolvedLocaleIsEnglish = null;
    Tr.deviceIsEnglish = () => false;
  });

  test(
    'Tr.pick follows the explicit language setting, and falls back to the '
    'device locale only when the setting is "system"',
    () {
      Tr.deviceIsEnglish = () => false;

      Tr.language = AppLanguage.system;
      expect(Tr.pick('日本語', 'English'), '日本語');
      expect(Tr.localeCode, isNull, reason: 'systemのときはFlutterに委ねるためnullを返す');

      Tr.language = AppLanguage.english;
      expect(Tr.pick('日本語', 'English'), 'English');
      expect(Tr.localeCode, 'en');

      Tr.language = AppLanguage.japanese;
      expect(Tr.pick('日本語', 'English'), '日本語');
      expect(Tr.localeCode, 'ja');

      // 端末が英語でも、日本語に固定していれば日本語のまま。
      Tr.deviceIsEnglish = () => true;
      expect(Tr.pick('日本語', 'English'), '日本語');

      Tr.language = AppLanguage.system;
      expect(Tr.pick('日本語', 'English'), 'English');
    },
  );

  test(
      'AppLanguage.label is itself localized, so the picker reads correctly '
      'in whichever language is active', () {
    Tr.language = AppLanguage.japanese;
    expect(AppLanguage.system.label, '端末の設定に従う');
    Tr.language = AppLanguage.english;
    expect(AppLanguage.system.label, 'Follow device setting');

    // 言語名そのものは翻訳しない。英語表示でも「日本語」と出るのが正しい。
    expect(AppLanguage.japanese.label, '日本語');
    expect(AppLanguage.english.label, 'English');
  });

  test('Tr.ordinal は 11〜13 を th にし、topTarget は 1 位を優勝と言う', () {
    expect(
      [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101, 111, 112].map(Tr.ordinal),
      [
        '1st', '2nd', '3rd', '4th', '11th', '12th', '13th', //
        '21st', '22nd', '23rd', '101st', '111th', '112th',
      ],
    );
    expect(Tr.topTarget(1), 'win the league');
    expect(Tr.topTarget(4), 'top 4');
  });
}
