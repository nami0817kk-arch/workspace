import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 試作（prototype.html）を同じ乱数・同じ手順で動かした毎月の数字（tool/trace.js で作った）と、
/// Dart に移した仕組みの数字が一致することを確かめる。
void main() {
  final cases = jsonDecode(File('test/fixtures/trace.json').readAsStringSync()) as List;
  for (final c in cases) {
    final m = c as Map<String, dynamic>;
    final cfg = m['cfg'] as Map<String, dynamic>;
    test('試作と同じ数字になる（seed ${m['seed']}・${cfg['mode']}・${cfg['year']}年・${cfg['home']}）', () {
      final s = Game.newGame(
          SetupConfig(mode: cfg['mode'] as String, year: cfg['year'] as int, traits: (cfg['traits'] as List).cast<String>(), home: cfg['home'] as String),
          rng: ParkMiller(m['seed'] as int))
        // 試作のあとに足した仕組み（取締役会・宿敵の物語）は切って比べる
        ..extras = false;
      final rows = (m['rows'] as List).cast<List>();
      for (var t = 0; t < rows.length; t++) {
        botMonth(s);
        final got = row(s);
        final want = rows[t].map((e) => (e as num).toDouble()).toList();
        for (var k = 0; k < want.length; k++) {
          final tol = want[k].abs() * 1e-6 + 1e-6;
          expect((got[k] - want[k]).abs() <= tol, isTrue, reason: '${t + 1}か月目の$k番目: 試作 ${want[k]} / Dart ${got[k]}\n試作 $want\nDart $got');
        }
      }
    });
  }
}
