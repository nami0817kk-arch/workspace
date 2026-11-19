import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/screens/finance_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/auto_columns.dart';
import 'package:soccer_manager/widgets/squad_table.dart';
import 'package:soccer_manager/widgets/table_sort.dart';

import 'support/stub_purchase_service.dart';

/// 使いやすさ(表の並べ替え・広い画面の2列)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  test('並べ替え: 数字は大きい順から、名前は小さい順から。向きを変えられる', () async {
    final gs = GameState();
    await gs.startNewGame('表FC');
    final ps = gs.userTeam.players;
    final byOvr = TableSort.sort(ps, 'ovr', false);
    for (var i = 1; i < byOvr.length; i++) {
      expect(byOvr[i - 1].overall, greaterThanOrEqualTo(byOvr[i].overall));
    }
    final byAgeUp = TableSort.sort(ps, 'age', true);
    expect(byAgeUp.first.age, lessThanOrEqualTo(byAgeUp.last.age));
    expect(TableSort.startsAscending('name'), isTrue);
    expect(TableSort.startsAscending('ovr'), isFalse);
    expect(identical(TableSort.sort(ps, null, true), ps), isTrue,
        reason: '並べ替えていなければ、渡された順のまま');
  });

  testWidgets('スカッドの表の見出しを押すと並び替わる', (tester) async {
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('表FC');
    });
    Tr.language = AppLanguage.japanese;
    final ps = game.userTeam.players;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 2000,
          child: SquadTable(players: ps, startingIds: const {}, onTap: (_) {}),
        ),
      ),
    ));
    await tester.tap(find.text('総合'));
    await tester.pump();
    expect(find.text('総合v'), findsOneWidget, reason: '大きい順の印');
    await tester.tap(find.text('総合v'));
    await tester.pump();
    expect(find.text('総合^'), findsOneWidget, reason: 'もう一度で逆');
  });

  test('2列に分ける位置は、間隔の後・見出しの前', () {
    final children = <Widget>[
      const Card(),
      const SizedBox(height: 8),
      const Card(),
      const Text('見出し'),
      const Card(),
      const SizedBox(height: 8),
      const Card(),
    ];
    final i = AutoColumns.splitIndex(children);
    // 見出しはその下のカードと一緒に右の列へ行く(左の列の最後が見出しで
    // 終わらない)。間隔からは始めない。
    expect(children[i - 1] is Text, isFalse);
    expect(children[i] is SizedBox, isFalse);
  });

  testWidgets('資金の画面は、広い画面(2列)でもどのタブも例外なく描ける', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    late final MonetizationController money;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      money = MonetizationController(purchases: StubPurchaseService());
      await money.initialize();
      game = GameState();
      await game.startNewGame('広いFC');
    });
    Tr.language = AppLanguage.japanese;
    tester.view.physicalSize = const Size(2732, 2048); // iPad の横向き
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(value: money),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FinanceScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final t in ['収支・契約', '資金・取引', '投資・規則', '記録']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tのタブ');
    }
    await tester.pump(GameState.persistDebounce);
  });
}
