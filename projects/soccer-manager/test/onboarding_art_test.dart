import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/widgets/onboarding_art.dart';

void main() {
  group('チュートリアルの挿絵', () {
    test('用意した絵が、すべてどこかのページで使われている', () {
      // 描いたのに使われていない絵は、増やした意味がない。逆に、
      // 同じ絵が2ページに出ると手抜きに見える。
      final source =
          File('lib/screens/onboarding_screen.dart').readAsStringSync();
      for (final kind in OnboardingArtKind.values) {
        final marker = 'OnboardingArtKind.${kind.name}';
        expect(
          marker.allMatches(source).length,
          1,
          reason: '$marker がチュートリアルで使われていない、または重複している',
        );
      }
    });

    test('どの絵も、どの大きさでも描画が落ちない', () {
      // 端末の幅に合わせて縮めるので、極端に小さい寸法でも通す必要がある。
      // 0 除算や負の半径は、この手の描画でいちばん出やすい。
      for (final kind in OnboardingArtKind.values) {
        for (final width in const [40.0, 120.0, 260.0, 600.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const painter = _PainterFactory();
          expect(
            () => painter.of(kind).paint(canvas, Size(width, width * 2 / 3)),
            returnsNormally,
            reason: '$kind を幅 $width で描くと落ちる',
          );
          recorder.endRecording().dispose();
        }
      }
    });

    testWidgets('ウィジェットとして置いても例外が出ない', (tester) async {
      for (final kind in OnboardingArtKind.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: OnboardingArt(kind: kind))),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$kind の描画で例外');
      }
    });
  });
}

class _PainterFactory {
  const _PainterFactory();

  OnboardingArtPainter of(OnboardingArtKind kind) => OnboardingArtPainter(
        kind: kind,
        primary: const Color(0xFF16233A),
        container: const Color(0xFFD7E0F5),
        accent: const Color(0xFF2E7D32),
      );
}
