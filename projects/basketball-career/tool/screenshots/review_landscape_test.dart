/// 横画面の点検用の画像を作る(ストア掲載用ではない。掲載用は `capture_test.dart`)。
///
/// **CI では回らない。** 手元で:
///
///     flutter test tool/screenshots/review_landscape_test.dart
///     DEVICE=ipad flutter test tool/screenshots/review_landscape_test.dart
///
/// 出力: `build/review_landscape/<端末>/*.png`。撮ったら必ず目で見る(はみ出し・切れ・空白)。
library;

// 生成器はテストの外にあるため、setMockInitialValues が警告になる。実体は flutter test で走らせる。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _device = Platform.environment['DEVICE'] ?? 'iphone';
final _size = _device == 'ipad' ? const Size(1376, 1032) : const Size(844, 390);
final _ratio = _device == 'ipad' ? 1.0 : 2.0;
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

Future<GmController> _controller() async => GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(7));

Future<GmController> _with(Career car) async {
  final c = await _controller();
  c.setCareer(car);
  c.pending.clear();
  return c;
}

Future<void> _shoot(WidgetTester t, String name, GmController c, {Future<void> Function(WidgetTester)? act}) async {
  t.view.physicalSize = _size * _ratio;
  t.view.devicePixelRatio = _ratio;
  await t.pumpWidget(RepaintBoundary(key: _key, child: KeyedSubtree(key: ValueKey(name), child: BasketballCareerApp(controller: c))));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
  if (act != null) await act(t);
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 700)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
  expect(t.takeException(), isNull, reason: '$name で例外');
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/review_landscape/$_device')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester t, String text, {bool first = false}) async {
  final f = first ? find.text(text).first : find.text(text).last;
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('横画面の点検', (t) async {
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    await _shoot(t, '1_title', await _controller());
    await _shoot(t, '2_teampick', await _controller(), act: (t) => _tap(t, 'GMに就任する'));

    final pre = careerAt(2, 20);
    await _shoot(t, '3_home_preseason', await _with(pre));

    final mid = careerAt(3, 12)..startSeason();
    mid.playBlock();
    await _shoot(t, '4_home_season', await _with(mid));
    await _shoot(t, '5_team', await _with(mid), act: (t) => _tap(t, 'チーム', first: true));
    await _shoot(t, '6_trade', await _with(mid), act: (t) => _tap(t, 'トレード', first: true));
    await _shoot(t, '7_market', await _with(mid), act: (t) => _tap(t, '補強', first: true));
    await _shoot(t, '8_league', await _with(mid), act: (t) => _tap(t, 'リーグ', first: true));
    await _shoot(t, '9_inbox', await _with(mid), act: (t) => _tap(t, '受信箱', first: true));

    final draft = careerAt(5, 28);
    var guard = 0;
    while (draft.phase != Phase.draft && guard++ < 400) {
      if (draft.phase == Phase.seasonEnd) draft.fired = false;
      botStep(draft);
    }
    await _shoot(t, '10_draft', await _with(draft));
    final over = botPlayCareer(8, team: teamAtRank(8, 15));
    await _shoot(t, '11_over', await _with(over));
  });
}
