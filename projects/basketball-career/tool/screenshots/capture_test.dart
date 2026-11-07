/// ストア掲載用のスクリーンショットを生成する(iPhone 6.3インチ = 1206x2622。App Store の必須枠)。
///
/// **CI では回らない**(`test/` の外にある生成器。実行するとファイルを書き換える)。
///
///     flutter test tool/screenshots/capture_test.dart
///     DEVICE=ipad flutter test tool/screenshots/capture_test.dart
///
/// 出力: `marketing/screenshots/<端末>/*.png`、点検用は `build/review/<端末>/`、課金の審査用は `marketing/iap_review/`。
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

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:basketball_career/monetization/monetization.dart';
import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/gm/common.dart';
import 'package:basketball_career/ui/gm/style.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:basketball_career/ui/remove_ads_offer.dart';
import 'package:basketball_career/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末。`DEVICE=ipad` で iPad 13インチ(2064x2752)。何も付けなければ iPhone(中型、1206x2622)。
final _device = Platform.environment['DEVICE'] ?? 'iphone';
final _ipad = _device == 'ipad';
final _logical = _ipad ? const Size(1032, 1376) : const Size(402, 874);
final _ratio = _ipad ? 2.0 : 3.0;
final _bandHeight = _ipad ? 210.0 : 160.0;

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noto = FontLoader('NotoSansJP');
  for (final f in ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf']) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    noto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await noto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
      await loader.load();
    }
  }
}

/// 上に見出し、下にアプリの画面。夜の体育館の色にそろえる。
Widget _framed(String caption, Widget app) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: GmColors.bg,
      child: Column(
        children: [
          SizedBox(
            height: _bandHeight,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSansJP',
                    color: Colors.white,
                    fontSize: _ipad ? 46 : 29,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: _ipad ? 90 : 60, height: 5, color: GmColors.ball),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(_ipad ? 40 : 14, 0, _ipad ? 40 : 14, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: GmColors.line, width: 2),
              ),
              child: app,
            ),
          ),
        ],
      ),
    ),
  );
}

final _key = GlobalKey();

Future<void> _shoot(
  WidgetTester t,
  String name,
  String caption,
  GmController c, {
  Future<void> Function(WidgetTester)? act,
  String? outDir,
}) async {
  t.view.physicalSize = _logical * _ratio;
  t.view.devicePixelRatio = _ratio;
  final inset = _ipad ? 80.0 : 28.0;
  await t.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: _framed(
        caption,
        MediaQuery(
          data: MediaQueryData(
            size: Size(_logical.width - inset, _logical.height - _bandHeight),
            devicePixelRatio: _ratio,
          ),
          child: KeyedSubtree(key: ValueKey(name), child: BasketballCareerApp(controller: c)),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
  if (act != null) await act(t);
  // 絵(assets の画像)の読み込みを待つ。待たないと空白で撮れる。
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 700)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
  expect(find.byType(CircularProgressIndicator), findsNothing, reason: '$name が読み込み中のまま撮られている');
  expect(find.byType(Text), findsAtLeastNWidgets(3), reason: '$name に文字がほとんど無い');
  expect(t.takeException(), isNull, reason: '$name で例外');
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(outDir ?? 'marketing/screenshots/$_device')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<GmController> _controller() async =>
    GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(7));

Future<GmController> _with(Career car) async {
  final c = await _controller();
  c.setCareer(car);
  c.pending.clear();
  return c;
}

/// 条件に合う局面が出るまで、種を変えて自動で進める。
Career _find(int rank, bool Function(Career) found, {int from = 1}) {
  for (var seed = from; seed < from + 400; seed++) {
    final car = careerAt(seed, rank);
    var guard = 0;
    while (car.phase != Phase.over && guard++ < 400) {
      if (found(car)) return car;
      if (car.phase == Phase.seasonEnd) car.fired = false;
      botStep(car);
    }
  }
  throw StateError('局面が見つからない');
}

Future<void> _tap(WidgetTester t, String text) async {
  // 一覧の端で半分隠れていると押し損ねるので、全体が見える位置まで送ってから押す
  await t.ensureVisible(find.text(text).last);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text(text).last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Finder get _list => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;

/// 相手が受けてくれる、見栄えのするトレード(若手と指名権で、相手の主力を取りに行く)。
(Career, TradeOffer) _tradeScene() {
  for (var seed = 3; seed < 400; seed++) {
    final car = careerAt(seed, 28);
    for (var t = 0; t < teamDefs.length; t++) {
      if (t == car.mine) continue;
      final them = car.teams[t];
      if (them.mode != TeamMode.rebuild && them.mode != TeamMode.cutCost) continue;
      final target = them.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      if (target.age < 28 || target.ovr < 73) continue;
      final young = [...car.me.roster]..sort((a, b) => b.pot.compareTo(a.pot));
      final pick = car.picksOf(car.mine).firstWhere((i) => car.picks[i].round == 1);
      for (final y in young.take(5)) {
        final o = TradeOffer(partner: t, give: [y.id], get: [target.id], givePicks: [pick]);
        final v = car.judge(o);
        if (v.ok && v.ratio < 1.3) return (car, o);
      }
    }
  }
  throw StateError('トレードの局面が見つからない');
}

Future<void> _tradeShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final (car, o) = _tradeScene();
  final c = await _with(car);
  final them = car.teams[o.partner];
  await _shoot(t, name, caption, c, outDir: outDir, act: (t) async {
    await _tap(t, 'トレード');
    // 相手を選ぶ横の一覧は、見えていない分は作られていないので、送ってから押す
    final row = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right).first;
    await t.scrollUntilVisible(find.text(them.def.short), 150, scrollable: row);
    await _tap(t, them.def.short);
    for (final id in o.get) {
      final n = them.roster.firstWhere((p) => p.id == id).name;
      await t.scrollUntilVisible(find.text(n), 200, scrollable: _list);
      await _tap(t, n);
    }
    for (final id in o.give) {
      final n = car.me.roster.firstWhere((p) => p.id == id).name;
      await t.scrollUntilVisible(find.text(n), 200, scrollable: _list);
      await _tap(t, n);
    }
    for (final i in o.givePicks) {
      final label = '指名権 ${car.picks[i].label(car.teams, car.season)}';
      await t.scrollUntilVisible(find.text(label), 200, scrollable: _list);
      await _tap(t, label);
    }
    expect(find.text('受けてくれそう'), findsOneWidget);
    // 受け取る選手が見える位置に戻す
    final first = them.roster.firstWhere((p) => p.id == o.get.first).name;
    await t.scrollUntilVisible(find.text(first), -300, scrollable: _list);
    await t.pump(const Duration(milliseconds: 300));
  });
}

