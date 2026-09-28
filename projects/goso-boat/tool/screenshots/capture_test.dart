/// ストア掲載用のスクリーンショットを生成する（soccer-manager の tool/screenshots と同じやり方）。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく生成器だからで、
/// 実行すると marketing/ の画像を書き換える。
///
///     flutter test tool/screenshots/capture_test.dart --update-goldens
///
/// 撮るときの決まり（Apple 2.3.2・2.3.7、STORE_LISTING.md）:
/// - 広告を消していない状態で撮る（ヒントのボタンが「動画でヒント」になっている）
/// - 掲載画像に値段を写さない。値段の写った1枚は、課金アイテムの審査用にだけ別に作る
/// - 読み込み中の丸や、文字の無い白紙を撮らない（サカマネで1枚目が白紙のまま出ていた）
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/achievements.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/app/settings.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/main.dart';
import 'package:goso_boat/monetization/monetization.dart';
import 'package:goso_boat/monetization/purchase_service.dart';
import 'package:goso_boat/ui/game_screen.dart';
import 'package:goso_boat/ui/menu_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store が求める寸法。iPhone 6.9インチ = 1290x2796、iPad 13インチ = 2064x2752。
/// iPad でも動く設定なので、iPad の画像が無いと提出できない。
typedef _Device = ({String dir, Size logical, double ratio});
const _phone = (dir: 'screenshots', logical: Size(430, 932), ratio: 3.0);
const _tablet = (dir: 'screenshots_ipad', logical: Size(1032, 1376), ratio: 2.0);

typedef _Lang = ({String code, String suffix});
const _ja = (code: 'ja', suffix: '');
const _en = (code: 'en', suffix: '_en');

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final goso = FontLoader('Goso');
  for (final f in ['GosoSans-Regular.ttf', 'GosoRounded-ExtraBold.ttf']) {
    goso.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
  }
  await goso.load();
  // アイコンのフォントを読まないと、ボタンの印がすべて豆腐（□）で写る
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!icons.existsSync()) fail('アイコンフォントが見つからない: ${icons.path}（FLUTTER_ROOT を設定して実行する）');
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

