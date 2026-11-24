import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';

/// 年の途中でアプリを閉じても、続きから同じ場面に戻る（2026-11-24、ユーザーの「全部」の2つめ。
/// 前は保存が年の初めだけで、その年に選んだことが消えていた）。
///
/// アプリと同じく年の初めに乱数を引き直し（`reseedAtCheckpoint`）、年の初めの保存と種と、
/// それから選んだ手（`choiceLog`）だけから別の Game に戻す。戻した Game は、閉じた時と同じ問い・同じ手・同じ暮らしになる。
void main() {
  test('年の途中で閉じても、続きから同じ問いと同じ暮らしに戻る', () {
    var checked = 0, replayed = 0, deep = 0;
    for (var s = 0; s < 600; s++) {
      String? saved;
      int? seed;
      final g = Game(
        rng: Rng(5000 + s),
        onCheckpoint: (g) {
          if (g.finished) return;
          saved = jsonEncode({
            'life': g.l.toJson(),
            'world': g.fa.values.map((f) => f.toJson()).toList(),
          });
          seed = g.checkpointSeed;
        },
      )..reseedAtCheckpoint = true;
      g.start(rollBirth(Rng(9000 + s)));
      final pick = Rng(7000 + s);
      final stopAt = pick.range(3, 160);
      var n = 0;
      while (!g.finished && n < stopAt) {
        final p = g.prompt!;
        g.choose(pick.range(0, p.choices.length - 1));
        n++;
      }
      // 年の途中（その年の手を一つ二つ選んだところ）で止まる人生を多くする。
      var extra = 0;
      while (!g.finished &&
          extra++ < 12 &&
          (g.choiceLog.isEmpty || (g.choiceLog.length < 2 && s.isEven))) {
        final p = g.prompt!;
        g.choose(pick.range(0, p.choices.length - 1));
      }
      if (g.finished || saved == null) continue;

      final p = g.prompt!;
      final replay = [...g.choiceLog];
      final want = jsonEncode(g.l.toJson());

      final j = jsonDecode(saved!) as Map<String, dynamic>;
      final g2 = Game(rng: Rng(1))..reseedAtCheckpoint = true;
      g2.restore(
        Life.fromJson(j['life'] as Map<String, dynamic>),
        {
          for (final e in (j['world'] as List))
            (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
        },
        seed: seed,
        replay: replay,
      );
      final p2 = g2.prompt;
      expect(p2, isNotNull, reason: '種 $s');
      expect(p2!.title, p.title, reason: '種 $s');
      expect(p2.text, p.text, reason: '種 $s');
      expect(
        p2.choices.map((c) => c.label).toList(),
        p.choices.map((c) => c.label).toList(),
        reason: '種 $s',
      );
      expect(g2.choiceLog, replay, reason: '種 $s');
      expect(jsonEncode(g2.l.toJson()), want, reason: '種 $s');
      checked++;
      if (replay.isNotEmpty) replayed++;
      if (replay.length >= 2) deep++;
    }
    // ignore: avoid_print
    print('【途中の再開】確かめた $checked・年の途中で閉じた $replayed・二手以上 $deep');
    expect(checked, greaterThan(150));
    expect(replayed, greaterThan(120));
    expect(deep, greaterThan(30));
  });

  test('種の無い古い保存は、その年の初めからやり直す', () {
    final g = Game(rng: Rng(3))..reseedAtCheckpoint = true;
    String? saved;
    final g0 = Game(
      rng: Rng(4),
      onCheckpoint: (g) {
        if (!g.finished) saved = jsonEncode(g.l.toJson());
      },
    );
    for (var s = 0; s < 50 && (saved == null || g0.finished); s++) {
      saved = null;
      g0.start(rollBirth(Rng(100 + s)));
    }
    expect(saved, isNotNull);
    g.restore(
      Life.fromJson(jsonDecode(saved!) as Map<String, dynamic>),
      g0.fa,
      replay: const [(0, 'どれでもない手')],
    );
    expect(g.prompt?.title, 'この年の心がけ');
    expect(g.choiceLog, isEmpty);
  });
}
