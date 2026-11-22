import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/club_license.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('条件: 1部はスタジアム3、2部は2、1〜3部は資金がマイナスでない', () {
    expect(ClubLicenseEngine.unmet(4, stadiumLevel: 1, budget: -100), isEmpty);
    expect(ClubLicenseEngine.unmet(3, stadiumLevel: 1, budget: 0), isEmpty);
    expect(ClubLicenseEngine.unmet(3, stadiumLevel: 1, budget: -1).length, 1);
    expect(ClubLicenseEngine.unmet(2, stadiumLevel: 1, budget: 0).length, 1);
    expect(ClubLicenseEngine.unmet(2, stadiumLevel: 2, budget: 0), isEmpty);
    expect(ClubLicenseEngine.unmet(1, stadiumLevel: 2, budget: -1).length, 2);
  });

  /// 自クラブが全勝、ほかは全部引き分けで季を終わらせる(首位で昇格の権利)。
  void winEverything(GameState gs) {
    final userId = gs.userTeam.id;
    for (final f in gs.save!.league.fixtures) {
      final home = f.homeTeamId == userId;
      final away = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: home ? 3 : (away ? 0 : 1),
        awayGoals: away ? 3 : (home ? 0 : 1),
        events: [],
      );
    }
  }

  // 3部制(2026-11-22)。新しいゲームは最下部の3部から始まり、2部へ上がる
  // にはライセンス(スタジアム2・資金がマイナスでない)を見る。

  test('首位でも、資金がマイナスなら2部へ上がれず、権利は2位に移る', () async {
    final gs = GameState();
    await gs.startNewGame('赤字FC');
    expect(gs.currentDivisionTier, 3);
    gs.save!.infrastructure.facilityLevels[FacilityType.stadium] = 2;
    winEverything(gs);
    // 季末の賞金などで判定の前にプラスへ戻らないよう、大きく赤字にする。
    gs.save!.budget = -10000000;
    expect(gs.clubLicenseUnmet(2), isNotEmpty);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 3);
    expect(gs.lastDivisionChangeMessage, isNotNull);
    expect(gs.lastDivisionChangeMessage!.toLowerCase(),
        anyOf(contains('ライセンス'), contains('licence')));
  });

  test('首位で資金とスタジアムが足りていれば、2部へ上がれる', () async {
    final gs = GameState();
    await gs.startNewGame('黒字FC');
    gs.save!.infrastructure.facilityLevels[FacilityType.stadium] = 2;
    winEverything(gs);
    gs.save!.budget = 1000000;
    expect(gs.clubLicenseUnmet(2), isEmpty);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 2);
    expect(gs.save!.licenseGraceTier, 0, reason: '足りていれば猶予は付かない');
  });

  // スタジアムの1年の猶予(2026-11-23)。

  // 文字列は日本語・英語のどちらで動いても見られるようにする。
  bool isGraceNews(String t) => t.contains('猶予') || t.contains('grace');
  bool isRefusedNews(String t) =>
      t.contains('ライセンスが下りませんでした') || t.contains('licence was refused');

  /// スタジアムLv1のまま首位で季を終え、猶予つきで2部へ上がる。
  Future<GameState> promotedOnGrace(String name) async {
    final gs = GameState();
    await gs.startNewGame(name);
    final s = gs.save!;
    expect(s.infrastructure.facilityLevel(FacilityType.stadium), 1);
    winEverything(gs);
    s.budget = 1000000;
    expect(gs.clubLicenseUnmet(2), isNotEmpty);
    expect(gs.clubLicenseUnmetExceptStadium(2), isEmpty);
    await gs.startNextSeason();
    return gs;
  }

  test('スタジアムだけが足りなくても、1年の猶予つきで昇格できる', () async {
    final gs = await promotedOnGrace('猶予FC');
    final s = gs.save!;
    expect(gs.currentDivisionTier, 2);
    expect(s.licenseGraceTier, 2);
    expect(s.licenseGraceSeason, s.league.season);
    expect(gs.inStadiumGrace, isTrue);
    expect(gs.stadiumGraceLevel, 2);
    expect(gs.stadiumGraceNote, anyOf(contains('猶予'), contains('grace')));
    expect(gs.stadiumGraceNote, anyOf(contains('Lv2'), contains('level 2')));
    expect(gs.lastDivisionChangeMessage,
        anyOf(contains('猶予'), contains('grace')));
    expect(s.newsLog.any((n) => isGraceNews(n.text)), isTrue);
  });

  test('資金がマイナスなら、スタジアムの猶予があっても上がれない', () async {
    final gs = GameState();
    await gs.startNewGame('赤字猶予FC');
    winEverything(gs);
    gs.save!.budget = -10000000;
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 3);
    expect(gs.save!.licenseGraceTier, 0);
  });

  test('猶予の季の終わりにスタジアムが届いていれば、何も起きない', () async {
    final gs = await promotedOnGrace('間に合うFC');
    final s = gs.save!;
    s.budget = 99999999;
    // 猶予の季のうちに着工すれば、来季の開幕までに完成するので届いた扱い。
    expect(await gs.upgradeFacility(FacilityType.stadium), isTrue);
    expect(gs.stadiumMeetsLicense(2), isTrue);
    // 中位で終える(昇格も降格も無い順位): 全部引き分け。
    for (final f in s.league.fixtures) {
      f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: []);
    }
    await gs.startNextSeason();
    // 順位しだいで昇格・降格はありうるが、ライセンスでは落ちない。
    expect(s.licenseGraceTier, isNot(2), reason: '2部の猶予は使い切る');
    expect(s.infrastructure.facilityLevel(FacilityType.stadium), 2);
    expect(s.newsLog.any((n) => isRefusedNews(n.text)), isFalse);
    expect(gs.lastDivisionChangeMessage ?? '',
        isNot(anyOf(contains('条件に届かず'), contains('fell short'))));
  });

  test('猶予の季の終わりにスタジアムが足りなければ、降格処分になる', () async {
    final gs = await promotedOnGrace('間に合わないFC');
    final s = gs.save!;
    // 2部で全勝しても(昇格の権利があっても)、ライセンスで落ちる。
    winEverything(gs);
    s.budget = 99999999;
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 3);
    expect(s.licenseGraceTier, 0);
    expect(s.adminRelegation, isFalse, reason: '処分はこの季で使い切る');
    expect(gs.lastDivisionChangeMessage,
        anyOf(contains('ライセンス'), contains('licence')));
    expect(s.newsLog.any((n) => isRefusedNews(n.text)), isTrue);
  });

  test('猶予の状態は保存して読み戻せ、無い旧セーブは猶予なしで読める', () async {
    final gs = await promotedOnGrace('保存猶予FC');
    final json = gs.save!.toJson();
    final restored = SaveGame.fromJson(json);
    expect(restored.licenseGraceTier, 2);
    expect(restored.licenseGraceSeason, gs.save!.licenseGraceSeason);

    json
      ..remove('licenseGraceTier')
      ..remove('licenseGraceSeason');
    final legacy = SaveGame.fromJson(json);
    expect(legacy.licenseGraceTier, 0);
    expect(legacy.licenseGraceSeason, 0);
  });
}
