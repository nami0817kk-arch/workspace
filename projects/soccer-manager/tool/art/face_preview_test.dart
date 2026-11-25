/// 似顔絵の見え方を1枚にまとめて書き出す（一時的な確認用）。
///
///     flutter test tool/art/face_preview_test.dart --update-goldens
///
/// 国ごと(アフリカの代表を含む)に、年齢を散らして並べる。上の2段は実寸
/// (名簿の 40)、下は拡大(96)。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/widgets/player_face_avatar.dart';

void main() {
  testWidgets('顔の見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(1180, 820) * 2.0;

    const positions = [Position.gk, Position.dc, Position.mc, Position.st];
    const ages = [18, 21, 24, 27, 30, 33, 36];
    final rows = <(LeagueTheme?, bool)>[
      for (final n in LeagueTheme.values) (n, false),
      (LeagueTheme.france, true),
    ];

    Widget face(int i, LeagueTheme? n, bool african, double size) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: PlayerFaceAvatar(
            playerId: 'pl${n?.index ?? 9}${african ? 'a' : ''}$i',
            position: positions[i % positions.length],
            size: size,
            highlighted: i == 0,
            nation: n,
            age: ages[i % ages.length],
            african: african,
          ),
        );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFFF2F2F5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (n, af) in rows)
                Row(children: [
                  for (var i = 0; i < 14; i++) face(i, n, af, 40),
                ]),
              const SizedBox(height: 8),
              for (final (n, af) in rows.take(4))
                Row(children: [
                  for (var i = 0; i < 7; i++) face(i, n, af, 96),
                ]),
            ],
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate().toList()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_faces.png'));
  });
}
