/// ストア掲載用のスクリーンショットを生成する(iPhone 6.3インチ = 1206x2622。App Store の必須枠)。
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

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/collection.dart';
import 'package:basketball_career/game/honors.dart';
import 'package:basketball_career/game/skills.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/monetization/monetization.dart';
import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:basketball_career/ui/settings_screen.dart';
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

/// 端末。`DEVICE=ipad flutter test tool/screenshots/capture_test.dart` で iPad 13インチ(2064x2752)。
/// 何も付けなければ iPhone(Dynamic Island 搭載の中型、1206x2622)。出力は `marketing/screenshots/<端末>/`。
final _device = Platform.environment['DEVICE'] ?? 'iphone';
final _ipad = _device == 'ipad';
final _logical = _ipad ? const Size(1032, 1376) : const Size(402, 874);
final _ratio = _ipad ? 2.0 : 3.0;
final _bandHeight = _ipad ? 200.0 : 150.0;

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
              fontSize: _ipad ? 44 : 30,
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
  (Color, Color) colors, {
  Future<void> Function(WidgetTester)? act,
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
  if (act != null) await act(t); // 画面を開く操作(殿堂など)
  // 画面の絵・ボタンのアイコン(assets の画像)の読み込みを待つ。待たないと空白で撮れる。
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
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
    // iPhone は論理 402x874 の3倍=1206x2622、iPad は論理 1032x1376 の2倍=2064x2752 で書き出す。
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('marketing/screenshots/$_device')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
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
      case Phase.halftime:
        g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
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


/// 課金アイテムの審査用: 値段(¥370)が出る設定画面を撮るための、偽のストア。
class _PricedStore implements PurchaseService {
  @override
  set onDelivered(Future<void> Function(String productId)? callback) {}
  @override
  set onRevoked(Future<void> Function(String productId)? callback) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => '¥370';
  @override
  Future<PurchaseOutcome> buyRemoveAds() async => PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement() async => null;
  @override
  void dispose() {}
}

void main() {
  testWidgets('ストア用スクリーンショット', (t) async {
    SharedPreferences.setMockInitialValues({'howtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    const orange = (Color(0xFFBF360C), Color(0xFFE65100));
    const blue = (Color(0xFF1A237E), Color(0xFF3949AB));
    const green = (Color(0xFF004D40), Color(0xFF00796B));
    const purple = (Color(0xFF4A148C), Color(0xFF7B1FA2));

    // 1. 育成画面: 6年ぶんの成長のあとの、年のはじめ(目標の選択が出る)。
    final a = Game.start('ミナト', rng: Random(11), events: false);
    _play(a, untilAge: 12);
    while (a.slot != 0 && a.phase == Phase.season) {
      a.choose(Action.rest, recommendedFocus(a.player));
    }
    await _shoot(t, '01_season', '6歳から、選手を育てる', _controller(a), orange);

    // 2. 勝負どころ: ライバル戦(タイムアウトのボタンも出る)。
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
    await _shoot(t, '02_clutch', '勝負どころは自分で選ぶ', clutch!, blue);

    // 3. ハーフタイム: 相手の持ち味との相性、ファウルトラブル、勢い。
    Game? half;
    for (var seed = 0; seed < 3000 && half == null; seed++) {
      final base = Game.start('ミナト', rng: Random(seed), events: false);
      final g = Game(
        eventsEnabled: false,
        player: base.player.copyWith(
          age: 26,
          heightCm: 196,
          abilities: {
            for (final x in Ability.values)
              x: (x == Ability.defense || x == Ability.physical) ? 90 : 66,
          },
        ),
        rng: Random(seed),
        track: Track.pro,
        salary: 3000,
        slot: 1,
      );
      g.choose(Action.rest, Ability.defense, askClutch: true, askHalftime: true);
      var guard = 0;
      while ((g.phase == Phase.halftime || g.phase == Phase.clutch) && guard++ < 30) {
        if (g.phase == Phase.halftime) {
          final h = g.halftimeInfo!;
          if (h.fouls >= 3 && g.run!.streak != 0 && h.style != OppStyle.balanced) {
            half = g;
            break;
          }
          g.resolveHalftime(Halftime.keep);
        } else {
          g.resolveClutch(Clutch.drive);
        }
      }
    }
    expect(half, isNotNull, reason: 'ファウルトラブルと勢いのあるハーフタイムが見つからない');
    await _shoot(t, '03_halftime', '作戦は相手に合わせる', _controller(half!), blue);

    // 4. 進路(19歳)。
    final pbase = Game.start('ミナト', rng: Random(3), events: false);
    final path = Game(
      eventsEnabled: false,
      player: pbase.player.copyWith(
        age: 19,
        heightCm: 190,
        abilities: {for (final x in Ability.values) x: 66},
      ),
      rng: Random(4),
      pathPending: true,
    );
    await _shoot(t, '04_path', '19歳、進路は自分で選ぶ', _controller(path), green);

    // 5. プロの状態: ドラフト・年俸・スポンサー・ビルド。
    final sbase = Game.start('ミナト', rng: Random(3), events: false);
    final pro = Game(
      eventsEnabled: false,
      player: sbase.player.copyWith(
        age: 27,
        heightCm: 196,
        abilities: {
          for (final x in Ability.values)
            x: (x == Ability.threePoint || x == Ability.midRange || x == Ability.freeThrow) ? 84 : 58,
        },
      ),
      rng: Random(4),
      track: Track.pro,
      number: 23,
      draftPick: 7,
      salary: 12500,
      sponsor: 1800,
      totalEarnings: 48300,
    );
    await _shoot(t, '05_pro', '年俸もビルドも育てる', _controller(pro), orange);

    // 6. 図鑑(殿堂): 集めたタイトル・ビルド・特性・得意技。
    // アプリは起動時に保存済みの図鑑を読み直すので、保存の模擬データとして先に入れる。
    SharedPreferences.setMockInitialValues({
      'howtoSeen': true,
      collectionKey: jsonEncode(Collection(
        honors: {Honor.scoringKing, Honor.rookie, Honor.allStar, Honor.finalMvp},
        traits: {Trait.lefty.name, Trait.hardWorker.name, Trait.captain.name, Trait.clutch.name},
        skills: {Skill.stepBack.name, Skill.dunk.name, Skill.pickAndRoll.name},
        builds: {Build.sharpshooter.name: 2, Build.playmaker.name: 1, Build.slasher.name: 0},
      ).toJson()),
    });
    final zc = _controller(Game.start('ミナト', rng: Random(2), events: false));
    await _shoot(t, '06_zukan', '集めて埋める、図鑑', zc, purple, act: (t) async {
      await t.tap(find.byTooltip('殿堂・実績'));
      await t.pumpAndSettle();
    });

    // 7. エンディング: 海外に渡って優勝した一生。
    GameController? ending;
    for (var seed = 0; seed < 400 && ending == null; seed++) {
      final g = Game.start('ミナト', rng: Random(seed), events: false);
      _play(g, untilAge: 60);
      if (g.phase == Phase.retired && g.abroad && g.titles >= 2) {
        ending = _controller(g);
      }
    }
    expect(ending, isNotNull, reason: '見栄えのするエンディングが見つからない');
    await _shoot(t, '07_ending', '称号と殿堂が物語を残す', ending!, purple);

    // 8. どんな選手を目指すか: 育成画面の「型を選ぶ」ダイアログ(選んだ型の説明つき)。
    final st = Game.start('ミナト', rng: Random(11), events: false, style: Build.sharpshooter);
    _play(st, untilAge: 12);
    while (st.slot != 0 && st.phase == Phase.season) {
      st.choose(Action.rest, recommendedFocus(st.player));
    }
    await _shoot(t, '08_style', '目指す選手を、自分で選ぶ', _controller(st), orange,
        act: (t) async {
      await t.tap(find.text('型を選ぶ'));
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  // 課金アイテムの審査用(App Store Connect の「審査に関する情報」)。値段(¥370)が写った設定画面。
  // 掲載画像ではないので、値段が写っていてよい。iPhone の寸法だけ作る。
  testWidgets('課金アイテムの審査用', (t) async {
    if (_ipad) return;
    SharedPreferences.setMockInitialValues({'howtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    t.view.physicalSize = _logical * _ratio;
    t.view.devicePixelRatio = _ratio;
    final m = Monetization(await SharedPreferences.getInstance(), store: _PricedStore());
    await t.pumpWidget(RepaintBoundary(
      key: _key,
      child: MediaQuery(
        data: MediaQueryData(size: _logical, devicePixelRatio: _ratio),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'NotoSansJP', colorSchemeSeed: const Color(0xFFE65100)),
          home: SettingsScreen(money: m),
        ),
      ),
    ));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('広告を消す(￥370)'), findsOneWidget, reason: '値段のボタンが出ていない');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.runAsync(() async {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: _ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('marketing/iap_review')..createSync(recursive: true);
      File('${dir.path}/remove_ads.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
