import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 目で見て確かめるための画面の書き出し。本物のフォントで幅390の縦画面を PNG にする。
/// QUAD_SHOTS に書き出し先のフォルダを渡したときだけ動く（画像はコミットしない）。
///   QUAD_SHOTS=C:/somewhere flutter test test/screens_test.dart
final _out = Platform.environment['QUAD_SHOTS'];

Future<void> _loadFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    final b = File(f).readAsBytesSync();
    jp.addFont(Future.value(ByteData.sublistView(b)));
  }
  await jp.load();
  // アイコン（×・＞）も本物で描く
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final im = await ro.toImage(pixelRatio: 2);
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('画面の書き出し（幅390）', (tester) async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77))
      ..setup = SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']);
    ctl.startNew();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
    await tester.pump();
    await _shot(tester, key, '1_town_guide');

    // 最初の事業を始めると、案内が次の段に進む
    final s = ctl.game!;
    final ind = s.liveInds().where((i) => s.capexOf(i) <= s.cash).first;
    ctl.act(() => s.startBiz(ind.id));
    await tester.pump();
    await _shot(tester, key, '2_town_guide_next');

    // 月を進めた直後（数字が光っている途中）
    doNext(ctl);
    ctl.closeSheet();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await _shot(tester, key, '3_flash');
    await tester.pumpAndSettle();

    // 途中のゲームで宿敵の色が出る画面（事業・株）
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(g);
    }
    resolveEvents(g);
    g.calcAll();
    ctl.game = g;
    ctl.setTab('biz');
    await tester.pump();
    await _shot(tester, key, '4_biz_rivals');
    ctl.setTab('town');
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pump();
    await _shot(tester, key, '5_town_rivals');
    expect(tester.takeException(), isNull);
  }, skip: _out == null);
}
