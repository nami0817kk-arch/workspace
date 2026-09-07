/// Google Play のフィーチャーグラフィック(1024x500)を作る。
///
/// **CI では回らない。** 実行するとファイルを書き換える生成器。
///
///     flutter test tool/screenshots/feature_graphic_test.dart --update-goldens
///
/// 背景 (`marketing/feature/stadium_bg.jpg`) は生成した画像で、実在の
/// スタジアム・クラブ・選手は写っていない。文字はここで載せる。
///
/// 画像生成側で文字まで載せようとすると、日本語が化ける(実際に化けた)うえ、
/// 書体もアプリと揃わない。アプリが同梱しているフォントで描けば、ストアの
/// 絵とアプリの中で同じ書体になる。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(1024, 500);

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = {
    'NotoSansJP': ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf'],
    'ShipporiMincho': [
      'ShipporiMincho-Regular.ttf',
      'ShipporiMincho-SemiBold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

Future<ui.Image> _decode(String path) async {
  final codec =
      await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('フィーチャーグラフィックを書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _size;

    late final ui.Image background;
    late final ui.Image icon;
    await tester.runAsync(() async {
      background = await _decode('marketing/feature/stadium_bg.jpg');
      icon = await _decode('assets/icon/app_icon.png');
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: _size.width,
          height: _size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: background, fit: BoxFit.cover),
              // 左半分を暗くして、文字を読ませる。全面を暗くすると
              // スタジアムが沈んで、ただの黒い帯になる。
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xF00B1B2B), Color(0x300B1B2B)],
                    stops: [0.05, 0.85],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 300, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: RawImage(image: icon, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Text(
                          'サッカー経営\nマネージャー',
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontWeight: FontWeight.w600,
                            fontSize: 44,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '5部リーグの弱小クラブを率いて、頂点へ。',
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 21,
                        color: Color(0xFFD8E4EC),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '育成・移籍・戦術・経営',
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 17,
                        letterSpacing: 3,
                        color: Color(0xFF8FD9A4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(Stack).first,
      matchesGoldenFile('../../marketing/feature/feature_graphic.png'),
    );
  });
}