Future<void> _draftShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(28, (c) => c.phase == Phase.draft && c.myTurn && c.draftAt <= 3, from: 5);
  car.news.clear();
  final open = byMid(car);
  car.scoutProspect(open[0]);
  car.scoutProspect(open[2]);
  await _shoot(t, name, caption, await _with(car), outDir: outDir);
}

Future<void> _rosterShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(28, (c) => c.phase == Phase.preseason && c.season == 3, from: 9);
  await _shoot(t, name, caption, await _with(car), outDir: outDir, act: (t) => _tap(t, 'チーム'));
}

Future<void> _seasonShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(15, (c) => c.phase == Phase.season && c.block == 2 && c.me.wins >= 24 && c.incoming == null, from: 2);
  await _shoot(t, name, caption, await _with(car), outDir: outDir);
}

Future<void> _offerShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(15, (c) => c.phase == Phase.season && c.block == 1 && c.incoming != null, from: 4);
  await _shoot(t, name, caption, await _with(car), outDir: outDir);
}

Future<void> _contractShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(
      1,
      (c) =>
          c.phase == Phase.contracts &&
          c.expiring.length >= 2 &&
          c.me.roster.where((p) => c.expiring.contains(p.id)).any((p) => p.ovr >= 72),
      from: 3);
  await _shoot(t, name, caption, await _with(car), outDir: outDir);
}

Future<void> _championShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(1, (c) => c.phase == Phase.seasonEnd && c.myResult == 5 && !c.fired);
  await _shoot(t, name, caption, await _with(car), outDir: outDir);
}

