/// ストア掲載用のスクリーンショットを生成する(iPhone 6.3インチ = 1206x2622。App Store の必須枠)。
///
/// **CI では回らない**(`test/` の外にある生成器。実行するとファイルを書き換える)。
///
///     flutter test tool/screenshots/capture_test.dart
///     DEVICE=ipad flutter test tool/screenshots/capture_test.dart   (iPad 13インチ 2064x2752)
///
/// 出力: `marketing/screenshots/*.png`(iPad は `marketing/screenshots/ipad/*.png`)
///
/// 決まり(`docs/app-pitfalls.md` #4、Apple 2.3.2・2.3.7):
/// - **読み込み中のまま撮らない。** 撮るたびに、読み込みの丸が無いこと・文字が一定数あることを検査する。
/// - タイトル画面は撮らない。
/// - 実在の名称(リーグ・チーム・選手)を入れない(このアプリの名前はすべて架空)。
///
/// 実フォントとアイコンフォントを読み込む(読まないと字が□になる)。
/// 撮ったら必ず1枚ずつ目で見る(`ios-app-release` スキルの E)。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではないコード」になる。
// 実体は flutter test で走らせる生成器。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:baseball_manager/game/after_career.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/final_moment.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `DEVICE=ipad` で iPad 13インチ(2064x2752)。既定は iPhone 6.3インチ(1206x2622)。
final _ipad = Platform.environment['DEVICE'] == 'ipad';
final _logical = _ipad ? const Size(1032, 1376) : const Size(402, 874);
final _ratio = _ipad ? 2.0 : 3.0;
final _bandHeight = _ipad ? 168.0 : 104.0;
final _outDir = _ipad ? 'marketing/screenshots/ipad' : 'marketing/screenshots';

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
            style: TextStyle(
              fontFamily: 'NotoSansJP',
              color: Colors.white,
              fontSize: _ipad ? 44 : 26,
              height: 1.25,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        // 横幅いっぱいに(Column の横は loose なので、縮めた画面のまわりが抜ける)。
        Expanded(child: SizedBox(width: double.infinity, child: app)),
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
  (Color, Color) colors, {
  Future<void> Function()? after,
  int minTexts = 8,
}) async {
  t.view.physicalSize = _logical * _ratio;
  t.view.devicePixelRatio = _ratio;
  await t.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: _framed(
        caption,
        colors.$1,
        colors.$2,
        // 育成タブは 390x844 の端末で1画面に収まる作り。残りの高さに合わせて少し縮める。
        // iPad は縮めずに、帯を除いた実寸でそのまま描く。
        ColoredBox(
          color: const Color(0xFFF3F7EF),
          child: _ipad
              ? MediaQuery(
                  data: MediaQueryData(
                    size: Size(_logical.width, _logical.height - _bandHeight),
                    devicePixelRatio: _ratio,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(name),
                    child: BaseballManagerApp(controller: c),
                  ),
                )
              : FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _logical.width,
                    height: 844,
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: Size(_logical.width, 844),
                        devicePixelRatio: _ratio,
                      ),
                      // 前の画面の State を使い回さない(controller が替わらなくなる)。
                      child: KeyedSubtree(
                        key: ValueKey(name),
                        child: BaseballManagerApp(controller: c),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
  // 絵(背景・アイコン)を先に読み込んでおく(読み込み前に撮ると、絵が抜ける)。
  final ctx = t.element(find.byType(BaseballManagerApp));
  await t.runAsync(() async {
    for (final dir in ['assets/images', 'assets/icons']) {
      for (final f in Directory(dir).listSync().whereType<File>()) {
        final path = f.path.replaceAll('\\', '/');
        await precacheImage(AssetImage(path), ctx);
      }
    }
  });
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
  if (after != null) {
    await after();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
  }
  // 節目のダイアログが出ていたら閉じる(撮りたいのは画面そのもの)。
  while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
    await t.tap(find.byKey(const Key('milestone-ok')));
    await t.pumpAndSettle();
  }
  // 読み込み中のまま撮っていないことを検査する。
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '$name が読み込み中のまま撮られている',
  );
  expect(
    find.byType(Text),
    findsAtLeastNWidgets(minTexts),
    reason: '$name に文字がほとんど無い(描画を待たずに撮っている)',
  );
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // 論理 402x874 を 3 倍にして、1206x2622(Dynamic Island 搭載 iPhone の中型)で書き出す。
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

GameController _controller(Game g) {
  final c = GameController(rng: Random(1));
  c.adopt(g);
  c.pending.clear();
  return c;
}

/// 決まった方針で、条件が満たされるまで進める。
Game _until(bool Function(Game) stop,
    {int seed = 1, int potential = 90, Role role = Role.batter}) {
  final g = Game.newGame(
      name: 'ハルト', role: role, rng: Random(seed), potential: potential);
  var guard = 0;
  while (g.phase != Phase.retired && !stop(g) && guard++ < 4000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(
            g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            abilitiesOf(
                g.player.role)[guard % abilitiesOf(g.player.role).length]);
      case Phase.event:
        if (g.pendingEvent!.id == finalMomentId && stop(g)) return g;
        g.resolveEvent(g.pendingEvent!.id == finalMomentId ? 1 : 0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

void main() {
  testWidgets('ストア用スクリーンショット', (t) async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    addTearDown(t.view.reset);

    // 1. 育成画面: 高校2年の春。
    final a = _until(
        (g) =>
            g.stage == Stage.highSchool &&
            g.player.age == 17 &&
            g.slot == 1 &&
            g.phase == Phase.term,
        seed: 7,
        potential: 92);
    await _shoot(t, '01_train', '6歳から、\nひとりの選手を育てる', _controller(a), (
      const Color(0xFF1B5E20),
      const Color(0xFF2E7D32),
    ));

    // 2. 能力タブ: 天賦と特性(レア特性を持つ選手)。
    Game? rare;
    for (var s = 0; s < 400 && rare == null; s++) {
      final g = _until(
          (g) =>
              g.stage == Stage.highSchool &&
              g.player.age == 17 &&
              g.slot == 1 &&
              g.phase == Phase.term,
          seed: s,
          potential: 92);
      if (g.player.traits.any((x) => x.rare) &&
          g.phase == Phase.term &&
          g.stage == Stage.highSchool) {
        rare = g;
      }
    }
    expect(rare, isNotNull, reason: 'レア特性を持つ選手が見つからない');
    await _shoot(t, '02_traits', '才能と特性が、\n選手ごとに違う', _controller(rare!), (
      const Color(0xFF4A148C),
      const Color(0xFF7B1FA2),
    ), after: () async {
      await t.tap(find.byKey(const Key('tab-ability')));
      await t.pumpAndSettle();
    });

    // 3. 決勝の見せ場。
    Game? fin;
    for (var s = 0; s < 80 && fin == null; s++) {
      final g = _until(
          (g) =>
              g.phase == Phase.event &&
              g.pendingEvent?.id == finalMomentId &&
              g.player.age >= 16,
          seed: s,
          potential: 100);
      if (g.phase == Phase.event &&
          g.pendingEvent?.id == finalMomentId &&
          g.player.age >= 16) {
        fin = g;
      }
    }
    expect(fin, isNotNull, reason: '決勝の見せ場が見つからない');
    await _shoot(t, '03_final', '決勝の見せ場は、\n自分で選ぶ', _controller(fin!), (
      const Color(0xFFBF360C),
      const Color(0xFFE65100),
    ));

    // 4. キャリアタブ: タイトルと表彰を重ねたプロ選手。
    Game? star;
    for (var s = 0; s < 300 && star == null; s++) {
      final g = _until(
          (g) =>
              g.stage == Stage.pro &&
              g.player.age >= 30 &&
              g.slot == 0 &&
              g.phase == Phase.term,
          seed: s,
          potential: 100);
      final awards = g.records.fold<int>(0, (x, r) => x + r.awards.length);
      final titles = g.records.fold<int>(0, (x, r) => x + r.titles.length);
      if (g.phase == Phase.term &&
          g.stage == Stage.pro &&
          awards >= 6 &&
          titles >= 3) {
        star = g;
      }
    }
    expect(star, isNotNull, reason: '見栄えのするプロ選手が見つからない');
    await _shoot(t, '04_career', '実際の野球にある\n表彰と大記録', _controller(star!), (
      const Color(0xFF0D47A1),
      const Color(0xFF1565C0),
    ), after: () async {
      await t.tap(find.byKey(const Key('records-open')));
      await t.pumpAndSettle();
    });

    // 5. エンディング: プロを引退して、引退後の道を選んだ一生。
    Game? ending;
    for (var s = 0; s < 300 && ending == null; s++) {
      final g = _until((g) => false, seed: s, potential: 100);
      if (g.phase == Phase.retired &&
          g.ending!.madePro &&
          g.ending!.proYears >= 12 &&
          g.ending!.title == 'レジェンド') {
        g.chooseAfterPath(AfterPath.manager);
        ending = g;
      }
    }
    expect(ending, isNotNull, reason: '見栄えのするエンディングが見つからない');
    await _shoot(
        t,
        '05_ending',
        '引退のあとも、\n物語は続く',
        _controller(ending!),
        (
          const Color(0xFF004D40),
          const Color(0xFF00796B),
        ),
        minTexts: 5);
  });
}
