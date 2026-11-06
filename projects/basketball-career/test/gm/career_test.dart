import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

Career _toPlayoffs(Career c) {
  c.startSeason();
  while (c.phase == Phase.season) {
    c.playBlock();
  }
  return c;
}

void main() {
  group('リーグ', () {
    test('30チーム(東西15ずつ)・14人で始まり、どのチームも年俸の合計の上限を超えない', () {
      expect(teamDefs.where((d) => d.east), hasLength(15));
      for (final sc in Scenario.values) {
        final c = Career.start(seed: 7, scenario: sc);
        expect(c.teams, hasLength(30));
        for (final t in c.teams) {
          expect(t.roster, hasLength(14));
          expect(t.payroll, lessThanOrEqualTo(hardCap), reason: '${sc.name} ${t.name}');
          expect(t.roster.any((p) => p.pos.guard) && t.roster.any((p) => p.pos.big), isTrue);
        }
      }
    });

    test('始め方で自分のチームの状態が違う(立て直しは最弱・若い、最後の好機は上位・年寄り・上限超え)', () {
      final r = Career.start(seed: 11, scenario: Scenario.rebuild);
      final l = Career.start(seed: 11, scenario: Scenario.lastWindow);
      expect(r.strengthRank(Career.mine), greaterThanOrEqualTo(25));
      expect(l.strengthRank(Career.mine), lessThanOrEqualTo(2));
      double age(Career c) => c.me.roster.fold(0, (s, p) => s + p.age) / c.me.roster.length;
      expect(age(r), lessThan(age(l)));
      expect(r.me.capRoom, greaterThan(100));
      expect(l.me.payroll, greaterThan(salaryCap));
    });

    test('総当たりは29節で、どのチームも1節に1試合、ほかの29チームと1回ずつ当たる', () {
      for (var cyc = 0; cyc < 3; cyc++) {
        final rounds = roundRobin(30, cyc);
        expect(rounds, hasLength(29));
        final met = <String>{};
        for (final r in rounds) {
          final ids = [for (final (h, a) in r) ...[h, a]];
          expect(ids.toSet(), hasLength(30));
          for (final (h, a) in r) {
            met.add(h < a ? '$h-$a' : '$a-$h');
          }
        }
        expect(met, hasLength(435));
      }
      expect(seasonSchedule(30), hasLength(gamesPerSeason));
      expect(blockSizes.fold(0, (s, n) => s + n), gamesPerSeason);
    });

    test('シーズンは82試合で、勝ちと負けの合計が合う', () {
      final c = _toPlayoffs(Career.start(seed: 3));
      for (final t in c.teams) {
        expect(t.wins + t.losses, gamesPerSeason);
      }
      expect(c.phase, Phase.playoffs);
    });

    test('強いチームほど勝つ(強さの差が結果に効く)', () {
      expect(winChance(75, 68), greaterThan(0.8));
      expect(winChance(70, 70), greaterThan(0.5), reason: 'ホームが少し有利');
      expect(winChance(66, 74), lessThan(0.2));
    });

    test('プレーオフ: 地区の1〜6位とプレーインの勝者2つ。どの回戦も4勝。シーズンの勝敗には数えない', () {
      final c = _toPlayoffs(Career.start(seed: 5));
      final wins = [for (final t in c.teams) t.wins];
      c.playPlayoffs();
      expect([for (final t in c.teams) t.wins], wins);
      // プレーイン3つ×2地区、1回戦8、2回戦4、地区決勝2、ファイナル1
      expect(c.playoffs.where((s) => s.round == 0), hasLength(6));
      expect(c.playoffs.where((s) => s.round == 1), hasLength(8));
      expect(c.playoffs.where((s) => s.round == 2), hasLength(4));
      expect(c.playoffs.where((s) => s.round == 3), hasLength(2));
      expect(c.playoffs.where((s) => s.round == 4), hasLength(1));
      for (final s in c.playoffs) {
        expect(s.need, s.round == 0 ? 1 : 4);
      }
      final first = {for (final s in c.playoffs.where((s) => s.round == 1)) ...[s.high, s.low]};
      for (final east in [true, false]) {
        final top6 = standings(c.teams, east: east).take(6).map((t) => t.index).toSet();
        expect(first.containsAll(top6), isTrue);
      }
      final f = c.finals!;
      expect(c.teams[f.high].east != c.teams[f.low].east, isTrue, reason: 'ファイナルは東と西');
      expect(c.phase, Phase.seasonEnd);
      expect(c.history.single.wins, c.me.wins);
    });
  });

  group('選手', () {
    test('若手は伸び、ベテランは落ちる。伸びしろを超えては伸びない', () {
      final rng = Rng(1);
      var young = 0, old = 0;
      for (var i = 0; i < 200; i++) {
        final y = Player(id: 1, name: 'a', pos: Pos.pg, age: 20, ovr: 60, pot: 75, salary: 20, years: 1);
        young += ageOneYear(y, rng);
        expect(y.ovr, lessThanOrEqualTo(75));
        final o = Player(id: 2, name: 'b', pos: Pos.c, age: 33, ovr: 75, pot: 75, salary: 20, years: 1);
        old += ageOneYear(o, rng);
      }
      expect(young / 200, greaterThan(3));
      expect(old / 200, lessThan(-2));
    });

    test('力に見合う年俸は、力が高いほど高く、上限と下限の間', () {
      expect(fairSalary(55, 25), minSalary);
      expect(fairSalary(70, 25), greaterThan(fairSalary(65, 25)));
      expect(fairSalary(95, 25), maxSalary);
      expect(fairSalary(75, 33), lessThan(fairSalary(75, 26)));
    });

    test('お金の見せ方', () {
      expect(money(490), '4900万ドル');
      expect(money(1400), '1.4億ドル');
      expect(money(2000), '2億ドル');
      expect(money(12), '120万ドル');
    });
  });

  group('トレード', () {
    test('相手は少し得をしないと受けない。釣り合わなければ理由を返す', () {
      final c = Career.start(seed: 9, scenario: Scenario.middle);
      // 年俸の決まりに当たらない相手(上限に空きのあるチーム)を選ぶ
      final them = c.teams.skip(1).reduce((a, b) => a.capRoom >= b.capRoom ? a : b);
      final pt = them.index;
      final star = them.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      final scrub = c.me.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final bad = c.judge(TradeOffer(partner: pt, give: [scrub.id], get: [star.id]));
      expect(bad.ok, isFalse);
      expect(bad.reason, isNotEmpty);
      final myStar = c.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      final theirScrub = them.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final good = c.judge(TradeOffer(partner: pt, give: [myStar.id], get: [theirScrub.id]));
      expect(good.ok, isTrue, reason: good.reason);
      expect(c.propose(TradeOffer(partner: pt, give: [myStar.id], get: [theirScrub.id])), isTrue);
      expect(c.me.roster.contains(theirScrub), isTrue);
      expect(them.roster.contains(myStar), isTrue);
      expect(c.tradesDone, 1);
    });

    test('立て直し中のチームは、若手と指名権を高く見る。優勝を狙うチームは今の力を見る', () {
      final young = Player(id: 1, name: 'a', pos: Pos.pg, age: 20, ovr: 62, pot: 85, salary: 30, years: 3);
      final vet = Player(id: 2, name: 'b', pos: Pos.pg, age: 32, ovr: 74, pot: 74, salary: 200, years: 1);
      expect(playerValue(young, TeamMode.rebuild), greaterThan(playerValue(vet, TeamMode.rebuild)));
      expect(playerValue(vet, TeamMode.contend), greaterThan(playerValue(young, TeamMode.contend)));
      final pick = DraftPick(season: 1, round: 1, from: 3, owner: 3);
      expect(pickValue(pick, TeamMode.rebuild, 3, 1), greaterThan(pickValue(pick, TeamMode.contend, 3, 1)));
    });

    test('上限を超えるチームは、受け取る年俸を出す年俸の125%までしか増やせない', () {
      final c = Career.start(seed: 4, scenario: Scenario.lastWindow);
      expect(c.me.payroll, greaterThan(salaryCap));
      expect(salaryRuleProblem(c.me, 400, 100), isNotNull);
      expect(salaryRuleProblem(c.me, 120, 100), isNull);
    });

    test('締め切り(2区切り)を過ぎたらトレードできない', () {
      final c = Career.start(seed: 2)..startSeason();
      expect(c.canTrade, isTrue);
      c.playBlock();
      c.playBlock();
      expect(c.canTrade, isFalse);
      final myStar = c.me.roster.first;
      final theirs = c.teams[1].roster.last;
      expect(c.propose(TradeOffer(partner: 1, give: [myStar.id], get: [theirs.id])), isFalse);
    });

    test('指名権も出せる。成立すると持ち主が変わる', () {
      final c = Career.start(seed: 8, scenario: Scenario.middle);
      final mine = c.picksOf(Career.mine).firstWhere((i) => c.picks[i].round == 1);
      final pt = c.teams.skip(1).firstWhere((t) => t.mode == TeamMode.rebuild).index;
      final theirScrub = c.teams[pt].roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final o = TradeOffer(partner: pt, givePicks: [mine], get: [theirScrub.id]);
      expect(c.judge(o).ok, isTrue, reason: c.judge(o).reason);
      c.propose(o);
      expect(c.picks[mine].owner, pt);
    });
  });

  group('相手に聞く・相手同士のトレード・ニュース', () {
    test('受け取りたい選手を選ぶと、相手が受ける出し方が返り、そのまま成立する', () {
      var found = 0;
      for (var seed = 1; seed <= 10; seed++) {
        final c = Career.start(seed: seed, scenario: Scenario.middle);
        final pt = c.teams.skip(1).firstWhere((t) => t.mode == TeamMode.rebuild).index;
        final target = c.teams[pt].roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
        final o = c.askPartner(pt, get: [target.id]);
        if (o == null) continue;
        found++;
        expect(c.judge(o).ok, isTrue);
        expect(o.give.length + o.givePicks.length, inInclusiveRange(1, 3));
        expect(c.propose(o), isTrue);
        expect(c.me.roster.any((p) => p.id == target.id), isTrue);
        expect(c.log.first, contains('トレード'));
      }
      expect(found, greaterThan(5), reason: 'たいていは出し方が見つかる');
    });

    test('何も受け取らないなら聞けない。締め切りのあとも聞けない', () {
      final c = Career.start(seed: 2)..startSeason();
      expect(c.askPartner(1), isNull);
      c
        ..playBlock()
        ..playBlock();
      expect(c.askPartner(1, get: [c.teams[1].roster.first.id]), isNull);
    });

    test('相手同士のトレードが起き、どのチームも人数と年俸の決まりを守る。ニュースに残る', () {
      var trades = 0;
      for (var seed = 1; seed <= 5; seed++) {
        final c = Career.start(seed: seed, scenario: Scenario.middle);
        var guard = 0;
        while (c.season <= 3 && c.phase != Phase.over && guard++ < 200) {
          if (c.phase == Phase.seasonEnd) c.fired = false;
          botStep(c);
          // ドラフトの間は新人が入って一時的に15人を超える。シーズン前・シーズン中は15人まで
          if (c.phase != Phase.preseason && c.phase != Phase.season) continue;
          for (final t in c.teams.skip(1)) {
            expect(t.roster.length, lessThanOrEqualTo(maxRoster), reason: t.name);
            expect(t.payroll, lessThanOrEqualTo(hardCap + 100), reason: t.name);
          }
        }
        trades += c.log.where((l) => l.contains('トレード:')).length;
        expect(c.log.length, lessThanOrEqualTo(Career.logLimit));
        expect(c.log.any((l) => l.contains('優勝:')), isTrue);
        expect(c.log.any((l) => l.contains('ドラフト全体1位')), isTrue);
      }
      expect(trades, greaterThan(5));
    });
  });

  group('オフ', () {
    test('ドラフト: 自分の番まで相手が指名し、指名した選手は新人の契約で入る。全員の指名が終わると契約へ', () {
      final c = _toPlayoffs(Career.start(seed: 12))..playPlayoffs();
      c.fired = false;
      c.toOffseason();
      expect(c.phase, Phase.draft);
      expect(c.myTurn, isTrue);
      final myPicks = c.order.where((i) => c.picks[i].owner == Career.mine).length;
      final before = c.me.roster.length;
      final p = byMid(c).first;
      c.pickProspect(p);
      expect(c.me.roster, contains(p.player));
      expect(p.player.years, anyOf(2, 3));
      expect(c.draftedIds, contains(p.player.id));
      expect(c.me.roster.length, before + 1);
      while (c.phase == Phase.draft) {
        c.passPick();
      }
      expect(c.phase, Phase.contracts);
      // 自分の番は1回だけ指名し、残りは見送った
      expect(c.draftLog, hasLength(c.order.length - (myPicks - 1)));
    });

    test('スカウトを送ると、見える幅が狭まり、本当の力は必ず幅の中にある', () {
      final rng = Rng(5);
      var id = 0;
      final list = makeProspects(rng, () => ++id, 30);
      for (final p in list) {
        expect(p.player.ovr, inInclusiveRange(p.ovrLo, p.ovrHi));
        expect(p.player.pot, inInclusiveRange(p.potLo, p.potHi));
        final w = p.potHi - p.potLo;
        scout(p, rng);
        expect(p.potHi - p.potLo, lessThan(w));
        expect(p.player.pot, inInclusiveRange(p.potLo, p.potHi));
      }
    });

    test('くじは、プレーオフに出なかった14チームだけで上位4つを決める', () {
      final c = _toPlayoffs(Career.start(seed: 21))..playPlayoffs();
      final seeds = {for (final s in c.playoffs.where((s) => s.round == 1)) ...[s.high, s.low]}.toList();
      expect(seeds, hasLength(16));
      final order = draftOrder(c.teams, c.picks, c.season, seeds, Rng(3));
      expect(order, hasLength(60));
      for (final i in order.take(14)) {
        expect(seeds.contains(c.picks[i].from), isFalse);
      }
      for (final i in order.skip(14).take(16)) {
        expect(seeds.contains(c.picks[i].from), isTrue);
      }
    });

    test('契約: 再契約は上限を超えてもできる。放した選手は自由契約に。オフを終えると次のシーズン前', () {
      final c = Career.start(seed: 30, scenario: Scenario.lastWindow);
      var guard = 0;
      while (c.phase != Phase.contracts && guard++ < 100) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.phase, Phase.contracts);
      if (c.expiring.isNotEmpty) {
        final id = c.expiring.first;
        final p = c.me.roster.firstWhere((x) => x.id == id);
        if (c.resignProblem(p) == null) {
          c.resign(id, 1);
          expect(p.years, 1);
          expect(c.expiring, isNot(contains(id)));
        }
      }
      for (final id in [...c.expiring]) {
        c.letGo(id);
        expect(c.freeAgents.any((p) => p.id == id), isTrue);
      }
      c.finishContracts();
      expect(c.phase, Phase.preseason);
      expect(c.season, 2);
      for (final t in c.teams.skip(1)) {
        expect(t.roster.length, inInclusiveRange(13, maxRoster));
      }
    });

    test('自由契約: 上限の空きが無ければ取れない。最低年俸の選手はいつでも取れる', () {
      final c = Career.start(seed: 6, scenario: Scenario.lastWindow);
      final cheap = c.freeAgents.firstWhere((p) => c.askOf(p, c.me).salary <= minSalary);
      c.release(c.me.roster.last.id);
      expect(c.signProblem(cheap), isNull);
      final pricey = Player(id: 9999, name: 'x', pos: Pos.sf, age: 27, ovr: 78, pot: 78, salary: 300, years: 1);
      c.freeAgents.add(pricey);
      expect(c.signProblem(pricey), isNotNull);
    });

    test('放した選手の年俸は、今季の合計に残る', () {
      final c = Career.start(seed: 6);
      final p = c.me.roster.first;
      final before = c.me.payroll, salary = p.salary;
      c.release(p.id);
      expect(c.me.payroll, before);
      expect(c.me.deadCap, salary);
    });
  });

  group('オーナー', () {
    test('目標に届かず信頼がなくなると解任。動画で1度だけ取り消せる', () {
      final c = Career.start(seed: 14, scenario: Scenario.lastWindow);
      c.trust = 1;
      c.startSeason();
      c.target = gamesPerSeason;
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      c.playPlayoffs();
      if (c.myResult < 5) {
        expect(c.fired, isTrue);
        expect(c.canRescue, isTrue);
        c.rescue();
        expect(c.fired, isFalse);
        expect(c.canRescue, isFalse);
        c.toOffseason();
        expect(c.phase, Phase.draft);
      }
    });

    test('解任されたまま閉じると任期は終わる。10年目のあとも終わる', () {
      final c = Career.start(seed: 15);
      final done = botPlayCareer(15, Scenario.middle);
      expect(done.phase, Phase.over);
      expect(done.history.length, done.fired ? lessThanOrEqualTo(careerSeasons) : careerSeasons);
      expect(c.phase, Phase.preseason);
    });

    test('ぜいたく税の線を超えると、超えた分だけ信頼が下がる', () {
      expect(luxuryTaxTrust(taxLine), 0);
      expect(luxuryTaxTrust(taxLine + 120), 12);
    });
  });

  group('保存', () {
    test('どの局面でも、保存して読み直すと同じ続きになる', () {
      final c = Career.start(seed: 40, scenario: Scenario.rebuild);
      var guard = 0;
      while (c.phase != Phase.over && guard++ < 300) {
        final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
        expect(jsonEncode(copy.toJson()), jsonEncode(c.toJson()), reason: '${c.season} ${c.phase}');
        botStep(c);
        botStep(copy);
        expect(jsonEncode(copy.toJson()), jsonEncode(c.toJson()), reason: '${c.season} ${c.phase} の次');
      }
    });

    test('壊れた保存は読まない', () {
      expect(() => Career.fromJson({'seed': 1, 'teams': []}), throwsA(anything));
    });
  });

  group('釣り合い(自動で遊ぶGM)', () {
    test('素朴に遊ぶと、優勝はたまに。始め方ごとに解任ばかり・優勝ばかりにならない', () {
      for (final sc in Scenario.values) {
        var titles = 0, fired = 0;
        const n = 30;
        for (var i = 0; i < n; i++) {
          final c = botPlayCareer(500 + i, sc);
          titles += c.titles;
          if (c.fired) fired++;
        }
        // 30チームなので、運だけなら10年で0.33回
        expect(titles / n, inInclusiveRange(0.05, 1.5), reason: '${sc.label} 優勝/任期');
        expect(fired / n, lessThan(0.5), reason: '${sc.label} 解任');
      }
    });
  });
}
