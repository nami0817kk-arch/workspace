// otherDivisionLeagues の容量削減にあたって、既存セーブが壊れないことを固定する。
//
// 削減本体より先にこのファイルを入れる。ここが通らないうちは削減に着手しない。
// 守る順序は「利用者の既存データが失われない」が最優先で、挙動の劣化はその次。
// 経緯は lib/models/save_game.dart の otherDivisionLeagues 宣言直下を参照。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';

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
}
