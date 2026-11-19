/// 大事な場面の1枚が、横画面(844x390)でどう見えるかを PNG に書き出す。
///
/// **CI では回らない。** 見た目を目で確かめるための生成器。
///
///     flutter test tool/art/moment_preview_test.dart --dart-define=OUT=<出力先>
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/big_moment.dart';
import 'package:soccer_manager/widgets/big_moment_overlay.dart';

import '../../test/support/app_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/moment_preview');
const _size = Size(844, 390);
const _ratio = 2.0;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Tr.language = AppLanguage.japanese;
  });

  for (final kind in BigMomentKind.values) {
    testWidgets('場面: ${kind.name}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = _ratio;
      tester.view.physicalSize = _size * _ratio;
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'NotoSansJP'),
        home: MediaQuery(
          data: const MediaQueryData(size: _size, disableAnimations: true),
          child: RepaintBoundary(
            key: key,
            child: BigMomentView(
              kind: kind,
              tag: Tr.pick('第38節・3部', 'Matchday 38, tier 3'),
              body: Tr.pick('残り3節を残して、上位2位以内が決まった。',
                  'Sealed with three games to spare.'),
            ),
          ),
        ),
      ));
      await tester.runAsync(() async {
        await precacheImage(
            AssetImage(kind.asset), tester.element(find.byKey(key)));
      });
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: _ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/${kind.name}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
