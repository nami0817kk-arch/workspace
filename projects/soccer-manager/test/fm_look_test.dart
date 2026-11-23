import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/theme/fm_look.dart';
import 'package:soccer_manager/theme/semantic_colors.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';

import 'color_contrast_test.dart' show contrastRatio;

/// 横画面(FM 風)の明るい見た目(案A)と暗い見た目(案B)。
///
/// 2026-11-24 まで、横画面は設定に関係なく暗い見た目に固定されていて、
/// 設定で「ライトモード」を選んでも効かなかった。「画面が暗い」と指摘を
/// 受けて明るい見た目を足し、既定もライトにした。
void main() {
  const app = SoccerManagerApp();

  group('配色の文字と地の差', () {
    for (final palette in [FmPalette.light, FmPalette.dark]) {
      final label = palette.isLight ? '明るい' : '暗い';
      test('$label版の対になる色が 4.5:1 以上', () {
        // MaterialApp と同じく、文字の大きさを埋めたテーマを土台にする。
        final raw = app.buildTheme(palette.brightness, boldText: false);
        final base = ThemeData.localize(raw, raw.typography.englishLike);
        final s = fmLookTheme(base, palette).colorScheme;
        final pairs = <(String, Color, Color)>[
          for (final (n, bg) in [
            ('surface', s.surface),
            ('surfaceContainerLow(箱)', s.surfaceContainerLow),
            ('surfaceContainerHighest(見出しの帯)', s.surfaceContainerHighest),
            ('上の帯', palette.topBar),
            ('左のメニュー', palette.sidebar),
          ]) ...[
            ('onSurface on $n', s.onSurface, bg),
            ('onSurfaceVariant on $n', s.onSurfaceVariant, bg),
          ],
          ('onPrimary on primary(塗りのボタン)', s.onPrimary, s.primary),
          ('primary on 箱(枠つき・文字のボタン)', s.primary, s.surfaceContainerLow),
          ('onSecondaryContainer', s.onSecondaryContainer,
              s.secondaryContainer),
          ('onErrorContainer', s.onErrorContainer, s.errorContainer),
          ('onError on error', s.onError, s.error),
          ('onPrimaryContainer', s.onPrimaryContainer, s.primaryContainer),
          ('onTertiaryContainer', s.onTertiaryContainer, s.tertiaryContainer),
        ];
        final failures = [
          for (final (name, fg, bg) in pairs)
            if (contrastRatio(fg, bg) < 4.5)
              '$name = ${contrastRatio(fg, bg).toStringAsFixed(2)}',
        ];
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }

    test('箱が地からはっきり分かれる(暗い版で箱が地に溶けていた)', () {
      for (final p in [FmPalette.light, FmPalette.dark]) {
        expect(contrastRatio(p.surface, p.surfaceContainerLow),
            greaterThan(1.1),
            reason: '${p.brightness} の地と箱の差が小さすぎる');
      }
    });
  });

  group('横画面の明暗は設定に従う', () {
    Future<ThemeData> themeInside(WidgetTester tester, ThemeMode mode,
        {bool darkOnly = false}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(852, 393);
      addTearDown(tester.view.reset);
      late ThemeData seen;
      Widget probe = Builder(builder: (context) {
        seen = Theme.of(context);
        return const SizedBox();
      });
      if (darkOnly) probe = FmDarkOnly(child: probe);
      await tester.pumpWidget(MaterialApp(
        theme: app.buildTheme(Brightness.light, boldText: false),
        darkTheme: app.buildTheme(Brightness.dark, boldText: false),
        themeMode: mode,
        builder: (context, child) => FmThemeScope(
          light: app.buildTheme(Brightness.light, boldText: false),
          dark: app.buildTheme(Brightness.dark, boldText: false),
          child: child!,
        ),
        home: probe,
      ));
      return seen;
    }

    testWidgets('ライトを選ぶと横画面も明るい配色になる', (tester) async {
      final t = await themeInside(tester, ThemeMode.light);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.surface, FmPalette.light.surface);
      expect(t.extension<FmLook>()?.sidebar, FmPalette.light.sidebar);
    });

    testWidgets('ダークを選ぶと暗い配色(案B)になる', (tester) async {
      final t = await themeInside(tester, ThemeMode.dark);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.surface, FmPalette.dark.surface);
    });

    testWidgets('試合の画面(FmDarkOnly)はライトでも暗いまま', (tester) async {
      final t = await themeInside(tester, ThemeMode.light, darkOnly: true);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.surface, FmPalette.dark.surface);
    });
  });

  test('初めて起動したときの見た目はライト', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.init();
    expect(settings.themeMode, ThemeMode.light);
    expect(SettingsController.defaultThemeMode, ThemeMode.light);
  });

  test('色の付いた文字は、地に合わせて読める濃さに寄せる', () {
    const white = Color(0xFFFFFFFF);
    final darkBox = FmPalette.dark.surfaceContainerLow;
    for (final c in [
      Colors.amber,
      Colors.orange,
      Colors.redAccent,
      Colors.teal,
      Colors.indigo,
      Colors.deepPurple,
    ]) {
      expect(contrastRatio(SemanticColors.readableOn(c, white), white),
          greaterThanOrEqualTo(4.5),
          reason: '$c が白地で読めない');
      expect(contrastRatio(SemanticColors.readableOn(c, darkBox), darkBox),
          greaterThanOrEqualTo(4.5),
          reason: '$c が暗い箱で読めない');
    }
  });
}
