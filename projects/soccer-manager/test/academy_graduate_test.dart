import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/achievement_engine.dart';
import 'package:soccer_manager/models/achievement.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/youth_promotion_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「生え抜き」の印の検査。
///
/// 買ってきた選手と、ユースで育てた選手が見分けられなかった。育成に時間を
/// かけた手応えが、名簿の上で何も残らない状態だった。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player prospect() => PlayerGenerator.generate(
        position: Position.mc,
        ageOverride: 18,
        strengthTier: 55,
      );

  test('昇格した選手には生え抜きの印が付く', () {
    final p = prospect();
    expect(p.academyGraduate, isFalse);

    final team = Team(id: 't', name: 'T', players: []);
    YouthPromotionEngine.applyPromotion(
        p, YouthPromotionEngine.termsFor(team, p));

    expect(p.academyGraduate, isTrue);
  });

  test('買ってきた選手には付かない', () {
    final bought = PlayerGenerator.generate(
      position: Position.st,
      ageOverride: 24,
      strengthTier: 70,
    );
    expect(bought.academyGraduate, isFalse);
  });

  test('印はセーブに残り、旧セーブでは false として読む', () {
    final p = prospect()..academyGraduate = true;
    expect(Player.fromJson(p.toJson()).academyGraduate, isTrue);

    final legacy = Map<String, dynamic>.from(p.toJson())
      ..remove('academyGraduate');
    expect(Player.fromJson(legacy).academyGraduate, isFalse);
  });

  test('生え抜きを送り出すと実績が解除される', () async {
    final game = GameState();
    await game.startNewGame('生え抜きFC');
    final save = game.save!;
    final team = game.userTeam;

    Achievement byId(String id) =>
        AchievementEngine.all.firstWhere((a) => a.id == id);

    expect(byId('academy_graduate').isUnlocked(save, team), isFalse);

    team.players.first.academyGraduate = true;
    expect(byId('academy_graduate').isUnlocked(save, team), isTrue);

    // 5人そろうまでは「ユースの背骨」は解除されない。
    expect(byId('academy_backbone').isUnlocked(save, team), isFalse);
    for (final p in team.players.take(5)) {
      p.academyGraduate = true;
    }
    expect(byId('academy_backbone').isUnlocked(save, team), isTrue);
  });
}
