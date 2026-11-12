import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/ui/gm/player_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('顔は選手の id から決まり(同じなら同じ)、選手ごとに違う。若い選手にはひげが無く、年寄りは白髪が増える', () {
    final c = careerAt(6, 12);
    final all = [for (final t in c.teams) ...t.roster];
    final styles = <int>{}, skins = <Color>{}, beards = <int>{};
    for (final p in all) {
      final a = faceOf(p), b = faceOf(p);
      expect(a.hairStyle, b.hairStyle);
      expect(a.skin, b.skin);
      expect(a.hair, b.hair);
      styles.add(a.hairStyle);
      skins.add(a.skin);
      beards.add(a.beard);
      if (p.age < 22) expect(a.beard, 0, reason: '${p.name}(${p.age}歳)');
    }
    expect(styles.length, 6);
    expect(skins.length, faceSkins.length);
    expect(beards.length, 4);
    // 同じ選手でも、年を取ると髪が灰色に近づく
    final p = all.first;
    p.age = 25;
    final young = faceOf(p).hair;
    p.age = 40;
    final old = faceOf(p).hair;
    expect(old.r + old.g + old.b, greaterThan(young.r + young.g + young.b));
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
    expect(t.takeException(), isNull);
    expect(find.byType(PlayerFace), findsNWidgets(players.length));
  });
}
