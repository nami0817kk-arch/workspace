// otherDivisionLeagues の容量削減にあたって、既存セーブが壊れないことを固定する。
//
// 削減本体より先にこのファイルを入れる。ここが通らないうちは削減に着手しない。
// 守る順序は「利用者の既存データが失われない」が最優先で、挙動の劣化はその次。
// 経緯は lib/models/save_game.dart の otherDivisionLeagues 宣言直下を参照。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 指定した強さのスカッドを持つチームを作る。
Team _teamWithSquad(String id, int strengthTier) {
  final players = [
    for (int i = 0; i < 11; i++)
      PlayerGenerator.generate(position: Position.mc, strengthTier: strengthTier),
  ];
  final t = Team(id: id, name: id, players: players);
  t.startingXI.addAll(players.map((p) => p.id));
  return t;
}

/// 他ディビジョンを1つ持つセーブ。ユーザーは1部、2部に4チーム。
SaveGame _saveWithOtherDivision() {
  final userLeague = League(
    teams: [_teamWithSquad('user', 70), _teamWithSquad('rival', 68)],
    fixtures: const [],
  );
  final second = League(
    teams: [
      _teamWithSquad('d2a', 55),
      _teamWithSquad('d2b', 50),
      _teamWithSquad('d2c', 45),
      _teamWithSquad('d2d', 40),
    ],
    fixtures: const [],
  );
  final others = List<League?>.filled(totalDivisionTiers, null);
  others[1] = second;
  return SaveGame(
    clubName: 'テストFC',
    userTeamId: 'user',
    league: userLeague,
    otherDivisionLeagues: others,
    currentDivisionTier: 1,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('旧形式(他ディビジョンが選手データを持つ)のセーブ', () {
    test('読み込めて、他ディビジョンのチーム強度が保たれる', () {
      final save = _saveWithOtherDivision();
      final before = {
        for (final t in save.otherDivisionLeagues[1]!.teams)
          t.id: t.overallRating,
      };
      // 前提: 生成した時点で強度がついている(0 なら以降の検査が無意味)。
      expect(before.values.every((r) => r > 0), isTrue,
          reason: '選手を持つチームは overallRating が 0 より大きいはず');

      final restored =
          SaveGame.fromJson(jsonDecode(jsonEncode(save.toJson())));
      final after = {
        for (final t in restored.otherDivisionLeagues[1]!.teams)
          t.id: t.overallRating,
      };

      expect(after, before,
          reason: '保存して読み直しても他ディビジョンのチーム強度は変わらない');
    });

    test('選手データを持ったままの JSON を読んでも落ちない', () {
      // 現行 master が書き出す形そのもの。将来 players を落とす形に変えても、
      // 既に端末にあるこの形を読めなければならない。
      final json = jsonDecode(jsonEncode(_saveWithOtherDivision().toJson()))
          as Map<String, dynamic>;
      final d2 = (json['otherDivisionLeagues'] as List)[1]
          as Map<String, dynamic>;
      final teams = d2['teams'] as List;

      expect(teams, isNotEmpty);
      expect(
        (teams.first as Map<String, dynamic>)['players'],
        isA<List>(),
        reason: '旧形式では他ディビジョンのチームも players を持っている',
      );

      final restored = SaveGame.fromJson(json);
      final team = restored.otherDivisionLeagues[1]!.teams.first;
      expect(team.overallRating, greaterThan(0),
          reason: '旧形式から読んだチームは選手から強度を計算できる');
    });

    test('順位表を組み立てられる', () {
      final save = _saveWithOtherDivision();
      final restored =
          SaveGame.fromJson(jsonDecode(jsonEncode(save.toJson())));
      final league = restored.otherDivisionLeagues[1]!;

      final standings = league.sortedStandings;
      expect(standings.length, league.teams.length,
          reason: '順位表には他ディビジョンの全チームが並ぶ');
      expect(
        standings.map((r) => r.teamId).toSet(),
        league.teams.map((t) => t.id).toSet(),
      );
    });

    test('保存すると他ディビジョンの選手データが落ち、強度だけが残る', () {
      final save = _saveWithOtherDivision();
      final before = {
        for (final t in save.otherDivisionLeagues[1]!.teams)
          t.id: t.overallRating,
      };

      final json = jsonDecode(jsonEncode(save.toJson()))
          as Map<String, dynamic>;
      final d2 =
          (json['otherDivisionLeagues'] as List)[1] as Map<String, dynamic>;
      for (final t in (d2['teams'] as List).cast<Map<String, dynamic>>()) {
        expect(t['players'], isEmpty,
            reason: '他ディビジョンのチームは選手データを保存しない');
        expect(t['retainedOverall'], isA<int>(),
            reason: '代わりに強度を残す');
      }

      final restored = SaveGame.fromJson(json);
      final after = {
        for (final t in restored.otherDivisionLeagues[1]!.teams)
          t.id: t.overallRating,
      };
      expect(after, before,
          reason: '選手を落としてもチーム強度は変わらない(背面シミュレーションの力量差が壊れない)');
      expect(after.values.every((r) => r > 0), isTrue,
          reason: '0 を返すと力量差が消える');
    });

    test('セーブが実際に小さくなる', () {
      final save = _saveWithOtherDivision();
      final reduced = jsonEncode(save.toJson()).length;

      // 比較用に、他ディビジョンも選手を持ったまま書き出した場合の大きさ。
      final full = jsonEncode({
        ...save.toJson(),
        'otherDivisionLeagues':
            save.otherDivisionLeagues.map((l) => l?.toJson()).toList(),
      }).length;

      expect(reduced, lessThan(full),
          reason: '他ディビジョンの選手データを落とした分だけ小さい');
      expect(reduced / full, lessThan(0.7),
          reason: '削減が効いていること(このセーブでは3割以上減る想定)');
    });

    test('ユーザーのチームは選手データを保持し続ける', () {
      // 削減の対象は他ディビジョンだけ。ユーザーのリーグを巻き込まないこと。
      final save = _saveWithOtherDivision();
      final restored =
          SaveGame.fromJson(jsonDecode(jsonEncode(save.toJson())));
      final user =
          restored.league.teams.firstWhere((t) => t.id == 'user');

      expect(user.players, isNotEmpty,
          reason: 'ユーザーの所属ディビジョンは選手を持ったまま');
      expect(user.startingXI, isNotEmpty,
          reason: 'スタメンの指定も残る');
    });
  });

  group('削減率の実測', () {
    // 合成データの比率は当てにならない(日程も結果も無いため)。
    // 1シーズン消化した実際のセーブで測り、数値をログに出す。
    test('1シーズン消化後のセーブで、他ディビジョンの選手を落とした効果を測る',
        () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      while (!gameState.save!.league.isSeasonComplete) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) {
          await gameState.playSecondHalf();
        }
      }

      final save = gameState.save!;
      final reduced = jsonEncode(save.toJson()).length;
      // 削減前の形: 他ディビジョンも選手データを持ったまま書き出す。
      final full = jsonEncode({
        ...save.toJson(),
        'otherDivisionLeagues':
            save.otherDivisionLeagues.map((l) => l?.toJson()).toList(),
      }).length;

      // ignore: avoid_print
      print('[save-size] 削減前=${(full / 1024).toStringAsFixed(1)}KB '
          '削減後=${(reduced / 1024).toStringAsFixed(1)}KB '
          '比率=${(reduced / full * 100).toStringAsFixed(1)}%');

      expect(reduced, lessThan(full), reason: '削減が効いていること');
    });
  });

  group('昇格してユーザーのディビジョンに入るチーム', () {
    // testWidgets は使わないこと。fake-async の中で実タイマーを待つと
    // シーズンの周回が進まず、10分でタイムアウトする(2026-09-03 に踏んだ)。
    // 既存のシーズン周回テストも全て素の test()。
    test('選手を持たない状態から、強度に見合うスカッドが用意される', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');

      // 保存を経たセーブと同じ状態にする(他ディビジョンは選手を持たない)。
      final stripped = <String, int>{};
      for (final other in gameState.save!.otherDivisionLeagues) {
        if (other == null) continue;
        for (final t in other.teams) {
          stripped[t.id] = t.overallRating;
          t.retainedOverall = t.overallRating;
          t.players = [];
          t.startingXI.clear();
        }
      }
      expect(stripped, isNotEmpty, reason: '他ディビジョンが存在する前提');

      while (!gameState.save!.league.isSeasonComplete) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) {
          await gameState.playSecondHalf();
        }
      }
      await gameState.startNextSeason();

      // ユーザーと同じディビジョンのチームは選手ごとに試合を進めるので、
      // 全チームがスカッドを持っていなければならない。
      for (final t in gameState.save!.league.teams) {
        expect(t.players, isNotEmpty,
            reason: '${t.name} に選手がいないと MatchEngine が試合を組めない');
        expect(t.overallRating, greaterThan(0),
            reason: '${t.name} の強度が 0 だと力量差が壊れる');
      }

      // 他ディビジョンのままのチームは、選手を持たずに強度だけを保つ。
      for (final other in gameState.save!.otherDivisionLeagues) {
        if (other == null) continue;
        for (final t in other.teams) {
          expect(t.overallRating, greaterThan(0),
              reason: '${t.name} は選手がいなくても順位表と昇降格のために強度が要る');
        }
      }
    });
  });
}
