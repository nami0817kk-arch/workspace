import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_stub.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('軽い形から何度作り直しても同じ選手になり、総合力も保たれる', () {
    for (var i = 0; i < 30; i++) {
      final p = PlayerGenerator.generate(
          position: Position.values[i % Position.values.length],
          strengthTier: 40 + i * 2);
      final stub = PlayerStub.encode(p);
      final a = PlayerStub.decode(jsonDecode(jsonEncode(stub)) as List);
      final b = PlayerStub.decode(jsonDecode(jsonEncode(stub)) as List);
      expect(a.id, p.id);
      expect(a.name, p.name);
      expect(a.age, p.age);
      expect(a.position, p.position);
      expect(a.overall, p.overall, reason: '${p.position} ${p.overall}');
      expect(a.attributes, b.attributes);
      // 作り直した選手をもう一度軽い形にしても、同じ並びになる
      expect(PlayerStub.encode(a), PlayerStub.encode(b));
      expect(PlayerStub.encode(a), stub);
    }
  });

  test('新しいゲームでは、自国の全部と他の4か国の1部のクラブが選手を持つ', () async {
    final gs = GameState();
    await gs.startNewGame('全員FC', theme: LeagueTheme.england);
    final save = gs.save!;
    for (final l in save.otherDivisionLeagues) {
      if (l == null) continue;
      for (final t in l.teams) {
        expect(t.players.length, greaterThanOrEqualTo(22), reason: t.name);
      }
    }
    expect(save.foreignLeagues.keys.toSet(),
        {'spain', 'germany', 'italy', 'france'});
    for (final e in save.foreignLeagues.entries) {
      final theme = LeagueTheme.values.byName(e.key);
      expect(e.value.teams.length, theme.teamsInTier(1));
      for (final t in e.value.teams) {
        expect(t.players.length, greaterThanOrEqualTo(22));
      }
    }
    // 全部で数千人(イングランド風 116 クラブ + 他国 76 クラブ)
    expect(save.allPlayers.length, greaterThan(4000));
  });

  test('保存して読み込んでも、他の部と他国の選手がそのまま残る', () async {
    final gs = GameState();
    await gs.startNewGame('保存FC', theme: LeagueTheme.germany);
    final save = gs.save!;
    final raw = jsonEncode(save.toJson());
    final loaded = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    Map<String, (String, int, int)> snapshot(SaveGame s) => {
          for (final p in s.allPlayers) p.id: (p.name, p.age, p.overall),
        };
    expect(snapshot(loaded), snapshot(save));
    // 大きさは数MBにならない(全部を細かく持つと 8MB ほどになる)
    expect(raw.length, lessThan(2500000), reason: '${raw.length} bytes');
  });
}
