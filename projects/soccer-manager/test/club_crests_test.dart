import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/club_crests.dart';
import 'package:soccer_manager/data/club_names.dart';
import 'package:soccer_manager/data/crest_hues.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/club_look.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/theme/club_palette.dart';
import 'package:soccer_manager/widgets/club_emblem.dart';

/// 画像生成で作ったクラブのエンブレム(2026-11-25)。
void main() {
  tearDown(() {
    Tr.language = AppLanguage.system;
    ClubLookRegistry.teamId = null;
    ClubLookRegistry.look = null;
  });

  group('表と素材', () {
    test('表のクラブ300件すべてが、日本語・英語のどちらからでも番号を引ける', () {
      expect(ClubNames.crestCount, 300);
      expect(kCrestCount, ClubNames.crestCount,
          reason: '色の表(crest_hues.dart)と名前の表の件数が違う');
      expect(kCrestHues.length, kCrestCount * 2);
      for (var i = 0; i < ClubNames.crestCount; i++) {
        final (ja, en) = ClubNames.crestNames(i);
        expect(ClubNames.crestIndexOf(ja), i, reason: ja);
        expect(ClubNames.crestIndexOf(en), i, reason: en);
        // 前後の空白は保存の仕方で付くことがある。
        expect(ClubNames.crestIndexOf(' $en '), i);
      }
      expect(ClubNames.crestIndexOf('どこにもないクラブ'), isNull);
    });

    test('番号の並びは、国・部ごとの名前の並びと同じ(画像の番号とずれない)', () {
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        final ordered = [
          for (final theme in LeagueTheme.values) ...ClubNames.all(theme),
        ];
        expect(ordered.length, ClubNames.crestCount);
        for (var i = 0; i < ordered.length; i++) {
          expect(ClubNames.crestIndexOf(ordered[i]), i, reason: ordered[i]);
        }
      }
    });

    test('300枚の画像がすべてあり、pubspec の assets に載っている', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/crests/'));
      for (var i = 0; i < ClubNames.crestCount; i++) {
        final path = ClubCrests.assetPath(i);
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: path);
        expect(f.lengthSync(), greaterThan(500), reason: '$path が小さすぎる');
      }
      // 余分な画像が残っていない(番号がずれた古い書き出しなど)。
      final files = Directory('assets/crests')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.webp'))
          .where((f) => !f.uri.pathSegments.last.startsWith('own_'))
          .length;
      expect(files, ClubNames.crestCount);
    });

    test('書き換えた名前のクラブ・見た目を決めた自クラブは表の画像を使わない', () {
      final (ja, en) = ClubNames.crestNames(5);
      expect(ClubCrests.indexFor('cpu1', ja), 5);
      expect(ClubCrests.indexFor('cpu1', en), 5);
      expect(ClubCrests.indexFor('cpu1', 'わたしの好きな名前'), isNull);
      ClubLookRegistry.teamId = 'user';
      // 見た目を決めていない自クラブ(表のクラブを買い直した直後)は元の画像。
      expect(ClubCrests.indexFor('user', ja), 5);
      ClubLookRegistry.look = const ClubLook(
          hue: 0, accentHue: 0, shape: 0, motif: 0, initial: 'A', crest: 3);
      expect(ClubCrests.indexFor('user', ja), isNull,
          reason: '自クラブはオーナーが見た目を決める');
      expect(ClubCrests.indexFor('cpu1', ja), 5);
    });

    test('新しく始めたとき、自クラブ以外のクラブはすべて画像を持つ', () async {
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        SharedPreferences.setMockInitialValues({});
        Tr.language = lang;
        final gs = GameState();
        await gs.startNewGame('自分FC');
        final s = gs.save!;
        final teams = [
          ...s.allTeams,
          for (final l in s.foreignLeagues.values) ...l.teams,
        ];
        expect(teams.length, greaterThan(100));
        for (final t in teams) {
          if (t.id == s.userTeamId) {
            expect(ClubCrests.indexFor(t.id, t.name), isNull);
            continue;
          }
          expect(ClubCrests.indexFor(t.id, t.name), isNotNull,
              reason: '${t.id} ${t.name} ($lang)');
        }
      }
    });
  });

  group('色', () {
    test('画像のあるクラブの色は、その画像の2色から決まる', () {
      for (var i = 0; i < ClubNames.crestCount; i++) {
        final (a, b) = ClubCrests.hues(i);
        final (ja, _) = ClubNames.crestNames(i);
        final p = ClubPalette.of('cpu$i', clubName: ja);
        final chromatic = [a, b].where((h) => h >= 0).toList();
        expect(chromatic, isNotEmpty, reason: '$i の色が両方とも白黒灰');
        expect(p.hue, chromatic.first.toDouble(), reason: ja);
        expect(p.accentHue, (b >= 0 ? b : chromatic.first).toDouble(),
            reason: ja);
        // 名前で引いても id で引いても同じ(エンブレムとユニフォームで揃う)。
        final (_, en) = ClubNames.crestNames(i);
        expect(ClubPalette.of('other', clubName: en).hue, p.hue);
      }
    });

    test('名前に色の語があるクラブは、画像の色もその色(名前と食い違わない)', () {
      var checked = 0;
      for (var i = 0; i < ClubNames.crestCount; i++) {
        final (ja, en) = ClubNames.crestNames(i);
        final (a, b) = ClubCrests.hues(i);
        for (final name in [ja, en]) {
          final named = ClubPalette.hueForName(name);
          if (named == null) continue;
          checked++;
          final near = [a, b].any(
              (h) => h >= 0 && ClubPalette.hueDistance(h.toDouble(), named) < 30);
          expect(near, isTrue, reason: '$name: 名前の色 $named / 画像 $a,$b');
        }
      }
      expect(checked, greaterThan(0));
    });

    test('自クラブの色は、決めた見た目(画像ならその絵の色)から', () {
      final (ja, _) = ClubNames.crestNames(0);
      ClubLookRegistry.teamId = 'user';
      // 決めていなければ、出ている表の画像の色。
      expect(ClubPalette.of('user', clubName: ja).hue,
          ClubPalette.fromCrest(0).hue);
      // 表に無い名前なら、クラブで決まる自クラブ用の画像の色。
      final own = ClubLook.defaultCrestFor('user', '自分FC');
      expect(ClubPalette.of('user', clubName: '自分FC').hue,
          ClubLook.crestHues(own).$1);
      ClubLookRegistry.look = const ClubLook(
          hue: 225, accentHue: 52, shape: 0, motif: 0, initial: 'A');
      expect(ClubPalette.of('user', clubName: ja).hue, 225);
      // 番号0は名前に色の語が無いので、他のクラブの id から決まる色は従来どおり。
      expect(ClubPalette.hueForName(ja), isNull);
      expect(ClubPalette.of('x', clubName: 'わたしの好きな名前').hue,
          Random('x'.hashCode).nextDouble() * 360);
    });
  });

  group('描画', () {
    setUp(() => Tr.language = AppLanguage.japanese);
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Center(child: child))),
        );
    Finder semanticsLabeled(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label);

    testWidgets('表にある名前なら画像を出す', (tester) async {
      final (ja, _) = ClubNames.crestNames(42);
      await pump(tester, ClubEmblem(teamId: 'cpu3', teamName: ja, size: 48));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/crests/042.webp');
      expect(image.filterQuality, FilterQuality.medium);
      expect(tester.getSize(find.byType(ClubEmblem)), const Size(48, 48));
      expect(semanticsLabeled('$jaのエンブレム'), findsOneWidget);
    });

    testWidgets('表に無い名前(自クラブ以外)は今までどおり描く', (tester) async {
      await pump(tester,
          const ClubEmblem(teamId: 'cpu3', teamName: 'わたしの好きな名前', size: 40));
      expect(find.byType(Image), findsNothing);
      expect(
          find.descendant(
              of: find.byType(ClubEmblem), matching: find.byType(CustomPaint)),
          findsWidgets);
      expect(semanticsLabeled('わたしの好きな名前のエンブレム'), findsOneWidget);

      // 自クラブでも、描いたエンブレムを選んでいれば描く。
      final (ja, _) = ClubNames.crestNames(0);
      ClubLookRegistry.teamId = 'user';
      ClubLookRegistry.look = const ClubLook(
          hue: 225, accentHue: 52, shape: 0, motif: 0, initial: 'A');
      await pump(tester, ClubEmblem(teamId: 'user', teamName: ja, size: 40));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('見た目を試しに描くときは画像を出さない', (tester) async {
      final (ja, _) = ClubNames.crestNames(0);
      await pump(
        tester,
        ClubEmblem(
          teamId: 'cpu1',
          teamName: ja,
          look: const ClubLook(
              hue: 0, accentHue: 40, shape: 1, motif: 2, initial: 'Z'),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });
  });
}
