import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/youth_promotion_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// ユースからの昇格を「手続き」にした部分の検査。
///
/// 以前は押した瞬間に名簿へ移るだけで費用も契約も無く、枠さえ空いていれば
/// 全員上げるのが最善だった。契約金・週俸・適応期間という代償が実際に
/// 付いていることを見る。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player prospect({int age = 18}) => PlayerGenerator.generate(
        position: Position.st,
        ageOverride: age,
        strengthTier: 55,
      );

  test('背番号は空いている最小の番号で、1番はGKに取っておく', () {
    final gk = PlayerGenerator.generate(
      position: Position.gk,
      ageOverride: 18,
      strengthTier: 55,
    );
    final field = prospect();
    final team = Team(id: 't', name: 'T', players: []);

    // フィールドプレーヤーは1番を取らない。
    expect(YouthPromotionEngine.nextSquadNumber(team, field), 2);
    // GKは空いていれば1番。
    expect(YouthPromotionEngine.nextSquadNumber(team, gk), 1);

    // 埋まっている番号は飛ばす。
    team.players.add(prospect()..squadNumber = 2);
    team.players.add(prospect()..squadNumber = 3);
    expect(YouthPromotionEngine.nextSquadNumber(team, field), 4);
  });

  test('昇格すると契約と背番号が入り、実戦感覚が下がる', () {
    final p = prospect();
    p.matchSharpness = 100;
    p.happiness = 50;
    p.youthMatchGoals = 9;
    final team = Team(id: 't', name: 'T', players: []);
    final terms = YouthPromotionEngine.termsFor(team, p);

    YouthPromotionEngine.applyPromotion(p, terms);

    expect(p.squadNumber, terms.squadNumber);
    expect(p.wage, terms.weeklyWage);
    expect(p.contractYearsRemaining, terms.years);
    expect(p.matchSharpness, YouthPromotionEngine.adaptationSharpness,
        reason: '一軍の強度に慣れる期間が無い');
    expect(p.happiness, greaterThan(50), reason: '昇格が本人に何も響いていない');
    expect(p.youthMatchGoals, 0, reason: 'ユース時代の記録が一軍に持ち越されている');
  });

  test('契約金が払えないと昇格できず、理由が残る', () async {
    final game = GameState();
    await game.startNewGame('昇格FC');

    final p = prospect();
    game.save!.youthProspects.add(p);
    game.save!.budget = 0;

    final ok = await game.promoteYouthProspect(p.id);

    expect(ok, isFalse);
    expect(game.lastSigningBlockReason, isNotNull, reason: '押しても無反応になっている');
    expect(game.save!.youthProspects.any((x) => x.id == p.id), isTrue,
        reason: '失敗したのにユースから消えている');
  });

  test('昇格すると契約金が資金から引かれ、一軍の名簿に入る', () async {
    final game = GameState();
    await game.startNewGame('昇格FC2');

    final p = prospect();
    game.save!.youthProspects.add(p);
    game.save!.budget = 100000;
    // 週給予算で弾かれないよう、枠は十分にある状態にしておく。
    game.save!.wageBudget = 100000;
    final before = game.save!.budget;
    final terms = game.youthPromotionTermsFor(p.id)!;

    final ok = await game.promoteYouthProspect(p.id);

    expect(ok, isTrue, reason: game.lastSigningBlockReason ?? '');
    expect(game.save!.budget, before - terms.signingBonus);
    expect(game.userTeam.players.any((x) => x.id == p.id), isTrue);
    expect(game.save!.youthProspects.any((x) => x.id == p.id), isFalse);
  });

  test('背番号はセーブに残る', () async {
    final game = GameState();
    await game.startNewGame('番号FC');

    final p = prospect();
    game.save!.youthProspects.add(p);
    game.save!.budget = 100000;
    game.save!.wageBudget = 100000;
    await game.promoteYouthProspect(p.id);

    final promoted = game.userTeam.players.firstWhere((x) => x.id == p.id);
    expect(promoted.squadNumber, isNotNull);
    final restored = Player.fromJson(promoted.toJson());
    expect(restored.squadNumber, promoted.squadNumber);
  });
}
