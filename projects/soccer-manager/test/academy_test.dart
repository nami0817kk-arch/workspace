import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/academy_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// アカデミーの等級と、育成の方針の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('点が高いほど上のカテゴリー、上ほど数と質が増える', () {
    expect(AcademyEngine.category(16), 1);
    expect(AcademyEngine.category(12), 2);
    expect(AcademyEngine.category(8), 3);
    expect(AcademyEngine.category(3), 4);
    expect(AcademyEngine.extraIntake(1), greaterThan(AcademyEngine.extraIntake(3)));
    expect(AcademyEngine.qualityBonus(1),
        greaterThan(AcademyEngine.qualityBonus(4)));
  });

  test('技術重視なら技術の能力が+5、数を取るなら人数が増えて質が下がる', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 50);
    final k = AttributeCategory.technical.keys.first;
    final before = p.attributeValue(k);
    AcademyEngine.applyPolicy(p, YouthPolicy.technical);
    expect(p.attributeValue(k), (before + 5).clamp(1, 100));
    expect(AcademyEngine.policyExtraIntake(YouthPolicy.quantity), 2);
    expect(AcademyEngine.policyQualityBonus(YouthPolicy.quantity), lessThan(0));
  });

  test('方針は選べて、保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('育成FC');
    expect(gs.youthPolicy, YouthPolicy.balanced);
    expect(gs.academyCategory, inInclusiveRange(1, 4));
    await gs.setYouthPolicy(YouthPolicy.physical);
    expect(gs.youthPolicy, YouthPolicy.physical);
    expect(SaveGame.fromJson(gs.save!.toJson()).youthPolicy, 'physical');
  });
}
