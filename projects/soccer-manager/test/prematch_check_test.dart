import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/prematch_check.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 試合前の確認の検査。
///
/// 負傷や出場停止の選手をスタメンに置いたまま試合に入っても何も言われず、
/// 気づくのは結果が出た後だった。そのときにはもう勝点は戻らない。
///
/// 同時に、**問題が無い週には何も出さない**ことも固定する。毎週タップが
/// 1回増えるだけの確認画面は、ただの邪魔になる。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 文言は言語設定で切り替わる。テスト環境の既定は英語なので、
    // 日本語の文面を確かめるならここで決めておく。
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('確認FC');
    LineupUtils.autoFill(game.userTeam);
    // 検査したい条件以外は「問題なし」に揃える。
    for (final p in game.userTeam.players) {
      p.fatigue = 0;
      p.matchSharpness = 100;
    }
    return game;
  }

  test('問題が無ければ何も出さない', () async {
    final game = await newGame();
    final warnings = PreMatchCheck.run(game.userTeam);
    // 本職外の配置だけは初期編成でも起きうるので、重いものが無いことを見る。
    expect(warnings.where((w) => w.serious), isEmpty);
  });

  test('出られない選手がスタメンにいると重い警告になる', () async {
    final game = await newGame();
    final starter = game.userTeam.players
        .firstWhere((p) => game.userTeam.startingXI.contains(p.id));
    starter.injuryWeeks = 2;

    final warnings = PreMatchCheck.run(game.userTeam);
    expect(warnings.any((w) => w.serious && w.message.contains(starter.name)),
        isTrue);
  });

  test('疲労と実戦感覚は人数でまとめて出す', () async {
    final game = await newGame();
    final starters = game.userTeam.players
        .where((p) => game.userTeam.startingXI.contains(p.id))
        .toList();
    starters[0].fatigue = 90;
    starters[1].fatigue = 88;
    starters[2].matchSharpness = 20;

    final warnings = PreMatchCheck.run(game.userTeam);
    expect(warnings.any((w) => w.message.contains('2人')), isTrue,
        reason: '疲労の人数がまとまっていない');
    expect(warnings.any((w) => w.message.contains('実戦感覚')), isTrue);
  });

  test('出られない選手は、疲労の数に重ねて数えない', () async {
    final game = await newGame();
    final starter = game.userTeam.players
        .firstWhere((p) => game.userTeam.startingXI.contains(p.id));
    starter.injuryWeeks = 2;
    starter.fatigue = 95;

    final warnings = PreMatchCheck.run(game.userTeam);
    // 同じ選手のことを2行で言うと、何人まずいのかが分からなくなる。
    expect(warnings.where((w) => w.message.contains('疲労')), isEmpty);
  });

  test('控えが足りないと知らせる', () async {
    final game = await newGame();
    final team = game.userTeam;
    // 控えを出せない状態にする(スタメン以外を全員負傷させる)。
    for (final p in team.players) {
      if (!team.startingXI.contains(p.id)) p.injuryWeeks = 3;
    }

    final warnings = PreMatchCheck.run(team);
    expect(warnings.any((w) => w.message.contains('交代で出せる')), isTrue);
  });

  test('重い警告が先に来る', () async {
    final game = await newGame();
    final starters = game.userTeam.players
        .where((p) => game.userTeam.startingXI.contains(p.id))
        .toList();
    starters[0].fatigue = 90; // 軽い
    starters[1].suspendedMatches = 1; // 重い

    final warnings = PreMatchCheck.run(game.userTeam);
    expect(warnings.first.serious, isTrue);
  });
}
