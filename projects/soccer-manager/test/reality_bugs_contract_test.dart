import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/contract_style.dart';
import 'package:soccer_manager/logic/manager_hr_engine.dart';
import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/contract_negotiation.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 契約まわりの「ゲームの中でつじつまが合わない」所を直した検査。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make(String id, {int age = 25}) =>
      Player(id: id, name: id, age: age, position: Position.mc, potential: 60);

  group('1. 売却では売り手が違約金を払わない', () {
    test('高年俸・長期契約でも、売値は市場価値の7割のまま', () async {
      final gs = GameState();
      await gs.startNewGame('売却FC');
      final p = make('rb_sale')
        ..wage = 500
        ..contractYearsRemaining = 5;
      gs.userTeam.players.add(p);
      final net = gs.netReleaseValueFor(p.id);
      expect(net, ContractEngine.salePrice(p));
      expect(net, (p.marketValue * 0.7).round());
      expect(net, greaterThan(0));

      final before = gs.save!.budget;
      expect(await gs.sellPlayer(p.id), isTrue);
      expect(gs.save!.budget, before + net, reason: '違約金は引かれない');
    });

    test('合意解除では、今まで通り残りの年俸の一部を払う', () async {
      final gs = GameState();
      await gs.startNewGame('解除FC');
      gs.save!.budget = 99999999;
      final p = make('rb_mutual')
        ..wage = 100
        ..contractYearsRemaining = 3;
      gs.userTeam.players.add(p);
      final cost = gs.mutualTerminationCostFor(p.id)!;
      expect(cost, greaterThan(0));
      expect(cost, ContractEngine.mutualTerminationCost(p, gs.today));
      final before = gs.save!.budget;
      expect(await gs.terminateContractByMutualConsent(p.id), isTrue);
      expect(gs.save!.budget, before - cost);
    });
  });

  group('2. 序列と年俸の向きが移籍と更新で揃う', () {
    test('移籍の交渉も更新も、立場が上ほど高い年俸を求める', () {
      for (final s in SquadStatus.values) {
        expect(PlayerTermsEngine.promiseFactor(s), s.wageFactor);
      }
      expect(PlayerTermsEngine.promiseFactor(SquadStatus.keyPlayer), 1.15);
      expect(PlayerTermsEngine.promiseFactor(SquadStatus.prospect), 0.85);

      int demand(SquadStatus s) => PlayerTermsEngine.demand(
        currentWage: 100,
        fairWage: 0,
        fromTier: 3,
        toTier: 3,
        wasStarter: false,
        wouldStart: true,
        promise: s,
      );
      expect(
        demand(SquadStatus.keyPlayer),
        greaterThan(demand(SquadStatus.regular)),
      );
      expect(
        demand(SquadStatus.regular),
        greaterThan(demand(SquadStatus.rotation)),
      );
      expect(
        demand(SquadStatus.rotation),
        greaterThan(demand(SquadStatus.prospect)),
      );

      int renewal(SquadStatus s) => ContractEngine.minimumAcceptableWage(
        make('r')
          ..wage = 100
          ..squadStatus = s,
      );
      expect(
        renewal(SquadStatus.keyPlayer),
        greaterThan(renewal(SquadStatus.prospect)),
      );
    });

    test('育成枠で更新した選手をキープレイヤーに上げると、週俸の見直しを求める', () async {
      final gs = GameState();
      await gs.startNewGame('序列FC');
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan)
        ..squadStatus = SquadStatus.prospect
        ..wage = 85
        ..wageStatus = SquadStatus.prospect; // 育成枠で交渉して決めた週俸
      gs.setSquadStatus(p.id, SquadStatus.keyPlayer);
      expect(p.wage, (85 * 1.15 / 0.85).round());
      expect(p.wageStatus, SquadStatus.keyPlayer);
      expect(gs.save!.newsLog.first.text, contains(p.name));

      // 下げても週俸は下がらず、元の立場へ戻しても二重には上がらない。
      final raised = p.wage;
      gs.setSquadStatus(p.id, SquadStatus.rotation);
      expect(p.wage, raised);
      gs.setSquadStatus(p.id, SquadStatus.keyPlayer);
      expect(p.wage, raised);
    });

    test('更新の交渉で合意した週俸は、そのときの序列で決めたものとして残る', () async {
      final gs = GameState();
      await gs.startNewGame('更新FC');
      gs.save!.budget = 99999999;
      final p = gs.userTeam.players.firstWhere(
        (p) => !p.isLoan && gs.renewalBlockReason(p) == null,
      )..squadStatus = SquadStatus.prospect;
      gs.startContractNegotiation(p.id);
      final wage = ContractEngine.minimumAcceptableWage(p);
      expect(await gs.offerContractWage(wage), ContractOfferResult.accepted);
      expect(p.wageStatus, SquadStatus.prospect);
      gs.setSquadStatus(p.id, SquadStatus.keyPlayer);
      expect(p.wage, greaterThan(wage));
    });

    test('記録の無い(旧セーブ・獲得したままの)選手は標準の立場として扱う', () async {
      final gs = GameState();
      await gs.startNewGame('旧FC');
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan)
        ..squadStatus = SquadStatus.regular
        ..wage = 100
        ..wageStatus = null;
      gs.setSquadStatus(p.id, SquadStatus.rotation);
      expect(p.wage, 100, reason: '下げても変わらない');
      gs.setSquadStatus(p.id, SquadStatus.regular);
      expect(p.wage, 100, reason: '標準へ戻すだけなら変わらない');
      gs.setSquadStatus(p.id, SquadStatus.keyPlayer);
      expect(p.wage, 115);
    });

    test('週俸を決めたときの序列は保存して読み戻せる', () {
      final p = make('rb_json')..wageStatus = SquadStatus.prospect;
      expect(Player.fromJson(p.toJson()).wageStatus, SquadStatus.prospect);
      expect(Player.fromJson(make('rb_json2').toJson()).wageStatus, isNull);
    });
  });

  group('3. 買取義務で完全移籍になったら新しい契約が付く', () {
    test('元のクラブとの契約が切れていても、年齢に合った年数の契約になる', () async {
      final gs = GameState();
      await gs.startNewGame('義務FC');
      gs.save!.budget = 99999999;
      final parent = gs.save!.league.teams.firstWhere(
        (t) => t.id != gs.save!.userTeamId,
      );
      final p = make('rb_obligation', age: 24)
        ..isLoan = true
        ..loanObligation = true
        ..loanBuyOptionFee = 100
        ..loanFromClubId = parent.id
        ..loanEndDate = gs.today
        ..contractEndYear = Player.contractClockYear - 1; // 契約なし
      gs.userTeam.players.add(p);
      gs.debugSettleLoansByDate();
      expect(gs.userTeam.players.contains(p), isTrue);
      expect(p.isLoan, isFalse);
      expect(
        p.contractEndYear,
        Player.contractClockYear + ContractEngine.negotiatedYears(p),
      );
      expect(p.contractYearsRemaining, greaterThan(1));
    });
  });

  group('4. 18歳未満の契約は、どの移籍でも3年まで', () {
    test('他のクラブへ移ったときの契約は、18歳未満なら3年に収まる', () {
      final young = make('rb_young', age: 16);
      ContractEngine.applyCpuClubContract(young, 4);
      expect(
        young.contractYearsRemaining,
        ContractEngine.maxMinorContractYears,
      );
      final adult = make('rb_adult', age: 25);
      ContractEngine.applyCpuClubContract(adult, 4);
      expect(adult.contractYearsRemaining, 4);
    });

    test('売却先へ移った16歳の契約は3年以内', () async {
      for (var i = 0; i < 5; i++) {
        final gs = GameState();
        await gs.startNewGame('若手FC$i');
        final p = make('rb_sold_$i', age: 16);
        gs.userTeam.players.add(p);
        expect(await gs.sellPlayer(p.id), isTrue);
        final moved = gs.save!.league.teams
            .expand((t) => t.players)
            .where((x) => x.id == p.id)
            .firstOrNull;
        expect(moved, isNotNull);
        expect(
          moved!.contractYearsRemaining,
          lessThanOrEqualTo(ContractEngine.maxMinorContractYears),
        );
      }
    });

    test('AI 同士の移籍で動いた16歳の契約も3年以内', () async {
      final gs = GameState();
      await gs.startNewGame('AI FC');
      final userId = gs.save!.userTeamId;
      final teams = gs.save!.league.teams;
      final marker = Player.contractClockYear + 10;
      for (final t in teams.where((t) => t.id != userId)) {
        for (final p in t.players) {
          p.age = 16;
          p.contractEndYear = marker;
        }
      }
      var moves = 0;
      for (var seed = 0; seed < 200 && moves < 10; seed++) {
        if (AiTransferEngine.maybeGenerate(teams, userId, Random(seed)) ==
            null) {
          continue;
        }
        moves++;
      }
      expect(moves, greaterThan(0));
      final moved = teams
          .where((t) => t.id != userId)
          .expand((t) => t.players)
          .where((p) => p.contractEndYear != marker)
          .toList();
      expect(moved, isNotEmpty);
      for (final p in moved) {
        expect(
          p.contractYearsRemaining,
          lessThanOrEqualTo(ContractEngine.maxMinorContractYears),
        );
      }
    });
  });

  group('5・7. スタッフの違約金は残りの日数に応じ、監督の率は決まりから', () {
    StaffMember staff(StaffRole r, int years) => StaffMember(
      id: r.name,
      name: 'x',
      age: 50,
      role: r,
      attributes: const {},
      wage: 10,
      contractYears: years,
    );

    test('5月に解任すれば、残りの約2か月分だけ', () {
      final m = staff(StaffRole.manager, 1);
      // 2027年5月1日 → 6月30日は60日 = 9週(切り上げ)。
      expect(m.severanceOn(DateTime(2027, 5, 1), 2027), 10 * 9);
      expect(m.severanceOn(DateTime(2027, 5, 1), 2027), lessThan(10 * 52));
      // 季の始めなら、ほぼ1年分。
      expect(m.severanceOn(DateTime(2026, 7, 1), 2027), 10 * 52);
      // 満了日を過ぎていれば掛からない。
      expect(m.severanceOn(DateTime(2027, 7, 1), 2027), 0);
    });

    test('監督は ManagerHrEngine の率、他の役職は2割', () {
      expect(
        staff(StaffRole.manager, 2).severanceRate,
        ManagerHrEngine.managerSeveranceRate,
      );
      expect(
        staff(StaffRole.scout, 2).severanceRate,
        StaffMember.staffSeveranceRate,
      );
      final day = DateTime(2026, 10, 1);
      expect(
        staff(StaffRole.scout, 2).severanceOn(day, 2027),
        (staff(StaffRole.manager, 2).severanceOn(day, 2027) *
                StaffMember.staffSeveranceRate /
                ManagerHrEngine.managerSeveranceRate)
            .round(),
      );
    });

    test('ゲームの中の解任でも、今日から満了までの額を払う', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      final s = staff(StaffRole.scout, 2)..wage = 50;
      gs.save!.infrastructure.staff[StaffRole.scout] = s;
      final expected = gs.scaledMoney(
        s.severanceOn(gs.today, Player.contractClockYear),
      );
      expect(gs.staffSeveranceFor(s), expected);
      final before = gs.save!.budget;
      expect(await gs.dismissStaff(StaffRole.scout), isTrue);
      expect(gs.save!.budget, before - expected);
    });
  });

  group('6. 新しい契約になったら契約の型は「固定」に戻る', () {
    Player styled() => make('rb_style')
      ..wage = 100
      ..goalBonus = 50
      ..raisePct = 5;

    test('更新・移籍・仮契約の加入・他のクラブへの移籍のどれでも戻る', () {
      for (final apply in <void Function(Player)>[
        (p) => ContractEngine.renewContract(p),
        (p) => ContractEngine.applyTransferContract(p),
        (p) => ContractEngine.applyCpuClubContract(p, 3),
        (p) => PreContractEngine.applyOnJoin(
          p,
          PreContract(
            playerId: p.id,
            playerName: p.name,
            fromClubId: 'a',
            fromClubName: 'A',
            toClubId: 'b',
            toClubName: 'B',
            wage: 120,
            endYear: Player.contractClockYear + 2,
            option: false,
            signedOn: DateTime(2027, 1, 1),
          ),
        ),
      ]) {
        final p = styled();
        apply(p);
        expect(p.goalBonus, 0);
        expect(p.raisePct, 0);
      }
    });

    test('段階昇給の選手を更新すると、それ以降は季が変わっても上がらない', () async {
      final gs = GameState();
      await gs.startNewGame('昇給FC');
      gs.save!.budget = 99999999;
      final p =
          gs.userTeam.players.firstWhere(
              (p) => !p.isLoan && gs.renewalBlockReason(p) == null,
            )
            ..wage = 100
            ..happiness = 60;
      expect(await gs.changeContractStyle(p.id, ContractStyle.stepped), isTrue);
      expect(await gs.renewContract(p.id), isTrue);
      expect(gs.contractStyleOf(p), ContractStyle.fixed);
      final wage = p.wage;
      gs.debugApplySteppedRaises();
      expect(p.wage, wage);
    });
  });
}
