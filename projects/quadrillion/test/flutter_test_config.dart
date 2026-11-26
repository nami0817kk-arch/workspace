import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/look.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:quadrillion/ui/world_map.dart';

/// テストの端末の言語は日本語にしておく（もとからあるテストは日本語の画面を見る）。英語のテストは lang: 'en' で始める
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final b = TestWidgetsFlutterBinding.ensureInitialized();
  b.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
  b.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
  L.lang = 'ja';
  // 小窓の出入りは、もとからあるテストでは時間0（開いた次の描画で、もう止まっている）。
  // 出入りそのものは test/improve_a_test.dart が本物の時間（220ms）で確かめる
  Ui.sheetMotion = Duration.zero;
  // 月を進めたときの数字の動き（1.1.0+40）も、もとからあるテストでは時間0。動きそのものは test/look_biz_test.dart が確かめる
  Motion.num = Duration.zero;
  // 保存は、もとからあるテストでは待たずに次の描き終わりでその場で（待つ・別 Isolate の道は test/improve_e_test.dart が確かめる）
  GameController.saveDelay = Duration.zero;
  // 本物の経済の統計（アプリは起動時に rootBundle から読む。1.1.0+25）
  EconData.current = loadEcon(File('assets/econ/econ.json').readAsStringSync());
  // 世界の地図の国の形（アプリは起動時に rootBundle から読む。1.1.0+41）
  WorldShapes.current = WorldShapes.parse(File('assets/map/world.json').readAsStringSync());
  await testMain();
}