Future<void> _leagueShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final car = _find(15, (c) => c.phase == Phase.playoffs && c.history.length >= 2, from: 6);
  await _shoot(t, name, caption, await _with(car), outDir: outDir, act: (t) => _tap(t, 'リーグ'));
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
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    await _tradeShot(t, '01_trade', '相手の考えを読んで、\nトレードを組む');
    await _draftShot(t, '02_draft', '指名するまで、\n本当の力は分からない');
    await _rosterShot(t, '03_roster', '伸びる若手と、\n年俸のやりくり');
    await _seasonShot(t, '04_season', '82試合を進めて、\nプレーオフへ');
    await _offerShot(t, '05_offer', '相手から届く、\nトレードの申し込み');
    await _contractShot(t, '06_contracts', '契約の切れた主力を、\n残すか放すか');
    await _championShot(t, '07_champion', 'めざせ、ファイナル制覇');
    await _leagueShot(t, '08_league', '東西30チームのリーグで、\nGMになる');
  });

  // 画面の点検用(掲載画像ではない)。build/review/ に書き出す(git には入れない)。
  testWidgets('画面の点検用', (t) async {
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    final out = 'build/review/$_device';
    await _shoot(t, 'r1_home', 'はじめの画面', await _controller(), outDir: out);
    final mail = _find(15, (c) => c.phase == Phase.season && c.block == 2 && c.inbox.length >= 4, from: 3);
    await _shoot(t, 'r9_inbox', '受信箱', await _with(mail), outDir: out, act: (t) async {
      await t.tap(find.byIcon(Icons.mail_rounded).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });
    final cardCar = _find(5, (c) => c.phase == Phase.preseason && c.season == 3, from: 2);
    await _shoot(t, 'r10_card', '選手のカード', await _with(cardCar), outDir: out, act: (t) async {
      await _tap(t, 'チーム');
      await _tap(t, cardCar.me.order.first.name);
    });
    final boxCar = _find(15, (c) => c.phase == Phase.season && c.block == 1 && c.incoming == null, from: 3);
    await _shoot(t, 'r11_box', 'ボックススコア', await _with(boxCar), outDir: out, act: (t) async {
      final first = boxCar.lastGames.first;
      final opp = teamDefs[first.opponentOf(boxCar.mine)].short;
      // 結果の一覧まで送ってから、最初の試合を押す
      await t.scrollUntilVisible(find.textContaining('ボックススコアが見られる'), 300, scrollable: _list);
      await _tap(t, opp);
    });
    // 前の撮影で保存された続きがあると「新しく任される?」が出るので、保存を空にしてから
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    await _shoot(t, 'r1b_teampick', 'チームを選ぶ', await _controller(), outDir: out, act: (t) => _tap(t, 'GMに就任する'));
    await _shoot(t, 'r2_preseason', 'シーズン前', await _with(careerAt(2, 28)), outDir: out);
    await _shoot(t, 'r3_market', '補強', await _with(Career.start(seed: 2)), outDir: out, act: (t) => _tap(t, '補強'));
    await _shoot(t, 'r4_playoffs', 'プレーオフ前', await _with(_find(1, (c) => c.phase == Phase.playoffs)), outDir: out);
    // 解任の局面は、信頼を1にして目標に届かないシーズンを作る
    final fired = careerAt(3, 1)
      ..trust = 1
      ..startSeason()
      ..target = gamesPerSeason;
    while (fired.phase == Phase.season) {
      fired.playBlock();
    }
    fired.playPlayoffs();
    await _shoot(t, 'r5_fired', '解任', await _with(fired), outDir: out);
    await _shoot(t, 'r6_over', '任期の終わり', await _with(botPlayCareer(8, team: teamAtRank(8, 15))), outDir: out);
    final offer = await _controller();
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    final m = Monetization(await SharedPreferences.getInstance(), store: _PricedStore());
    await _shoot(t, 'r7_offer', '広告を消す案内', offer, outDir: out, act: (t) async {
      final ctx = t.element(find.text('GMに就任する'));
      showRemoveAdsOffer(ctx, m);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });
    await _shoot(t, 'r8_howto', '遊び方の画面', await _controller(), outDir: out, act: (t) async {
      await t.scrollUntilVisible(find.text('遊び方'), 200, scrollable: _list);
      await _tap(t, '遊び方');
    });
  });

  // 30チームのロゴの一覧(点検用)。
  testWidgets('ロゴの一覧', (t) async {
    if (_ipad) return;
    await _loadFonts();
    addTearDown(t.view.reset);
    t.view.physicalSize = const Size(402, 1100) * 2;
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: gmTheme(),
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 5,
            padding: const EdgeInsets.all(8),
            childAspectRatio: 0.62,
            children: [
              for (var i = 0; i < teamDefs.length; i++)
                Column(children: [
                  TeamBadge(team: i, size: 64),
                  const SizedBox(height: 4),
                  Text(teamDefs[i].nick, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  TeamBadge(team: i, size: 22),
                ]),
            ],
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(() async {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/review')..createSync(recursive: true);
      File('${dir.path}/logos.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  // 掲載画像ではないので、値段が写っていてよい。iPhone の寸法だけ作る。
  testWidgets('課金アイテムの審査用', (t) async {
    if (_ipad) return;
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
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
          theme: gmTheme(),
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
