import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CustomPainter の中で描く文字に、書体が指定されているかの検査。
///
/// `TextPainter` はウィジェットの木の外にいるので、`ThemeData.fontFamily` が
/// 当たらない。省くと端末の標準フォント任せになり、**同梱フォントしか無い
/// Web版で日本語が豆腐(□)になる**。能力レーダーの軸ラベルが実際にそうだった。
///
/// 画面を開けば見えるが、誰も Web版のレーダーを開かないまま出ていた。
void main() {
  test('CustomPainter で文字を描くファイルは、書体を指定している', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (!source.contains('TextPainter(')) continue;
      if (!source.contains('fontFamily')) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'TextPainter で描いているのに書体を指定していない: $offenders');
  });
}
