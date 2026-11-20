// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/game_state.dart';

String _encode(Object save) => jsonEncode((save as dynamic).toJson());

/// セーブの書き出しを別の処理に回しても、中身が変わらないこと。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('encoding off the main isolate gives the same JSON', () async {
    final gs = GameState();
    await gs.startNewGame('書き出しFC');
    for (var i = 0; i < 3; i++) {
      await gs.playNextMatchdayQuickSim();
    }
    final here = jsonEncode(gs.save!.toJson());
    final there = await GameState.encodeSaveOffMain(gs.save!);
    expect(there.length, here.length);
    expect(there, here);
  });

  test('the save can be handed to another isolate (no silent fallback)',
      () async {
    final gs = GameState();
    await gs.startNewGame('渡せるFC');
    await gs.playNextMatchdayQuickSim();
    // 渡せないものが混じっていると、ここで例外になる。
    final json = await compute(_encode, gs.save!);
    expect(json, jsonEncode(gs.save!.toJson()));
  });
}
