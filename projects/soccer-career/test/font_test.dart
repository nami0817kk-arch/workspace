/// 同梱フォントが、画面に出す文字をすべて持っているか。
///
/// 持っていない字はその1文字だけ豆腐（□）になる。ほとんどの字は出るので、
/// 画面のテストでは気付けない。公開ページを開いて初めて分かった
/// （「監□の期待」「得□関□」「契約更□の年□に□く」）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/font_coverage.dart';

void main() {
  group('同梱フォント', () {
    test('画面に出す文字がすべて入っている', () {
      final used = literalCharactersIn(Directory('lib'));
      expect(used.length, greaterThan(500), reason: '文字を拾えていない');

      for (final path in [
        'assets/fonts/NotoSansJP-Regular.ttf',
        'assets/fonts/NotoSansJP-Bold.ttf',
      ]) {
        final covered = fontCodePoints(path);
        final missing = <String>[];
        for (final ch in used) {
          final code = ch.runes.first;
          // 改行やタブは字形を持たない。
          if (code < 0x20) continue;
          if (!covered.contains(code)) missing.add(ch);
        }
        expect(missing, isEmpty,
            reason: '$path に無い字がある: ${missing.join()}');
      }
    });

    test('豆腐になっていた字が、今は入っている', () {
      // 実際に公開ページで欠けていた字。回帰の見張り。
      final covered = fontCodePoints('assets/fonts/NotoSansJP-Regular.ttf');
      for (final ch in '督点与改俸効悪疲労'.split('')) {
        expect(covered.contains(ch.runes.first), isTrue, reason: ch);
      }
    });

    test('cmap を読めている', () {
      final covered = fontCodePoints('assets/fonts/NotoSansJP-Regular.ttf');
      expect(covered.length, greaterThan(5000));
      expect(covered.contains('あ'.runes.first), isTrue);
      expect(covered.contains('A'.runes.first), isTrue);
      // 収録されていないはずのもの（絵文字）。全部入りだと検査にならない。
      expect(covered.contains('🙂'.runes.first), isFalse);
    });
  });
}
