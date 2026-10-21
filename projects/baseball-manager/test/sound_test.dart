import 'dart:io';
import 'dart:math';

import 'package:baseball_manager/game/game.dart' show Phase;
import 'package:baseball_manager/game/path.dart' show Course;
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rec implements SoundPlayer {
  final played = <Sfx>[];
  @override
  Future<void> play(Sfx s) async => played.add(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('効果音のファイルが、全部そろっていて軽い(合計 600KB 未満)', () {
    var total = 0;
    for (final s in Sfx.values) {
      final f = File('assets/sfx/${s.name}.wav');
      expect(f.existsSync(), isTrue, reason: s.name);
      total += f.lengthSync();
      expect(f.lengthSync(), lessThan(100 * 1024), reason: s.name);
    }
    expect(total, lessThan(600 * 1024));
  });

  test('行動で音が鳴り、設定でオフにすれば鳴らない', () async {
    SharedPreferences.setMockInitialValues({});
    final rec = _Rec();
    final c = GameController(rng: Random(3), sound: rec);
    c.newGame('テスト', Role.batter);
    void next() {
      if (c.game!.phase == Phase.event) c.chooseEvent(0);
    }

    c.act(Plan.train);
    expect(rec.played, isNotEmpty);
    final n = rec.played.length;
    next();
    c.setFlags(sound: false);
    c.act(Plan.rest);
    expect(rec.played.length, n);
    next();
    c.setFlags(sound: true);
    c.act(Plan.train);
    expect(rec.played.length, greaterThan(n));
  });

  test('能力を上げると鳴る', () async {
    SharedPreferences.setMockInitialValues({});
    final rec = _Rec();
    final c = GameController(rng: Random(3), sound: rec);
    c.newGame('テスト', Role.batter);
    c.game!.adminAddExp(200);
    rec.played.clear();
    c.spend(Ability.contact);
    expect(rec.played, contains(Sfx.gain));
  });

  test('節目(ドラフト・優勝・引退)で、それぞれの音が鳴る', () async {
    SharedPreferences.setMockInitialValues({});
    final seen = <Sfx>{};
    for (var s = 0;
        s < 12 && !(seen.containsAll({Sfx.draft, Sfx.retire}));
        s++) {
      final rec = _Rec();
      final c = GameController(rng: Random(s), sound: rec);
      c.newGame('テスト', Role.batter);
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
      }
      seen.addAll(rec.played);
    }
    expect(seen, containsAll({Sfx.draft, Sfx.retire, Sfx.event}));
  });

  test('設定の保存: 音は4つ目の値。古い保存(3つ)は音あり', () async {
    SharedPreferences.setMockInitialValues(
        {'baseball_manager_flags_v1': '0,1,1'});
    final f = await SaveStore().loadFlags();
    expect(f.sound, isTrue);
    await SaveStore().saveFlags(false, true, true, false);
    final g = await SaveStore().loadFlags();
    expect(g.sound, isFalse);
    expect(g.haptics, isTrue);
  });
}
