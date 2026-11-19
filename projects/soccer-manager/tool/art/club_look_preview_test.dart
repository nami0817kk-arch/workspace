/// クラブの見た目のカードを PNG に書き出す(確認用。CI では回らない)。
///
///     flutter test tool/art/club_look_preview_test.dart
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/club_look.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/club_emblem.dart';
import 'package:soccer_manager/widgets/club_look_card.dart';

import '../../test/support/app_fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Tr.language = AppLanguage.japanese;
  });

  testWidgets('クラブの見た目のカード', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(900, 760) * 2;
    SharedPreferences.setMockInitialValues({});
    late final GameState gs;
    await tester.runAsync(() async {
      gs = GameState();
      await gs.startNewGame('つるはしFC');
    });
    final key = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: gs,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'NotoSansJP'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                    width: 520,
                    child: SingleChildScrollView(child: ClubLookCard())),
                // 形と模様の組み合わせの例。
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < 6; i++)
                        ClubEmblem(
                          teamId: 'x',
                          teamName: 'つるはし',
                          size: 72,
                          look: ClubLook(
                            hue: ClubLook.colors[i * 2].$1,
                            accentHue: ClubLook.colors[(i * 2 + 5) % 12].$1,
                            shape: i,
                            motif: (i + 3) % 6,
                            initial: i.isEven ? 'つ' : 'TF',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File('build/club_look_preview.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
