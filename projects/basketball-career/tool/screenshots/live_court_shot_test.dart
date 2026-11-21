/// 采配の画面(コートで選手が動く)を、途中の何コマかで撮る点検用。**CI では回らない。**
///
///     flutter test tool/screenshots/live_court_shot_test.dart
///
/// 出力: `build/review_live/*.png`。撮ったら必ず目で見る。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/policy.dart';
import 'package:basketball_career/ui/gm/live_game_screen.dart';
import 'package:basketball_career/ui/gm/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(844, 390);
const _ratio = 2.0;
final _key = GlobalKey();

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noto = FontLoader('NotoSansJP');
  for (final f in ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf']) {
    noto.addFont(Future.value(ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer)));
  }
  await noto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
      await loader.load();
    }
  }
}

Future<void> _save(WidgetTester t, String name, {String dir = 'build/review_live'}) async {
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final d = Directory(dir)..createSync(recursive: true);
    File('${d.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('采配の画面で選手が動く', (t) async {
    addTearDown(t.view.reset);
    t.view.physicalSize = _size * _ratio;
    t.view.devicePixelRatio = _ratio;
    final car = careerAt(3, 12)..startSeason();
    await t.pumpWidget(RepaintBoundary(
      key: _key,
      child: MaterialApp(theme: gmTheme(), debugShowCheckedModeBanner: false, home: LiveGameScreen(car: car)),
    ));
    final shots = [900, 1700, 2600, 4200, 9000, 16000, for (var k = 0; k < 40; k++) 20000 + k * 150];
    var at = 0;
    for (final ms in shots) {
      while (at < ms) {
        await t.pump(const Duration(milliseconds: 50));
        at += 50;
      }
      await _save(t, 'a_${ms}ms');
    }
    // 選手を押す
    await t.tapAt(t.getCenter(find.byKey(const Key('moving-court'))));
    await t.pump(const Duration(milliseconds: 50));
    await _save(t, 'b_tap');
    // 区切りまで飛ばす
    await t.tap(find.textContaining('まで飛ばす'));
    await t.pump(const Duration(milliseconds: 100));
    await _save(t, 'c_break');
    // 采配の選択肢は、はじめは何も選ばれていない(速さの印が残らない)
    expect(t.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((c) => c.selected), isEmpty);
    // 3Qまで進めた所も撮る
    await t.tap(find.textContaining('前半終了まで'));
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await _save(t, 'd_q2_playing');
    await t.tap(find.textContaining('まで飛ばす'));
    await t.pump(const Duration(milliseconds: 100));
    await _save(t, 'e_half');
    expect(t.takeException(), isNull);
  });
  // 方針ごとの動きの違い(攻めの重点・ボールの回し方・展開の速さ・守り方を、両チームに同じく入れる)
  for (final (name, pol) in [
    ('outside_pass_fast_press', [2, 0, 2, 2, 1]),
    ('inside_ace_slow_pack', [0, 2, 0, 0, 1]),
  ]) {
    testWidgets('方針: $name', (t) async {
      addTearDown(t.view.reset);
      t.view.physicalSize = _size * _ratio;
      t.view.devicePixelRatio = _ratio;
      final car = careerAt(3, 12)..startSeason();
      final g = car.nextMyGame!;
      for (final team in [car.teams[g.$1], car.teams[g.$2]]) {
        team.policy = List.of(pol);
      }
      expect(PolicyAxis.values.length, pol.length);
      await t.pumpWidget(RepaintBoundary(
        key: _key,
        child: MaterialApp(theme: gmTheme(), debugShowCheckedModeBanner: false, home: LiveGameScreen(car: car)),
      ));
      var at = 0;
      for (var k = 0; k < 40; k++) {
        final ms = 6000 + k * 150;
        while (at < ms) {
          await t.pump(const Duration(milliseconds: 50));
          at += 50;
        }
        await _save(t, 'f_$k', dir: 'build/review_live/$name');
      }
      await t.tap(find.textContaining('まで飛ばす'));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    });
  }
}
