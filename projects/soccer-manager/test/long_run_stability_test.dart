import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player_instruction.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 長く遊んだときと、極端な条件で、値や状態が壊れないことを確かめる。
///
/// 単体のテストは1試合・1シーズンしか見ない。実際に壊れるのは、何十
/// シーズンも回した後や、想定していない極端な入力を与えたときで、
/// **通しで走らせないと見えない**。実際、クラブ方針の効き方が試合結果を
/// 押し潰していた不具合は、5シーズン通しで初めて見つかった。
///
/// 手元では100シーズン(21分)まで確認している。ここに置くのはCIで回せる
/// 長さに絞ったもので、確かめている内容は同じ。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 値が取りうる範囲に収まっているか。壊れた項目名を返す。
  List<String> invariantViolations(GameState game, String label) {
    final problems = <String>[];
    final s = game.save!;
    final team = game.userTeam;
    final league = s.league;

    void check(bool ok, String message) {
      if (!ok) problems.add('$label $message');
    }

    check(s.confidence >= 0 && s.confidence <= 100, '信頼度=${s.confidence}');
    check(s.currentDivisionTier >= 1 && s.currentDivisionTier <= 5,
        'ティア=${s.currentDivisionTier}');
    check(team.players.length >= minSquadSize, '選手数=${team.players.length}');
    check(team.players.length <= maxSquadSize, '選手数=${team.players.length}');
    check(team.currentFamiliarity >= 0 && team.currentFamiliarity <= 100,
        '習熟度=${team.currentFamiliarity}');
    check(league.teams.length >= 2, 'チーム数=${league.teams.length}');
    check(league.sortedStandings.length == league.teams.length, '順位表の件数');

    for (final p in team.players) {
      check(p.age >= 15 && p.age <= 45, '年齢 ${p.name}=${p.age}');
      check(p.overall >= 1 && p.overall <= 99, '総合 ${p.name}=${p.overall}');
      check(p.morale >= 0 && p.morale <= 100, '士気 ${p.name}');
      check(p.fatigue >= 0 && p.fatigue <= 100, '疲労 ${p.name}');
      check(p.wage >= 0, '週俸 ${p.name}=${p.wage}');
      check(p.marketValue > 0, '市場価値 ${p.name}=${p.marketValue}');
    }

    // 放出・引退した選手を指し続けていないか。指していると、その選手を
    // 開こうとした画面が落ちる。
    final ids = team.players.map((p) => p.id).toSet();
    void ref(String name, String? id) {
      check(id == null || ids.contains(id), '参照切れ $name');
    }
    ref('キャプテン', team.captainId);
    ref('副キャプテン', team.viceCaptainId);
    ref('PK', team.penaltyTakerId);
    ref('FK', team.freeKickTakerId);
    ref('CK', team.cornerTakerId);
    ref('マンマーク', team.manMarkerId);
    ref('セットプレー守備', team.setPieceDefenderId);
    for (final id in team.startingXI) {
      check(ids.contains(id), '参照切れ スタメン');
    }
    for (final o in s.incomingOffers) {
      check(ids.contains(o.playerId), '参照切れ オファー ${o.playerName}');
    }
    return problems;
  }

  Future<void> playSeasons(GameState game, int seasons) async {
    for (int i = 0; i < seasons; i++) {
      int guard = 0;
      while (!game.save!.league.isSeasonComplete && guard++ < 60) {
        await game.simulateAheadMatchdays(10);
      }
      if (i < seasons - 1) await game.startNextSeason();
    }
  }

  test('10シーズン回しても、値が壊れず参照も切れない', () async {
    final game = GameState();
    await game.startNewGame('耐久FC');

    final problems = <String>[];
    for (int season = 1; season <= 10; season++) {
      int guard = 0;
      while (!game.save!.league.isSeasonComplete && guard++ < 60) {
        await game.simulateAheadMatchdays(10);
      }
      problems.addAll(invariantViolations(game, 'S$season'));
      if (season < 10) await game.startNextSeason();
    }

    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('長く遊んでもセーブが保存・復元でき、容量も収まる', () async {
    final game = GameState();
    await game.startNewGame('容量FC');
    await playSeasons(game, 10);

    final encoded = jsonEncode(game.save!.toJson());
    final restored = SaveGame.fromJson(jsonDecode(encoded));

    expect(restored.userTeamId, game.save!.userTeamId);
    expect(restored.league.teams.length, game.save!.league.teams.length);

    // ブラウザの localStorage で実測した上限は約1,300万文字。
    // スロットは3つあるので、1スロットあたり400万文字を超えないこと。
    // 実測では100シーズンで約195万文字だった。
    expect(encoded.length, lessThan(4000000),
        reason: 'セーブが大きすぎる: ${encoded.length}文字');
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('最強のスカッドでも値が壊れない', () async {
    final game = GameState();
    await game.startNewGame('最強FC');
    game.save!.budget = 99999999;
    for (final p in game.userTeam.players) {
      for (final k in AttributeKeys.all) {
        p.setAttributeValue(k, 99);
      }
      p.potential = 99;
      p.age = 25;
      p.morale = 100;
      p.fatigue = 0;
    }

    await playSeasons(game, 5);

    expect(invariantViolations(game, '最強'), isEmpty);
    // 資金が青天井に発散しないこと。
    expect(game.save!.budget, lessThan(1000000000));
    for (final p in game.userTeam.players) {
      expect(p.marketValue, lessThanOrEqualTo(20000));
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('最弱・赤字のスカッドでも成り立つ', () async {
    final game = GameState();
    await game.startNewGame('最弱FC');
    game.save!.budget = -5000;
    for (final p in game.userTeam.players) {
      for (final k in AttributeKeys.all) {
        p.setAttributeValue(k, 1);
      }
      p.potential = 20;
      p.morale = 0;
      p.happiness = 0;
      p.fatigue = 100;
    }

    await playSeasons(game, 5);

    expect(invariantViolations(game, '最弱'), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('全員が負傷・出場停止でも試合を進められる', () async {
    final game = GameState();
    await game.startNewGame('満身創痍FC');
    for (final p in game.userTeam.players) {
      p.injuryWeeks = 8;
      p.suspendedMatches = 5;
    }

    // 出せる選手がいない状況でも、例外で止まらないこと。
    await game.simulateAheadMatchdays(5);

    expect(invariantViolations(game, '全員離脱'), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('戦術と指示を両端に振っても壊れない', () async {
    final game = GameState();
    await game.startNewGame('極端FC');
    final t = game.userTeam;
    t.pressing = 100;
    t.lineHeight = 100;
    t.width = 100;
    t.tempo = 100;
    for (final p in t.players) {
      p.instruction = PlayerInstruction.getForward;
    }

    await playSeasons(game, 3);

    expect(invariantViolations(game, '極端設定'), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('壊れたセーブを読んでも、アプリは落ちずに空スロット扱いになる', () {
    // 保存形式が変わったときや書き込みが途中で切れたときに、起動できなく
    // なるのが最悪の壊れ方。GameState 側は try/catch で握って null に
    // するので、ここでは「fromJson が投げる」ことだけを固定しておく。
    // 握りを外したら、この前提が崩れたと気づける。
    expect(() => SaveGame.fromJson(<String, dynamic>{}), throwsA(anything));
  });
}
