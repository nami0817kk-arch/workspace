import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/ui/widgets.dart';

/// 目で見て確かめるための画面の書き出し先。QUAD_SHOTS にフォルダを渡したときだけ書き出す（画像はコミットしない）
final shotDir = Platform.environment['QUAD_SHOTS'];

/// 本物のフォント（同梱の Noto Sans JP と Material のアイコン）で描く
Future<void> loadRealFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    jp.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await jp.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

/// [key] の RepaintBoundary を PNG にする
Future<void> shot(WidgetTester tester, GlobalKey key, String name, {double pixelRatio = 2}) async {
  final dir = shotDir;
  if (dir == null) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final im = await ro.toImage(pixelRatio: pixelRatio);
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
  });
}
