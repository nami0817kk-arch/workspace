import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/transfer_value.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 移籍市場を実際の欧州サッカーに近づけた検査(2026-11-23)。
/// 1. 契約の残り年数が移籍金に効く
/// 2. 売るのは「移籍リスト → 届いたオファーを受ける」の形だけ
/// 3. CPU どうしの移籍は、窓の間は毎週何件も、移籍金付きで動く
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. 契約の残り年数の係数', () {
    test('残り半年0.2・1年0.5・2年0.8・3年1.0・4年以上1.1、間は直線', () {
      expect(TransferValue.contractFactor(0), 0.2);
      expect(TransferValue.contractFactor(0.5), 0.2);
      expect(TransferValue.contractFactor(1), 0.5);
      expect(TransferValue.contractFactor(2), closeTo(0.8, 1e-9));
      expect(TransferValue.contractFactor(3), 1.0);
      expect(TransferValue.contractFactor(4), 1.1);
      expect(TransferValue.contractFactor(6), 1.1);
      expect(TransferValue.contractFactor(1.5), closeTo(0.65, 1e-9));
      expect(TransferValue.contractFactor(0.75), closeTo(0.35, 1e-9));
    });

    test('シーズンの進みを引いて残りを出す(冬の窓で残り1なら半年)', () {
      expect(TransferValue.yearsLeft(1, 0), 1.0);
      expect(TransferValue.yearsLeft(1, 0.5), 0.5);
      expect(TransferValue.yearsLeft(3, 0.5), 2.5);
      expect(TransferValue.yearsLeft(0, 0.5), 0);
    });

    test('売りに出したときの相場も係数込み(残り1年なら市場価値の半分)', () async {
      final gs = GameState();
      await gs.startNewGame('相場FC');
      expect(gs.seasonProgress, 0);
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      p.contractYearsRemaining = 1;
      expect(gs.netReleaseValueFor(p.id), (p.marketValue * 0.5).round());
      p.contractYearsRemaining = 5;
      expect(gs.netReleaseValueFor(p.id), (p.marketValue * 1.1).round());
    });

    test('CPU も同じ係数で判断する: 残り半年の選手は市場価値の2割で応じる', () async {
      final gs = GameState();
      await gs.startNewGame('判断FC');
      final club =
          gs.save!.league.teams.firstWhere((t) => t.id != gs.save!.userTeamId);
      final p = club.players.firstWhere((p) => !club.startingXI.contains(p.id));
      p.contractYearsRemaining = 3;
      final full = gs.transferOfferAcceptChance(1000, 300, player: p);
      expect(full, 0, reason: '残り3年なら3割では断る');
      p.contractYearsRemaining = 1;
      // 残り1年(係数0.5)なら、市場価値の5割で必ず応じる。
      expect(gs.transferOfferAcceptChance(1000, 500, player: p), 1.0);
      // 言い値(交渉)も同じ係数。
      final asking1 = gs.askingPriceFor(p);
      p.contractYearsRemaining = 3;
      final asking3 = gs.askingPriceFor(p);
      expect(asking1, closeTo(asking3 * 0.5, 2));
    });
  });

  group('2. 移籍リストに載せて、届いたオファーで売る', () {
    test('人気のない選手(年を取って力が下の方)には声がかからない', () {
      final old = Player(
          id: 'old',
          name: 'old',
          age: 35,
          position: Position.mc,
          potential: 40);
      expect(TransferValue.listedInterestChance(old, old.overall + 15), 0);
      final young = Player(
          id: 'young',
          name: 'young',
          age: 21,
          position: Position.mc,
          potential: 80);
      expect(TransferValue.listedInterestChance(young, young.overall),
          greaterThan(0.3));
    });

    test('載せた選手に、相場の0.75〜0.98倍の額でオファーが届く', () async {
      final gs = GameState();
      await gs.startNewGame('売却FC');
      expect(gs.isTransferWindowOpen, isTrue);
      final s = gs.save!;
      final team = gs.userTeam;
      // いちばん力のある選手(人気がある)を載せる。
      final star = ([...team.players.where((p) => !p.isLoan)]
            ..sort((a, b) => b.overall.compareTo(a.overall)))
          .first;
      await gs.setTransferListed(star.id, true);
      var got = s.incomingOffers.where((o) => o.playerId == star.id).toList();
      for (var week = 0; week < 12 && got.isEmpty; week++) {
        gs.debugAdvanceIncomingOffers();
        got = s.incomingOffers.where((o) => o.playerId == star.id).toList();
      }
      expect(got, isNotEmpty, reason: '主力を売りに出したのに声がかからない');
      final worth = gs.netReleaseValueFor(star.id);
      final index = gs.marketIndex / 100;
      expect(
          got.first.amount,
          inInclusiveRange((worth * 0.75 * index).floor() - 1,
              (worth * 0.98 * index).ceil() + 1));
      // その場では売れていない(受けるまでは自クラブの選手)。
      expect(team.players.contains(star), isTrue);

      final before = s.budget;
      expect(await gs.acceptIncomingOffer(got.first.id), isTrue);
      expect(team.players.contains(star), isFalse);
      expect(s.budget, greaterThan(before));
      expect(star.isTransferListed, isFalse);
    });

    test('買い手は他の部・他の国のクラブからも来る', () async {
      final gs = GameState();
      await gs.startNewGame('買い手FC');
      final s = gs.save!;
      final league = {for (final t in s.league.teams) t.name};
      final star = ([...gs.userTeam.players.where((p) => !p.isLoan)]
            ..sort((a, b) => b.overall.compareTo(a.overall)))
          .first;
      final buyers = <String>{};
      for (var i = 0; i < 60; i++) {
        final o = gs.debugOfferFor(star.id);
        if (o != null) buyers.add(o.buyerClubName);
        s.incomingOffers.clear();
      }
      expect(buyers.length, greaterThan(3), reason: '買い手が偏っている');
      expect(buyers.any((b) => !league.contains(b)), isTrue,
          reason: '同じ部のクラブしか買いに来ない');
    });

    test('載せていない選手に、売るボタンでその場で売れる道はない', () async {
      final gs = GameState();
      await gs.startNewGame('道FC');
      final p = gs.userTeam.players.first;
      final before = gs.userTeam.players.length;
      await gs.setTransferListed(p.id, true);
      expect(gs.userTeam.players.length, before, reason: '載せただけでは売れない');
      expect(p.isTransferListed, isTrue);
    });
  });

  group('3. CPU どうしの移籍', () {
    List<Team> league({int clubs = 20}) => [
          Team(id: 'user', name: 'U', players: []),
          for (var i = 0; i < clubs; i++)
            PlayerGenerator.generateSquad(
                id: 'c$i', name: 'C$i', strengthTier: 20 + i * 4),
        ];

    test('窓の1週で何件も、移籍金付きで動く。人数の上下限と選手の総数を守る', () {
      final teams = league();
      final total = teams.fold<int>(0, (s, t) => s + t.players.length);
      final rng = Random(3);
      var moves = 0;
      var feeTotal = 0;
      // 夏の窓(週の処理で約4〜5回)。
      for (var week = 0; week < 5; week++) {
        final m = AiTransferEngine.runWeek(teams, 'user', rng);
        moves += m.length;
        for (final x in m) {
          expect(x.fee, greaterThan(0));
          expect(x.to.players.contains(x.player), isTrue);
          expect(x.from.players.contains(x.player), isFalse);
          feeTotal += x.fee;
        }
      }
      expect(moves, inInclusiveRange(15, 60), reason: '1つの窓で数十件');
      expect(feeTotal, greaterThan(0));
      expect(teams.fold<int>(0, (s, t) => s + t.players.length), total);
      expect(teams.first.players, isEmpty, reason: 'ユーザーのクラブは触らない');
      for (final t in teams.skip(1)) {
        expect(
            t.players.length, lessThanOrEqualTo(AiTransferEngine.maxSquadSize));
        expect(t.players.length, greaterThanOrEqualTo(16));
      }
    });

    test('買うのは弱いポジションを上げられる選手で、資金の範囲', () {
      final teams = league();
      final budgets = {
        for (final t in teams) t.id: AiTransferEngine.defaultBudget(t),
      };
      final moves = AiTransferEngine.runWeek(teams, 'user', Random(5),
          budgetOf: (t) => budgets[t.id]!);
      expect(moves, isNotEmpty);
      final spent = <String, int>{};
      for (final m in moves) {
        spent[m.to.id] = (spent[m.to.id] ?? 0) + m.fee;
      }
      for (final e in spent.entries) {
        // 売った額の一部を回せるので、元の資金に売上の6割を足した範囲。
        final income = moves
            .where((m) => m.from.id == e.key)
            .fold<int>(0, (s, m) => s + (m.fee * 0.6).round());
        expect(e.value, lessThanOrEqualTo(budgets[e.key]! + income));
      }
    });

    test('資金が無ければ動かない。登録できなければ動かない', () {
      expect(
          AiTransferEngine.runWeek(league(), 'user', Random(1),
              budgetOf: (_) => 0),
          isEmpty);
      expect(
          AiTransferEngine.runWeek(league(), 'user', Random(1),
              canRegister: (_, __) => false),
          isEmpty);
    });

    test('契約が残り半年の選手は安く動く(移籍金にも係数)', () {
      final teams = league();
      for (final t in teams) {
        for (final p in t.players) {
          p.contractYearsRemaining = 1;
        }
      }
      final moves = AiTransferEngine.runWeek(teams, 'user', Random(9),
          seasonProgress: 0.5);
      expect(moves, isNotEmpty);
      for (final m in moves) {
        // 主力でも ×1.3・有望株 ×1.15 までなので、市場価値の半分を超えない。
        expect(m.fee, lessThanOrEqualTo(m.player.marketValue * 0.2 * 1.5 + 1));
      }
    });

    test('ゲームの週の処理: 資金が動き、主力の移籍はニュースに出る', () async {
      final gs = GameState();
      await gs.startNewGame('観察FC');
      expect(gs.isTransferWindowOpen, isTrue);
      final s = gs.save!;
      final userCount = gs.userTeam.players.length;
      final news = <String>[];
      final sw = Stopwatch()..start();
      for (var week = 0; week < 5; week++) {
        news.addAll(gs.debugAdvanceAiTransfers());
      }
      sw.stop();
      expect(s.clubCash, isNotEmpty, reason: '移籍金がクラブの資金に入っていない');
      expect(news, isNotEmpty, reason: '主力の移籍がニュースに出ない');
      expect(news.length, lessThanOrEqualTo(5 * 3));
      expect(gs.lastAiTransferNews, isNotNull);
      expect(gs.userTeam.players.length, userCount);
      // 1週あたりの処理が目立って遅くならない(登録の判定込み)。
      expect(sw.elapsedMilliseconds / 5, lessThan(400));
      for (final t in s.league.teams) {
        expect(
            t.players.length, lessThanOrEqualTo(AiTransferEngine.maxSquadSize));
      }
    });
  });
}
