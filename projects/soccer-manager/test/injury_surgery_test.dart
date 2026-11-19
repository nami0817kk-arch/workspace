import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/injury_care.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 怪我の部位と、大きな怪我の手術の判断の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(GameState, Player)> withLigament(int weeks) async {
    final gs = GameState();
    await gs.startNewGame('医療FC');
    final p = gs.userTeam.players.first
      ..injuryType = InjuryType.ligament
      ..injuryWeeks = weeks;
    return (gs, p);
  }

  test('靭帯の怪我は膝か足首、肉離れは脚の筋肉', () async {
    final (_, p) = await withLigament(8);
    expect([InjuryPart.knee, InjuryPart.ankle], contains(InjuryCare.partOf(p)));
    p.injuryType = InjuryType.muscle;
    expect([InjuryPart.thigh, InjuryPart.calf, InjuryPart.hamstring],
        contains(InjuryCare.partOf(p)));
  });

  test('長い靭帯の怪我だけ判断待ちになり、手術は費用がかかり離脱が延びる', () async {
    final (gs, p) = await withLigament(8);
    gs.debugReviewInjuries();
    expect(gs.playersAwaitingSurgeryDecision, [p]);
    final budget = gs.save!.budget;
    expect(await gs.decideSurgery(p.id, surgery: true), isTrue);
    expect(p.injuryWeeks, 8 + InjuryCare.surgeryExtraWeeks);
    expect(gs.save!.budget, budget - gs.surgeryCost);
    expect(gs.playersAwaitingSurgeryDecision, isEmpty);
    // 手術なら、治っても再発しない。
    p.injuryWeeks = 0;
    expect(gs.debugHeal(p, 0.0), isFalse);
  });

  test('短い怪我は判断待ちにならない', () async {
    final (gs, _) = await withLigament(InjuryCare.decisionWeeks - 1);
    gs.debugReviewInjuries();
    expect(gs.playersAwaitingSurgeryDecision, isEmpty);
  });

  test('保存療法は離脱が縮み、治ったときに再発することがある', () async {
    final (gs, p) = await withLigament(8);
    gs.debugReviewInjuries();
    await gs.decideSurgery(p.id, surgery: false);
    expect(p.injuryWeeks, 8 - InjuryCare.restSavedWeeks);
    p.injuryWeeks = 0;
    expect(gs.debugHeal(p, 0.1), isTrue, reason: '3割の内なら再発');
    expect(p.injuryWeeks, InjuryCare.setbackWeeks);
    // 再発の後は、もう選ばせない(再発もしない)。
    p.injuryWeeks = 0;
    expect(gs.debugHeal(p, 0.0), isFalse);
  });

  test('判断は保存して読み戻せる', () async {
    final (gs, p) = await withLigament(8);
    gs.debugReviewInjuries();
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.injuryPlans[p.id], 'pending');
  });
}
