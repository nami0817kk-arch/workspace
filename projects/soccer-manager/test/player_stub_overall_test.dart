import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_stub.dart';

void main() {
  test('軽い形から作り直しても、上限近くの総合力(〜99)も保たれる', () {
    var checked = 0;
    for (var i = 0; i < 300; i++) {
      for (final pos in [Position.gk, Position.dc, Position.mc, Position.st]) {
        final p = PlayerGenerator.generate(
            position: pos, strengthTier: 92 + i % 8, ageOverride: 27);
        final back = PlayerStub.decode(PlayerStub.encode(p));
        expect(back.overall, p.overall,
            reason: '${p.id} ${pos.name} ${p.overall}');
        checked++;
      }
    }
    expect(checked, 1200);
  });

  test('下限近くの総合力も保たれる', () {
    for (var i = 0; i < 200; i++) {
      final p = PlayerGenerator.generate(
          position: Position.mc, strengthTier: 40, ageOverride: 17);
      final target = 5 + i % 20;
      PlayerStub.matchOverall(p, target);
      expect(p.overall, target);
    }
  });
}
