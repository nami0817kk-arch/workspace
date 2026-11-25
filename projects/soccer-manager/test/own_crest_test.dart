import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/club_crests.dart';
import 'package:soccer_manager/data/club_names.dart';
import 'package:soccer_manager/data/own_crest_hues.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/club_look.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/theme/club_palette.dart';
import 'package:soccer_manager/widgets/club_emblem.dart';
import 'package:soccer_manager/widgets/club_look_card.dart';

/// 自クラブのエンブレムを、画像生成で作った25枚から選ぶ(2026-11-25)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Tr.language = AppLanguage.system;
    ClubLookRegistry.teamId = null;
    ClubLookRegistry.look = null;
  });

  group('素材', () {
    test('25枚がすべてあり、pubspec の assets に載っている', () {
      expect(ClubLook.crestCount, 25);
      expect(kOwnCrestHues.length, ClubLook.crestCount * 2);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/crests/'));
      for (var i = 0; i < ClubLook.crestCount; i++) {
        final path = ClubCrests.ownAssetPath(i);
        expect(path, 'assets/crests/own_${i.toString().padLeft(2, '0')}.webp');
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: path);
        expect(f.lengthSync(), greaterThan(500), reason: '$path が小さすぎる');
      }
      expect(File(ClubCrests.ownAssetPath(25)).existsSync(), isFalse,
          reason: '表より多い画像が残っている');
      // 名前は日英とも25個。
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        expect(ClubLook.crestNames.length, ClubLook.crestCount);
        expect(ClubLook.crestNames.toSet().length, ClubLook.crestCount);
      }
    });

    test('どの画像も色を持つ(白黒だけの絵はクラブ色が決まらない)', () {
      for (var i = 0; i < ClubLook.crestCount; i++) {
        final (h, a) = ClubLook.crestHues(i);
        expect(h, inInclusiveRange(0, 359), reason: '$i');
        expect(a, inInclusiveRange(0, 359), reason: '$i');
      }
    });

    test('最初に付ける1枚は、同じクラブならいつも同じで、クラブごとに散る', () {
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        final c = ClubLook.defaultCrestFor('user', 'クラブ$i');
        expect(c, inInclusiveRange(0, ClubLook.crestCount - 1));
        expect(ClubLook.defaultCrestFor('user', 'クラブ$i'), c);
        seen.add(c);
      }
      expect(seen.length, greaterThan(15));
    });
  });

  group('保存', () {
    test('画像の番号を保存して読み直せる。2回読んでも変わらない', () {
      const look = ClubLook(
          hue: 1, accentHue: 2, shape: 3, motif: 4, initial: 'K', crest: 7);
      final once = ClubLook.fromJson(look.toJson());
      expect(once.crest, 7);
      expect(once.sameAs(look), isTrue);
      final twice = ClubLook.fromJson(
          jsonDecode(jsonEncode(once.toJson())) as Map<String, dynamic>);
      expect(twice.sameAs(look), isTrue);
    });

    test('画像の番号を持たない古い見た目は、描いたエンブレムのまま読める', () {
      final old = {
        'hue': 225.0,
        'accentHue': 52.0,
        'shape': 2,
        'motif': 3,
        'initial': 'MF',
      };
      final look = ClubLook.fromJson(old);
      expect(look.crest, isNull);
      expect(look.toJson().containsKey('crest'), isFalse);
      expect(ClubLook.fromJson(look.toJson()).sameAs(look), isTrue);
      // 範囲の外の番号も描いたエンブレムに戻す。
      expect(ClubLook.fromJson({...old, 'crest': 99}).crest, isNull);
      expect(ClubLook.fromJson({...old, 'crest': -1}).crest, isNull);
    });

    test('画像を選ぶと色はその絵の色、描いたエンブレムに戻すと形・頭文字が残る', () {
      const drawn = ClubLook(
          hue: 225, accentHue: 52, shape: 2, motif: 3, initial: 'MF');
      final pic = drawn.withCrest(1);
      expect(pic.crest, 1);
      expect((pic.hue, pic.accentHue), ClubLook.crestHues(1));
      expect(pic.copyWith(initial: 'Z').crest, 1, reason: 'copyWith は画像を外さない');
      final back = pic.withoutCrest();
      expect(back.crest, isNull);
      expect((back.shape, back.motif, back.initial), (2, 3, 'MF'));
    });
  });

  group('自クラブ', () {
    test('新しく始めると、25枚の1つが付き、エンブレムとユニフォームの色がそろう',
        () async {
      final gs = GameState();
      await gs.startNewGame('画像FC');
      final s = gs.save!;
      final look = s.clubLook;
      expect(look, isNotNull);
      expect(look!.crest, ClubLook.defaultCrestFor(s.userTeamId, '画像FC'));
      expect(ClubLookRegistry.lookFor(s.userTeamId)?.crest, look.crest);
      final (h, a) = ClubLook.crestHues(look.crest!);
      final p = ClubPalette.of(s.userTeamId, clubName: s.clubName);
      expect(p.hue, h);
      expect(p.accentHue, a);
      // 最初に付けた分は「変えた」に数えない。
      expect(s.clubLookChangedSeason, 0);
      expect(gs.canChangeClubLook, isTrue);
      // セーブを2回通しても同じ。
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(SaveGame.fromJson(s.toJson()).toJson()))
              as Map<String, dynamic>);
      expect(back.clubLook!.sameAs(look), isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('見た目を決めていない古いセーブは、開いたときに1つ付ける。決めた見た目は残す',
        () async {
      final gs = GameState();
      await gs.startNewGame('古いFC');
      final json = gs.save!.toJson()..remove('clubLook');
      expect(await gs.importSaveJson(jsonEncode(json)), isTrue);
      final look = gs.save!.clubLook;
      expect(look?.crest, ClubLook.defaultCrestFor('user', '古いFC'));
      expect(gs.save!.clubLookChangedSeason, 0);
      // 開き直しても同じ1枚。
      expect(await gs.importSaveJson(jsonEncode(gs.save!.toJson())), isTrue);
      expect(gs.save!.clubLook!.sameAs(look!), isTrue);

      // 描いたエンブレムを決めていた人は、そのまま。
      final drawn = {
        ...gs.save!.toJson(),
        'clubLook': {
          'hue': 225.0,
          'accentHue': 52.0,
          'shape': 2,
          'motif': 3,
          'initial': 'MF',
        },
      };
      expect(await gs.importSaveJson(jsonEncode(drawn)), isTrue);
      expect(gs.save!.clubLook!.crest, isNull);
      expect(gs.save!.clubLook!.initial, 'MF');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('オフシーズン以外は画像を選べない', () async {
      final gs = GameState();
      await gs.startNewGame('時期FC');
      final first = gs.currentClubLook;
      final other = (first.crest! + 1) % ClubLook.crestCount;
      expect(await gs.setClubLook(first.withCrest(other)), isTrue,
          reason: '最初の開幕前は選べる');
      expect(gs.save!.clubLook!.crest, other);
      await gs.playNextMatchdayQuickSim();
      expect(gs.isOffseason, isFalse);
      expect(gs.canChangeClubLook, isFalse);
      expect(await gs.setClubLook(first.withCrest(first.crest!)), isFalse);
      expect(gs.save!.clubLook!.crest, other);
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  group('画面', () {
    setUp(() => Tr.language = AppLanguage.japanese);

    testWidgets('自クラブは画像のエンブレムを出す', (tester) async {
      ClubLookRegistry.teamId = 'user';
      // 決めていない・表に無い名前: クラブで決まる1枚。
      await tester.pumpWidget(const MaterialApp(
          home: ClubEmblem(teamId: 'user', teamName: '自分FC', size: 48)));
      final c = ClubLook.defaultCrestFor('user', '自分FC');
      var image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, ClubCrests.ownAssetPath(c));
      // 選んだ画像。
      ClubLookRegistry.look = const ClubLook(
          hue: 0, accentHue: 0, shape: 0, motif: 0, initial: 'A', crest: 19);
      await tester.pumpWidget(const MaterialApp(
          home: ClubEmblem(teamId: 'user', teamName: '自分FC', size: 40)));
      image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/crests/own_19.webp');
      // 他のクラブには自クラブ用の画像を出さない(書き換えた名前は描く)。
      await tester.pumpWidget(const MaterialApp(
          home: ClubEmblem(teamId: 'cpu1', teamName: '自分FC', size: 40)));
      expect(find.byType(Image), findsNothing);
      // 表の名前のクラブは表の画像。
      final (ja, _) = ClubNames.crestNames(3);
      await tester.pumpWidget(MaterialApp(
          home: ClubEmblem(teamId: 'cpu1', teamName: ja, size: 40)));
      image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, ClubCrests.assetPath(3));
    });

    testWidgets('見た目の画面で25枚から選んで決められる', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gs = GameState();
      await tester.runAsync(() => gs.startNewGame('選ぶFC'));
      await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
        value: gs,
        child: const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: ClubLookEditor())),
        ),
      ));
      await tester.pump();
      // 25枚 + 描いたエンブレムの枠。
      for (final name in ClubLook.crestNames) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }
      expect(find.byTooltip('描いたエンブレム(形・模様・頭文字)'), findsOneWidget);
      // 画像を選んでいるあいだは、色・形を選ぶ欄を出さない。
      expect(find.text('主の色'), findsNothing);
      final target = (gs.save!.clubLook!.crest! + 5) % ClubLook.crestCount;
      await tester.tap(find.byTooltip(ClubLook.crestNames[target]));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('この見た目にする'));
        await tester.pump();
      });
      await tester.pump();
      expect(gs.save!.clubLook!.crest, target);
      expect(ClubPalette.of('user', clubName: gs.save!.clubName).hue,
          ClubLook.crestHues(target).$1);
      // 描いたエンブレムの枠を選ぶと、色・形を選ぶ欄が出る。
      await tester.tap(find.byTooltip('描いたエンブレム(形・模様・頭文字)'));
      await tester.pump();
      expect(find.text('主の色'), findsOneWidget);
      expect(find.text('形'), findsOneWidget);
    });
  });
}
