import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/logic/youth_promotion_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_stub.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// いつも同じ値を返す乱数(確率の分岐を決め打ちで通すため)。
class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// 契約を満了日(○年6月30日)で持つ作りの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late int savedClock;
  setUp(() => savedClock = Player.contractClockYear);
  tearDown(() => Player.contractClockYear = savedClock);

  Player make({int age = 25, int strength = 60}) => PlayerGenerator.generate(
        position: Position.mc,
        ageOverride: age,
        strengthTier: strength,
      );

  group('満了日の持ち方と表示', () {
    test('残り年数は今のシーズンを含めて数え、満了の年に直る', () {
      Player.contractClockYear = 2027; // 第1季(2026/27)
      final p = make()..contractYearsRemaining = 1;
      expect(p.contractEndYear, 2027, reason: '残り1年は今のシーズン末で満了');
      p.contractYearsRemaining = 3;
      expect(p.contractEndYear, 2029);
      Player.contractClockYear = 2028; // 7月1日に次のシーズンへ
      expect(p.contractYearsRemaining, 2, reason: '年が進むと残りが自然に減る');
    });

    test('表示は「2028年6月まで」/ "until Jun 2028"', () {
      Player.contractClockYear = 2027;
      final before = Tr.language;
      addTearDown(() => Tr.language = before);
      Tr.language = AppLanguage.japanese;
      expect(ContractEngine.untilLabel(2028), '2028年6月まで');
      expect(ContractEngine.untilLabel(2026), '契約なし');
      Tr.language = AppLanguage.english;
      expect(ContractEngine.untilLabel(2028), 'until Jun 2028');
    });

    test('旧セーブの残り年数は「今のシーズンの6/30 + 残り-1」に換算する', () {
      final p = make();
      final json = p.toJson()
        ..remove('contractEndYear')
        ..['contractYearsRemaining'] = 2;
      // 第3季(2028/29、終わる年は2029)のセーブ。
      Player.contractClockYear = Player.seasonEndYearOf(3);
      final restored = Player.fromJson(json);
      expect(restored.contractEndYear, 2030);
      expect(restored.contractYearsRemaining, 2);
    });

    test('セーブの読み込みは、そのシーズンを基準に旧形式を換算する', () {
      Player.contractClockYear = 2027;
      final p = make()..contractYearsRemaining = 1;
      final json = p.toJson()
        ..remove('contractEndYear')
        ..['contractYearsRemaining'] = 1;
      final save = SaveGame.fromJson({
        'clubName': 'C',
        'userTeamId': 'u',
        'league': {
          'teams': [
            {
              'id': 'u',
              'name': 'U',
              'players': [json],
            }
          ],
          'fixtures': [],
          'season': 4,
        },
      });
      expect(Player.contractClockYear, 2030, reason: '第4季は2030年6月に終わる');
      expect(save.league.teams.first.players.first.contractEndYear, 2030);
    });

    test('軽い形の保存は満了の年を持ち、往復しても変わらない', () {
      Player.contractClockYear = 2028;
      final p = make()..contractEndYear = 2031;
      final encoded = PlayerStub.encode(p);
      expect(encoded[7], 2031);
      final decoded =
          PlayerStub.decode(jsonDecode(jsonEncode(encoded)) as List<dynamic>);
      expect(decoded.contractEndYear, 2031);
    });

    test('旧セーブの軽い形(年数)も満了の年に直す', () {
      Player.contractClockYear = 2028;
      final p = make();
      final encoded = PlayerStub.encode(p)..[7] = 3;
      final decoded = PlayerStub.decode(encoded);
      expect(decoded.contractEndYear, 2030);
    });
  });

  group('6月30日で自由契約', () {
    test('満了の年を過ぎると外れ、満了の年に入った選手は知らせる', () {
      Player.contractClockYear = 2027;
      final ending = make()..contractEndYear = 2027;
      final next = make()..contractEndYear = 2028;
      final long = make()..contractEndYear = 2031;
      final team = Team(id: 't', name: 'T', players: [ending, next, long]);
      Player.contractClockYear = 2028; // 7月1日
      final r = ContractEngine.advanceSeason(team);
      expect(r.expired, [ending]);
      expect(r.nearingExpiry, [next]);
      expect(team.players, isNot(contains(ending)));
    });

    test('新しいシーズンに入ると、自クラブも他のクラブも満了した選手が出ていく',
        () async {
      final game = GameState();
      await game.startNewGame('満了FC');
      final clock = Player.contractClockYear;
      final mine = game.userTeam.players.first..contractEndYear = clock;
      for (final p in game.userTeam.players.skip(1)) {
        p.contractEndYear = clock + 3;
      }
      final cpu = game.save!.league.teams.firstWhere((t) => t.id != 'user');
      final theirs = cpu.players.first..contractEndYear = clock;
      final cpuSize = cpu.players.length;
      // シーズンを終えた5月末から進める(1月1日の仮契約の処理は済んだ扱い)。
      game.save!.today = DateTime(clock, 5, 31);

      await game.startNextSeason();

      expect(Player.contractClockYear, clock + 1);
      expect(game.userTeam.players.any((p) => p.id == mine.id), isFalse);
      expect(game.lastContractExpirations, contains(mine.name));
      final cpuNow = game.save!.allTeams.firstWhere((t) => t.id == cpu.id);
      expect(cpuNow.players.any((p) => p.id == theirs.id), isFalse,
          reason: '他のクラブの満了した選手も出ていく');
      expect(cpuNow.players.length, greaterThanOrEqualTo(cpuSize - 2),
          reason: '抜けた分は若手で埋める');
    });
  });

  group('仮契約(ボスマン)', () {
    test('1月1日から6月30日まで、満了の年の選手とだけ結べる', () {
      Player.contractClockYear = 2027;
      expect(PreContractEngine.isOpen(DateTime(2026, 12, 31)), isFalse);
      expect(PreContractEngine.isOpen(DateTime(2027, 1, 1)), isTrue);
      expect(PreContractEngine.isOpen(DateTime(2027, 6, 30)), isTrue);
      final p = make()..contractEndYear = 2028;
      expect(
          PreContractEngine.blockReason(p,
              today: DateTime(2027, 2, 1),
              fromForeignLeague: false,
              alreadyPreContracted: false),
          'notFinalYear');
    });

    test('他国の18歳未満とは仮契約も結べない', () {
      Player.contractClockYear = 2027;
      final p = make(age: 17)..contractEndYear = 2027;
      expect(
          PreContractEngine.blockReason(p,
              today: DateTime(2027, 2, 1),
              fromForeignLeague: true,
              alreadyPreContracted: false),
          'minor');
    });

    test('1月1日に結び、7月1日に移籍金なしで加入する', () async {
      final game = GameState();
      await game.startNewGame('仮契約FC');
      final clock = Player.contractClockYear;
      final cpu = game.save!.league.teams.firstWhere((t) => t.id != 'user');
      // 引退・ベテランの入れ替えで消えない年齢にしておく。
      final target = cpu.players.first
        ..age = 24
        ..contractEndYear = clock;
      // 自クラブの選手は来季も残る(枠の検査で止まらないように)。
      for (final p in game.userTeam.players) {
        p.contractEndYear = clock + 2;
      }

      game.save!.today = DateTime(clock - 1, 12, 31);
      expect(await game.signPreContract(target.id), isFalse,
          reason: '12月31日はまだ結べない');

      game.save!.today = DateTime(clock, 1, 1);
      final budget = game.save!.budget;
      expect(await game.signPreContract(target.id, endYear: clock + 3),
          isTrue,
          reason: game.lastSigningBlockReason ?? '');
      expect(game.save!.budget, budget, reason: '移籍金はかからない');
      expect(game.incomingPreContracts.map((c) => c.playerId),
          contains(target.id));
      expect(game.userTeam.players.any((p) => p.id == target.id), isFalse,
          reason: '加入は7月1日');

      await game.startNextSeason();

      final joined =
          game.userTeam.players.where((p) => p.id == target.id).toList();
      expect(joined, hasLength(1));
      expect(joined.first.contractEndYear, clock + 3);
      expect(game.preContracts, isEmpty);
    });

    test('仮契約の長さも最長5年、18歳未満は3年', () {
      Player.contractClockYear = 2027;
      final adult = make(age: 25);
      final minor = make(age: 16);
      expect(PreContractEngine.endYearChoices(adult).last, 2032,
          reason: '2027年7月1日から5年');
      expect(PreContractEngine.endYearChoices(minor).last, 2030);
    });

    test('AI は自クラブの満了の年の選手と仮契約を結び、7月1日に連れていく',
        () async {
      Player.contractClockYear = 2027;
      final mine = make()..contractEndYear = 2027;
      final user = Team(id: 'user', name: 'U', players: [mine]);
      final cpu = Team(id: 'c', name: 'C', players: [make()]);
      final made = PreContractEngine.poachFromUser(
        user,
        [cpu],
        _FixedRandom(0.0),
        today: DateTime(2027, 2, 1),
      );
      expect(made.map((c) => c.playerId), [mine.id]);
      expect(made.first.toClubId, 'c');

      // 延長オプションを行使できる間(3月31日まで)は取られない。
      mine.contractOption = true;
      expect(
          PreContractEngine.poachFromUser(user, [cpu], _FixedRandom(0.0),
              today: DateTime(2027, 3, 1)),
          isEmpty);
    });

    test('自クラブの選手が他のクラブと仮契約すると更新できず、7月1日に移る',
        () async {
      final game = GameState();
      await game.startNewGame('流出FC');
      final clock = Player.contractClockYear;
      final mine = game.userTeam.players.first
        ..age = 24
        ..contractEndYear = clock;
      final cpu = game.save!.league.teams.firstWhere((t) => t.id != 'user');
      game.save!.preContracts.add(PreContract(
        playerId: mine.id,
        playerName: mine.name,
        fromClubId: 'user',
        fromClubName: game.userTeam.name,
        toClubId: cpu.id,
        toClubName: cpu.name,
        wage: mine.wage,
        endYear: clock + 2,
        option: false,
        signedOn: DateTime(clock, 1, 10),
      ));
      expect(game.renewalBlockReason(mine), isNotNull);
      expect(await game.renewContract(mine.id), isFalse);

      await game.startNextSeason();

      final cpuNow = game.save!.allTeams.firstWhere((t) => t.id == cpu.id);
      expect(cpuNow.players.any((p) => p.id == mine.id), isTrue,
          reason: '仮契約の先へ移っている');
      expect(game.userTeam.players.any((p) => p.id == mine.id), isFalse);
    });

    test('1月1日の解禁で、AI は自分の選手を更新するか決める', () {
      Player.contractClockYear = 2027;
      final a = Team(id: 'a', name: 'A', players: [
        for (var i = 0; i < 5; i++) make()..contractEndYear = 2027,
      ]);
      final b = Team(id: 'b', name: 'B', players: [make()]);
      // 乱数0: 全員更新される。
      PreContractEngine.openSeasonForAi([a, b], 'user', _FixedRandom(0.0),
          today: DateTime(2027, 1, 1));
      expect(a.players.every((p) => p.contractEndYear > 2027), isTrue);
      // 乱数0.99: 更新されず、仮契約も結ばれない(相手として残る)。
      for (final p in a.players) {
        p.contractEndYear = 2027;
      }
      final made = PreContractEngine.openSeasonForAi(
          [a, b], 'user', _FixedRandom(0.99),
          today: DateTime(2027, 1, 1));
      expect(made, isEmpty);
      expect(a.players.every((p) => p.contractEndYear == 2027), isTrue);
    });
  });

  group('110. 契約の長さの上限', () {
    test('最長5年、18歳未満は3年', () {
      Player.contractClockYear = 2027;
      final adult = make(age: 25);
      ContractEngine.renewContract(adult, endYear: 2040);
      expect(adult.contractEndYear, 2031, reason: '今のシーズンから数えて5年まで');
      final minor = make(age: 16);
      ContractEngine.renewContract(minor, endYear: 2040);
      expect(minor.contractEndYear, 2029, reason: '18歳未満は3年まで');
    });

    test('移籍で獲った選手の長い契約も上限に縮める', () {
      Player.contractClockYear = 2027;
      final p = make(age: 17)..contractEndYear = 2035;
      ContractEngine.applyTransferContract(p);
      expect(p.contractEndYear, 2029);
    });
  });

  group('111. 延長オプション', () {
    test('3月31日まで行使でき、同じ年俸で1年延びる', () {
      Player.contractClockYear = 2027;
      final p = make()
        ..contractEndYear = 2027
        ..contractOption = true;
      final wage = p.wage;
      expect(ContractEngine.canExerciseOption(p, DateTime(2027, 3, 31)), isTrue);
      expect(ContractEngine.canExerciseOption(p, DateTime(2027, 4, 1)), isFalse);
      ContractEngine.exerciseOption(p);
      expect(p.contractEndYear, 2028);
      expect(p.wage, wage);
      expect(p.contractOption, isFalse);
    });

    test('付けられるのは、延びても上限に収まるときだけ', () {
      Player.contractClockYear = 2027;
      expect(ContractEngine.canAttachOption(2030, 25), isTrue);
      expect(ContractEngine.canAttachOption(2031, 25), isFalse);
      final p = make();
      ContractEngine.renewContract(p, endYear: 2031, option: true);
      expect(p.contractOption, isFalse);
    });

    test('更新の交渉でオプションを付けると、求める週俸が5%上がる', () async {
      final game = GameState();
      await game.startNewGame('オプションFC');
      final p = game.userTeam.players.first;
      game.startContractNegotiation(p.id);
      final plain = game.pendingContractNegotiation!.counterWage;
      game.cancelContractNegotiation();
      game.startContractNegotiation(p.id,
          endYear: Player.contractClockYear + 1, option: true);
      expect(game.pendingContractNegotiation!.counterWage,
          (plain * ContractEngine.optionWageFactor).round());
    });

    test('行使しなかったオプションは期限で消える(保存も往復する)', () {
      Player.contractClockYear = 2027;
      final p = make()
        ..contractEndYear = 2027
        ..contractOption = true
        ..refusesRenewal = true;
      final r = Player.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(r.contractOption, isTrue);
      expect(r.refusesRenewal, isTrue);
    });
  });

  group('112. プロ契約は16歳から', () {
    test('16歳未満は昇格できない', () async {
      final game = GameState();
      await game.startNewGame('ユースFC');
      final kid = make(age: 15);
      game.save!.youthProspects.add(kid);
      game.save!.budget = 1000000;
      game.save!.wageBudget = 999999;
      expect(await game.promoteYouthProspect(kid.id), isFalse);
      expect(game.lastSigningBlockReason, contains('16'));
    });

    test('年数を選べ、18歳未満は3年まで', () async {
      final game = GameState();
      await game.startNewGame('ユースFC2');
      final p = make(age: 16);
      game.save!.youthProspects.add(p);
      game.save!.budget = 1000000;
      game.save!.wageBudget = 999999;
      expect(YouthPromotionEngine.yearChoices(p), [1, 2, 3]);
      expect(await game.promoteYouthProspect(p.id, years: 5), isTrue,
          reason: game.lastSigningBlockReason ?? '');
      expect(p.contractYearsRemaining, 3, reason: '5年を選んでも3年に収める');
    });
  });

  group('113. 「延長しない」選手', () {
    test('性格・不満・年俸で確率が変わる(上限60%)', () {
      final calm = make()
        ..personality = PlayerPersonality.loyal
        ..happiness = 90;
      // 能力が高く価値があるのに年俸が安い(作った選手の価値で結果が
      // 揺れないよう、能力を高くして年俸の不満を必ず立てる)。
      final upset = make(strength: 85)
        ..personality = PlayerPersonality.ambitious
        ..happiness = 30
        ..wage = 5;
      expect(upset.wage * 4 < weeklyWageForValue(upset.marketValue) * 3, isTrue);
      expect(ContractEngine.refuseRenewalChance(calm), lessThan(0.1));
      // 8% + 野心家12% + 不満25% + 年俸の不満10%。
      expect(ContractEngine.refuseRenewalChance(upset), closeTo(0.55, 1e-9));
    });

    test('言い出した選手とは更新できない', () async {
      final game = GameState();
      await game.startNewGame('拒否FC');
      final p = game.userTeam.players.first..refusesRenewal = true;
      game.save!.budget = 1000000;
      expect(await game.renewContract(p.id), isFalse);
      expect(game.lastSigningBlockReason, isNotNull);
      game.startContractNegotiation(p.id);
      expect(game.pendingContractNegotiation, isNull);
    });

    test('残り1年に入ったときに決まる', () async {
      final game = GameState();
      await game.startNewGame('拒否FC2');
      GameStateContracts.contractRng = _FixedRandom(0.0);
      addTearDown(() => GameStateContracts.contractRng = Random());
      final clock = Player.contractClockYear;
      for (final p in game.userTeam.players) {
        p.contractEndYear = clock + 3;
      }
      // 引退しない年齢にしておく(シーズン末の引退判定で消えないように)。
      final p = game.userTeam.players.first
        ..age = 24
        ..contractEndYear = clock + 1;
      await game.startNextSeason();
      final now = game.userTeam.players.firstWhere((x) => x.id == p.id);
      expect(now.refusesRenewal, isTrue);
      expect(game.lastRenewalRefusals, contains(p.name));
    });
  });

  group('114. 給料の未払いで解除', () {
    test('2か月+催告2週(11週)まで続かなければ誰も出ていかない', () {
      final team = Team(
          id: 't', name: 'T', players: [for (var i = 0; i < 10; i++) make()]);
      expect(
          ContractEngine.unpaidWageWalkouts(
              team, ContractEngine.unpaidTerminationWeeks - 1, _FixedRandom(0)),
          isEmpty);
      final leaving = ContractEngine.unpaidWageWalkouts(
          team, ContractEngine.unpaidTerminationWeeks, _FixedRandom(0));
      expect(leaving, hasLength(ContractEngine.unpaidWalkoutsPerWeek));
      final topWage = team.players.map((p) => p.wage).reduce(max);
      expect(leaving.first.wage, topWage, reason: '週俸の高い選手から出ていく');
    });
  });

  group('115. 合意解除', () {
    test('残りの年俸の半分〜全額を、年齢と価値で払う', () {
      Player.contractClockYear = 2027;
      final today = DateTime(2026, 7, 1);
      final young = make(age: 22)
        ..contractEndYear = 2029
        ..wage = 100;
      final old = make(age: 34)
        ..contractEndYear = 2029
        ..wage = 100;
      final remaining = ContractEngine.remainingWages(young, today);
      expect(remaining, 100 * 157, reason: '2029年6月30日まで157週');
      expect(ContractEngine.mutualTerminationCost(young, today),
          (remaining * 0.5).round());
      expect(ContractEngine.mutualTerminationCost(old, today), remaining);
    });

    test('払って解除すると自由契約になる', () async {
      final game = GameState();
      await game.startNewGame('解除FC');
      final p = game.userTeam.players.first;
      final cost = game.mutualTerminationCostFor(p.id)!;
      game.save!.budget = cost + 10;
      expect(await game.terminateContractByMutualConsent(p.id), isTrue,
          reason: game.lastSigningBlockReason ?? '');
      expect(game.save!.budget, 10);
      expect(game.userTeam.players.any((x) => x.id == p.id), isFalse);
      expect(game.freeAgents.any((x) => x.id == p.id), isTrue);
    });
  });
}
