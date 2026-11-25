/// ストア掲載用のスクリーンショットを生成する（goso-boat の tool/screenshots を写した形）。
///
/// **CI では回らない。** 生成器なので test/ の外に置いてある。実行すると marketing/ の画像を書き換える。
///
///     flutter test tool/screenshots/capture_test.dart --update-goldens
///
/// 決まり（docs/app-pitfalls.md の4、ios-app-release スキルの E）:
/// - 必須の寸法: iPhone 中型 1206x2622（402x874 の3倍）、iPad 13インチ 2064x2752（1032x1376 の2倍）
/// - 掲載画像に値段を写さない（値段の写った1枚は課金アイテムの審査用にだけ別に作る）
/// - 読み込み中の丸や、文字の無い白紙を撮らない。タイトル画面は撮らない
/// - 書体: 端末では iOS の明朝（ヒラギノ明朝）。ここでは Windows に入っている Noto Serif JP（OFL）で描く
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/endings_catalog.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/play_views.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/monetization/monetization.dart';
import 'package:ranse/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phone = (dir: 'screenshots_iphone', logical: Size(402, 874), ratio: 3.0);
const _tablet = (dir: 'screenshots_ipad', logical: Size(1032, 1376), ratio: 2.0);

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File(
    Platform.environment['RANSE_SHOT_FONT'] ?? r'C:\Windows\Fonts\NotoSerifJP-VF.ttf',
  );
  if (!font.existsSync()) fail('明朝の書体が見つからない: ${font.path}（RANSE_SHOT_FONT で渡す）');
  final bytes = ByteData.sublistView(font.readAsBytesSync());
  // テストの既定の書体（Roboto）と、テーマの明朝の並びの名前の両方に当てる
  for (final family in ['Roboto', 'Noto Serif JP', 'Hiragino Mincho ProN']) {
    await (FontLoader(family)..addFont(Future.value(bytes))).load();
  }
  // 端末では記号（✦ など）を iOS が別の書体で補う。ここでは Windows の記号の書体を明朝の並びの最後（serif）に当てる
  final sym = File(r'C:\Windows\Fonts\seguisym.ttf');
  if (sym.existsSync()) {
    await (FontLoader('serif')..addFont(Future.value(ByteData.sublistView(sym.readAsBytesSync())))).load();
  }
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!icons.existsSync()) fail('アイコンの書体が見つからない: ${icons.path}（FLUTTER_ROOT を設定して実行する）');
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

