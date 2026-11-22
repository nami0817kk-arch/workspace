import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/nation_names.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/league_rules.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/logic/squad_registration_engine.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/rules_card.dart';

import 'support/sell_via_offer.dart';

/// 選手と移籍を実際のサッカーに近づけた決まりの続き(2026-11-22)。
///
/// reality2_players_test.dart で入れた決まりのうち、自クラブにしか効いて
/// いなかったもの・足りなかったものの検査: AI 同士の仮契約の開始日・CPU の
/// クラブの登録の決まり・イタリアの EU 外の数え方(所属なし・ローン・CPU)・
/// 自クラブの選手の国籍・スペインの「売った分の一部だけ使える」。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Player make(String id, {int age = 25, int endYear = 2030}) {
    final p = PlayerGenerator.generate(
        position: Position.mc, strengthTier: 60, ageOverride: age);
    return Player.fromJson({...p.toJson(), 'id': id})
      ..contractEndYear = endYear
      ..contractOption = false;
  }

  group('AI 同士の仮契約・AI が自クラブの選手に持ちかける時期', () {
    setUp(() => Player.contractClockYear = 2027);

    final jan1 = DateTime(2027, 1, 1);

    test('1月1日: イングランドのクラブの選手は、国内のクラブとはまだ結ばない', () {
      final e1 =
          Team(id: 'e1', name: 'E1', players: [make('p', endYear: 2027)]);
      final e2 = Team(id: 'e2', name: 'E2', players: [make('q')]);
      final f1 = Team(id: 'f1', name: 'F1', players: [make('r')]);
      final country = {
        'e1': LeagueTheme.england,
        'e2': LeagueTheme.england,
        'f1': LeagueTheme.france,
      };
      // 乱数: 更新しない(0.9)・仮契約を結ぶ(0.1)。行き先は[e2, f1]の0番目。
      final domestic = PreContractEngine.openSeasonForAi(
          [e1, e2, f1], 'user', _Script([0.9, 0.1]),
          today: jan1, countryOf: (t) => country[t.id]!);
      expect(domestic, isEmpty, reason: '国内のクラブとは6月1日から');
      expect(e1.players.single.contractEndYear, 2027, reason: '更新もしていない');
      // 行き先が国外(フランス)のクラブなら1月1日に結ぶ。
      final abroad = PreContractEngine.openSeasonForAi(
          [e1, e2, f1], 'user', _Script([0.9, 0.1], pick: 1),
          today: jan1, countryOf: (t) => country[t.id]!);
      expect(abroad.single.toClubId, 'f1');
      // 国を渡さなければ以前どおり(国内のクラブとも結ぶ)。
      final old = PreContractEngine.openSeasonForAi(
          [e1, e2, f1], 'user', _Script([0.9, 0.1]),
          today: jan1);
      expect(old.single.toClubId, 'e2');
    });

    test('1月1日: スペイン・ドイツ・フランスのクラブの選手は国内のクラブとも結ぶ', () {
      for (final c in [
        LeagueTheme.spain,
        LeagueTheme.germany,
        LeagueTheme.france
      ]) {
        final a = Team(id: 'a', name: 'A', players: [make('p', endYear: 2027)]);
        final b = Team(id: 'b', name: 'B', players: [make('q')]);
        final made = PreContractEngine.openSeasonForAi(
            [a, b], 'user', _Script([0.9, 0.1]),
            today: jan1, countryOf: (_) => c);
        expect(made.single.toClubId, 'b', reason: c.name);
      }
    });

    test('国内の開始日(イングランド6月1日・イタリア2月1日)に、国内の行き先と結ぶ', () {
      expect(PreContractEngine.lateDomesticCountries,
          unorderedEquals([LeagueTheme.england, LeagueTheme.italy]));
      final e1 =
          Team(id: 'e1', name: 'E1', players: [make('p', endYear: 2027)]);
      final e2 = Team(id: 'e2', name: 'E2', players: [make('q')]);
      final f1 = Team(id: 'f1', name: 'F1', players: [make('r')]);
      final country = {
        'e1': LeagueTheme.england,
        'e2': LeagueTheme.england,
        'f1': LeagueTheme.france,
      };
      final made = PreContractEngine.openDomesticForAi(
          [e1, e2, f1], 'user', _Script([0.1], pick: 5),
          country: LeagueTheme.england,
          countryOf: (t) => country[t.id]!,
          today: DateTime(2027, 6, 1));
      expect(made.single.toClubId, 'e2', reason: '行き先は同じ国のクラブだけ');
      // もう結んだ選手・登録の決まりで入らないクラブは除く。
      expect(
          PreContractEngine.openDomesticForAi(
              [e1, e2, f1], 'user', _Script([0.1]),
              country: LeagueTheme.england,
              countryOf: (t) => country[t.id]!,
              today: DateTime(2027, 6, 1),
              alreadyTaken: {'p'}),
          isEmpty);
      expect(
          PreContractEngine.openDomesticForAi(
              [e1, e2, f1], 'user', _Script([0.1]),
              country: LeagueTheme.england,
              countryOf: (t) => country[t.id]!,
              today: DateTime(2027, 6, 1),
              canRegister: (_, __) => false),
          isEmpty);
    });

    test('自クラブの選手に声をかけるのは、国内の開始日までは他の国のクラブだけ', () {
      final user =
          Team(id: 'user', name: 'U', players: [make('u', endYear: 2027)]);
      final d = Team(id: 'd', name: 'D', players: [make('q')]);
      final f = Team(id: 'f', name: 'F', players: [make('r')]);
      List<String> poach(DateTime today, {List<Team> foreign = const []}) => [
            for (final c in PreContractEngine.poachFromUser(
                user, [d], _Script([0.0]),
                today: today,
                foreignTeams: foreign,
                domesticOpensOn: DateTime(2027, 6, 1)))
              c.toClubId,
          ];
      expect(poach(DateTime(2027, 1, 10), foreign: [f]), ['f']);
      expect(poach(DateTime(2027, 1, 10)), isEmpty,
          reason: '国外のクラブが無ければ、6月まで誰も声をかけない');
      expect(poach(DateTime(2027, 6, 5), foreign: [f]), ['d']);
      // 登録の決まりで入らないクラブは声をかけない。
      expect(
          PreContractEngine.poachFromUser(user, [d], _Script([0.0]),
              today: DateTime(2027, 6, 5), canRegister: (_, __) => false),
          isEmpty);
    });

    test('ゲームの中(イングランド): 1月はイングランド・イタリアの国内同士の仮契約が無く、開始日から出る', () async {
      final gs = GameState();
      await gs.startNewGame('仮契約FC');
      final s = gs.save!;
      final y = Player.contractClockYear;
      final foreign = {
        for (final e in s.foreignLeagues.entries)
          for (final t in e.value.teams) t.id: e.key,
      };
      String countryOf(String id) => foreign[id] ?? LeagueTheme.england.name;
      bool domesticIn(String country, PreContract c) =>
          countryOf(c.fromClubId) == country &&
          countryOf(c.toClubId) == country &&
          c.fromClubId != s.userTeamId;

      void jumpTo(DateTime from, DateTime to) {
        s.today = from;
        s.lastWeeklyTickDate = from;
        gs.debugAdvanceTodayTo(to);
      }

      jumpTo(DateTime(y - 1, 12, 31), DateTime(y, 1, 2));
      final jan = [...gs.preContracts];
      expect(jan, isNotEmpty);
      expect(
          jan.where((c) => domesticIn(LeagueTheme.england.name, c)), isEmpty);
      expect(jan.where((c) => domesticIn(LeagueTheme.italy.name, c)), isEmpty);
      expect(
          jan.any((c) =>
              domesticIn(LeagueTheme.spain.name, c) ||
              domesticIn(LeagueTheme.germany.name, c) ||
              domesticIn(LeagueTheme.france.name, c)),
          isTrue,
          reason: 'ほかの国は1月1日から国内同士でも結ぶ');
      // 自クラブの選手に声をかけたのは、6月までは他の国のクラブだけ。
      expect(
          jan
              .where((c) => c.fromClubId == s.userTeamId)
              .every((c) => foreign.containsKey(c.toClubId)),
          isTrue);

      jumpTo(DateTime(y, 1, 31), DateTime(y, 2, 2));
      expect(gs.preContracts.any((c) => domesticIn(LeagueTheme.italy.name, c)),
          isTrue,
          reason: 'イタリアは2月1日から');
      expect(
          gs.preContracts.where((c) => domesticIn(LeagueTheme.england.name, c)),
          isEmpty);

      jumpTo(DateTime(y, 5, 31), DateTime(y, 6, 2));
      expect(
          gs.preContracts.any((c) => domesticIn(LeagueTheme.england.name, c)),
          isTrue,
          reason: 'イングランドは6月1日から');
    });
  });

  group('CPU のクラブの補強にも登録の決まり', () {
    List<Team> squads() => [
          Team(id: 'user', name: 'U', players: []),
          for (var i = 0; i < 4; i++)
            PlayerGenerator.generateSquad(
                id: 'c$i', name: 'C$i', strengthTier: 60),
        ];

    test('AI 同士の移籍: 登録できないクラブへは移らない', () {
      for (var seed = 0; seed < 40; seed++) {
        final teams = squads();
        final before = {for (final t in teams) t.id: t.players.length};
        AiTransferEngine.runWeek(teams, 'user', Random(seed),
            canRegister: (t, _) => t.id != 'c1');
        expect(teams.firstWhere((t) => t.id == 'c1').players.length,
            lessThanOrEqualTo(before['c1']!),
            reason: 'seed $seed');
      }
      for (var seed = 0; seed < 20; seed++) {
        final teams = squads();
        expect(
            AiTransferEngine.runWeek(teams, 'user', Random(seed),
                canRegister: (_, __) => false),
            isEmpty);
      }
    });

    test('スペイン: 英国籍(EU 外)が3人いる CPU のクラブは、4人目を取らない', () async {
      final gs = GameState();
      await gs.startNewGame('登録FC', theme: LeagueTheme.spain);
      final s = gs.save!;
      final cpus = s.league.teams.where((t) => t.id != s.userTeamId).toList();
      for (final t in cpus) {
        for (final p in t.players.take(3)) {
          p.nation = LeagueTheme.england.name;
        }
      }
      final english = gs.userTeam.players.firstWhere((p) => !p.isLoan)
        ..nation = LeagueTheme.england.name;
      final french =
          gs.userTeam.players.firstWhere((p) => !p.isLoan && p.id != english.id)
            ..nation = LeagueTheme.france.name
            ..age = 20;
      expect(
          gs.debugCpuCanRegister(cpus.first, english,
              fromCountry: LeagueTheme.spain),
          isFalse);
      expect(
          gs.debugCpuCanRegister(cpus.first, french,
              fromCountry: LeagueTheme.spain),
          isTrue,
          reason: 'EU の国籍なら枠の外');
      // 放出しても、枠の埋まったクラブへは移らない。
      expect(gs.isTransferWindowOpen, isTrue);
      expect(await sellViaOffer(gs, english.id), isNotNull);
      expect(
          cpus.any((t) => t.players.any((p) => p.id == english.id)), isFalse);
    });

    test('ドイツ: 外国籍が18人いる CPU のクラブは、外国籍を取らない', () async {
      final gs = GameState();
      await gs.startNewGame('登録FC', theme: LeagueTheme.germany);
      final s = gs.save!;
      final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      while (cpu.players.length < 18) {
        cpu.players.add(make('fill${cpu.players.length}', age: 20));
      }
      for (final p in cpu.players) {
        p.nation = LeagueTheme.france.name;
      }
      final incoming = make('in', age: 20)..nation = LeagueTheme.france.name;
      expect(
          gs.debugCpuCanRegister(cpu, incoming,
              fromCountry: LeagueTheme.germany),
          isFalse);
      incoming.nation = LeagueTheme.germany.name;
      expect(
          gs.debugCpuCanRegister(cpu, incoming,
              fromCountry: LeagueTheme.germany),
          isTrue);
    });
  });

  group('イタリアの「EU 外の新規獲得は1季2人まで」', () {
    test('所属なしの選手も数える', () async {
      final gs = GameState();
      await gs.startNewGame('伊FC', theme: LeagueTheme.italy);
      final s = gs.save!
        ..budget = 1 << 40
        ..wageBudget = 1 << 30;
      final fa = gs.freeAgents.first
        ..nation = LeagueTheme.england.name
        ..age = 20;
      s
        ..nonEuSignings = 2
        ..nonEuSigningsSeason = s.league.season;
      expect(gs.registrationBlockFor(fa), contains('2'));
      s.nonEuSignings = 1;
      expect(gs.registrationBlockFor(fa), isNull);
      expect(await gs.signFreeAgent(fa.id), isTrue,
          reason: gs.lastSigningBlockReason);
      expect(gs.nonEuSignedThisSeason, 2);
    });

    test('他の国のクラブからのローンも数える(国内のクラブからは数えない)', () async {
      final gs = GameState();
      await gs.startNewGame('伊FC', theme: LeagueTheme.italy);
      gs.rivalsEnabled = false;
      gs.save!
        ..budget = 1 << 40
        ..wageBudget = 1 << 30;
      final club =
          gs.save!.foreignLeagues[LeagueTheme.england.name]!.teams.first;
      final p = club.players.firstWhere((p) => !p.isLoan)
        ..nation = LeagueTheme.england.name
        ..age = 20;
      expect(gs.nonEuSignedThisSeason, 0);
      expect(await gs.signLoanPlayer(p.id), isTrue,
          reason: gs.lastSigningBlockReason);
      expect(gs.nonEuSignedThisSeason, 1);
      final cpu =
          gs.save!.league.teams.firstWhere((t) => t.id != gs.save!.userTeamId);
      final local = cpu.players.firstWhere((p) => !p.isLoan)
        ..nation = LeagueTheme.england.name
        ..age = 20;
      expect(await gs.signLoanPlayer(local.id), isTrue,
          reason: gs.lastSigningBlockReason);
      expect(gs.nonEuSignedThisSeason, 1, reason: '国内のクラブからは数えない');
    });

    test('CPU のクラブも数え、2人取ったら他の国・所属なしの EU 外は取らない', () async {
      final gs = GameState();
      await gs.startNewGame('伊FC', theme: LeagueTheme.italy);
      final s = gs.save!;
      final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      final fa = gs.freeAgents.first
        ..nation = LeagueTheme.england.name
        ..age = 20;
      s
        ..cpuNonEuSignings[cpu.id] = 2
        ..cpuNonEuSigningsSeason = s.league.season;
      expect(gs.debugCpuCanRegister(cpu, fa, fromCountry: null), isFalse);
      expect(gs.debugCpuCanRegister(cpu, fa, fromCountry: LeagueTheme.italy),
          isTrue,
          reason: '国内のクラブから取るなら数えない');
      s.cpuNonEuSignings[cpu.id] = 1;
      expect(gs.debugCpuCanRegister(cpu, fa, fromCountry: null), isTrue);
      // 前の季の数は数えない。
      s
        ..cpuNonEuSignings[cpu.id] = 2
        ..cpuNonEuSigningsSeason = s.league.season - 1;
      expect(gs.debugCpuCanRegister(cpu, fa, fromCountry: null), isTrue);
      // 保存して読み直しても残る(古いセーブは空)。
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.cpuNonEuSignings[cpu.id], 2);
      final json = s.toJson()
        ..remove('cpuNonEuSignings')
        ..remove('cpuNonEuSigningsSeason');
      expect(SaveGame.fromJson(json).cpuNonEuSignings, isEmpty);
    });
  });

  group('自クラブの選手の国籍', () {
    test('新しいゲームでは、3部の CPU と同じ割合(2〜3割)で外国籍が混ざる', () async {
      var total = 0, foreign = 0;
      var national = 0, nationalHg = 0, foreignHg = 0;
      for (var i = 0; i < 3; i++) {
        final gs = GameState();
        await gs.startNewGame('国籍FC');
        for (final p in gs.userTeam.players) {
          expect(p.nation, isNotNull, reason: '国籍を覚えている');
          expect(NationNames.fits(p.name, gs.nationalityOf(p)), isTrue,
              reason: '${p.name} / ${p.nation}');
          total++;
          if (gs.nationalityOf(p) == LeagueTheme.england) {
            national++;
            if (p.homegrown) nationalHg++;
          } else {
            foreign++;
            if (p.homegrown) foreignHg++;
          }
        }
        // 始めた時点で登録の決まりは破っていない。
        expect(gs.registrationOverLimit, isFalse);
      }
      // 変更前は0(全員が自国籍)。イングランドの3部は 65% × 0.45 ≒ 29%。
      expect(foreign / total, inInclusiveRange(0.15, 0.45));
      expect(nationalHg / national, greaterThan(0.5), reason: '自国籍は3人に2人');
      expect(foreignHg / max(1, foreign), lessThan(0.3), reason: '外国籍は10人に1人');
    });

    test('スペインは EU 外3人まで・ドイツは自国籍12人以上で始まる', () async {
      final es = GameState();
      await es.startNewGame('国籍FC', theme: LeagueTheme.spain);
      expect(es.nonEuPlayerCount, lessThanOrEqualTo(3));
      expect(
          es.userTeam.players
              .where((p) => es.nationalityOf(p) != LeagueTheme.spain),
          isNotEmpty);
      final de = GameState();
      await de.startNewGame('国籍FC', theme: LeagueTheme.germany);
      expect(de.nationalPlayerCount, greaterThanOrEqualTo(12));
    });

    test('古いセーブの自クラブの選手は、自国籍・名前・国内育成の印のまま', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final save = SaveGame.fromJson(
          jsonDecode(jsonEncode(gs.save!.toJson())) as Map<String, dynamic>);
      final user = save.league.teams.firstWhere((t) => t.id == save.userTeamId);
      // 国籍を覚えていなかった頃の自クラブ(全員がリーグの国の名前)。
      var k = 0;
      for (final p in user.players) {
        p.nation = null;
        p.name = NationNames.nameFor(LeagueTheme.england, 1000 + k * 37);
        k++;
      }
      final names = {for (final p in user.players) p.id: p.name};
      final hg = {for (final p in user.players) p.id: p.homegrown};
      final restored = GameState();
      expect(await restored.importSaveJson(jsonEncode(save.toJson())), isTrue);
      for (final p in restored.userTeam.players) {
        expect(restored.nationalityOf(p), LeagueTheme.england);
        expect(p.name, names[p.id]);
        expect(p.homegrown, hg[p.id]);
      }
    });
  });

  group('スペインの人件費の上限: 売った分の一部だけ使える', () {
    test('上限を超えている間に減った分の半分(1:2)だけ使える', () {
      int track(int prev, int cost, {int allowance = 0}) =>
          RulesEngine.trackSaleAllowance(
              allowance: allowance, previousCost: prev, cost: cost, limit: 100);
      expect(RulesEngine.saleSpendShare, 0.5);
      expect(track(120, 100), 10);
      expect(track(120, 90), 10, reason: '上限の下まで減った分は、上限の空きとして使う');
      expect(track(90, 80), 0);
      expect(track(100, 106, allowance: 10), 4, reason: '上限を上回る分が増えたら使った');
      expect(track(90, 99, allowance: 10), 10, reason: '上限の下での増減は数えない');
      expect(track(0, 50, allowance: 7), 7, reason: 'まだ見ていないなら何もしない');
      expect(RulesEngine.spendableSquadCost(limit: 100, cost: 90, allowance: 5),
          15);
      expect(
          RulesEngine.spendableSquadCost(limit: 100, cost: 120, allowance: 5),
          5);
    });

    test('上限を超えていても、使える額までなら登録できる', () {
      // 上限は 100000 × 70% = 70000。人件費 80000 で超えている。
      const snap =
          ClubFinanceSnapshot(projectedIncome: 100000, squadCost: 80000);
      String? block(int added, int allowance) => RulesEngine.signingBlock(
          ruleSet: RuleSet.spain,
          tier: 1,
          snapshot: snap,
          addedSquadCost: added,
          saleAllowance: allowance);
      expect(block(5000, 0), contains('登録できません'));
      expect(block(5000, 5000), isNull);
      expect(block(5000, 4999), contains('いま使える額'));
    });

    test('ゲームの中: 上限を超えたクラブが売ると、売った人件費の半分だけ取れる', () async {
      final gs = GameState();
      await gs.startNewGame('人件費FC', theme: LeagueTheme.spain);
      final s = gs.save!
        ..budget = 1 << 40
        ..wageBudget = 1 << 30;
      // 最初の季は罰と同じく猶予するので、2季目にする。
      s.league.season = 2;
      final limit = gs.squadCostLimitNow;
      final scale = limit * 1.4 / gs.annualSquadCost;
      for (final p in gs.userTeam.players) {
        p.wage = max(1, (p.wage * scale).round());
      }
      // 年俸を書き換えた分は「売った」ではないので、見始めから数える
      // (始めた時点の人件費が上限の1.4倍より重いと、下げた分が数えられる)。
      s
        ..squadCostObserved = 0
        ..squadCostAllowance = 0;
      gs.debugObserveSquadCost();
      expect(gs.annualSquadCost, greaterThan(limit));
      expect(gs.squadCostSaleAllowance, 0);
      expect(gs.squadCostSpendable, 0);
      expect(gs.debugAllowsSigning(1), isFalse, reason: '上限を超えている');

      final cheapest = gs.userTeam.players
          .where((p) => !p.isLoan && !p.isLoanedOut)
          .reduce((a, b) => a.wage <= b.wage ? a : b);
      final before = gs.annualSquadCost;
      expect(await sellViaOffer(gs, cheapest.id), isNotNull);
      final drop = before - gs.annualSquadCost;
      expect(drop, greaterThan(0));
      expect(gs.annualSquadCost, greaterThan(limit), reason: 'まだ上限の上');
      final allowance = gs.squadCostSaleAllowance;
      expect(allowance, (drop * RulesEngine.saleSpendShare).round());
      expect(gs.squadCostSpendable, allowance);
      expect(s.squadCostAllowance, allowance, reason: '覚えている');

      final weekly = allowance ~/ 52;
      expect(weekly, greaterThan(0));
      expect(gs.debugAllowsSigning(weekly), isTrue,
          reason: gs.lastSigningBlockReason);
      expect(gs.debugAllowsSigning(weekly + 1), isFalse);
      expect(gs.lastSigningBlockReason, contains('いま使える額'));

      // 保存して読み直しても残る。
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.squadCostAllowance, allowance);
      expect(back.squadCostObserved, s.squadCostObserved);
    });

    testWidgets('規則の画面に「新加入に使える人件費」を出す(スペインだけ)', (tester) async {
      final es = GameState();
      final settings = SettingsController();
      await tester.runAsync(() async {
        await settings.init();
        await es.startNewGame('規則FC', theme: LeagueTheme.spain);
      });
      // SettingsController.init() が言語を上書きするので、この後で決める。
      Tr.language = AppLanguage.japanese;
      Widget card(GameState gs) => MultiProvider(
            providers: [
              ChangeNotifierProvider<GameState>.value(value: gs),
              ChangeNotifierProvider<SettingsController>.value(value: settings),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SingleChildScrollView(child: RulesCard())),
            ),
          );
      await tester.pumpWidget(card(es));
      expect(find.byKey(const Key('rules-spendable')), findsOneWidget);
      expect(find.textContaining('新加入に使える人件費'), findsOneWidget);

      final en = GameState();
      await tester.runAsync(() => en.startNewGame('規則FC'));
      await tester.pumpWidget(card(en));
      expect(find.byKey(const Key('rules-spendable')), findsNothing);
    });
  });

  test('登録の決まりの国ごとの値は変えていない', () {
    expect(RegistrationRules.spain.nonEuLimit, 3);
    expect(RegistrationRules.italy.nonEuSigningsPerSeason, 2);
  });
}

/// 決まった順に値を返す乱数。[pick]は nextInt の答え(上限で割った余り)。
class _Script implements Random {
  _Script(this.doubles, {this.pick = 0});

  final List<double> doubles;
  final int pick;
  var _i = 0;

  @override
  double nextDouble() => doubles[_i++ % doubles.length];

  @override
  int nextInt(int max) => pick % max;

  @override
  bool nextBool() => false;
}
