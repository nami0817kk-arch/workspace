import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/development_advisor.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 育成アドバイスが「読むだけ」で終わらず、その場で適用できることを固定する。
///
/// 助言は以前からあったが、対応は利用者任せだった。「メンター未設定」と言われて
/// から、適任のベテランを自分で探して設定する必要がある。毎週これを選手ごとに
/// 繰り返すのが育成の手間の中心だった。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('メンター未設定の提案は、その場で付けられる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;

    // メンター候補(28歳以上)と、付ける相手(23歳以下)を明示的に作る。
    final veteran = team.players[0]..age = 32;
    final young = team.players[1]
      ..age = 20
      ..mentorId = null;
    expect(veteran.age, greaterThanOrEqualTo(TrainingEngine.minMentorAge));

    final advice = DevelopmentAdvisor.advise(team).firstWhere(
        (a) => a.kind == AdviceKind.noMentor && a.playerId == young.id);
    expect(advice.fix, isA<AssignMentorFix>(), reason: '提案に「誰を付けるか」が入っていない');

    expect(game.applyAdviceFix(advice), isTrue);
    expect(young.mentorId, isNotNull, reason: 'メンターが設定されていない');

    // 付けた相手は条件を満たしていること。
    final mentor = team.players.firstWhere((p) => p.id == young.mentorId);
    expect(mentor.age, greaterThanOrEqualTo(TrainingEngine.minMentorAge));
    expect(mentor.id, isNot(young.id));
  });

  test('疲労の提案は、個別方針を休養にする', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    final tired = team.players.first;
    tired.fatigue = DevelopmentAdvisor.fatigueThreshold + 5;
    tired.individualFocus = null;

    final advice = DevelopmentAdvisor.advise(team)
        .firstWhere((a) => a.kind == AdviceKind.highFatigue);
    expect(advice.fix, isA<RestFix>());

    expect(game.applyAdviceFix(advice), isTrue);
    expect(
      team.players.firstWhere((p) => p.id == advice.playerId).individualFocus,
      TrainingFocus.rest,
    );
  });

  test('伸びしろの提案は、一番低い属性の特訓を設定する', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    final young = team.players.first;
    young.age = 19;
    young.potential =
        (young.overall + DevelopmentAdvisor.potentialGapThreshold + 5)
            .clamp(1, 99);
    young.drillAttributeKey = null;
    young.developmentTargetRole = null;

    final advice = DevelopmentAdvisor.advise(team).firstWhere(
        (a) => a.kind == AdviceKind.unusedPotential && a.playerId == young.id);
    final fix = advice.fix;
    expect(fix, isA<SetDrillFix>());

    expect(game.applyAdviceFix(advice), isTrue);
    expect(young.drillAttributeKey, (fix as SetDrillFix).attributeKey);
  });

  test('自動で決められない提案には手を用意しない', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    final rusty = team.players.first;
    rusty.injuryWeeks = 0;
    rusty.matchSharpness = DevelopmentAdvisor.sharpnessThreshold - 10;

    final advice = DevelopmentAdvisor.advise(team)
        .firstWhere((a) => a.kind == AdviceKind.lowSharpness);
    // 出場機会を作るかローンに出すかは、こちらでは決められない。
    expect(advice.fix, isNull);
    expect(game.applyAdviceFix(advice), isFalse);
  });
}