/// 図鑑に、遊び込んだ人の見た最期を入れておく（希少度が混ざるように）。
Map<String, Object> _dexSeed() {
  final picked = <EndingDef>[];
  final byTier = <Tier, int>{};
  const want = {Tier.common: 150, Tier.uncommon: 70, Tier.rare: 24, Tier.phantom: 5};
  for (var i = 0; i < kHandEndings.length; i++) {
    final d = kHandEndings[(i * 37) % kHandEndings.length];
    final n = byTier[d.tier] ?? 0;
    if (n >= (want[d.tier] ?? 0) || picked.contains(d)) continue;
    byTier[d.tier] = n + 1;
    picked.add(d);
  }
  return {
    'ranse.dex.v1': jsonEncode({
      for (final d in picked)
        'hand:${d.id}': {
          'k': 'hand:${d.id}',
          't': d.title,
          'x': d.text,
          'w': d.way,
          'd': (d.kinds?.isNotEmpty ?? false) ? d.kinds!.first : 'tenju',
          'n': const ['尾張の太郎', '近江のお梅', '甲斐の与助', '越後のお菊', '堺の宗兵衛'][d.id.length % 5],
          'a': d.way == 'young' ? 3 + d.id.length % 10 : 28 + d.id.length * 3 % 40,
          'y': 1550 + d.id.length * 7 % 60,
          'c': 1,
        },
    }),
  };
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

  Future<AppController> app(
    WidgetTester tester,
    ({String dir, Size logical, double ratio}) device,
    AppController Function() make, {
    Map<String, Object> saved = const {},
  }) async {
    tester.view.devicePixelRatio = device.ratio;
    tester.view.physicalSize = device.logical * device.ratio;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'ranse.guide_seen.v1': true,
      'ranse.livesStarted': 30,
      ..._dexSeed(),
      ...saved,
    });
    late AppController c;
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      c = make()..money = Monetization(prefs);
    });
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  /// 画面にある絵を読み込んでから撮る（読み込みの前に撮ると絵が空になる）。
  Future<void> shoot(WidgetTester tester, String path, {bool priceOk = false}) async {
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: '$path の描画で例外が出ている');
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: '$path が読み込み中のまま');
    expect(find.byType(Text), findsAtLeastNWidgets(3), reason: '$path に文字がほとんど無い');
    if (!priceOk) {
      expect(find.textContaining(RegExp(r'¥|\$|€')), findsNothing, reason: '$path に値段が写っている');
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../marketing/$path.png'));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  /// 条件に合う人生の場面が出るまで、種を変えて流す。
  AppController seek(bool Function(Game g) stopWhen, {bool Function(Game g)? keep, int from = 1}) {
    for (var s = from; s < from + 4000; s++) {
      final c = AppController(rng: Rng(s));
      c.birth = rollBirth(Rng(s * 7 + 1));
      c.begin();
      final g = c.game;
      final pick = Rng(s * 13 + 5);
      var n = 0;
      while (!g.finished && n++ < 4000) {
        if (stopWhen(g)) return c;
        final p = g.prompt!;
        g.choose(pick.range(0, p.choices.length - 1));
      }
      if (g.finished && (keep?.call(g) ?? false)) return c;
    }
    fail('撮る場面が見つからなかった');
  }

  for (final device in [_phone, _tablet]) {
    final dir = device.dir;

    // 1枚目: 籤で決まった生まれ（稀な生まれ。身分・国・稀少度・特性が一目で）
    testWidgets('01 生まれ ($dir)', (tester) async {
      await app(tester, device, () {
        for (var s = 1; s < 5000; s++) {
          final b = rollBirth(Rng(s));
          if (b.cls.id == 'daimyo' || !isSpecialBirth(b)) continue;
          if (b.traits.length < 2) continue;
          final c = AppController(rng: Rng(s));
          c.birth = b;
          c.screen = AppScreen.birth;
          return c;
        }
        fail('稀な生まれが見つからなかった');
      });
      await shoot(tester, '$dir/01_birth');
      await finish(tester);
    });

    // 2枚目: 史実の大きな分かれ道（本能寺などの絵つき）
    testWidgets('02 史実の岐路 ($dir)', (tester) async {
      await app(tester, device, () => seek((g) {
            final p = g.prompt;
            return p != null && (p.art ?? '').contains('event_') && p.choices.length >= 3 && !g.isChild;
          }));
      await shoot(tester, '$dir/02_history');
      await finish(tester);
    });

    // 3枚目: 戦の場面（能力・特性で増えた手の札が見える）
    testWidgets('03 合戦 ($dir)', (tester) async {
      await app(tester, device, () => seek((g) {
            final p = g.prompt;
            return p != null &&
                (p.art ?? '').contains('battle') &&
                !(p.art ?? '').contains('event') &&
                p.choices.length >= 3 &&
                !g.isChild;
          }, from: 300));
      await shoot(tester, '$dir/03_battle');
      await finish(tester);
    });

    // 4枚目: 一生の終わり（結果カード・称号・最期の文）
    testWidgets('04 最期 ($dir)', (tester) async {
      await app(tester, device, () => seek((_) => false, keep: (g) {
            if (g.age < 45 || g.l.maxRank < 5) return false;
            return buildEnding(g).key.startsWith('hand:');
          }, from: 900));
      await shoot(tester, '$dir/04_ending');
      await finish(tester);
    });

    // 5枚目: 最期の図鑑（集める目当て）
    testWidgets('05 図鑑 ($dir)', (tester) async {
      final c = await app(tester, device, () => AppController(rng: Rng(1)));
      await tester.runAsync(() => c.openDex());
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, '$dir/05_dex');
      await finish(tester);
    });
  }

  // 課金アイテムの審査用（App Store Connect の「審査に関する情報」）。「広告を消す」の釦が写ったタイトル。
  testWidgets('課金アイテムの審査用', (tester) async {
    final c = await app(tester, _phone, () => AppController(rng: Rng(1)));
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      c.money = Monetization(prefs, store: _PricedStore());
    });
    c.toTitle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    final buy = find.text('広告を消す');
    expect(buy, findsOneWidget, reason: '広告を消す の釦が出ていない');
    await tester.ensureVisible(buy);
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'iap_review/remove_ads', priceOk: true);
    await finish(tester);
  });
}
