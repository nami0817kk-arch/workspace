import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 施設の増築(2026-11-23): 費用は部で変えず、スタジアムは「席の数 × 1席の
/// 値段」。工事には時間が掛かり、完成までは効き目が出ない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 自クラブが全勝、ほかは全部引き分けで季を終わらせる。
  void finishLeague(GameState gs) {
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

  test('スタジアムの工事費は、増やす席の数 × 1席の値段', () {
    for (var lvl = 1; lvl < ClubInfrastructure.maxLevel; lvl++) {
      expect(
        ClubInfrastructure.stadiumUpgradeCost(lvl),
        ClubInfrastructure.stadiumSeatsPerLevel *
            ClubInfrastructure.stadiumSeatCost(lvl),
      );
      // 1席は数十万〜百万円台(万円で 20〜200)。
      expect(
        ClubInfrastructure.stadiumSeatCost(lvl),
        inInclusiveRange(20, 200),
      );
      // 1段で増える席は、収容人数の差と同じ。
      expect(
        ClubInfrastructure.stadiumCapacity(lvl + 1) -
            ClubInfrastructure.stadiumCapacity(lvl),
        ClubInfrastructure.stadiumSeatsPerLevel,
      );
    }
    // Lv1→2 は12億、Lv7→8 は84億。
    expect(ClubInfrastructure.stadiumUpgradeCost(1), 120000);
    expect(ClubInfrastructure.stadiumUpgradeCost(7), 840000);
    // ほかの施設は段ごとの固定の額で、上の段ほど高い。
    expect(ClubInfrastructure.facilityUpgradeCost(1), 15000);
    expect(
      ClubInfrastructure.facilityUpgradeCost(2),
      greaterThan(ClubInfrastructure.facilityUpgradeCost(1)),
    );
  });

  test('工事費は、いる部で変わらない', () async {
    final gs = GameState();
    await gs.startNewGame('部FC');
    final s = gs.save!;
    final costs = {
      for (final f in FacilityType.values) f: gs.facilityUpgradeCostFor(f),
    };
    for (final tier in [1, 2, 3]) {
      s.currentDivisionTier = tier;
      for (final f in FacilityType.values) {
        expect(gs.facilityUpgradeCostFor(f), costs[f], reason: '$tier部 $f');
      }
    }
  });

  test('3部の初めの資金ではスタジアムに届かないが、年収の範囲で数季貯めれば届く', () async {
    final gs = GameState();
    await gs.startNewGame('貯金FC');
    final cost = gs.facilityUpgradeCostFor(FacilityType.stadium);
    final initial = GameState.initialBudgetFor(3, gs.currentLeagueTheme);
    expect(cost, greaterThan(initial));
    // 初めの資金(年収の半分)の3倍までには収まる。
    expect(cost, lessThan(initial * 3));
  });

  test('ほかの施設は3か月後に完成し、それまでは効き目が出ない', () async {
    final gs = GameState();
    await gs.startNewGame('工事FC');
    final s = gs.save!;
    s.budget = 99999999;
    const type = FacilityType.trainingGround;
    final start = gs.today;
    final cost = gs.facilityUpgradeCostFor(type);

    expect(await gs.upgradeFacility(type), isTrue);
    expect(s.budget, 99999999 - cost, reason: '費用は着工のときに払う');
    expect(s.infrastructure.facilityLevel(type), 1, reason: '完成までは上がらない');
    final ready = s.infrastructure.constructionReadyOn(type)!;
    expect(ready, DateTime(start.year, start.month + 3, start.day));
    expect(s.newsLog.first.text, contains(ready.year.toString()));

    // 工事中は重ねて増築できない(お金も減らない)。
    final before = s.budget;
    expect(await gs.upgradeFacility(type), isFalse);
    expect(s.budget, before);

    // 完成の前の日まではそのまま。
    gs.debugAdvanceTodayTo(ready.subtract(const Duration(days: 1)));
    expect(s.infrastructure.facilityLevel(type), 1);
    expect(s.infrastructure.isUnderConstruction(type), isTrue);

    // 完成の日に上がり、ニュースで知らせる。
    gs.debugAdvanceTodayTo(ready);
    expect(s.infrastructure.facilityLevel(type), 2);
    expect(s.infrastructure.isUnderConstruction(type), isFalse);
    expect(s.newsLog.any((n) => n.text.contains(type.label)), isTrue);

    // 完成したら次の段を着工できる。
    expect(await gs.upgradeFacility(type), isTrue);
  });

  test('スタジアムは次の季の始まりに完成し、季の途中では席が増えない', () async {
    final gs = GameState();
    await gs.startNewGame('増築FC');
    final s = gs.save!;
    s.budget = 99999999;
    final season = s.league.season;
    final capacity = gs.stadiumCapacity;

    expect(await gs.upgradeFacility(FacilityType.stadium), isTrue);
    expect(
      s.infrastructure.constructionReadyOn(FacilityType.stadium),
      SeasonCalendar.preseasonDate(season + 1),
    );
    expect(gs.stadiumCapacity, capacity);
    // ライセンスの判定では、来季の開幕に間に合うので完成後の段で数える。
    expect(gs.licensedStadiumLevel, 2);
    expect(gs.clubLicenseUnmet(2), isEmpty);

    // 季の終わりの近くまで進めても、まだ工事中。
    gs.debugAdvanceTodayTo(
      DateTime(SeasonCalendar.startYear(season) + 1, 6, 1),
    );
    expect(s.infrastructure.facilityLevel(FacilityType.stadium), 1);

    // 季を締めて次の季へ進むと完成している。
    finishLeague(gs);
    await gs.startNextSeason();
    expect(s.infrastructure.facilityLevel(FacilityType.stadium), 2);
    expect(s.infrastructure.isUnderConstruction(FacilityType.stadium), isFalse);
    expect(
      gs.stadiumCapacity,
      capacity + ClubInfrastructure.stadiumSeatsPerLevel,
    );
  });

  test('工事中の状態は保存して読み戻せ、無い旧セーブは工事なしで読める', () async {
    final gs = GameState();
    await gs.startNewGame('保存FC');
    final s = gs.save!..budget = 99999999;
    expect(await gs.upgradeFacility(FacilityType.medicalCenter), isTrue);
    final ready = s.infrastructure.constructionReadyOn(
      FacilityType.medicalCenter,
    );

    final json = s.toJson();
    final restored = SaveGame.fromJson(json);
    expect(
      restored.infrastructure.constructionReadyOn(FacilityType.medicalCenter),
      ready,
    );
    expect(
      restored.infrastructure.facilityLevel(FacilityType.medicalCenter),
      1,
    );

    final infraJson = Map<String, dynamic>.from(
      json['infrastructure'] as Map<String, dynamic>,
    )..remove('construction');
    final legacy = ClubInfrastructure.fromJson(infraJson);
    expect(legacy.construction, isEmpty);
    expect(legacy.isUnderConstruction(FacilityType.medicalCenter), isFalse);
    // 工事が無ければ書き出しにも入らない(セーブを太らせない)。
    expect(ClubInfrastructure().toJson().containsKey('construction'), isFalse);
  });

  test('最大の段では着工できない', () {
    final infra = ClubInfrastructure(
      facilityLevels: {for (final f in FacilityType.values) f: 8},
    );
    expect(
      infra.startConstruction(FacilityType.stadium, DateTime(2030)),
      isFalse,
    );
    expect(infra.construction, isEmpty);
  });
}
