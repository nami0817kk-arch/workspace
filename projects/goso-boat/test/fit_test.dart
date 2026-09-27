// リリース前の最終チェック（2026-09-27）: 画面が端末に収まるか。
//
// 全120面を、小さい iPhone・大きい iPhone・iPad、日本語・英語、文字の拡大（上限の1.3倍）で描き、
// はみ出し（RenderFlex overflow）や例外が出ないことを確かめる。
// 字は同梱フォントを読み込んで測る（テストの既定の字は幅が実物と違うため）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/app/settings.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/l10n/app_localizations.dart';
import 'package:goso_boat/main.dart';
import 'package:goso_boat/monetization/monetization.dart';
import 'package:goso_boat/ui/game_screen.dart';
import 'package:goso_boat/ui/menu_screens.dart';
import 'package:goso_boat/monetization/purchase_service.dart';
import 'package:goso_boat/ui/records_screen.dart';
import 'package:goso_boat/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末の大きさ（論理ピクセル）と画素密度。
const devices = {
  'iPhone SE（第1世代）': (Size(320, 568), 2.0),
  'iPhone SE（第3世代）': (Size(375, 667), 2.0),
  'iPhone 16 Pro Max': (Size(440, 956), 3.0),
  'iPad': (Size(820, 1180), 2.0),
  // iPad では縦固定が効かない（マルチタスク対応のため）。横向きと、分割画面の細い方も見る
  'iPad 横': (Size(1180, 820), 2.0),
  'iPad 分割': (Size(320, 1180), 2.0),
};

/// ストアが使える状態（値段の出るボタンを描かせるため）。値段は長めの表記も試す。
class _Store extends NoOpPurchaseService {
  _Store(this.price);
  final String price;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => price;
}

List<Level> _levels() {
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Goso')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/GosoSans-Regular.ttf').readAsBytesSync())))
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/GosoRounded-ExtraBold.ttf').readAsBytesSync())));
  await loader.load();
}

void _setDevice(WidgetTester tester, String name, {double textScale = 1.3}) {
  final (size, dpr) = devices[name]!;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
}

void _resetDevice(WidgetTester tester) {
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

/// アプリと同じ土台（言語・字・設定・文字の拡大の上限・幅の上限）で包む。
Widget _wrap(Widget child, Locale locale, GameSettings settings) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(fontFamily: 'Goso', useMaterial3: true),
      builder: (context, c) {
        final mq = MediaQuery.of(context);
        return AppScope(
          settings: settings,
          child: MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: c)),
          ),
        );
      },
      home: child,
    );

Future<(Progress, Monetization, GameSettings)> _deps([Map<String, Object> saved = const {}, PurchaseService? store]) async {
  SharedPreferences.setMockInitialValues({
    for (var w = 1; w <= 8; w++) 'intro.$w': true,
    ...saved,
  });
  final p = await Progress.open(_levels());
  return (p, Monetization(p.prefsForTest, store: store), GameSettings(p.prefsForTest, silent: true));
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('ja'), Locale('en')]) {
    for (final device in devices.keys) {
      testWidgets('全面が収まる: $device・${locale.languageCode}・文字1.3倍', (tester) async {
        _setDevice(tester, device);
        addTearDown(() => _resetDevice(tester));
        final (p, m, st) = await _deps();
        for (final l in p.levels) {
          await tester.pumpWidget(_wrap(GameScreen(key: ValueKey(l.id), level: l, progress: p, money: m), locale, st));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull, reason: '${l.id} で例外（はみ出しなど）');
        }
        // 最後に空の画面にして、残ったタイマーを片付ける
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('メニューの画面が収まる: 最小の iPhone・${locale.languageCode}・文字1.3倍', (tester) async {
      _setDevice(tester, 'iPhone SE（第1世代）');
      addTearDown(() => _resetDevice(tester));
      // 星・今日の1問・実績と、ストアの「広告を消す（値段）」「購入を復元」が出て表示が増える状態にしておく
      final (p, m, st) = await _deps({
        for (final id in ['1-1', '1-2', '1-3', '1-4']) 'stars.$id': 2,
        'stat.escapes': 12345,
        'stat.trips': 99999,
        'ach.firstClear': true,
      }, _Store('Rp 49.000'));
      for (final screen in <Widget>[
        HomeScreen(progress: p, money: m),
        StageSelectScreen(progress: p, money: m),
        SettingsScreen(progress: p, money: m),
        RecordsScreen(progress: p),
      ]) {
        await tester.pumpWidget(_wrap(screen, locale, st));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull, reason: '${screen.runtimeType} で例外（はみ出しなど）');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('広告を消した後のメニューが収まる: 最小の iPhone・${locale.languageCode}・文字1.3倍', (tester) async {
      _setDevice(tester, 'iPhone SE（第1世代）');
      addTearDown(() => _resetDevice(tester));
      final (p, m, st) = await _deps({'adFree': true}, _Store('¥370'));
      for (final screen in <Widget>[HomeScreen(progress: p, money: m), SettingsScreen(progress: p, money: m)]) {
        await tester.pumpWidget(_wrap(screen, locale, st));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull, reason: '${screen.runtimeType} で例外（はみ出しなど）');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('結果の札が収まる: 最小の iPhone・${locale.languageCode}・文字1.3倍', (tester) async {
      _setDevice(tester, 'iPhone SE（第1世代）');
      addTearDown(() => _resetDevice(tester));
      // 広告を消した状態でヒントに従って1-1を解き、札に知らせがたくさん並ぶ状態にする
      final (p, m, st) = await _deps({'adFree': true, 'stat.escapes': 9});
      await tester.pumpWidget(GosoBoatApp(progress: p, money: m, settings: st, locale: locale));
      await tester.pump(const Duration(milliseconds: 300));
      // 小さい画面ではホームがスクロールするので、ボタンを見える所まで送ってから押す
      final start = find.text(locale.languageCode == 'ja' ? 'はじめる' : 'Start');
      await tester.ensureVisible(start);
      await tester.pump();
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text(locale.languageCode == 'ja' ? 'ヒント' : 'Hint'));
        await tester.pump(const Duration(milliseconds: 400));
        final up = find.textContaining(locale.languageCode == 'ja' ? '向こう岸へ' : 'To the far bank');
        await tester.tap(up.evaluate().isNotEmpty ? up.last : find.textContaining(locale.languageCode == 'ja' ? '手前の岸へ' : 'To the near bank').last);
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(locale.languageCode == 'ja' ? '全員護送' : 'All across!'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '結果の札で例外（はみ出しなど）');
      await tester.pump(const Duration(seconds: 3));
    });
  }

  test('日本語と英語の文言がそろっている', () {
    Map<String, Object?> load(String lang) => jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, Object?>;
    final ja = load('ja').keys.where((k) => !k.startsWith('@')).toSet();
    final en = load('en').keys.where((k) => !k.startsWith('@')).toSet();
    expect(ja.difference(en), isEmpty, reason: '英語に無い');
    expect(en.difference(ja), isEmpty, reason: '日本語に無い');
  });
}
