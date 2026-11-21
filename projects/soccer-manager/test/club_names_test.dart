import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/club_names.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

/// クラブ名・大会名を実在に寄せた(2026-11-22。ユースのアプリと同じ付け方)。
void main() {
  tearDown(() => Tr.language = AppLanguage.system);

  test('どの国のどの部も、部のクラブ数ぶんの名前があり、国の中で重ならない', () {
    for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
      Tr.language = lang;
      for (final theme in LeagueTheme.values) {
        final all = <String>[];
        for (var tier = 1; tier <= totalDivisionTiers; tier++) {
          final names = ClubNames.tier(theme, tier);
          expect(names.length, greaterThanOrEqualTo(theme.teamsInTier(tier)),
              reason: '$theme $tier部 $lang');
          all.addAll(names);
        }
        expect(all.toSet().length, all.length, reason: '$theme $lang');
        for (final n in all) {
          expect(n.trim(), isNotEmpty);
          expect(n.contains('|'), isFalse);
        }
      }
    }
  });

  test('保存されたリーグ名から国を引ける(前の名前・英語でも)', () {
    Tr.language = AppLanguage.japanese;
    expect(leagueThemeFromName('アルビオン・リーグ'), LeagueTheme.england);
    expect(leagueThemeFromName('Iberia League'), LeagueTheme.spain);
    expect(leagueThemeFromName(LeagueTheme.italy.label), LeagueTheme.italy);
    expect(leagueThemeFromName('Serie Prima'), LeagueTheme.italy);
    expect(leagueThemeFromName('どこでもない'), isNull);
    expect(LeagueTheme.england.divisionName(1), 'プレミア・ディビジョン');
    expect(LeagueTheme.germany.divisionName(3), 'ドイツ3部リーグ');
  });

  test('新しいゲームのクラブは、その部の実在に寄せた名前になり、書き換えられる',
      () async {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
    final gs = GameState();
    await gs.startNewGame('自分FC');
    final s = gs.save!;
    final tier3 = ClubNames.tier(LeagueTheme.england, 3).toSet();
    for (final t in s.league.teams) {
      if (t.id == s.userTeamId) continue;
      expect(tier3.contains(t.name), isTrue, reason: t.name);
    }
    final tier1 = ClubNames.tier(LeagueTheme.england, 1).toSet();
    for (final t in s.otherDivisionLeagues[0]!.teams) {
      expect(tier1.contains(t.name), isTrue, reason: t.name);
    }
    expect(gs.leagueDisplayName, 'リーグ・ディビジョン1');

    final other = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    expect(await gs.renameClub(other.id, '  わたしの好きな名前  '), isTrue);
    expect(other.name, 'わたしの好きな名前');
    expect(await gs.renameClub(other.id, '   '), isFalse);
    expect(await gs.renameClub(s.userTeamId, '新しい自分FC'), isTrue);
    expect(s.clubName, '新しい自分FC');
    expect(gs.userTeam.name, '新しい自分FC');
  });
}
