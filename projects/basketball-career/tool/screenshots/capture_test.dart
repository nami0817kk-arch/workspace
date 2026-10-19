/// ストア掲載用のスクリーンショットを生成する(iPhone 6.9インチ = 1320x2868)。
///
/// **CI では回らない**(`test/` の外にある生成器。実行するとファイルを書き換える)。
///
///     flutter test tool/screenshots/capture_test.dart
///
/// 出力: `marketing/screenshots/*.png`
///
/// 決まり(`docs/app-pitfalls.md` #4、Apple 2.3.2・2.3.7):
/// - **読み込み中のまま撮らない。** 撮るたびに、読み込みの丸が無いこと・文字が一定数あることを検査する。
/// - タイトル画面は撮らない。広告を消していない状態で撮り、値段を写さない。
/// - 実在の名称(リーグ・チーム・選手)を入れない(このアプリの名前はすべて架空)。
///
/// 実フォントとアイコンフォントを読み込む(読まないと字が□になる)。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではないコード」になり、
// @visibleForTesting の項目(setMockInitialValues)を使うと警告になる。実体は flutter test で走らせる生成器。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter/material.dart' hide Action, Route;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}

const _logical = Size(440, 956);
const _ratio = 3.0;
const _bandHeight = 150.0;

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noto = FontLoader('NotoSansJP');
  for (final f in ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf']) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    noto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await noto.load();
  // アイコンフォントは Flutter SDK にある。
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
      );
      await loader.load();
    }
  }
}

/// 帯つきで描く。上に言葉、下にアプリの画面。
Widget _framed(String caption, Color top, Color bottom, Widget app) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: [
        Container(
          height: _bandHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
          ),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansJP',
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(child: app),
      ],
    ),
  );
}

final _key = GlobalKey();

Future<void> _shoot(
  WidgetTester t,
  String name,
  String caption,
  GameController c,
  (Color, Color) colors,
) async {
  t.view.physicalSize = _logical * _ratio;
  t.view.devicePixelRatio = _ratio;
  await t.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: _framed(
        caption,
        colors.$1,
        colors.$2,
        MediaQuery(
          data: MediaQueryData(
            size: Size(_logical.width, _logical.height - _bandHeight),
            devicePixelRatio: _ratio,
          ),
          // 前の画面の State を使い回さない(controller が替わらなくなる)。
        child: KeyedSubtree(
            key: ValueKey(name), child: BasketballCareerApp(controller: c)),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
  // 読み込み中のまま撮っていないことを検査する。
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '$name が読み込み中のまま撮られている',
  );
  expect(
    find.byType(Text),
    findsAtLeastNWidgets(3),
    reason: '$name に文字がほとんど無い(描画を待たずに撮っている)',
  );
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // 論理 440x956 を 3 倍にして、1320x2868(iPhone 6.9インチ)で書き出す。
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('marketing/screenshots/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
  });
}

GameController _controller(Game g) {
  final c = GameController(store: _NullStore(), rng: Random(1), events: false);
  c.game = g;
  return c;
}

/// おすすめで進める(勝負どころは自動)。
void _play(Game g, {required int untilAge}) {
  var guard = 0;
  while (g.phase != Phase.retired && g.player.age < untilAge && guard++ < 600) {
    switch (g.phase) {
      case Phase.season:
        if (g.goal == null && g.goalOptions.isNotEmpty && g.slot <= 2) {
          g.adoptGoal(0);
        }
        g.choose(recommendedAction(g), recommendedFocus(g.player));
        if (g.canGoAbroad) g.goAbroad();
      case Phase.clutch:
        g.resolveClutch(Clutch.drive);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.path:
        final ok = g.chooseRoute(Route.pro);
        if (!ok && !g.retired) g.chooseRoute(Route.university);
      case Phase.retired:
        break;
    }
  }
}

void main() {
  testWidgets('ストア用スクリーンショット', (t) async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    addTearDown(t.view.reset);

    // 1. 育成画面: 6年ぶんの成長のあとの、年のはじめ(目標の選択が出る)。
    final a = Game.start('ミナト', rng: Random(11), events: false);
    _play(a, untilAge: 12);
    while (a.slot != 0 && a.phase == Phase.season) {
      a.choose(Action.rest, recommendedFocus(a.player));
    }
    await _shoot(t, '01_season', '6歳から、選手を育てる', _controller(a), (
      const Color(0xFFBF360C),
      const Color(0xFFE65100),
    ));

    // 2. 勝負どころ: ライバル戦。
    GameController? clutch;
    for (var seed = 0; seed < 600 && clutch == null; seed++) {
      final g = Game.start('ミナト', rng: Random(seed), events: false);
      _play(g, untilAge: 14);
      while (g.slot != 1 && g.phase == Phase.season) {
        g.choose(Action.rest, recommendedFocus(g.player));
      }
      if (g.phase != Phase.season) continue;
      g.choose(Action.rest, recommendedFocus(g.player), askClutch: true);
      if (g.phase == Phase.clutch && g.run!.pending!.vsRival) {
        clutch = _controller(g);
      }
    }
    expect(clutch, isNotNull, reason: 'ライバル戦の勝負どころが見つからない');
    await _shoot(t, '02_clutch', '勝負どころは自分で選ぶ', clutch!, (
      const Color(0xFF1A237E),
      const Color(0xFF3949AB),
    ));

    // 3. 進学先の選択(出来事)。
    final base = Game.start('ミナト', rng: Random(5), events: false);
    final e = Game(
      eventsEnabled: true,
      player: base.player.copyWith(
        age: 15,
        heightCm: 178,
        abilities: {for (final x in Ability.values) x: 58},
      ),
      rng: Random(5),
      pendingEventId: 'school_hs',
    );
    await _shoot(t, '03_school', '進学も移籍も自分で決める', _controller(e), (
      const Color(0xFF004D40),
      const Color(0xFF00796B),
    ));

    // 4. エンディング: 海外に渡って優勝した一生。
    GameController? ending;
    for (var seed = 0; seed < 400 && ending == null; seed++) {
      final g = Game.start('ミナト', rng: Random(seed), events: false);
      _play(g, untilAge: 60);
      if (g.phase == Phase.retired && g.abroad && g.titles >= 2) {
        ending = _controller(g);
      }
    }
    expect(ending, isNotNull, reason: '見栄えのするエンディングが見つからない');
    await _shoot(t, '04_ending', '称号と殿堂が物語を残す', ending!, (
      const Color(0xFF4A148C),
      const Color(0xFF7B1FA2),
    ));
  });
}
