import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';

import 'support/app_fonts.dart';

/// 英語は日本語よりラベルが横に長くなるため、日本語では収まっていたUIが
/// 英語でだけ枠からはみ出すことがある。リリースビルドではオーバーフローの
/// 縞模様も例外も出ないので目視でも気づきにくい。デバッグビルドのテストなら
/// RenderFlexのオーバーフローが例外として上がるので、英語表示のまま
/// 主要画面を狭いスマートフォン幅で描画して回帰を検出する。
void main() {
  // 代替フォントは全文字が同じ幅で、英語だけおよそ2倍に太る。
  // 実機の幅で測るために同梱フォントを読み込む。
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.english;
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.localeTestValue = const Locale('en');
    dispatcher.localesTestValue = const [Locale('en')];
  });

  tearDown(() {
    Tr.language = AppLanguage.system;
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
  });

  /// 小さめのスマートフォン幅。ここで収まればより広い画面でも収まる。
  void useNarrowPhone(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 780);
  }

  /// タイトル画面からクラブを創設してホーム画面まで進む。
  Future<void> createClub(WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test FC');
    await tester.tap(find.text('Found the club'));
    await tester.pumpAndSettle();
  }

  testWidgets('start screen fits within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('New game'), findsWidgets);
  });

  testWidgets('the new club dialog fits within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game').first);
    await tester.pumpAndSettle();

    expect(find.text('Found the club'), findsOneWidget);
  });

  testWidgets('the main tabs fit within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);
    await createClub(tester);

    // ボトムナビの各タブを開く。オーバーフローがあればpumpの時点で
    // 例外になり、このテストが落ちる。
    for (final tab in const ['Team', 'Signings', 'Finance', 'League', 'Status']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    expect(find.text('Test FC'), findsWidgets);
  });

  testWidgets('the league lines in the new game dialog fit a narrow phone',
      (WidgetTester tester) async {
    // 5枚の説明はやめた(2026-11-25)。代わりに、新しく始めるの各リーグに
    // 予算・登録・難しさの1行が付いた。狭い幅の英語ではみ出さないか。
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Budget '), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
