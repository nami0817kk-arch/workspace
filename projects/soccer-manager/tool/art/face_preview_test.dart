/// 似顔絵の見え方を1枚にまとめて書き出す（一時的な確認用）。
///
///     flutter test tool/art/face_preview_test.dart --update-goldens
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/widgets/player_face_avatar.dart';

void main() {
  testWidgets('顔の見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(940, 460) * 3.0;

    const positions = [
      Position.gk, Position.dc, Position.mc, Position.st,
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFFF2F2F5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 実寸（名簿で出る 40 と、選手詳細の 56）
              for (final size in const [40.0, 56.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      for (var i = 0; i < 14; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: PlayerFaceAvatar(
                            playerId: 'p-$i',
                            position: positions[i % positions.length],
                            size: size,
                            highlighted: i == 0,
                          ),
                        ),
                    ],
                  ),
                ),
              // 拡大（作りを見るため）
              Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: PlayerFaceAvatar(
                        playerId: 'p-$i',
                        position: positions[i % positions.length],
                        size: 120,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 6; i < 12; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: PlayerFaceAvatar(
                        playerId: 'p-$i',
                        position: positions[i % positions.length],
                        size: 120,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_faces.png'));
  });
}
