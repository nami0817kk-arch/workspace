import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/free_agent_engine.dart';
import 'package:soccer_manager/logic/offscreen_development.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/logic/relations_engine.dart';
import 'package:soccer_manager/logic/squad_registration_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/logic/transfer_terms_engine.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_stub.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手と移籍を実際のサッカーに近づけた決まり(2026-11-22)の検査。
///
/// 国ごとの選手登録・スペインのリリース条項・CPU のクラブの国籍・年齢と
/// 衰え・レンタル・所属なしの選手・契約の長さ・仮契約と18歳未満の決まり。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make(String id, {int age = 27, bool homegrown = false}) {
    final p = PlayerGenerator.generate(
        position: Position.mc, strengthTier: 60, ageOverride: age);
    return Player.fromJson({...p.toJson(), 'id': id, 'homegrown': homegrown});
  }

  Team team(List<Player> players) => Team(id: 't', name: 'T', players: players);

  group('国ごとの選手登録', () {
    LeagueTheme Function(Player) nations(
            Map<String, LeagueTheme> m, LeagueTheme fallback) =>
        (p) => m[p.id] ?? fallback;

    test('スペイン: EU 外(英国籍)は年齢を問わず3人まで。国内育成の枠は無い', () {
      final players = [
        for (var i = 0; i < 3; i++) make('e$i', age: 20),
        for (var i = 0; i < 18; i++) make('s$i'),
      ];
      final nationOf = nations(
          {for (var i = 0; i < 3; i++) 'e$i': LeagueTheme.england},
          LeagueTheme.spain);
      final t = team(players);
      final english = make('x');
      final french = make('y');
      final m = {
        for (var i = 0; i < 3; i++) 'e$i': LeagueTheme.england,
        'x': LeagueTheme.england,
        'y': LeagueTheme.france,
      };
      final of = nations(m, LeagueTheme.spain);
      expect(
          SquadRegistration.blockReason(t, english,
              rules: RegistrationRules.spain, nationOf: of),
          contains('3'));
      expect(
          SquadRegistration.blockReason(t, french,
              rules: RegistrationRules.spain, nationOf: of),
          isNull,
          reason: 'フランス国籍は EU なので枠の外');
      // 国外で育った22歳以上が18人いても、スペインには国内育成の枠が無い。
      expect(
          SquadRegistration.blockReason(t, make('z'),
              rules: RegistrationRules.spain, nationOf: nationOf),
          isNull);
      // 同じ顔ぶれでもイングランドの決まりなら、国外育成17人の枠に当たる。
      expect(SquadRegistration.blockReason(t, make('z')), isNotNull);
    });

    test('フランス: EU 外は4人まで', () {
      final t = team([for (var i = 0; i < 4; i++) make('e$i')]);
      LeagueTheme of(Player p) => p.id.startsWith('e') || p.id == 'x'
          ? LeagueTheme.england
          : LeagueTheme.france;
      expect(
          SquadRegistration.blockReason(t, make('x'),
              rules: RegistrationRules.france, nationOf: of),
          contains('4'));
      expect(
          SquadRegistration.blockReason(t, make('y'),
              rules: RegistrationRules.france, nationOf: of),
          isNull);
    });

    test('イタリア: EU 外を他の国から取れるのは1季に2人まで。クラブ育成4人の枠', () {
      final t = team([make('a')]);
      LeagueTheme of(Player p) =>
          p.id == 'x' ? LeagueTheme.england : LeagueTheme.italy;
      expect(
          SquadRegistration.blockReason(t, make('x'),
              rules: RegistrationRules.italy,
              nationOf: of,
              nonEuSignedThisSeason: 2,
              incomingFromAbroad: true),
          contains('2'));
      expect(
          SquadRegistration.blockReason(t, make('x'),
              rules: RegistrationRules.italy,
              nationOf: of,
              nonEuSignedThisSeason: 1,
              incomingFromAbroad: true),
          isNull);
      expect(
          SquadRegistration.blockReason(t, make('x'),
              rules: RegistrationRules.italy,
              nationOf: of,
              nonEuSignedThisSeason: 2,
              incomingFromAbroad: false),
          isNull,
          reason: '国内のクラブから取るなら数えない');
      // ユース出身でない22歳以上は21人まで(4人はクラブ育成の席)。
      final full = team([
        for (var i = 0; i < 21; i++) make('h$i', homegrown: true),
      ]);
      expect(
          SquadRegistration.blockReason(full, make('n', homegrown: true),
              rules: RegistrationRules.italy, nationOf: of),
          isNotNull);
      final grad = make('g', homegrown: true)..academyGraduate = true;
      expect(
          SquadRegistration.blockReason(full, grad,
              rules: RegistrationRules.italy, nationOf: of),
          isNull);
    });

    test('ドイツ: 国籍の枠は無いが、ドイツ国籍を12人残す(外国籍は18人まで)', () {
      final t = team([for (var i = 0; i < 18; i++) make('f$i', age: 20)]);
      LeagueTheme of(Player p) =>
          p.id.startsWith('g') ? LeagueTheme.germany : LeagueTheme.england;
      expect(
          SquadRegistration.blockReason(t, make('x', age: 20),
              rules: RegistrationRules.germany, nationOf: of),
          contains('12'));
      expect(
          SquadRegistration.blockReason(t, make('g1', age: 20),
              rules: RegistrationRules.germany, nationOf: of),
          isNull);
    });

    test('締切: スペインで EU 外が3人を超えたら、EU 外から名簿を外す', () {
      final players = [
        for (var i = 0; i < 5; i++) make('e$i', age: 20 + i),
        for (var i = 0; i < 10; i++) make('s$i'),
      ];
      final t = team(players);
      LeagueTheme of(Player p) =>
          p.id.startsWith('e') ? LeagueTheme.england : LeagueTheme.spain;
      expect(
          SquadRegistration.isOverLimit(t,
              rules: RegistrationRules.spain, nationOf: of),
          isTrue);
      final out = SquadRegistration.plannedExclusions(t,
          rules: RegistrationRules.spain, nationOf: of);
      expect(out, hasLength(2));
      expect(out.every((p) => p.id.startsWith('e')), isTrue);
    });

    test('ゲームの中: スペインでは4人目の英国籍の選手を取れない', () async {
      final gs = GameState();
      await gs.startNewGame('登録FC', theme: LeagueTheme.spain);
      expect(gs.registrationRules.nonEuLimit, 3);
      // 自クラブにも外国籍が混ざる(2026-11-22)ので、数えやすいように全員を
      // 自国籍にしてから英国籍を3人足す。
      for (final p in gs.userTeam.players) {
        p.nation = LeagueTheme.spain.name;
      }
      final english = gs.save!.foreignLeagues[LeagueTheme.england.name]!.teams
          .expand((t) => t.players)
          .where((p) => p.age >= 18)
          .take(4)
          .toList();
      for (final p in english.take(3)) {
        final q = Player.fromJson(p.toJson())
          ..nation = LeagueTheme.england.name;
        gs.userTeam.players.add(q);
      }
      expect(gs.nonEuPlayerCount, 3);
      final fourth = english[3]..nation = LeagueTheme.england.name;
      expect(gs.registrationBlockFor(fourth), contains('EU'));
    });
  });

  group('スペインのリリース条項', () {
    test('スペインのクラブの選手には必ず付き、額は市場価値の3〜8倍', () async {
      final gs = GameState();
      await gs.startNewGame('条項FC', theme: LeagueTheme.spain);
      expect(gs.releaseClausesRequired, isTrue);
      for (final p in gs.userTeam.players) {
        final c = gs.releaseClauseOf(p)!;
        expect(c, greaterThanOrEqualTo(p.marketValue * 3));
        expect(c, lessThanOrEqualTo(p.marketValue * 8 + 1));
      }
      final cpu = gs.save!.league.teams.firstWhere((t) => t.id != 'user');
      expect(cpu.players.every((p) => gs.releaseClauseOf(p) != null), isTrue);
      // 他の国のクラブの選手には付かない(スペインのクラブを除く)。
      final germanClub =
          gs.save!.foreignLeagues[LeagueTheme.germany.name]!.teams.first;
      expect(gs.releaseClauseOf(germanClub.players.first), isNull);
    });

    test('イングランドでは自クラブの選手に付けるのはオーナーの任意', () async {
      final gs = GameState();
      await gs.startNewGame('条項FC');
      final p = gs.userTeam.players.first;
      expect(gs.releaseClauseOf(p), isNull);
      await gs.setReleaseClause(p.id, 500);
      expect(gs.releaseClauseOf(p), 500);
      // スペインのクラブ(他国の1部)の選手には付いている。
      final spanish =
          gs.save!.foreignLeagues[LeagueTheme.spain.name]!.teams.first;
      expect(gs.releaseClauseOf(spanish.players.first), isNotNull);
    });

    test('条項の額を払うとクラブとは合意の扱いになり、選手が条件をのめば移る', () async {
      final gs = GameState();
      await gs.startNewGame('条項FC', theme: LeagueTheme.spain);
      gs.rivalsEnabled = false;
      gs.save!.budget = 1 << 40;
      gs.save!.wageBudget = 1 << 30;
      expect(gs.isTransferWindowOpen, isTrue);
      final cpu = gs.save!.league.teams.firstWhere((t) => t.id != 'user');
      final target = cpu.players.firstWhere((p) =>
          p.age >= 22 && p.age < 30 && gs.registrationBlockFor(p) == null);
      final clause = gs.releaseClauseOf(target)!;
      final budget = gs.save!.budget;
      expect(await gs.triggerReleaseClause(target.id), isTrue,
          reason: gs.lastSigningBlockReason);
      final talk = gs.talkFor(target.id)!;
      expect(talk.stage, TransferTalkStage.agreed);
      expect(talk.fee, clause);
      expect(gs.userTeam.players.any((p) => p.id == target.id), isFalse,
          reason: '払うと伝えただけでは移らない(選手の返事次第)');
      final out = await gs.offerPersonalTerms(target.id,
          weeklyWage: target.wage * 3,
          endYear: Player.contractClockYear + 3,
          signingBonus: target.wage * 20);
      expect(out, TermsOutcome.signed);
      expect(gs.userTeam.players.any((p) => p.id == target.id), isTrue);
      expect(gs.save!.budget, lessThanOrEqualTo(budget - clause));
    });

    test('AI が払いに来るのは額が市場価値の2倍未満のときだけ。選手が断ることもある', () {
      expect(GameStateReleaseClause.aiClausePayChance(900, 1000), 1);
      expect(GameStateReleaseClause.aiClausePayChance(1500, 1000),
          closeTo(0.5, 1e-9));
      expect(GameStateReleaseClause.aiClausePayChance(2500, 1000), 0);
      final p = make('c')
        ..happiness = 80
        ..personality = PlayerPersonality.loyal;
      final q = make('d')
        ..happiness = 30
        ..personality = PlayerPersonality.ambitious
        ..isTransferListed = true;
      expect(
          GameStateReleaseClause.releaseClauseConsentChance(p), lessThan(0.2));
      expect(GameStateReleaseClause.releaseClauseConsentChance(q),
          greaterThan(0.8));
    });
  });

  group('CPU のクラブの国籍', () {
    double foreignShareOf(
        GameState gs, Iterable<Team> teams, LeagueTheme home) {
      final ps = teams.expand((t) => t.players).toList();
      return ps.where((p) => gs.nationalityOf(p) != home).length / ps.length;
    }

    test('イングランド: 1部は外国籍が6〜7割、2部・3部は2〜4割', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final s = gs.save!;
      final t1 = s.otherDivisionLeagues[0]!.teams;
      final t2 = s.otherDivisionLeagues[1]!.teams;
      final t3 = s.league.teams.where((t) => t.id != 'user');
      expect(foreignShareOf(gs, t1, LeagueTheme.england),
          inInclusiveRange(0.55, 0.75));
      expect(foreignShareOf(gs, t2, LeagueTheme.england),
          inInclusiveRange(0.25, 0.5));
      expect(foreignShareOf(gs, t3, LeagueTheme.england),
          inInclusiveRange(0.18, 0.4));
      // 自クラブは 2026-11-22 から3部と同じ割合で外国籍が混ざる
      // (reality3_players_test.dart。以前は全員自国籍だった)。
    });

    test('他の国の1部: 外国籍はイタリア約6割・ドイツ約55%・スペインとフランス約45%', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final expected = {
        LeagueTheme.italy: 0.60,
        LeagueTheme.germany: 0.55,
        LeagueTheme.spain: 0.45,
        LeagueTheme.france: 0.45,
      };
      for (final e in expected.entries) {
        final teams = gs.save!.foreignLeagues[e.key.name]!.teams;
        expect(foreignShareOf(gs, teams, e.key), closeTo(e.value, 0.1),
            reason: e.key.name);
      }
    });

    test('国内育成の印は、自国籍に多く外国籍に少ない', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final ps =
          gs.save!.otherDivisionLeagues[0]!.teams.expand((t) => t.players);
      final national =
          ps.where((p) => gs.nationalityOf(p) == LeagueTheme.england).toList();
      final foreign =
          ps.where((p) => gs.nationalityOf(p) != LeagueTheme.england).toList();
      double hg(List<Player> l) =>
          l.where((p) => p.homegrown).length / l.length;
      expect(hg(national), inInclusiveRange(0.55, 0.78));
      expect(hg(foreign), lessThan(0.2));
    });

    test('国籍は選手に覚えさせ、軽い形の保存でも残る', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final p = gs.save!.foreignLeagues.values.first.teams.first.players.first;
      expect(p.nation, isNotNull);
      final back = PlayerStub.decode(PlayerStub.encode(p));
      expect(back.nation, p.nation);
      // 国籍を持たない古い軽い形(17項目)も読める。
      final old = PlayerStub.encode(p)..removeLast();
      expect(PlayerStub.decode(old).nation, isNull);
    });

    test('版1のセーブは、今の国籍(1割)をそのまま覚えさせてから版2にする', () async {
      final gs = GameState();
      await gs.startNewGame('国籍FC');
      final json = gs.save!.toJson();
      json.remove('nationRuleVersion');
      // 国籍を覚えていなかった頃の形にする。
      final save = SaveGame.fromJson(json);
      for (final t in save.league.teams) {
        for (final p in t.players) {
          p.nation = null;
        }
      }
      expect(save.nationRuleVersion, 1);
      final cpu = save.league.teams.firstWhere((t) => t.id != 'user');
      final ids = [for (final p in cpu.players) p.id];
      // 版1の決め方: id のハッシュの1割だけ別の国。
      final legacyForeign = {
        for (final id in ids)
          if (Player.foreignNationalFromId(id)) id,
      };
      final restored = GameState();
      expect(await restored.importSaveJson(_encode(save)), isTrue);
      expect(restored.save!.nationRuleVersion, 2);
      final team =
          restored.save!.league.teams.firstWhere((t) => t.id == cpu.id);
      for (final p in team.players) {
        expect(
            p.nation != LeagueTheme.england.name, legacyForeign.contains(p.id),
            reason: p.id);
      }
    });
  });

  group('年齢と衰え', () {
    test('生成される選手の年齢は24〜28歳が山(変更前は17〜34歳が均等)', () {
      final rng = Random(7);
      final ages = [
        for (var i = 0; i < 2000; i++) PlayerGenerator.rollAge(rng)
      ];
      double share(bool Function(int) f) => ages.where(f).length / ages.length;
      final mean = ages.reduce((a, b) => a + b) / ages.length;
      expect(share((a) => a >= 24 && a <= 28), inInclusiveRange(0.36, 0.48));
      expect(share((a) => a <= 20), lessThan(0.16));
      expect(share((a) => a >= 32), lessThan(0.12));
      expect(mean, inInclusiveRange(25.0, 26.8));
      expect(ages.reduce(min), greaterThanOrEqualTo(17));
      expect(ages.reduce(max), lessThanOrEqualTo(35));
    });

    test('衰えは32〜33歳から速まる(標準の型の真ん中の選手)', () {
      Player mc(int age) => PlayerGenerator.generate(
          position: Position.mc, strengthTier: 70, ageOverride: age)
        ..growthType = PlayerGrowthType.balanced;
      expect(TrainingEngine.declineSeverity(mc(31)), 1.0);
      expect(TrainingEngine.declineSeverity(mc(32)), greaterThan(1.5));
      expect(TrainingEngine.declineSeverity(mc(34)),
          greaterThan(TrainingEngine.declineSeverity(mc(33))));
      // GK は遅く始まり、遅く速まる(position_peaks_test の決まりを残す)。
      final gk = PlayerGenerator.generate(
          position: Position.gk, strengthTier: 70, ageOverride: 34)
        ..growthType = PlayerGrowthType.balanced;
      expect(TrainingEngine.declineSeverity(gk), 1.0);
    });

    test('画面に出る選手と出ない選手で、1年の落ち方が揃っている', () {
      for (final age in [31, 33, 35]) {
        var on = 0.0;
        var off = 0.0;
        const n = 40;
        for (var i = 0; i < n; i++) {
          final p = PlayerGenerator.generate(
              position: Position.mc, strengthTier: 75, ageOverride: age)
            ..growthType = PlayerGrowthType.balanced;
          p.potential = p.overall;
          final t = Team(id: 't', name: 'T', players: [p]);
          final before = p.overall;
          for (var w = 0; w < 52; w++) {
            TrainingEngine.applyPassiveCpuGrowth(t);
          }
          on += p.overall - before;
          final q = PlayerGenerator.generate(
              position: Position.mc, strengthTier: 75, ageOverride: age)
            ..growthType = PlayerGrowthType.balanced;
          off += OffscreenDevelopment.yearlyChange(q, Random(i));
        }
        expect((on - off).abs() / n, lessThan(0.8), reason: '$age歳');
        if (age == 35) {
          expect(on / n, lessThan(-2.5), reason: '35歳は年2.5以上落ちる');
        }
        if (age == 31) {
          expect(on / n, greaterThan(-1.5), reason: '31歳はまだ緩い');
        }
      }
    });
  });

  group('レンタル', () {
    test('買取額は市場価値と同じか少し上(完全移籍より安い抜け道にしない)', () {
      expect(GameState.loanBuyOptionRatio, greaterThanOrEqualTo(1.0));
      expect(GameState.loanBuyOptionRatio, lessThanOrEqualTo(1.2));
    });

    test('同時に借りられるのは6人まで', () async {
      final gs = GameState();
      await gs.startNewGame('レンタルFC');
      gs.save!.budget = 1 << 40;
      gs.save!.wageBudget = 1 << 30;
      for (var i = 0; i < GameState.maxLoansIn; i++) {
        gs.userTeam.players.add(make('loan$i', age: 20)..isLoan = true);
      }
      final target = gs.transferTargets.firstWhere((p) => p.age >= 18);
      expect(await gs.signLoanPlayer(target.id), isFalse);
      expect(gs.lastSigningBlockReason, contains('${GameState.maxLoansIn}'));
    });

    test('同時に貸し出せるのは6人まで', () async {
      final gs = GameState();
      await gs.startNewGame('レンタルFC');
      final squad = gs.userTeam.players;
      for (var i = 0; i < 12; i++) {
        squad.add(make('extra$i', age: 19));
      }
      for (final p in squad.take(GameState.maxLoansOut)) {
        p.loanedOutWeeksRemaining = 10;
      }
      final next = squad.firstWhere((p) => !p.isLoanedOut && !p.isLoan);
      expect(await gs.loanOutPlayer(next.id), isFalse);
      expect(gs.lastSigningBlockReason, contains('${GameState.maxLoansOut}'));
    });
  });

  group('所属なしの選手', () {
    test('夏は数十人いて、季が進むと減る', () async {
      final gs = GameState();
      await gs.startNewGame('自由FC');
      expect(gs.freeAgents.length,
          greaterThanOrEqualTo(FreeAgentEngine.summerPoolSize));
      final pool = [...gs.freeAgents];
      final rng = Random(3);
      for (var w = 0; w < 20; w++) {
        FreeAgentEngine.weeklyDrift(pool, DateTime(2026, 12, 1), rng: rng);
      }
      expect(
          pool.length,
          lessThanOrEqualTo(
              FreeAgentEngine.targetPoolSize(DateTime(2026, 12, 1)) + 2));
      expect(FreeAgentEngine.targetPoolSize(DateTime(2026, 7, 10)),
          greaterThan(FreeAgentEngine.targetPoolSize(DateTime(2027, 3, 1))));
    });

    test('取るときは契約金(年俸の2割)と代理人手数料(年俸の1割前後)がかかる', () async {
      final gs = GameState();
      await gs.startNewGame('自由FC');
      gs.save!.wageBudget = 1 << 30;
      gs.save!.budget = 1 << 40;
      final fa = gs.freeAgents
          .firstWhere((p) => p.age <= 30 && gs.registrationBlockFor(p) == null);
      final annual = fa.wage * 52;
      expect(gs.freeAgentSigningFeeFor(fa),
          TransferTermsEngine.freeAgentSigningFee(annual));
      expect(TransferTermsEngine.freeAgentSigningFee(1000), 200);
      final agentPct = RelationsEngine.agentOf(fa).feePercent;
      expect(agentPct, inInclusiveRange(8, 12));
      expect(gs.freeAgentAgentFeeFor(fa, fa.wage),
          (annual * agentPct / 100).round());
      final budget = gs.save!.budget;
      // 契約すると週俸が書き換わるので、先に計算しておく。
      final weekly = fa.wage * 2;
      final expectedCost =
          gs.freeAgentSigningFeeFor(fa) + gs.freeAgentAgentFeeFor(fa, weekly);
      expect(expectedCost, greaterThan(0));
      final out = await gs.offerPersonalTerms(fa.id,
          weeklyWage: weekly, endYear: Player.contractClockYear + 2);
      expect(out, TermsOutcome.signed, reason: gs.lastSigningBlockReason);
      expect(budget - gs.save!.budget, expectedCost,
          reason: 'サイン料を出さなくても最低の契約金と手数料はかかる');
    });

    test('窓の外でも取れる(実在の決まりどおり)', () async {
      final gs = GameState();
      await gs.startNewGame('自由FC');
      gs.save!.today = DateTime(2026, 10, 15);
      gs.save!.wageBudget = 1 << 30;
      gs.save!.budget = 1 << 40;
      expect(gs.isTransferWindowOpen, isFalse);
      final fa = gs.freeAgents.first..age = 20;
      expect(await gs.signFreeAgent(fa.id), isTrue);
    });
  });

  group('契約の長さ', () {
    tearDown(() =>
        ContractEngine.adultContractYearsCap = ContractEngine.maxContractYears);

    test('スペインは8年まで、ほかは5年まで(18歳未満は3年)', () async {
      final es = GameState();
      await es.startNewGame('長期FC', theme: LeagueTheme.spain);
      expect(ContractEngine.endYearChoicesNow(25).length, 7,
          reason: '来季末から8年目の末まで');
      expect(ContractEngine.capYears(17), 3);
      final en = GameState();
      await en.startNewGame('長期FC');
      expect(ContractEngine.endYearChoicesNow(25).length, 4);
      expect(ContractEngine.capYears(25), 5);
    });
  });

  group('仮契約・18歳未満・連帯貢献金・代理人手数料', () {
    test('国内のクラブの選手との仮契約は、イングランドは6月から・イタリアは2月から', () {
      final p = make('pc')..contractEndYear = Player.contractClockYear;
      final y = Player.contractClockYear;
      String? reason(LeagueTheme t, DateTime d, {bool foreign = false}) =>
          PreContractEngine.blockReason(p,
              today: d,
              fromForeignLeague: foreign,
              alreadyPreContracted: false,
              domesticOpensOn: PreContractEngine.domesticOpensOn(t));
      expect(reason(LeagueTheme.england, DateTime(y, 1, 1)), 'domesticNotYet');
      expect(reason(LeagueTheme.england, DateTime(y, 1, 1), foreign: true),
          isNull);
      expect(reason(LeagueTheme.england, DateTime(y, 6, 1)), isNull);
      expect(reason(LeagueTheme.italy, DateTime(y, 1, 15)), 'domesticNotYet');
      expect(reason(LeagueTheme.italy, DateTime(y, 2, 1)), isNull);
      expect(reason(LeagueTheme.germany, DateTime(y, 1, 1)), isNull);
    });

    test('18歳未満の国際移籍は、EU の中の16〜17歳だけ例外', () {
      expect(minorMayMoveBetween(17, LeagueTheme.spain, LeagueTheme.germany),
          isTrue);
      expect(minorMayMoveBetween(16, LeagueTheme.france, LeagueTheme.italy),
          isTrue);
      expect(minorMayMoveBetween(15, LeagueTheme.spain, LeagueTheme.germany),
          isFalse);
      expect(minorMayMoveBetween(17, LeagueTheme.spain, LeagueTheme.england),
          isFalse,
          reason: 'イングランドは EU の外');
      expect(minorMayMoveBetween(17, LeagueTheme.england, LeagueTheme.italy),
          isFalse);
      expect(minorMayMoveBetween(15, LeagueTheme.england, LeagueTheme.england),
          isTrue);
    });

    test('ゲームの中: ドイツのクラブは他の国の1部の17歳を狙える', () async {
      final gs = GameState();
      await gs.startNewGame('若手FC', theme: LeagueTheme.germany);
      final club = gs.save!.foreignLeagues[LeagueTheme.spain.name]!.teams.first;
      final kid = club.players.first..age = 17;
      expect(gs.transferTargets.any((p) => p.id == kid.id), isTrue);
      final eng = GameState();
      await eng.startNewGame('若手FC');
      final club2 =
          eng.save!.foreignLeagues[LeagueTheme.spain.name]!.teams.first;
      final kid2 = club2.players.first..age = 17;
      expect(eng.transferTargets.any((p) => p.id == kid2.id), isFalse);
    });

    test('連帯貢献金は国をまたぐ移籍だけ。代理人手数料は1割前後', () async {
      final gs = GameState();
      await gs.startNewGame('売却FC');
      final p = gs.userTeam.players.first..academyGraduate = false;
      expect(gs.solidarityFor(p, 1000, international: false), 0);
      expect(gs.solidarityFor(p, 1000), 50);
      expect(TransferTermsEngine.agentFee(1000), 100);
      expect(AgentStyle.standard.feePercent, 10);
    });
  });
}

String _encode(SaveGame s) => jsonEncode(s.toJson());