List<Level> _levels() {
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

/// 値段を返すストア（課金アイテムの審査用の1枚だけで使う）。
class _PricedStore extends NoOpPurchaseService {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => '¥370';
}

void main() {
  setUpAll(_loadFonts);
  final levels = _levels();
  Level lv(String id) => levels.firstWhere((l) => l.id == id);

  Future<(Progress, Monetization, GameSettings)> deps(WidgetTester tester, Map<String, Object> saved,
      {PurchaseService? store}) async {
    SharedPreferences.setMockInitialValues({
      for (var w = 1; w <= 8; w++) 'intro.$w': true,
      // 実績は取った後にしておく（脱走の札に「実績: 初めての護送」が出ると、失敗の場面がちぐはぐになる）
      for (final a in Achievement.values) 'ach.${a.name}': true,
      ...saved,
    });
    late Progress p;
    await tester.runAsync(() async => p = await Progress.open(levels));
    // 広告を消していない状態（ヒントは「動画でヒント」）。広告そのものは出さない
    final m = Monetization(p.prefsForTest, store: store);
    return (p, m, GameSettings(p.prefsForTest, silent: true));
  }

  /// 撮る。読み込み中や白紙のまま撮らないよう、撮る前に確かめる。
  Future<void> shoot(WidgetTester tester, String path) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: '$path の描画で例外が出ている');
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: '$path が読み込み中のまま');
    expect(find.byType(Text), findsAtLeastNWidgets(3), reason: '$path に文字がほとんど無い');
    expect(find.textContaining(RegExp(r'¥|\$|€')), findsNothing, reason: '$path に値段が写っている（掲載画像に値段は入れない）');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../marketing/$path.png'));
  }

  Future<void> openGame(WidgetTester tester, Progress p, Monetization m, Level l) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).push(PageRouteBuilder(
          pageBuilder: (_, _, _) => GameScreen(level: l, progress: p, money: m),
        ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 面の名前の帯が消えるまで待つ（盤面を隠さないように）。消え始めるのは状態が変わった次のコマから
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  for (final device in [_phone, _tablet]) {
    for (final lang in [_ja, _en]) {
      final dir = '${device.dir}${lang.suffix}';
      final ja = lang.code == 'ja';

      Future<(Progress, Monetization)> app(WidgetTester tester, Map<String, Object> saved) async {
        tester.view.devicePixelRatio = device.ratio;
        tester.view.physicalSize = device.logical * device.ratio;
        addTearDown(tester.view.reset);
        final (p, m, st) = await deps(tester, saved);
        await tester.pumpWidget(GosoBoatApp(progress: p, money: m, settings: st, locale: Locale(lang.code)));
        await tester.pump(const Duration(milliseconds: 300));
        return (p, m);
      }

      // 1枚目: 警官が囚人を乗せて渡っている場面（ほかに無い題材を一目で）
      testWidgets('01 渡っている ($dir)', (tester) async {
        final (p, m) = await app(tester, {for (final l in levels.where((l) => l.world <= 2)) 'stars.${l.id}': 3});
        await openGame(tester, p, m, lv('3-5'));
        await tester.tap(find.bySemanticsLabel(RegExp(ja ? '^警官[0-9]*、手前の岸' : '^Officer[0-9]*, near bank')).first);
        await tester.pump(const Duration(milliseconds: 400));
        // 手前の岸にいる人だけを選ぶ（舟の上の人を押すと降りてしまう）。囚人は「囚人1」のように番号付き
        await tester.tap(find.bySemanticsLabel(RegExp(ja ? '^囚人[0-9]*、手前の岸' : '^Prisoner[0-9]*, near bank')).first);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(ja ? '向こう岸へ' : 'To the far bank'));
        await tester.pump(); // 舟が動き出すコマ
        // 900ms で渡る。途中だと人が舟からずれて写るので、ほぼ着いたところ（人が舟に乗りきった所）で撮る
        await tester.pump(const Duration(milliseconds: 780));
        await shoot(tester, '$dir/01_crossing');
        await finish(tester);
      }, semanticsEnabled: true);

      // 2枚目: 見張りが足りず脱走された場面
      testWidgets('02 脱走 ($dir)', (tester) async {
        final (p, m) = await app(tester, {'stars.1-1': 1});
        await openGame(tester, p, m, lv('1-1'));
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.bySemanticsLabel(RegExp(ja ? '^警官[0-9]*、手前の岸' : '^Officer[0-9]*, near bank')).first);
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.tap(find.text(ja ? '向こう岸へ' : 'To the far bank'));
        await tester.pump(const Duration(seconds: 4));
        expect(find.text(ja ? '脱走された' : 'They escaped!'), findsOneWidget);
        await shoot(tester, '$dir/02_escape');
        await finish(tester);
      }, semanticsEnabled: true);

      // 3枚目: 川の中州のある面（ほかの川渡りアプリに無い仕掛け）
      testWidgets('03 中州 ($dir)', (tester) async {
        final (p, m) = await app(tester, {for (final l in levels.where((l) => l.world <= 5)) 'stars.${l.id}': 3});
        await openGame(tester, p, m, lv('6-5'));
        await shoot(tester, '$dir/03_island');
        await finish(tester);
      });

      // 4枚目: 看守長・警察犬・ボスがそろう総力戦
      testWidgets('04 役がそろう ($dir)', (tester) async {
        final (p, m) = await app(tester, {for (final l in levels.where((l) => l.world <= 6)) 'stars.${l.id}': 3});
        await openGame(tester, p, m, lv('7-5'));
        await shoot(tester, '$dir/04_roles');
        await finish(tester);
      });

      // 5枚目: 全120面の面選び（星が並んだ、遊び込んだ状態）
      testWidgets('05 面選び ($dir)', (tester) async {
        final (p, m) = await app(tester, {
          for (final l in levels.where((l) => l.world <= 3)) 'stars.${l.id}': l.id.hashCode % 3 + 1,
          for (final l in levels.where((l) => l.world == 4).take(6)) 'stars.${l.id}': 2,
        });
        tester.state<NavigatorState>(find.byType(Navigator).first).push(PageRouteBuilder(
              pageBuilder: (_, _, _) => StageSelectScreen(progress: p, money: m),
            ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        // 遊びかけの面まで自動で送られるので、先頭（舞台1）に戻してから撮る
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 100));
        await shoot(tester, '$dir/05_stages');
        await finish(tester);
      });
    }
  }

  // 課金アイテムの審査用（App Store Connect の「審査に関する情報」）。値段のボタンが写ったホーム画面。
  // 掲載画像ではないので、値段が写っていてよい。
  testWidgets('課金アイテムの審査用', (tester) async {
    tester.view.devicePixelRatio = _phone.ratio;
    tester.view.physicalSize = _phone.logical * _phone.ratio;
    addTearDown(tester.view.reset);
    final (p, m, st) = await deps(tester, {'stars.1-1': 3, 'stars.1-2': 2}, store: _PricedStore());
    await tester.pumpWidget(GosoBoatApp(progress: p, money: m, settings: st, locale: const Locale('ja')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 400));
    final buy = find.text('広告を消す（¥370）');
    expect(buy, findsOneWidget, reason: '値段のボタンが出ていない');
    await tester.ensureVisible(buy);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../marketing/iap_review/remove_ads.png'));
    await finish(tester);
  });
}
