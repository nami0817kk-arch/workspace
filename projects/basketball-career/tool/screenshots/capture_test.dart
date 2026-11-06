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

import 'package:basketball_career/deck/battle.dart';
import 'package:basketball_career/deck/cards.dart';
import 'package:basketball_career/deck/mates.dart';
import 'package:basketball_career/deck/opponents.dart';
import 'package:basketball_career/deck/run.dart';
import 'package:basketball_career/monetization/monetization.dart';
import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/deck/style.dart';
import 'package:basketball_career/ui/deck_controller.dart';
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
      color: DeckColors.bg,
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
                Container(width: _ipad ? 90 : 60, height: 5, color: DeckColors.ball),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(_ipad ? 40 : 14, 0, _ipad ? 40 : 14, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: DeckColors.line, width: 2),
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
  DeckController c, {
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
  // 絵・アイコン(assets の画像)の読み込みを待つ。待たないと空白で撮れる。
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

Future<DeckController> _controller() async =>
    DeckController(prefs: await SharedPreferences.getInstance(), seedSource: Random(7));

CardInstance _c(String id, {bool up = false}) => CardInstance(card(id), upgraded: up);

/// 見栄えのする途中のシーズン(県大会・仲間3人・強くしたカード入り)。
Future<DeckController> _midSeason({int stage = 1, int floor = 3}) async {
  final c = await _controller();
  c.newRun(difficulty: 0);
  final r = c.run!;
  r.stage = stage;
  r.floor = floor;
  r.money = 146;
  r.hearts = 2;
  r.deck
    ..clear()
    ..addAll([
      for (var i = 0; i < 3; i++) _c('jumper'),
      _c('jumper', up: true),
      for (var i = 0; i < 3; i++) _c('defense'),
      _c('pass', up: true),
      _c('three', up: true),
      _c('alleyoop'),
      _c('nolook'),
      _c('block'),
      _c('eurostep', up: true),
      _c('hothand'),
      _c('drive'),
      _c('charge'),
    ]);
  r.mates.addAll([mateById['shooter']!, mateById['center']!, mateById['playmaker']!]);
  return c;
}

/// 試合を、[round] ラウンド目の途中の形にする。
void _setBattle(DeckController c,
    {required int round,
    required int mine,
    required int theirs,
    required Threat intent,
    required List<CardInstance> hand,
    List<String> playFirst = const [],
    Opponent? opponent}) {
  final r = c.run!;
  r.map[r.floor] = [NodeType.game];
  r.opponent = opponent ?? Opponent(name: '星丘工業', style: OppStyle.outside, stage: r.stage);
  r.current = opponent?.boss == true ? NodeType.boss : NodeType.game;
  r.battleSeed = 99;
  r.startBattle();
  final b = r.battle!;
  // 前のラウンドの点(クォーターの表)
  var m = 0, t = 0;
  for (var i = 0; i < round; i++) {
    final dm = i == round - 1 ? mine - m : (mine / round).round();
    final dt = i == round - 1 ? theirs - t : (theirs / round).round();
    b.rounds.add(RoundScore(dm, dt));
    m += dm;
    t += dt;
  }
  b.round = round;
  b.mine = mine;
  b.theirs = theirs;
  b.intent = intent;
  b.drawPile.addAll(b.hand);
  b.hand
    ..clear()
    ..addAll(hand);
  b.stamina = Battle.baseStamina;
  for (final id in playFirst) {
    b.play(b.hand.firstWhere((x) => x.def.id == id));
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

Future<void> _battleShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason();
  _setBattle(c,
      round: 3,
      mine: 24,
      theirs: 22,
      intent: const Threat(IntentKind.three, [9]),
      hand: [_c('pass', up: true), _c('alleyoop'), _c('three', up: true), _c('block'), _c('defense')],
      playFirst: ['pass']);
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _clutchShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason(stage: 2, floor: RunState.floorsPerStage - 1);
  c.run!.mates.add(mateById['closer']!);
  _setBattle(c,
      round: 7,
      mine: 71,
      theirs: 74,
      intent: const Threat(IntentKind.ace, [15]),
      hand: [_c('buzzer'), _c('block', up: true), _c('jumper'), _c('defense'), _c('handsup')],
      opponent: Opponent(name: bossNames[2], style: OppStyle.height, stage: 2, boss: true));
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _mapShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason(floor: 2);
  final r = c.run!;
  r.map = [
    [NodeType.game],
    [NodeType.game, NodeType.event],
    [NodeType.game, NodeType.elite, NodeType.shop],
    [NodeType.event, NodeType.game],
    [NodeType.practice, NodeType.elite, NodeType.game],
    [NodeType.game, NodeType.shop],
    [NodeType.practice, NodeType.shop],
    [NodeType.boss],
  ];
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _rewardShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason();
  final r = c.run!;
  r.phase = Phase.reward;
  r.current = NodeType.game;
  r.lastPrize = 38;
  r.rewardCards = [_c('deepthree'), _c('pickroll'), _c('zone')];
  r.rerolled = false;
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _mateShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason();
  final r = c.run!;
  r.phase = Phase.mateReward;
  r.current = NodeType.elite;
  r.rewardMates = [mateById['ace']!, mateById['stopper']!];
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _shopShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason();
  final r = c.run!;
  r.phase = Phase.shop;
  r.money = 214;
  r.shopItems = [
    ShopItem.card(_c('steal'), 66),
    ShopItem.card(_c('dunk'), 72),
    ShopItem.card(_c('screen'), 44),
    ShopItem.card(_c('floater'), 68),
    ShopItem.card(_c('gamemaker'), 112),
    ShopItem.mate(mateById['iron']!, 120),
  ];
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _championShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _midSeason(stage: 2, floor: RunState.floorsPerStage - 1);
  final r = c.run!;
  r.mates.addAll([mateById['ace']!, mateById['closer']!]);
  r.phase = Phase.finished;
  r.champion = true;
  r.wins = 21;
  r.losses = 2;
  await _shoot(t, name, caption, c, outDir: outDir);
}

Future<void> _collectionShot(WidgetTester t, String name, String caption, {String? outDir}) async {
  final c = await _controller();
  final p = c.profile;
  p.unlocked.addAll(['firstWin', 'stage1', 'stage2', 'champion', 'bigWin', 'fullTeam']);
  p.seenCards.addAll(allCards.map((x) => x.id).where((id) => !['clutch', 'timeout', 'gamemaker'].contains(id)));
  p.seasons = 9;
  await _shoot(t, name, caption, c, outDir: outDir, act: (t) async {
    await t.tap(find.text('カード図鑑'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  });
}

int get _cardKinds => allCards.where((x) => x.rarity != Rarity.status).length;

void main() {
  testWidgets('ストア用スクリーンショット', (t) async {
    SharedPreferences.setMockInitialValues({'deckHowtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    await _battleShot(t, '01_battle', '相手の予告を読んで、\nカードを切る');
    await _clutchShot(t, '02_buzzer', 'ラスト1本は、\nブザービーター');
    await _mapShot(t, '03_map', '行き先を選んで、\n勝ち抜く');
    await _rewardShot(t, '04_reward', '勝つたびに、\nデッキが強くなる');
    await _mateShot(t, '05_mates', '仲間を5人そろえる');
    await _shopShot(t, '06_shop', '部費でプレーを\n買い足す');
    await _championShot(t, '07_champion', 'めざせ、全国制覇');
    await _collectionShot(t, '08_collection', '$_cardKinds種のカードを\n集めよう');
  });

  // 画面の点検用(掲載画像ではない)。build/review/ に書き出す(git には入れない)。
  testWidgets('画面の点検用', (t) async {
    SharedPreferences.setMockInitialValues({'deckHowtoSeen': true});
    await _loadFonts();
    addTearDown(t.view.reset);
    final out = 'build/review/$_device';
    final home = await _controller();
    await _shoot(t, 'r1_home', 'はじめの画面', home, outDir: out);
    final pr = await _midSeason();
    pr.run!.phase = Phase.practice;
    await _shoot(t, 'r2_practice', '練習', pr, outDir: out);
    final ev = await _midSeason();
    ev.run!
      ..phase = Phase.event
      ..event = allEvents[3];
    await _shoot(t, 'r3_event', '出来事', ev, outDir: out);
    final lost = await _midSeason(stage: 1, floor: RunState.floorsPerStage - 1);
    lost.run!
      ..phase = Phase.finished
      ..current = NodeType.boss
      ..opponent = Opponent(name: bossNames[1], style: OppStyle.outside, stage: 1, boss: true);
    await _shoot(t, 'r4_lost', '決勝で負けた', lost, outDir: out);
    final over = await _midSeason();
    _setBattle(over,
        round: 7, mine: 60, theirs: 52, intent: const Threat(IntentKind.shot, [8]), hand: [_c('jumper')]);
    over.run!.battle!.endRound();
    await _shoot(t, 'r5_over', '試合終了', over, outDir: out);
    final offer = await _controller();
    SharedPreferences.setMockInitialValues({'deckHowtoSeen': true});
    final m = Monetization(await SharedPreferences.getInstance(), store: _PricedStore());
    await _shoot(t, 'r6_offer', '広告を消す案内', offer, outDir: out, act: (t) async {
      final ctx = t.element(find.text('新しいシーズン'));
      showRemoveAdsOffer(ctx, m);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });
    await _shoot(t, 'r7_howto', '遊び方の画面', await _controller(), outDir: out, act: (t) async {
      await t.tap(find.text('遊び方'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  // 掲載画像ではないので、値段が写っていてよい。iPhone の寸法だけ作る。
  testWidgets('課金アイテムの審査用', (t) async {
    if (_ipad) return;
    SharedPreferences.setMockInitialValues({'deckHowtoSeen': true});
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
          theme: deckTheme(),
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
