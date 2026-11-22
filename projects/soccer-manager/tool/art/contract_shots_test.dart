/// 契約の画面(移籍・更新・仮契約)を横画面の iPhone で PNG に書き出す。
/// 見た目を確かめるための見本。**CI では回らない。**
///
///     flutter test tool/art/contract_shots_test.dart --dart-define=OUT=<出力先>
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/screens/contract_offer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';

import '../../test/support/app_fonts.dart';

const _out =
    String.fromEnvironment('OUT', defaultValue: 'build/contract_shots');
const _size = Size(852, 393);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final root = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  });

  for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
    testWidgets('contract shots $lang', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = _size * 2;
      tester.view.padding =
          const FakeViewPadding(left: 118, right: 118, bottom: 42);
      tester.view.viewPadding = tester.view.padding;

      SharedPreferences.setMockInitialValues({});
      late final GameState game;
      await tester.runAsync(() async {
        Tr.language = lang;
        game = GameState();
        await game.startNewGame('青嵐FC');
      });
      addTearDown(() => Tr.language = AppLanguage.system);

      final key = GlobalKey();
      final navKey = GlobalKey<NavigatorState>();
      const app = SoccerManagerApp();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<SettingsController>(
              create: (_) => SettingsController()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            navigatorKey: navKey,
            debugShowCheckedModeBanner: false,
            locale: Locale(lang == AppLanguage.english ? 'en' : 'ja'),
            theme: app.buildTheme(Brightness.light, boldText: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => LandscapeScale(
              child: FmThemeScope(
                dark: app.buildTheme(Brightness.dark, boldText: false),
                child: NotchSideInsets(child: child!),
              ),
            ),
            home: const Scaffold(),
          ),
        ),
      ));
      await tester.pump();

      final problems = <String>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (d) => problems.add(d.exceptionAsString());
      addTearDown(() => FlutterError.onError = oldOnError);

      final tag = lang == AppLanguage.english ? 'en' : 'ja';
      Future<void> shoot(String name) async {
        await tester.pump(const Duration(milliseconds: 400));
        final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await b.toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(_out).createSync(recursive: true);
          File('$_out/${tag}_$name.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      Future<void> open(Player p, ContractKind kind, String name,
          {String? from, bool offerOnce = false}) async {
        unawaited(openContractOffer(navKey.currentContext!,
            player: p, kind: kind, fromClubName: from));
        await tester.pump(const Duration(milliseconds: 600));
        await shoot(name);
        if (offerOnce) {
          // 低めに出して、代理人の返事を撮る。
          for (var k = 0; k < 5; k++) {
            await tester.tap(find.byTooltip(Tr.pick('下げる', 'Lower')).first);
            await tester.pump();
          }
          await tester.runAsync(() async {
            await tester
                .tap(find.byKey(const ValueKey('contract-offer-submit')));
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await tester.pump(const Duration(milliseconds: 600));
          await shoot('${name}_reply');
        }
        navKey.currentState!.pop();
        await tester.pump(const Duration(milliseconds: 600));
      }

      final mine = game.userTeam.players
          .reduce((a, b) => a.overall >= b.overall ? a : b);
      await open(mine, ContractKind.renewal, '1_renewal', offerOnce: true);
      final fa = game.save!.freeAgents.first;
      await open(fa, ContractKind.signing, '2_free_agent');
      final other = game.save!.league.teams
          .firstWhere((t) => t.id != game.save!.userTeamId);
      await open(
          other.players.first, ContractKind.preContract, '3_pre_contract',
          from: other.name);

      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
