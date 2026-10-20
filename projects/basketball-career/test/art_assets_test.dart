// アプリ内の絵(Gemini で生成)の置き忘れを止める。
// pubspec.yaml の assets に無いと、実機では読み込めず代替の絵に戻るだけで気づきにくい。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('タイトルの絵が assets にあり、pubspec.yaml に宣言されている', () {
    final f = File('assets/art/title.jpg');
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), lessThan(400 * 1024), reason: 'アプリを重くしない');
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/art/title.jpg'));
  });

  test('アイコンの元の絵は 1024x1024', () {
    final bytes = File('tool/icon_source.png').readAsBytesSync();
    // PNG の IHDR: 幅と高さは 16〜23 バイト目(ビッグエンディアン)。
    int be(int o) => (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
    expect(be(16), 1024);
    expect(be(20), 1024);
  });
}
