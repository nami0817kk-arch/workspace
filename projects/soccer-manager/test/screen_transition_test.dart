import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/screens/training_screen.dart';

/// 画面遷移の品質を固定するテスト。
///
/// 遷移はすべて命令的な Navigator.push で、連打を止める明示的な仕組みは
/// 入っていない。同じ画面が2枚積まれると、戻るボタンを2回押さないと元に
/// 戻れず、利用者からは「戻れない」としか見えないため原因に辿り着きにくい。
///
/// 現状は Material の遷移のおかげで二重に積まれない(実測で確認)。この
/// テストはその挙動を固定するためのもの。タイルの押下処理を作り変えたときに
/// 壊れていないかを見る。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  /// タイトル画面からクラブを創設してホーム画面まで進む。
  Future<void> createClub(WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New club').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test FC');
    await tester.tap(find.text('Found the club'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a quick-access tile twice opens only one screen',
      (WidgetTester tester) async {
    await createClub(tester);

    // ホームのクラブ運営タイルまでスクロールする。scrollUntilVisible は
    // 見つかるまで繰り返し評価するので、.last のような空集合で例外になる
    // ファインダは渡せない。
    final tile = find.text('Training');
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // 連打。1回目の遷移が始まる前に2回目が入る状況を作る。
    await tester.tap(tile.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(tile.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      find.byType(TrainingScreen),
      findsOneWidget,
      reason: '同じ画面が複数積まれている。連打で二重にpushされている。',
    );
  });
}
