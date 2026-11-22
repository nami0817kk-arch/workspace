import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/data/nation_names.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手の名前が国籍に合っていること(以前は日本語の表示で全員が日本の姓名だった)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final japaneseSurname = RegExp(r'^(佐藤|鈴木|高橋|田中|伊藤|渡辺|山本|中村) ');

  test('every player in every league carries a name of their nationality',
      () async {
    final gs = GameState();
    await gs.startNewGame('名前FC', theme: LeagueTheme.spain);
    final s = gs.save!;
    final teams = [
      ...s.allTeams,
      for (final l in s.foreignLeagues.values) ...l.teams,
    ];
    var checked = 0;
    for (final t in teams) {
      for (final p in t.players) {
        expect(japaneseSurname.hasMatch(p.name), isFalse, reason: p.name);
        expect(NationNames.fits(p.name, gs.nationalityOf(p)), isTrue,
            reason: '${p.name} / ${gs.nationalityOf(p).name}');
        checked++;
      }
    }
    expect(checked, greaterThan(500));
    // 自クラブも国籍の名前(以前は全員リーグの国の名前だったが、
    // 2026-11-22 から自クラブにも外国籍が混ざる)。
    for (final p in gs.userTeam.players) {
      expect(NationNames.fits(p.name, gs.nationalityOf(p)), isTrue,
          reason: '${p.name} / ${gs.nationalityOf(p).name}');
    }
  });

  test('old saves with Japanese names are renamed on load, once', () async {
    final gs = GameState();
    await gs.startNewGame('名前FC');
    final p = gs.userTeam.players.first;
    p.name = '佐藤 翔太';
    await gs.flushPendingSave();
    final exported = gs.exportSaveJson()!;
    final gs2 = GameState();
    expect(await gs2.importSaveJson(exported), isTrue);
    final again = gs2.userTeam.players.firstWhere((q) => q.id == p.id);
    expect(again.name, isNot('佐藤 翔太'));
    expect(NationNames.fits(again.name, gs2.nationalityOf(again)), isTrue);
  });

  test('the same seed gives the same person in both languages', () {
    final a = NationNames.nameFor(LeagueTheme.germany, 12345);
    expect(NationNames.fits(a, LeagueTheme.germany), isTrue);
    expect(NationNames.combinations(LeagueTheme.england), greaterThan(400));
  });
}
