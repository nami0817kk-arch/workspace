import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 暗いテーマで読めなくなる書き方が入っていないかの検査。
///
/// 描画の検査（screen_render_test）は例外とはみ出しだけを見るので、
/// **暗い背景に黒い文字**は通ってしまう。崩れてはいないが読めない。
/// 実際、ユース画面の「育成方針」「メンター」のドロップダウンが
/// `color: Colors.black87` を直書きしており、暗いテーマでは選んだ値が
/// 背景に沈んでいた（2026-09-29 に見つけた）。
///
/// 影（`Shadow`）や覆い（`withValues(alpha:)`）の黒は問題ないので対象外。
void main() {
  test('文字色に黒を直書きしていない', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!RegExp(r'color:\s*Colors\.black').hasMatch(line)) continue;
        // 影と覆いは黒でよい。読ませる文字ではない。
        if (line.contains('Shadow(') || line.contains('withValues(')) continue;
        // 直前の数行に TextStyle があれば、文字の色として書いている。
        final from = (i - 4).clamp(0, i);
        final context = lines.sublist(from, i + 1).join('\n');
        if (!context.contains('TextStyle(')) continue;
        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: '暗いテーマで背景に沈む。色を指定せずテーマに任せること:\n'
            '${offenders.join('\n')}');
  });
}
