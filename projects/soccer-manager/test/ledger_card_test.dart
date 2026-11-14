import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/ledger_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<void> show(WidgetTester tester, GameState gs, {double w = 360}) async {
    tester.view.physicalSize = Size(w, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: gs),
        // 色の出し分けが読む。初期化しなくても既定値で動く。
        ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController()),
      ],
      child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: LedgerCard()))),
    ));
  }

  testWidgets('試合の前は内訳が無く、人件費率と見通しは出る', (tester) async {
    late GameState gs;
    await tester.runAsync(() async {
      gs = GameState();
      await gs.startNewGame('テストFC');
    });
    await show(tester, gs);
    expect(find.textContaining('まだ試合が行われていません'), findsOneWidget);
    expect(find.textContaining('人件費率'), findsOneWidget);
    expect(find.textContaining('資金の見通し'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('節を進めると内訳と損益が出る。狭い画面でも溢れない', (tester) async {
    late GameState gs;
    await tester.runAsync(() async {
      gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
    });
    await show(tester, gs, w: 320);
    expect(find.text('観客収入'), findsOneWidget);
    expect(find.text('選手の給与'), findsOneWidget);
    expect(find.text('今季の損益'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(GameState.persistDebounce);
  });
}
