// アプリ内の絵(Gemini で生成)の置き忘れを止める。
// pubspec.yaml の assets に無いと、実機では読み込めず代替の絵に戻るだけで気づきにくい。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const arts = [
    'title',
    'ending_glory',
    'ending_quiet',
    'path',
    'hall',
  ];

  test('アプリ内の絵がすべて assets にあり、pubspec.yaml に宣言されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    var total = 0;
    for (final n in arts) {
      final f = File('assets/art/$n.jpg');
      expect(f.existsSync(), isTrue, reason: '$n.jpg が無い');
      expect(f.lengthSync(), lessThan(400 * 1024), reason: '$n.jpg が重い');
      expect(pubspec, contains('assets/art/$n.jpg'), reason: '$n.jpg が pubspec.yaml に無い');
      total += f.lengthSync();
    }
    expect(total, lessThan(2 * 1024 * 1024), reason: '絵の合計でアプリを重くしない');
  });

  test('コードで使っている絵の名前が、置いてある絵と一致する', () {
    final used = <String>{};
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in RegExp(r"assets/art/([a-z_]+)\.jpg")
          .allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, arts.toSet());
  });

  test('アイコンの元の絵は 1024x1024', () {
    final bytes = File('tool/icon_source.png').readAsBytesSync();
    // PNG の IHDR: 幅と高さは 16〜23 バイト目(ビッグエンディアン)。
    int be(int o) => (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
    expect(be(16), 1024);
    expect(be(20), 1024);
  });
}
