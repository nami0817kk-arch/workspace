import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 同梱している実フォントをテストへ読み込む。
///
/// これを呼ばないと、テストは全文字が同じ幅の代替フォントで描画される。
/// 実測すると `iiiiiiii` も `MMMMMMMM` も 112px(14px × 8文字)で、
/// 日本語は実フォントと一致する一方、**英語だけがおよそ2倍に太る**。
///
///   "Sign him"  代替 112.0px / 実フォント 57.1px
///   "Player of the season" 代替 280px / 実フォント 130.5px
///   "獲得する"  代替 56.0px / 実フォント 56.0px
///
/// つまりフォントを読まないままレイアウトを検査すると、英語について
/// 実機では起きないはみ出しを検出してしまう。逆に見落とす方向には
/// 効かないので害は小さいが、直す必要のないものを直す判断に繋がる。
Future<void> loadAppFonts() async {
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
