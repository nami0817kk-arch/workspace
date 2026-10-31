import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// [p] を ID だけ変えて複製する。
Player _withId(Player p, String id) => Player.fromJson({...p.toJson(), 'id': id});

/// 次に払い出される選手IDの番号。
int _nextIdNumber() {
  final peek = PlayerGenerator.generate(position: Position.st, strengthTier: 50);
  return int.parse(peek.id.substring(2)) + 1;
}

/// 保存して、別の GameState で読み直す(再起動の代わり)。
Future<GameState> _reload(GameState game) async {
  await game.flushPendingSave();
  final reloaded = GameState();
  await reloaded.init();
  return reloaded;
}

List<String> _allIds(GameState game) => [
      for (final p in game.save!.allPlayers) p.id,
      for (final p in game.scoutCandidates) p.id,
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('監督オファーの相手が別のリーグへ移った', () {
    String otherDivisionTeamId(GameState game) => game.save!.otherDivisionLeagues
        .firstWhere((l) => l != null && l.teams.isNotEmpty)!
        .teams
        .first
        .id;

    test('pendingJobOfferTeam は落ちずに null を返し、オファーを消す', () async {
      final game = GameState();
      await game.startNewGame('オファーFC');
      game.save!.pendingJobOfferTeamId = otherDivisionTeamId(game);

      expect(() => game.pendingJobOfferTeam, returnsNormally);
      expect(game.save!.pendingJobOfferTeamId, isNotNull,
          reason: '前提: まだ消えていない');
      expect(game.pendingJobOfferTeam, isNull);
      expect(game.save!.pendingJobOfferTeamId, isNull,
          reason: '成り立たないオファーが残っている');
    });

    test('acceptJobOffer は何もせずに false を返す', () async {
      final game = GameState();
      await game.startNewGame('オファーFC');
      final userTeamId = game.save!.userTeamId;
      final clubs = List.of(game.save!.clubHistory);
      game.save!.pendingJobOfferTeamId = otherDivisionTeamId(game);

      final ok = await game.acceptJobOffer();

      expect(ok, isFalse);
      expect(game.save!.userTeamId, userTeamId, reason: 'クラブが変わってしまった');
      expect(game.save!.clubHistory, clubs);
      expect(game.save!.pendingJobOfferTeamId, isNull);
    });

    test('既に詰んだセーブも読み込みで直る', () async {
      final game = GameState();
      await game.startNewGame('オファーFC');
      game.save!.pendingJobOfferTeamId = otherDivisionTeamId(game);

      final reloaded = await _reload(game);
      expect(reloaded.save!.pendingJobOfferTeamId, isNull,
          reason: '読み込み時に成り立たないオファーを消していない');
      expect(() => reloaded.pendingJobOfferTeam, returnsNormally);
    });

    test('同じリーグのクラブからのオファーは残る', () async {
      final game = GameState();
      await game.startNewGame('オファーFC');
      final teamId = game.save!.league.teams
          .firstWhere((t) => t.id != game.save!.userTeamId)
          .id;
      game.save!.pendingJobOfferTeamId = teamId;

      final reloaded = await _reload(game);
      expect(reloaded.save!.pendingJobOfferTeamId, teamId);
      expect(reloaded.pendingJobOfferTeam?.id, teamId);
    });
  });

  group('再起動後に選手IDが重複しない', () {
    // 再起動の代わりに、カウンターより先のIDを1か所にだけ置いて読み直す。
    // そこを数えていなければ、読み込み後に作る選手(スカウト候補など)が
    // 同じIDになる。
    final pools = <String, void Function(SaveGame save, Player p)>{
      'transferMarketPlayers': (s, p) => s.transferMarketPlayers.add(p),
      'freeAgents': (s, p) => s.freeAgents.add(p),
      'pendingYouthIntake': (s, p) => s.pendingYouthIntake.add(p),
      'youthProspects': (s, p) => s.youthProspects.add(p),
      'retiredLegends': (s, p) => s.retiredLegends.add(p),
      'continentalTeams': (s, p) => s.continentalTeams.first.players.add(p),
      'otherDivisionLeagues': (s, p) => s.otherDivisionLeagues
          .firstWhere((l) => l != null)!
          .teams
          .first
          .players
          .add(p),
    };

    for (final entry in pools.entries) {
      test('${entry.key} の選手を数えている', () async {
        final game = GameState();
        await game.startNewGame('ID FC');
        final template = game.save!.league.teams.first.players.first;
        // 海外クラブは大陸カップに出るまで居ない。作るとIDを使うので、
        // 次のIDを覗く前に作っておく。
        if (game.save!.continentalTeams.isEmpty) {
          game.save!.continentalTeams.add(PlayerGenerator.generateSquad(
              id: 'continental_test', name: 'Test Club', strengthTier: 60));
        }
        final n = _nextIdNumber();
        final ahead = 'pl$n';
        entry.value(game.save!, _withId(template, ahead));

        final reloaded = await _reload(game);
        final ids = _allIds(reloaded);
        expect(ids.where((id) => id == ahead).length, 1,
            reason: '${entry.key} の選手と同じIDの選手が作られた');
        expect(ids.toSet().length, ids.length, reason: '選手IDが重複している');

        final fresh =
            PlayerGenerator.generate(position: Position.mc, strengthTier: 50);
        expect(ids.contains(fresh.id), isFalse,
            reason: '読み込み後に作った選手が既存のIDになった');
      });
    }

    test('既に重複したIDは読み込みで振り直す(参照されない側だけ)', () async {
      final game = GameState();
      await game.startNewGame('ID FC');
      final save = game.save!;
      final userPlayer =
          save.league.teams.firstWhere((t) => t.id == save.userTeamId).players.first;
      final marketPlayer = save.transferMarketPlayers.first;
      save.transferMarketPlayers[0] = _withId(marketPlayer, userPlayer.id);
      save.freeAgents.add(_withId(marketPlayer, userPlayer.id));

      final reloaded = await _reload(game);
      final re = reloaded.save!;
      final ids = _allIds(reloaded);
      expect(ids.toSet().length, ids.length, reason: '重複が残っている');

      final userTeam = re.league.teams.firstWhere((t) => t.id == re.userTeamId);
      expect(userTeam.players.first.id, userPlayer.id,
          reason: '自クラブの選手のIDは変えない(先発・主将などから参照される)');
      expect(userTeam.players.first.name, userPlayer.name);
      expect(re.transferMarketPlayers.first.id, isNot(userPlayer.id));
      expect(re.transferMarketPlayers.first.name, marketPlayer.name,
          reason: '振り直しで選手の中身が変わった');
    });

    test('重複が無ければ何も振り直さない', () async {
      final game = GameState();
      await game.startNewGame('ID FC');
      final copy = SaveGame.fromJson(game.save!.toJson());
      final before = [for (final p in copy.allPlayers) p.id];
      expect(copy.renumberDuplicatePlayerIds(PlayerGenerator.nextPlayerId), 0);
      expect([for (final p in copy.allPlayers) p.id], before);
    });
  });
}
