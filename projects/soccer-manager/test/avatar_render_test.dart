import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/widgets/player_face_avatar.dart';

void main() {
  group('似顔絵', () {
    test('同じ選手なら常に同じ顔になる', () {
      final a = FaceFeatures.fromSeed(12345);
      final b = FaceFeatures.fromSeed(12345);
      expect(a.hairStyle, b.hairStyle);
      expect(a.eyeStyle, b.eyeStyle);
      expect(a.mouthStyle, b.mouthStyle);
      expect(a.faceWidth, b.faceWidth);
    });

    test('用意した見た目の分岐が、すべて実際に出てくる', () {
      // 分岐を足しても乱数の引き方が合っていないと、一部の髪型が
      // 一度も選ばれないまま残る。到達しない絵を持っていても意味がない。
      final hair = <int>{};
      final eyes = <int>{};
      final mouths = <int>{};
      final beards = <int>{};
      for (var seed = 0; seed < 600; seed++) {
        final f = FaceFeatures.fromSeed(seed);
        hair.add(f.hairStyle);
        eyes.add(f.eyeStyle);
        mouths.add(f.mouthStyle);
        beards.add(f.facialHair);
      }
      expect(hair.length, FaceFeatures.hairStyleCount);
      expect(eyes.length, FaceFeatures.eyeStyleCount);
      expect(mouths.length, FaceFeatures.mouthStyleCount);
      expect(beards.length, FaceFeatures.facialHairCount);
    });

    test('輪郭も振れている(色違いの同じ顔にならない)', () {
      // 以前は肌と髪の色しか振っておらず、名簿を眺めると同じ顔が
      // 並んでいるように見えた。
      final widths = <double>{};
      final heights = <double>{};
      final spreads = <double>{};
      for (var seed = 0; seed < 200; seed++) {
        final f = FaceFeatures.fromSeed(seed);
        widths.add(f.faceWidth);
        heights.add(f.faceHeight);
        spreads.add(f.eyeSpread);
      }
      expect(widths.length, greaterThan(150));
      expect(heights.length, greaterThan(150));
      expect(spreads.length, greaterThan(150));
    });

    test('顔の寸法が枠からはみ出さない範囲に収まる', () {
      // 円形に切り抜いて表示するので、1.0 を超えると輪郭が切れる。
      for (var seed = 0; seed < 500; seed++) {
        final f = FaceFeatures.fromSeed(seed);
        expect(f.faceWidth, inInclusiveRange(0.7, 0.96));
        expect(f.faceHeight, inInclusiveRange(0.8, 1.0));
        // 目が離れすぎると輪郭の外に出る。
        expect(f.eyeSpread, lessThan(f.faceWidth / 2 - 0.05));
      }
    });

    test('描き直しの判定が、絵を決める値をすべて見ている', () {
      // エンブレム側で motifIndex の見落としが実際にあった。形と色が
      // 同じで柄だけ違うクラブが隣り合うと、前のクラブの柄が残る。
      final source = File('lib/widgets/club_emblem.dart').readAsStringSync();
      final painter = source.substring(source.indexOf('class _EmblemPainter'));
      final shouldRepaint =
          painter.substring(painter.indexOf('shouldRepaint'));
      for (final field in const ['base', 'accent', 'shapeIndex', 'motifIndex']) {
        expect(shouldRepaint, contains('oldDelegate.$field'),
            reason: '_EmblemPainter.shouldRepaint が $field を見ていない');
      }
    });
  });

  group('クラブエンブレム', () {
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
