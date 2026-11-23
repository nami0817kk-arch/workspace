import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/l10n/lang.dart';

/// テストの端末の言語は日本語にしておく（もとからあるテストは日本語の画面を見る）。英語のテストは lang: 'en' で始める
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final b = TestWidgetsFlutterBinding.ensureInitialized();
  b.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
  b.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
  L.lang = 'ja';
  await testMain();
}
