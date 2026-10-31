import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/backup_share.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSharer implements BackupSharer {
  final shared = <String>[];
  @override
  Future<void> share(String text, {Rect? origin}) async => shared.add(text);
}

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(900, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('育成中の選手を始め直す前に、自動バックアップがとられる。最大3件・新しい順', () async {
    SharedPreferences.setMockInitialValues({});
    final c = GameController(rng: Random(1));
    c.newGame('一人目', Role.batter);
    expect(c.autoBackups, isEmpty); // 最初の選手は、控える前のデータが無い
    c.act(Plan.train);
    c.newGame('二人目', Role.batter);
    expect(c.autoBackups.length, 1);
    expect(c.autoBackups.first.why, contains('一人目'));
    for (var i = 0; i < 5; i++) {
      c.act(Plan.train);
      c.newGame('選手$i', Role.pitcher);
    }
    expect(c.autoBackups.length, autoBackupMax);
    // 新しい順(いちばん新しいものが先頭)
    expect(c.autoBackups.first.why, contains('選手3'));
    // 保存され、新しいコントローラーでも読める
    final c2 = GameController(rng: Random(2));
    await c2.loadSaved();
    expect(c2.autoBackups.length, autoBackupMax);
    expect(c2.autoBackups.first.why, c.autoBackups.first.why);
  });

  test('控えに戻せる。戻す前のデータも控えに残る(やり直せる)', () async {
    SharedPreferences.setMockInitialValues({});
    final c = GameController(rng: Random(1));
    c.newGame('はじめ', Role.batter);
    c.act(Plan.train);
    c.newGame('あと', Role.batter); // 「はじめ」の控えができる
    expect(c.game!.player.name, 'あと');
    final ok = await c.restoreAutoBackup(0);
    expect(ok, isTrue);
    expect(c.game!.player.name, 'はじめ');
    // 戻す前(「あと」)の控えが先頭に残っている
    expect(c.autoBackups.first.why, '戻す前');
    expect(await c.restoreAutoBackup(0), isTrue);
    expect(c.game!.player.name, 'あと');
    // 範囲外は戻さない
    expect(await c.restoreAutoBackup(99), isFalse);
    expect(await c.restoreAutoBackup(-1), isFalse);
  });

  test('引退したとき・4歳ごとの節目にも控えがとられる。すべて消すと控えも消える', () async {
    SharedPreferences.setMockInitialValues({});
    final c = GameController(rng: Random(4));
    c.newGame('テスト', Role.batter);
    final whys = <String>{};
    var guard = 0;
    while (c.game!.phase != Phase.retired && guard++ < 3000) {
      c.pending.clear();
      final g = c.game!;
      switch (g.phase) {
        case Phase.term:
          c.autoSpend();
          c.act(Plan.train);
        case Phase.event:
          c.chooseEvent(0);
        case Phase.pathChoice:
          c.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
      for (final b in c.autoBackups) {
        whys.add(b.why);
      }
    }
    expect(whys.any((w) => w.contains('歳')), isTrue);
    expect(c.autoBackups.any((b) => b.why.contains('引退したとき')), isTrue);
    await c.eraseAll();
    expect(c.autoBackups, isEmpty);
    final c2 = GameController(rng: Random(1));
    await c2.loadSaved();
    expect(c2.autoBackups, isEmpty);
  });

  test('壊れた控えは読み飛ばす', () async {
    SharedPreferences.setMockInitialValues(
        {autoBackupKey: '[{"at": 1, "why": "x", "text": "t"}, {"bad": 1}, 5]'});
    final c = GameController(rng: Random(1));
    await c.loadSaved();
    expect(c.autoBackups.length, 1);
    expect(c.autoBackups.first.why, 'x');
  });

  testWidgets('設定のバックアップに、控えの一覧と「戻す」が出る。共有ボタンは係があるときだけ', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final sharer = _FakeSharer();
    final c = GameController(rng: Random(1), sharer: sharer);
    c.newGame('はじめ', Role.batter);
    c.act(Plan.train);
    c.newGame('あと', Role.batter);
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('backup-open')));
    await t.tap(find.byKey(const Key('backup-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('autobackup-0')), findsOneWidget);
    expect(find.textContaining('はじめを始め直す前'), findsOneWidget);
    // 共有
    await t.tap(find.byKey(const Key('backup-share')));
    await t.pumpAndSettle();
    expect(sharer.shared.length, 1);
    expect(sharer.shared.first, contains('baseball-manager'));
    // 戻す
    await t.tap(find.byKey(const Key('autobackup-restore-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('autobackup-restore-confirm')));
    await t.pumpAndSettle();
    expect(c.game!.player.name, 'はじめ');
    expect(t.takeException(), isNull);
  });

  testWidgets('共有の係が無いとき(テスト・既定)は、共有ボタンを出さない', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final c = GameController(rng: Random(1));
    c.newGame('テスト', Role.batter);
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('backup-open')));
    await t.tap(find.byKey(const Key('backup-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('backup-share')), findsNothing);
    expect(find.byKey(const Key('backup-export')), findsOneWidget);
    expect(find.byKey(const Key('autobackup-0')), findsNothing);
  });
}
