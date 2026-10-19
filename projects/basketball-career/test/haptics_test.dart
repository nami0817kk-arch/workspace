// 触覚の呼び出しが、対応しない環境(Web・テスト・デスクトップ)で未処理の例外にならないこと。
// このファイルは、画面の仕組み(binding)を初期化しない通常のテストにしている。
import 'dart:async';
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}

void main() {
  test('触覚が使えない環境でも、操作から未処理の非同期エラーが出ない', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final c = GameController(store: _NullStore(), rng: Random(5), events: false);
      c.newGame('ハプティクス');
      for (var i = 0; i < 40 && c.game!.phase != Phase.retired; i++) {
        switch (c.game!.phase) {
          case Phase.season:
            c.act(Action.practice);
          case Phase.clutch:
            await c.playClutch(Clutch.drive);
          case Phase.event:
            c.chooseEvent(0);
          case Phase.path:
          case Phase.retired:
            break;
        }
      }
      // 非同期の失敗が届くまで少し待つ。
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (e, s) => errors.add(e));
    expect(errors, isEmpty);
  });
}
