import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/l10n/lang.dart';
import 'package:quadrillion/ui/app.dart';

/// テストの端末の言語は日本語にしておく（もとからあるテストは日本語の画面を見る）。英語のテストは lang: 'en' で始める。
/// 小窓の出入りの動きは長さ0にしておく（もとからあるテストは、1回の描画で小窓が開き切り・閉じ切る前提で押している）。
/// 動きそのものは test/ux2_test.dart で元の長さに戻して、終わりまで進めて確かめる
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final b = TestWidgetsFlutterBinding.ensureInitialized();
  b.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
  b.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
  L.lang = 'ja';
  SheetMotion.duration = Duration.zero;
  SheetMotion.reverseDuration = Duration.zero;
  await testMain();
}
