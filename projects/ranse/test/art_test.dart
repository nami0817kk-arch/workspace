import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/ways.dart';
import 'package:ranse/ui/end_screen.dart';

/// Gemini で作った絵（assets/images）の置き忘れを止める。
void main() {
  test('10の道すべてに絵があり、ファイルが置いてある', () {
    for (final w in kWays.keys) {
      final art = kWayArt[w];
      expect(art, isNotNull, reason: w);
      expect(File(art!).existsSync(), isTrue, reason: art);
    }
  });

  test('タイトルの絵が置いてある', () {
    expect(File('assets/images/title_castle.jpg').existsSync(), isTrue);
  });
}
