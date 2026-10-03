/// エンブレムの見え方を1枚にまとめて書き出す（確認用）。
///
///     flutter test tool/art/emblem_preview_test.dart --update-goldens
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/widgets/club_emblem.dart';

const _names = [
  '青嵐フットボールクラブ',
  '北風ユナイテッド',
  '王冠シティ',
  '霧の丘アスレチック',
  '紅獅子アスレチック',
  '翠波ローバーズ',
  '鉄槌ウォリアーズ',
  '銀嶺タウン',
  '湊町アルビオン',
  '黎明オリンピック',
  '白樺ワンダラーズ',
  '黒鉄カウンティ',
];

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 本体のテーマは2つの書体を使う。片方だけ読むと、その書体を指している
  // 文字が豆腐(□)になる。
  const bundled = {
    'NotoSansJP': ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf'],
    'ShipporiMincho': [
      'ShipporiMincho-Regular.ttf',
      'ShipporiMincho-SemiBold.ttf',
    ],
  };
  for (final entry in bundled.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('エンブレムの見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(940, 420) * 3.0;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      // アプリ本体と同じテーマを使う。ThemeData(fontFamily:) を自分で
      // 組むと、頭文字が豆腐(□)になった。
      theme: const SoccerManagerApp().buildTheme(Brightness.light, boldText: false),
      // Material で包む。包まないと、文字に黄色い二重下線が引かれる。
      home: Material(
        color: const Color(0xFFF2F2F5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 実寸（一覧で出る 28 と 40）
              for (final size in const [28.0, 40.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < _names.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClubEmblem(
                            teamId: 'team-$i',
                            teamName: _names[i],
                            size: size,
                          ),
                        ),
                    ],
                  ),
                ),
              // 拡大（作りを見るため）
              for (final from in const [0, 6])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      for (var i = from; i < from + 6; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: ClubEmblem(
                            teamId: 'team-$i',
                            teamName: _names[i],
                            size: 110,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_emblems.png'));
  });
}
