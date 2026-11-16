import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 練習はコーチ陣の仕事。オーナーは触れないので、毎節かならず実施される。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('自動練習をオンにしていなくても、節を進めると練習が行われる', () async {
    final game = GameState();
    await game.startNewGame('練習FC');
    game.userTeam.autoTrainingEnabled = false;
    expect(game.trainingDoneThisWeek, isFalse);

    await game.playNextMatchday();

    expect(game.trainingDoneThisWeek, isTrue,
        reason: '練習を行う画面が無いので、節の処理で必ず行われる');
  });

  test('1週に練習は1回だけ(続けて呼んでも二重に行われない)', () async {
    final game = GameState();
    await game.startNewGame('練習FC');
    expect(await game.runWeeklyTraining(), isTrue);
    expect(await game.runWeeklyTraining(), isFalse);
  });
}
