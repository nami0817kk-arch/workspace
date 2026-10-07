import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// 手で取る控え(復元ポイント)の検査。
///
/// 控えを取る手段はクリップボードへの書き出ししか無く、1MBを超えるJSONを
/// 自分でどこかへ保管する必要があった。「大型補強の前に念のため」という
/// 使い方には重すぎる。押すだけで取れて押すだけで戻せる地点を、スロット
/// ごとに1つ持てるようにしてある。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('控えが無ければ、戻す先も無い', () async {
    final game = GameState();
    await game.startNewGame('控え無しFC');

    expect(await game.restorePointInfo(), isNull);
    expect(await game.restoreFromRestorePoint(), isFalse,
        reason: '控えが無いのに戻せたことになっている');
  });

  test('控えを取ると、いつ・どこの時点かが分かる', () async {
    final game = GameState();
    await game.startNewGame('しおりFC');

    expect(await game.saveRestorePoint(), isTrue);
    final info = await game.restorePointInfo();

    expect(info, isNotNull);
    expect(info!.clubName, 'しおりFC');
    expect(info.season, game.save!.league.season);
    expect(info.matchday, 1, reason: '開幕前なら次は第1節のはず');
  });

  test('進めたあとでも、控えの時点まで戻せる', () async {
    final game = GameState();
    await game.startNewGame('巻き戻しFC');
    await game.saveRestorePoint();

    final before = game.save!.budget;
    await game.simulateAheadMatchdays(3);
    expect(game.save!.league.nextUnplayedFixture!.matchday, greaterThan(1),
        reason: '節が進んでいない(前提が崩れている)');

    expect(await game.restoreFromRestorePoint(), isTrue);

    expect(game.save!.league.nextUnplayedFixture!.matchday, 1,
        reason: '節が戻っていない');
    expect(game.save!.budget, before, reason: '資金が戻っていない');
    expect(game.save!.clubName, '巻き戻しFC');
  });

  test('戻した内容は端末にも書き込まれる(次の起動でも戻ったまま)', () async {
    final game = GameState();
    await game.startNewGame('保存FC');
    await game.saveRestorePoint();
    await game.simulateAheadMatchdays(2);
    await game.restoreFromRestorePoint();

    final reloaded = GameState();
    await reloaded.init();

    expect(reloaded.save!.league.nextUnplayedFixture!.matchday, 1,
        reason: '戻した状態が保存されていない');
  });

  test('控えはスロットごとに持つ(別スロットを開いても消えない)', () async {
    // 壊れたとき用の自動の控えはスロットを跨いで上書きされる。手で取った
    // 控えが別スロットを開いただけで消えると、取った意味が無くなる。
    final game = GameState();
    await game.startNewGame('1軍FC');
    await game.saveRestorePoint();

    await game.loadSlot(1);
    await game.startNewGame('2軍FC');
    expect(await game.restorePointInfo(), isNull,
        reason: '別スロットの控えが見えている');

    await game.loadSlot(0);
    final info = await game.restorePointInfo();
    expect(info?.clubName, '1軍FC', reason: '控えが消えている');
  });

  test('スロットを消すと、その控えも消える', () async {
    final game = GameState();
    await game.startNewGame('解散FC');
    await game.saveRestorePoint();

    await game.deleteSlot(0);

    expect(await game.restorePointInfo(0), isNull,
        reason: '消したクラブに戻せてしまう');
  });
}
