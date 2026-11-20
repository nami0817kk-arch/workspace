import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/services/sfx_service.dart';

void main() {
  test('効果音のファイルがそろっていて、出どころが書いてある', () {
    final credits = File('assets/sfx/CREDITS.md').readAsStringSync();
    for (final s in Sfx.values) {
      final f = File('assets/sfx/${s.file}');
      expect(f.existsSync(), isTrue, reason: s.file);
      expect(f.lengthSync(), lessThan(80 * 1024), reason: '${s.file} が大きすぎる');
      expect(credits, contains(s.file));
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/sfx/'));
  });
}
