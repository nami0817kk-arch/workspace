import 'dart:io';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/ui/gm/player_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('顔は選手の id から決まり(同じなら同じ)、選手ごとに違う。若い選手にはひげが無く、年寄りは白髪になる', () {
    final c = careerAt(6, 12);
    final all = [for (final t in c.teams) ...t.roster];
    final types = <String>{}, hairs = <int>{}, beards = <int>{}, faces = <FaceSpec>{};
    for (final p in all) {
      final a = faceOf(p), b = faceOf(p);
      expect(a, b);
      types.add(a.type.name);
      hairs.add(a.hair);
      beards.add(a.beard);
      faces.add(a);
      expect(a.type.tones, contains(a.tone));
      if (p.age < 22) expect(a.beard, 0, reason: '${p.name}(${p.age}歳)');
      if (p.age < 33) expect(a.gray, isFalse, reason: '${p.name}(${p.age}歳)');
      // 日本人の名前にはアジア系の顔(2026-11-23 篠宮に肌の濃い顔が付いていた)
      expect(a.type.name == 'asian', isJapaneseName(p.name) ? isTrue : anything, reason: p.name);
    }
    expect(all.where((p) => isJapaneseName(p.name)), isNotEmpty);
    expect(isJapaneseName('篠宮 悠真'), isTrue);
    expect(isJapaneseName('イグナス・クロウリー'), isFalse);
    expect(types.length, greaterThanOrEqualTo(10));
    expect(hairs.length, greaterThanOrEqualTo(9));
    expect(beards.length, 4);
    // 半分を超える選手は、リーグの中で自分だけの顔になる(部品の組み合わせは約3,900通り)
    expect(faces.length, greaterThan(all.length * 0.55));
    // 同じ選手でも、年を取ると白髪が増え、一度なったら戻らない
    final withHair = all.where((p) => faceOf(p).hair >= 0).toList();
    var grayAt40 = 0;
    for (final p in withHair) {
      final age = p.age;
      var was = false;
      for (var y = 30; y <= 42; y++) {
        p.age = y;
        final g = faceOf(p).gray;
        expect(!was || g, isTrue, reason: '${p.name} $y歳で白髪が戻った');
        was = g;
        if (y == 40 && g) grayAt40++;
      }
      p.age = age;
    }
    expect(grayAt40, greaterThan(withHair.length * 0.6));
  });

  test('どの組み合わせでも絵がそろっている', () {
    for (final t in faceTypes) {
      for (var e = 0; e < t.eyes; e++) {
        for (var b = 0; b < faceBeardCount; b++) {
          for (final tone in t.tones) {
            final s = FaceSpec(type: t, eyes: e, beard: b, tone: tone, hair: -1, gray: false);
            expect(File(s.bodyAsset).existsSync(), isTrue, reason: s.bodyAsset);
          }
        }
      }
      for (var h = 0; h < faceHairCount; h++) {
        for (final g in [false, true]) {
          final s = FaceSpec(type: t, eyes: 0, beard: 0, tone: t.tones.first, hair: h, gray: g);
          expect(File(s.hairAsset!).existsSync(), isTrue, reason: s.hairAsset);
        }
      }
    }
  });

  testWidgets('選手の顔は例外なく描ける(いろいろな年・髪型・大きさ)', (t) async {
    final c = careerAt(6, 12);
    final players = [for (final x in c.teams) ...x.roster].take(40).toList();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(children: [
          for (var i = 0; i < players.length; i++) PlayerFace(p: players[i]..age = 20 + i % 20, team: i % 30, size: i.isEven ? 40 : 84),
        ]),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byType(PlayerFace), findsNWidgets(players.length));
  });
}
