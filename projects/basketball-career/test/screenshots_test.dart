// 掲載画像(marketing/screenshots/)が、App Store の必須の寸法で、そろっているか。
// 寸法が違うと「サイズが無効です」と弾かれる(2026-10 に 1320x2868 で踏んだ)。画像は生成器が作る(tool/screenshots/capture_test.dart)。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

(int, int) _size(File f) {
  final b = f.readAsBytesSync();
  int be(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (be(16), be(20)); // PNG の IHDR(幅・高さ)
}

void main() {
  const expected = {
    'iphone': (1206, 2622), // Dynamic Island 搭載 iPhone(中型)
    'ipad': (2064, 2752), // iPad 13インチ
  };

  for (final e in expected.entries) {
    test('${e.key}の掲載画像は ${e.value.$1}x${e.value.$2} で、8枚そろっている', () {
      final dir = Directory('marketing/screenshots/${e.key}');
      expect(dir.existsSync(), isTrue, reason: '${dir.path} が無い');
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, 8, reason: '8枚(01_season〜08_style)');
      for (final f in files) {
        expect(_size(f), e.value, reason: f.path);
        expect(f.lengthSync(), lessThan(8 * 1024 * 1024), reason: '${f.path} が大きすぎる(App Store の上限は8MB)');
      }
      expect(files.first.path, contains('01_season'));
      expect(files.last.path, contains('08_style'));
    });
  }
}
