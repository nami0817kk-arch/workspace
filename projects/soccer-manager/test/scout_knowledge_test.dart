import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/scout_knowledge.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// スカウトの派遣と、能力が幅で見える仕組みの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('見立ての幅', () {
    test('見えているほど幅が狭く、本当の値は必ず幅の中', () {
      for (final id in ['a', 'pl12', 'pl999', 'xyz']) {
        for (final v in [45, 70, 88]) {
          var last = 999;
          for (final k in [10, 30, 60, 90, 100]) {
            final r = ScoutKnowledge.range(v, k, id, 1)!;
            expect(r.$1 <= v && v <= r.$2, isTrue, reason: '$id $v $k $r');
            final width = r.$2 - r.$1;
            expect(width, lessThanOrEqualTo(last));
            last = width;
          }
          expect(ScoutKnowledge.range(v, 100, id, 1), (v, v));
          expect(ScoutKnowledge.range(v, 0, id, 1), isNull);
        }
      }
      expect(ScoutKnowledge.label(null), '?');
    });

    test('送れる数は1〜3、速さは見極めの力で上がる', () {
      expect(ScoutKnowledge.slotsFor(1), 1);
      expect(ScoutKnowledge.slotsFor(4), 2);
      expect(ScoutKnowledge.slotsFor(8), 3);
      expect(ScoutKnowledge.weeklyGain(8),
          greaterThan(ScoutKnowledge.weeklyGain(1)));
    });
  });

  group('ゲームの中', () {
    test('自クラブは全部、同じ部は30%、それ以外は0%から', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      expect(gs.knowledgeOf(gs.userTeam.players.first), 100);
      final rival = gs.save!.league.teams
          .firstWhere((t) => t.id != gs.save!.userTeamId)
          .players
          .first;
      expect(gs.knowledgeOf(rival), ScoutKnowledge.sameLeagueBase);
      final foreign =
          gs.save!.foreignLeagues.values.first.teams.first.players.first;
      expect(gs.knowledgeOf(foreign), 0);
      expect(gs.overallEstimate(foreign), isNull);
    });

    test('送った地域は毎週見えてきて、出張費がかかる', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      final region = gs.scoutRegions.firstWhere((r) => r.key.startsWith('foreign:'));
      final p = region.teams.first.players.first;
      expect(await gs.toggleScoutRegion(region.key), isTrue);
      expect(gs.isScoutRegionActive(region.key), isTrue);
      final before = gs.currentLedger.of(LedgerCategory.facilities);

      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 7)));
      expect(gs.knowledgeOf(p), gs.scoutWeeklyGain);
      expect(gs.currentLedger.of(LedgerCategory.facilities),
          before - gs.scoutTripCostPerWeek);

      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 70)));
      expect(gs.knowledgeOf(p), 100, reason: '10週を超えれば全部見える');
      expect(gs.overallEstimate(p), (p.overall, p.overall));
    });

    test('送れる数を超えては送れない', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      final keys = gs.scoutRegions.map((r) => r.key).toList();
      for (var i = 0; i < gs.scoutSlots; i++) {
        expect(await gs.toggleScoutRegion(keys[i]), isTrue);
      }
      expect(await gs.toggleScoutRegion(keys[gs.scoutSlots]), isFalse);
      // 引き上げれば、別の場所へ送れる。
      expect(await gs.toggleScoutRegion(keys[0]), isTrue);
      expect(await gs.toggleScoutRegion(keys[gs.scoutSlots]), isTrue);
    });

    test('注目リストの選手は、どこにいても少しずつ見えてくる', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      final foreign =
          gs.save!.foreignLeagues.values.first.teams.first.players.first;
      await gs.toggleWatched(foreign.id);
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 14)));
      expect(gs.knowledgeOf(foreign), ScoutKnowledge.watchWeeklyGain * 2);
    });

    test('監督の補強案は、ある程度見えている選手からしか出ない', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      final same = gs.sameLeaguePlayerIds();
      for (final p in gs.proposalTargets) {
        expect(gs.knowledgeOf(p, sameLeagueIds: same),
            greaterThanOrEqualTo(ScoutKnowledge.proposalMinimum));
      }
      expect(gs.proposalTargets.length, lessThan(gs.transferTargets.length));
    });

    test('見え方と送った地域は保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('見立てFC');
      final region = gs.scoutRegions.last;
      await gs.toggleScoutRegion(region.key);
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 7)));
      final copy = SaveGame.fromJson(gs.save!.toJson());
      expect(copy.scoutRegionKeys, [region.key]);
      expect(copy.scoutKnowledge, gs.save!.scoutKnowledge);
      expect(copy.scoutKnowledge, isNotEmpty);
    });
  });
}
