import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/models/player.dart';

/// ユースインテークの「見立て」の検査。
///
/// 選抜画面は潜在能力をそのまま出していた。数字が見えているなら、大きい順に
/// 取るだけで判断が要らない。スカウト候補と同じく推定幅にして、ユースコーチの
/// 見極めに意味を持たせる。
void main() {
  Player graduate() => PlayerGenerator.generate(
        position: Position.mc,
        ageOverride: 17,
        strengthTier: 55,
      );

  test('推定幅は実際の潜在能力を含む', () {
    for (var i = 0; i < 20; i++) {
      final p = graduate();
      final range = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: 3);
      expect(p.potential, greaterThanOrEqualTo(range.$1));
      expect(p.potential, lessThanOrEqualTo(range.$2));
    }
  });

  test('見極めが高いほど幅が狭い', () {
    final p = graduate()..potential = 70;
    int width(int level) {
      final r = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: level);
      return r.$2 - r.$1;
    }

    expect(width(8), lessThan(width(1)),
        reason: '良いコーチを雇っても見立ての精度が変わらない');
  });

  test('選抜画面は潜在能力をそのまま出さない', () {
    // 画面のコードを読んで確かめる。数字を直に出す実装に戻ると、
    // 選抜から判断が消える。
    final source =
        File('lib/screens/youth_intake_screen.dart').readAsStringSync();

    expect(source, contains('estimatedPotentialRange'),
        reason: '見立てを使っていない');
    expect(source, isNot(contains(r'潜在 ${p.potential}')),
        reason: '潜在能力をそのまま出している');
  });
}
