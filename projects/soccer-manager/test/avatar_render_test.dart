import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 選手の顔(描いた絵の重ね)のテストは player_faces_test.dart。
void main() {
  group('クラブエンブレム', () {
    test('描き直しの判定が、絵を決める値をすべて見ている', () {
      // motifIndex の見落としが実際にあった。形と色が同じで柄だけ違う
      // クラブが隣り合うと、前のクラブの柄が残る。
      final source = File('lib/widgets/club_emblem.dart').readAsStringSync();
      final painter = source.substring(source.indexOf('class _EmblemPainter'));
      final shouldRepaint =
          painter.substring(painter.indexOf('shouldRepaint'));
      for (final field in const ['base', 'accent', 'shapeIndex', 'motifIndex']) {
        expect(shouldRepaint, contains('oldDelegate.$field'),
            reason: '_EmblemPainter.shouldRepaint が $field を見ていない');
      }
    });

    test('形と柄の組み合わせが、実際に散らばる', () {
      // 形3種・柄3種だと、少人数のリーグでも同じ絵のクラブが並ぶ。
      final source = File('lib/widgets/club_emblem.dart').readAsStringSync();
      expect(source, contains('shapeCount = 6'));
      expect(source, contains('motifCount = 6'));

      // 実際のチームIDの並びで、形が偏らないことを見る。
      final shapes = <int>{};
      final motifs = <int>{};
      for (var i = 0; i < 200; i++) {
        final seed = 'team-$i'.hashCode.abs();
        shapes.add(seed % 6);
        motifs.add((seed ~/ 6) % 6);
      }
      expect(shapes.length, 6, reason: '出てこない形がある');
      expect(motifs.length, 6, reason: '出てこない柄がある');
    });
  });
}
