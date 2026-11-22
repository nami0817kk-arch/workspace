import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手の国籍と労働許可の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 以前は「9割がその国の国籍」だった。実在の1部は外国籍が5〜7割
  // (スペイン・フランスは約45%)なので、自国籍は3〜6割になる(2026-11-22)。
  test('他の国の1部の選手は、自国籍が3〜6割', () async {
    final gs = GameState();
    await gs.startNewGame('国籍FC');
    for (final e in gs.save!.foreignLeagues.entries) {
      final players = e.value.teams.expand((t) => t.players).toList();
      final same =
          players.where((p) => gs.nationalityOf(p).name == e.key).length;
      expect(same / players.length, inInclusiveRange(0.28, 0.65),
          reason: e.key);
    }
    // 自クラブと自由契約は自国。
    expect(gs.userTeam.players.every((p) =>
        gs.nationalityOf(p) == gs.currentLeagueTheme), isTrue);
    expect(gs.freeAgents.every((p) =>
        gs.nationalityOf(p) == gs.currentLeagueTheme), isTrue);
  });

  test('移るときに国籍を覚え、移ったあとも変わらない', () async {
    final gs = GameState();
    await gs.startNewGame('国籍FC');
    final p = gs.save!.foreignLeagues.values.first.teams.first.players.first;
    final before = gs.nationalityOf(p);
    p.nation ??= before.name;
    expect(gs.nationalityOf(p), before);
    expect(Player.fromJson(p.toJson()).nation, before.name);
  });

  test('アルビオン式では、外国籍の弱い選手に労働許可が下りない', () async {
    final gs = GameState();
    await gs.startNewGame('国籍FC');
    if (gs.currentLeagueTheme != LeagueTheme.england) return;
    final tier = gs.save!.currentDivisionTier;
    final need = gs.workPermitMinimum(tier);
    final foreign = gs.save!.foreignLeagues.values
        .expand((l) => l.teams)
        .expand((t) => t.players)
        .where((p) => gs.nationalityOf(p) != gs.currentLeagueTheme);
    final weak = foreign.where((p) => p.overall < need).firstOrNull;
    final strong = foreign.where((p) => p.overall >= need).firstOrNull;
    if (weak != null) expect(gs.workPermitBlock(weak), isNotNull);
    if (strong != null) expect(gs.workPermitBlock(strong), isNull);
    expect(gs.workPermitMinimum(1), greaterThan(gs.workPermitMinimum(5)));
    // 自国の選手には要らない。
    expect(gs.workPermitBlock(gs.userTeam.players.first), isNull);
  });
}
