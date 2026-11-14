import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/inbox.dart';
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
      for (final team in [0, 9, 21]) {
        final c = Career.start(seed: 7, team: team);
        expect(c.teams, hasLength(30));
        for (final t in c.teams) {
          expect(t.roster, hasLength(14));
          expect(t.payroll, lessThanOrEqualTo(secondApron), reason: t.name);
          expect(t.roster.any((p) => p.pos.guard) && t.roster.any((p) => p.pos.big), isTrue);
        }
      }
    });

    test('同じ種なら、どのチームを選んでも同じリーグになる。チームの状態は強さの順位から決まる', () {
      final a = Career.start(seed: 11, team: 3);
      final b = Career.start(seed: 11, team: 17);
      // 自分のチームにだけ名前のあるコーチがいる(強さは変えない)ので、それを除いて比べる
      String league(Career c) => jsonEncode([for (final t in c.teams) t.toJson()..remove('co')]);
      expect(league(a), league(b));
      expect(a.mine, 3);
      expect(b.me.name, '${teamDefs[17].city}・${teamDefs[17].nick}');
      final strong = careerAt(11, 0), weak = careerAt(11, 29);
      expect(strong.outlook, Outlook.contender);
      expect(weak.outlook, Outlook.rebuild);
      strong.startSeason();
      weak.startSeason();
      expect(strong.target, greaterThan(weak.target), reason: '強いチームほど目標が高い');
      // チームの状態はチームごとに違う(若い立て直し・年寄りの強豪がいる)
      double age(Team t) => t.roster.fold(0, (s, p) => s + p.age) / t.roster.length;
      final ages = [for (final t in a.teams) age(t)]..sort();
      expect(ages.last - ages.first, greaterThan(3));
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
      final c = careerAt(9, 15);
      // 年俸の決まりに当たらない相手(上限に空きのあるチーム)を選ぶ
      final them = c.teams.where((t) => t.index != c.mine).reduce((a, b) => a.capRoom >= b.capRoom ? a : b);
      final pt = them.index;
      final star = them.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      final scrub = c.me.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final bad = c.judge(TradeOffer(partner: pt, give: [scrub.id], get: [star.id]));
      expect(bad.ok, isFalse);
      expect(bad.reason, isNotEmpty);
      final theirScrub = them.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      // 相手の上限の空きに収まる中で、いちばん力の高い選手を出す
      final myStar = c.me.roster
          .where((p) => p.salary <= them.capRoom + theirScrub.salary)
          .reduce((a, b) => a.ovr >= b.ovr ? a : b);
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
      final c = careerAt(4, 1);
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
      final other = c.mine == 0 ? 1 : 0;
      final theirs = c.teams[other].roster.last;
      expect(c.propose(TradeOffer(partner: other, give: [myStar.id], get: [theirs.id])), isFalse);
    });

    test('指名権も出せる。成立すると持ち主が変わる', () {
      final c = careerAt(8, 15);
      final mine = c.picksOf(c.mine).firstWhere((i) => c.picks[i].round == 1);
      final pt = c.teams.where((t) => t.index != c.mine).firstWhere((t) => t.mode == TeamMode.rebuild).index;
      final theirScrub = c.teams[pt].roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final o = TradeOffer(partner: pt, givePicks: [mine], get: [theirScrub.id]);
      expect(c.judge(o).ok, isTrue, reason: c.judge(o).reason);
      c.propose(o);
      expect(c.picks[mine].owner, pt);
    });
  });

  group('個人成績・能力・表彰', () {
    test('試合のたびに個人の数字が配られ、チームの得点と合う。開幕で前のシーズンに移る', () {
      final c = careerAt(3, 15)..startSeason();
      c.playBlock();
      final ptsSum = c.me.roster.fold(0, (s, p) => s + p.stats.pts);
      final teamPts = c.lastGames.fold(0, (s, g) => s + g.ptsOf(c.mine));
      expect(ptsSum, teamPts, reason: '個人の得点の合計はチームの得点');
      final star = lineup(c.me.roster).first;
      expect(star.stats.gp, inInclusiveRange(blockSizes[0] - 8, blockSizes[0]), reason: 'けがで休んだ試合は数えない');
      expect(star.stats.ppg, greaterThan(8));
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      c.playPlayoffs();
      c.fired = false;
      final line = star.stats.line;
      c.toOffseason();
      while (c.phase == Phase.draft) {
        c.passPick();
      }
      c.finishContracts();
      c.startSeason();
      if (c.me.roster.contains(star)) {
        expect(star.stats.gp, 0);
        expect(star.prev.line, line);
      }
    });

    test('ビッグはリバウンド、ガードはアシストを多く取る', () {
      final c = careerAt(5, 10)..startSeason();
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      final reb = c.leaders((s) => s.rpg, count: 10);
      final ast = c.leaders((s) => s.apg, count: 10);
      expect(reb.where((x) => x.$1.pos.big).length, greaterThanOrEqualTo(7));
      expect(ast.where((x) => x.$1.pos.guard).length, greaterThanOrEqualTo(7));
    });

    test('能力の内訳はポジションの色が出る(センターはリバウンド、ポイントガードはパス)', () {
      final c = Career.start(seed: 8);
      final all = [for (final t in c.teams) ...t.roster];
      double avg(Pos pos, Attr a) {
        final ps = all.where((p) => p.pos == pos).toList();
        return ps.fold(0, (s, p) => s + p.attrs[a.index]) / ps.length;
      }
      expect(avg(Pos.c, Attr.rebound), greaterThan(avg(Pos.pg, Attr.rebound) + 10));
      expect(avg(Pos.pg, Attr.passing), greaterThan(avg(Pos.c, Attr.passing) + 10));
    });

    test('シーズンの終わりにMVP・最優秀守備選手が決まり、2年目からは新人王も決まる', () {
      final c = careerAt(6, 12);
      var guard = 0;
      while (c.history.length < 2 && guard++ < 300) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.awardsOf(1).map((a) => a.kind), containsAll([AwardKind.mvp, AwardKind.dpoy]));
      for (final roy in c.awards.where((a) => a.kind == AwardKind.roy)) {
        final p = [for (final t in c.teams) ...t.roster, ...c.freeAgents].where((p) => p.id == roy.player);
        if (p.isNotEmpty && roy.season == c.season) expect(p.first.exp, 0, reason: '新人王は1年目の選手');
        expect(double.parse(roy.line.split('点').first), greaterThanOrEqualTo(5));
      }
      expect(c.log.any((l) => l.contains('MVP:')), isTrue);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.awards.length, c.awards.length);
    });
  });

  group('表彰と歴史', () {
    late Career c;
    setUpAll(() {
      c = careerAt(6, 15);
      var guard = 0;
      while (c.phase != Phase.over && guard++ < 1500) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
    });

    test('毎シーズン、9つの表彰がそろい、オールリーグは3チーム×5人(ガード2・フォワード2・センター1)', () {
      expect(c.champs.length, c.history.length);
      for (final h in c.history) {
        final aw = c.awardsOf(h.season);
        for (final k in [AwardKind.mvp, AwardKind.dpoy, AwardKind.sixth, AwardKind.finalsMvp]) {
          expect(aw.where((a) => a.kind == k).length, 1, reason: '${h.season}年目 ${k.label}');
        }
        for (final k in [AwardKind.allLeague1, AwardKind.allLeague2, AwardKind.allLeague3]) {
          final five = aw.where((a) => a.kind == k).toList();
          expect(five.length, 5, reason: '${h.season}年目 ${k.label}');
          expect(five.map((a) => a.player).toSet().length, 5);
        }
        final al = aw.where((a) => a.kind.allLeague).map((a) => a.player).toSet();
        expect(al.length, 15, reason: '同じ選手が2つのチームに入らない');
        // ファイナルMVPは優勝したチームの選手
        final fm = aw.firstWhere((a) => a.kind == AwardKind.finalsMvp);
        expect(fm.team, c.champs.firstWhere((r) => r[0] == h.season)[1]);
      }
      expect(c.awards.where((a) => a.kind == AwardKind.mip), isNotEmpty);
    });

    test('選手に年ごとの成績が残り、通算は年ごとの合計', () {
      final vets = [for (final t in c.teams) ...t.roster].where((p) => p.career.length >= 3).toList();
      expect(vets, isNotEmpty);
      for (final p in vets) {
        expect(p.careerTotals.pts, p.career.fold<int>(0, (n, r) => n + r[3]));
        final seasons = p.career.map((r) => r[0]).toList();
        expect(seasons.toSet().length, seasons.length, reason: '同じ年が2回ない');
      }
      final top = c.careerLeaders((s) => s.pts, count: 3);
      expect(top.length, 3);
      expect(top.first.$1.careerTotals.pts, greaterThanOrEqualTo(top.last.$1.careerTotals.pts));
    });

    test('表彰を重ねて引退した選手は殿堂に入り、保存しても残る', () {
      expect(c.hall, isNotEmpty);
      for (final h in c.hall) {
        expect(h.honors, isNotEmpty);
        expect(c.awards.any((a) => a.name == h.name), isTrue);
      }
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.hall.map((h) => h.name), c.hall.map((h) => h.name));
      expect(copy.champs, c.champs);
      final p = c.careerLeaders((s) => s.pts, count: 1).first.$1;
      final q = [for (final t in copy.teams) ...t.roster].firstWhere((x) => x.id == p.id);
      expect(q.career, p.career);
    });

    test('殿堂の点: MVPは6点、オールスターは1回1点', () {
      final p = c.teams.first.roster.first;
      final base = c.hallScore(p);
      c.awards.add(Award(season: 99, kind: AwardKind.mvp, player: p.id, name: p.name, team: 0, line: ''));
      p.allStars += 2;
      expect(c.hallScore(p), base + 8);
      c.awards.removeLast();
      p.allStars -= 2;
    });
  });

  group('ポジションと人数', () {
    test('任期の終わりまで、ほかのチームはどのポジションにも選手がいて、先発は偏らない', () {
      // 3つの任期で数える(1つだけだと、試合の流れしだいで当たり外れが大きい)
      var skewed = 0;
      for (final seed in [3, 4, 5]) {
        final c = botPlayCareer(seed, team: teamAtRank(seed, 12));
        final others = c.teams.where((t) => t.index != c.mine).toList();
        for (final t in others) {
          for (final pos in Pos.values) {
            expect(t.roster.any((p) => p.pos == pos), isTrue, reason: '${t.def.short} に ${pos.short} がいない');
          }
          final five = t.order.take(5).map((p) => p.pos).toList();
          if (five.toSet().length < 4) skewed++;
        }
      }
      expect(skewed / 3, lessThanOrEqualTo(3), reason: '先発で同じポジションが3人以上のチーム(1任期あたり)');
    });

    test('先発は本来のポジションの選手を選び、PG から C の順に当てはめられる。違う位置に出すと強さが下がる', () {
      Player mk(int id, Pos pos, int ovr) => Player(id: id, name: 'p$id', pos: pos, age: 26, ovr: ovr, pot: ovr, salary: 50, years: 2);
      final balanced = [mk(1, Pos.pg, 75), mk(2, Pos.sg, 74), mk(3, Pos.sf, 73), mk(4, Pos.pf, 72), mk(5, Pos.c, 71), mk(6, Pos.sg, 72), mk(7, Pos.sf, 70)];
      final five = lineup(balanced).take(5).toList();
      expect(five.map((p) => p.pos).toSet().length, 5);
      expect(positionPenalty(five), 0);
      expect(bySlot(five).map((x) => x.$1), Pos.values);
      final guards = [mk(1, Pos.pg, 75), mk(2, Pos.pg, 75), mk(3, Pos.sg, 75), mk(4, Pos.sg, 75), mk(5, Pos.sg, 75)];
      expect(positionPenalty(guards), greaterThan(3), reason: 'ガード5人はビッグの位置が大きく外れる');
      // ずっと力の高い選手なら、隣のポジションでも先発に入る
      final star = [mk(1, Pos.pg, 60), mk(2, Pos.sg, 90), mk(3, Pos.sg, 74), mk(4, Pos.sf, 73), mk(5, Pos.pf, 72), mk(6, Pos.c, 71)];
      expect(lineup(star).take(5).map((p) => p.id), containsAll([2, 3]));
    });

    test('ドラフトでは契約が切れる選手を数えず、オフは17人まで指名できる。開幕は15人まで', () {
      final c = careerAt(7, 27);
      var guard = 0;
      while (!(c.phase == Phase.draft && c.myTurn) && guard++ < 200) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.myTurn, isTrue);
      // 15人いて、2人は契約が切れる
      while (c.me.roster.length < maxRoster) {
        c.me.roster.add(Player(id: 900000 + c.me.roster.length, name: 'x${c.me.roster.length}', pos: Pos.sf, age: 30, ovr: 50, pot: 50, salary: minSalary, years: 0));
      }
      for (final p in c.me.roster.take(2)) {
        p.years = 0;
      }
      expect(c.me.roster.length, maxRoster);
      expect(c.signedCount, lessThan(offseasonRoster));
      expect(c.draftProblem, isNull, reason: '15人いても指名できる');
      final before = c.me.roster.length;
      c.pickProspect(byMid(c).first);
      expect(c.me.roster.length, before + 1);
      // 契約中が17人になったら、それ以上は指名できない
      while (c.signedCount < offseasonRoster) {
        c.me.roster.add(Player(id: 910000 + c.me.roster.length, name: 'y${c.me.roster.length}', pos: Pos.pf, age: 30, ovr: 50, pot: 50, salary: minSalary, years: 2));
      }
      expect(c.draftProblem, isNotNull);
    });
  });

  group('トレードブロックと月間MVP', () {
    test('トレードブロックに載せると気持ちが少し下がり、申し込みを集めて受けられる。保存しても残る', () {
      final c = careerAt(3, 12);
      final p = c.me.order[4];
      p.morale = 60;
      c.toggleTradeBlock(p.id);
      expect(c.tradeBlock, [p.id]);
      expect(p.morale, 55);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.tradeBlock, [p.id]);
      final offers = c.blockOffers(p.id);
      expect(offers, isNotEmpty, reason: '先発級なら、どこかは出してくれる');
      expect(offers.map((o) => o.partner).toSet().length, offers.length, reason: 'チームごとに1つ');
      for (final o in offers) {
        expect(o.give, [p.id]);
        expect(c.judge(o).ok, isTrue);
      }
      expect(c.acceptBlockOffer(offers.first), isTrue);
      expect(c.me.roster.contains(p), isFalse);
      expect(c.tradeBlock, isEmpty);
      // 外すと戻る
      final q = c.me.order[5];
      c
        ..toggleTradeBlock(q.id)
        ..toggleTradeBlock(q.id);
      expect(c.tradeBlock, isEmpty);
    });

    test('トレードブロックの選手には、区切りのあとの申し込みが届きやすい', () {
      var toBlock = 0, total = 0;
      for (var seed = 1; seed <= 12; seed++) {
        final c = careerAt(seed, 12);
        final p = c.me.order[3];
        c
          ..toggleTradeBlock(p.id)
          ..startSeason();
        while (c.phase == Phase.season && c.block < tradeDeadlineBlock) {
          c.playBlock();
          final o = c.incoming;
          if (o != null) {
            total++;
            if (o.give.contains(p.id)) toBlock++;
            c.declineIncoming();
          }
        }
      }
      expect(total, greaterThan(0));
      expect(toBlock * 2, greaterThanOrEqualTo(total), reason: '申し込みの半分以上がブロックの選手');
    });

    test('区切りごとに東西の月間MVPが決まり、何区切り目かが残る', () {
      final c = careerAt(4, 12)..startSeason();
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      final m = c.monthly.where((a) => a.season == c.season).toList();
      expect(m.length, blocksPerSeason * 2);
      for (var b = 1; b <= blocksPerSeason; b++) {
        final two = m.where((a) => a.block == b).toList();
        expect(two.length, 2);
        expect(two.map((a) => teamDefs[a.team].east).toSet(), {true, false});
      }
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.monthly.map((a) => a.block), c.monthly.map((a) => a.block));
      expect(copy.awards.where((a) => a.kind == AwardKind.month), isEmpty, reason: '月間MVPはシーズンの表彰とは別');
    });
  });

  group('ドラフトのボードと候補の情報', () {
    Career toDraft(int seed) {
      final c = careerAt(seed, 25);
      var guard = 0;
      while (c.phase != Phase.draft && guard++ < 100) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.phase, Phase.draft);
      return c;
    }

    test('予想順位は1から順に重ならず、経歴・身体測定・去年の成績は何度見ても同じ', () {
      final c = toDraft(3);
      final ranks = mockRanks(c.prospects);
      expect(ranks.values.toSet().length, ranks.length);
      expect(ranks.values.reduce((a, b) => a < b ? a : b), 1);
      final p = c.prospects.first;
      expect(backgroundOf(p), backgroundOf(p));
      expect(combineOf(p), combineOf(p));
      expect(amateurStatsOf(p), amateurStatsOf(p));
      for (final q in c.prospects) {
        final cb = combineOf(q);
        expect(cb.vertical, inInclusiveRange(45, 100));
        expect(cb.sprint, inInclusiveRange(3.0, 3.8));
        expect(backgroundOf(q), anyOf(startsWith('大学'), '海外のプロリーグ'));
      }
      // 運動能力が高い候補ほど、よく跳ぶ(平均で)
      final byAth = [...c.prospects]..sort((a, b) => a.player.attr(Attr.athletic).compareTo(b.player.attr(Attr.athletic)));
      final half = byAth.length ~/ 2;
      double avg(Iterable<Prospect> l) => l.fold(0.0, (n, q) => n + combineOf(q).vertical) / l.length;
      expect(avg(byAth.skip(half)), greaterThan(avg(byAth.take(half))));
      // 予想順位は、見立てのいい候補ほど上(おおむね)
      final top = ranks.entries.where((e) => e.value <= 5).map((e) => e.key.mid).reduce((a, b) => a + b) / 5;
      final low = ranks.entries.where((e) => e.value > ranks.length - 5).map((e) => e.key.mid).reduce((a, b) => a + b) / 5;
      expect(top, greaterThan(low));
      // 自分のスカウトでは、予想順位は変わらない
      final before = Map.of(ranks);
      c.scoutProspect(c.prospects.firstWhere((q) => !q.scouted));
      expect(mockRanks(c.prospects).values, before.values);
      expect(mockRanks(c.prospects).keys, before.keys);
    });

    test('ボードに印を付け外しでき、保存しても残る。次の指名までの人数が分かる', () {
      final c = toDraft(5);
      final a = c.prospects[0], b = c.prospects[1];
      c
        ..toggleBoard(a)
        ..toggleBoard(b);
      expect(c.board, [a.player.id, b.player.id]);
      c.toggleBoard(a);
      expect(c.board, [b.player.id]);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.board, c.board);
      final before = c.picksBeforeMine();
      if (before != null) {
        expect(c.picks[c.order[c.draftAt + before]].owner, c.mine);
        if (c.myTurn) expect(before, 0);
      }
    });
  });

  group('試合の数字', () {
    test('ボックススコアは両チーム分。シュートの内訳は点と合い、成功は試投を超えない', () {
      final c = careerAt(6, 12)..startSeason();
      c.playBlock();
      final games = c.lastGames.where((g) => g.box.isNotEmpty).toList();
      expect(games, isNotEmpty);
      for (final g in games) {
        expect(g.oppBox, isNotEmpty);
        for (final (box, pts) in [(g.box, g.ptsOf(c.mine)), (g.oppBox, g.ptsAgainst(c.mine))]) {
          expect(box.fold<int>(0, (n, b) => n + b.pts), pts);
          expect(box.fold<int>(0, (n, b) => n + b.min), totalMinutes + 25 * g.overtimes);
          for (final b in box) {
            expect(2 * (b.fgm - b.tpm) + 3 * b.tpm + b.ftm, b.pts, reason: b.name);
            expect(b.fgm, lessThanOrEqualTo(b.fga));
            expect(b.tpm, lessThanOrEqualTo(b.tpa));
            expect(b.ftm, lessThanOrEqualTo(b.fta));
            expect(b.tpa, lessThanOrEqualTo(b.fga));
          }
        }
        final copy = GameResult.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
        expect(copy.oppBox.first.fga, g.oppBox.first.fga);
        expect(copy.box.first.pm, g.box.first.pm);
      }
    });

    test('シーズンの成績にシュート・スティール・ブロック・ミスがたまり、率は本当らしい', () {
      final c = careerAt(6, 12)..startSeason();
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      final regulars = [for (final t in c.teams) ...t.roster].where((p) => p.stats.gp >= 60 && p.stats.mpg >= 25).toList();
      expect(regulars.length, greaterThan(60));
      double avg(double Function(Stats) f) => regulars.fold(0.0, (n, p) => n + f(p.stats)) / regulars.length;
      expect(avg((s) => s.fgPct), inInclusiveRange(0.40, 0.55));
      expect(avg((s) => s.ftPct), inInclusiveRange(0.65, 0.85));
      expect(avg((s) => s.spg), greaterThan(0.3));
      expect(avg((s) => s.bpg), greaterThan(0.2));
      expect(avg((s) => s.tpg), greaterThan(0.8));
      // センターはガードより3ポイントを打たず、ブロックが多い
      final cs = regulars.where((p) => p.pos == Pos.c).toList(), gs = regulars.where((p) => p.pos.guard).toList();
      double of(List<Player> l, double Function(Stats) f) => l.fold(0.0, (n, p) => n + f(p.stats)) / l.length;
      expect(of(cs, (s) => s.tpa / s.gp), lessThan(of(gs, (s) => s.tpa / s.gp)));
      expect(of(cs, (s) => s.bpg), greaterThan(of(gs, (s) => s.bpg)));
      // 保存しても残り、前の版の4つだけの成績も読める
      final p = regulars.first;
      expect(Stats.fromJson(p.stats.toJson()).fga, p.stats.fga);
      final old = Stats.fromJson([10, 200, 50, 30]);
      expect((old.ppg, old.fga, old.fgPct), (20.0, 0, 0.0));
    });
  });

  group('出場時間とコーチ陣', () {
    test('出場時間は合計240分。けがや移籍で足りないときは上から足す。36分を超えると戦力が落ちる', () {
      final c = careerAt(3, 12);
      final o = c.me.order;
      final even = {for (var i = 0; i < o.length; i++) o[i].id: i < 10 ? 24 : 0};
      c.setMinutes({...even, o.first.id: 10});
      expect(c.me.minutes, isEmpty, reason: '合計が240分でないと決まらない');
      c.setMinutes(even);
      expect(c.me.minutes.length, o.length);
      expect(c.me.playMinutes().fold<int>(0, (a, b) => a + b), totalMinutes);
      final evenStrength = c.me.strength;
      // 先発に44分ずつ(疲れる)
      final heavy = {for (var i = 0; i < o.length; i++) o[i].id: i < 5 ? 44 : i == 5 ? 20 : 0};
      c.setMinutes(heavy);
      final t = c.me;
      final heavyMinus = t.minutesEffect;
      c.setMinutes({});
      expect(c.me.minutesEffect, 0);
      expect(heavyMinus, lessThan(1.5), reason: '疲れの分が引かれる');
      expect(evenStrength, lessThan(c.me.strength), reason: '控えに長く出すと弱い');
      // 主力がけがをしても、合計は240分のまま
      c.setMinutes(even);
      o.first.injured = 5;
      final m = c.me.playMinutes();
      expect(m.fold<int>(0, (a, b) => a + b), totalMinutes);
      expect(m.last, 0, reason: 'けが人は出ない(順のいちばん後ろ)');
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.me.minutes, c.me.minutes);
    });

    test('期待より大きく少ない出場時間だと気持ちが下がる', () {
      // 区切りの途中でけが人が出ると、足りない時間は上から足される(エースに戻る)。そうならなかった局面で確かめる
      var checked = 0;
      for (final seed in [5, 6, 7, 8, 9, 10]) {
        final c = careerAt(seed, 12)..startSeason();
        final o = c.me.order;
        final star = o.first;
        final m = {for (var i = 0; i < o.length; i++) o[i].id: i == 0 ? 4 : 0};
        var left = totalMinutes - 4;
        for (final p in o.skip(1)) {
          final add = left.clamp(0, 40);
          m[p.id] = add;
          left -= add;
        }
        c.setMinutes(m);
        expect(c.me.minutes, isNotEmpty);
        star.morale = 60;
        c.playBlock();
        if (c.me.playMinutes()[c.me.order.indexOf(star)] > 10) continue;
        checked++;
        expect(star.morale, lessThan(60), reason: 'seed $seed');
      }
      expect(checked, greaterThan(0));
    });

    test('ヘッドコーチの力で戦力が変わり、保存しても残る。はじめのコーチは強さを変えない', () {
      final c = careerAt(4, 12);
      expect(c.me.coachBonus, 0);
      final base = c.me.strength;
      c.coachPool.add(const Coach(name: '名将', role: Staff.coach, rating: 95));
      c.hireCoach(c.coachPool.length - 1);
      expect(c.me.strength, closeTo(base + 0.75, 0.001));
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.me.coachOf(Staff.coach)!.name, '名将');
      expect(copy.coachPool.length, c.coachPool.length);
      expect(c.me.coachOf(Staff.coach)!.salary, greaterThan(staffCosts[2]));
    });

    test('前の版の保存(スタッフが3役)も読める', () {
      final c = careerAt(4, 12);
      final j = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      for (final t in j['teams'] as List) {
        (t as Map)['sf'] = [3, 2, 1];
        t.remove('co');
      }
      final old = Career.fromJson(j);
      expect(old.me.staffLevel(Staff.coach), 3);
      expect(old.me.staffLevel(Staff.development), 2);
    });
  });

  group('練習', () {
    Career toSeasonEnd(int seed, {int training = 1}) {
      final c = careerAt(seed, 12)..setTraining(training);
      var guard = 0;
      while (c.phase != Phase.seasonEnd && guard++ < 50) {
        botStep(c);
      }
      expect(c.phase, Phase.seasonEnd);
      c.fired = false;
      return c;
    }

    test('重点の能力はオフに伸び、成長の記録が残る。保存しても重点と強さは残る', () {
      final c = toSeasonEnd(4, training: 2);
      final p = c.me.roster.firstWhere((p) => p.attrs[Attr.defense.index] <= 10);
      c.setFocus(p.id, Attr.defense);
      final before = p.attrs[Attr.defense.index];
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.me.training, 2);
      expect(copy.me.roster.firstWhere((x) => x.id == p.id).focus, Attr.defense);
      c.toOffseason();
      expect(p.attrs[Attr.defense.index], before + 2);
      expect(c.growth.length, greaterThanOrEqualTo(c.me.roster.length));
      final g = c.growth.firstWhere((g) => g.name == p.name);
      expect(g.focus, Attr.defense);
      expect(g.after, p.ovr);
      final again = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(again.growth.map((g) => g.after), c.growth.map((g) => g.after));
    });

    test('きつい練習はけがが増える(10チーム分のシーズンで比べる)', () {
      int hurt(int training) {
        var n = 0;
        for (var seed = 20; seed < 30; seed++) {
          final c = careerAt(seed, 12)..setTraining(training);
          c.startSeason();
          var guard = 0;
          while (c.phase == Phase.season && guard++ < 10) {
            c.playBlock();
            n += c.log.where((l) => l.contains('けが:') && l.contains(c.me.def.short)).length;
            c.log.clear();
          }
        }
        return n;
      }

      expect(hurt(2), greaterThan(hurt(0)));
    });
  });

  group('自由契約の競り合い', () {
    Career toContracts(int seed) {
      final c = careerAt(seed, 12);
      var guard = 0;
      while (c.phase != Phase.contracts && guard++ < 300) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
      }
      expect(c.phase, Phase.contracts);
      // 申し込みの空きを作る(契約切れは放し、年俸を軽くする)
      for (final id in [...c.expiring]) {
        c.letGo(id);
      }
      return c;
    }

    Player bigOne(Career c, [double factor = 1.0]) => c.freeAgents.firstWhere((p) => c.isBigFa(p) && c.bidProblem(p, factor: factor) == null);

    test('大物はすぐには取れず、申し込むと日が進むうちに行き先を決める', () {
      final c = toContracts(3);
      while (c.me.payroll > salaryCap - 300 && c.me.roster.isNotEmpty) {
        c.release(c.me.roster.reduce((a, b) => a.salary >= b.salary ? a : b).id);
      }
      final p = bigOne(c, 1.1);
      expect(c.signProblem(p), isNotNull, reason: '大物はそのまま契約できない');
      expect(c.bid(p.id, 2, 1.1), isTrue);
      expect(c.myBid(p.id)!.years, 2);
      expect(c.winChanceOf(p), greaterThan(0));
      final rosterBefore = c.me.roster.length;
      for (var d = 0; d < faDays; d++) {
        c.nextFaDay();
      }
      expect(c.faDay, faDays);
      expect(c.bids, isEmpty, reason: '最後の日にはみんな決める');
      expect(c.faLog, isNotEmpty);
      final joined = c.me.roster.any((x) => x.id == p.id);
      if (joined) {
        expect(c.me.roster.length, rosterBefore + 1);
        expect(p.salary, (c.askOf(p, c.me).salary * 1.1).round().clamp(minSalary, maxSalary));
      } else {
        expect(c.teams.any((t) => t.roster.contains(p)), isTrue, reason: 'ほかのチームに行った');
        expect(c.inbox.any((m) => m.title.contains(p.name)), isTrue);
      }
      // もう申し込めない。オフは終えられる
      expect(c.bidProblem(c.freeAgents.firstWhere((x) => x.salary > minSalary, orElse: () => p)), isNotNull);
      c.finishContracts();
      expect(c.phase, Phase.preseason);
    });

    test('高く申し込むほど選ばれやすく、申し込み中の年俸は上限の空きに数える', () {
      // 申し込める大物がいる局面を探す(種によっては、上限の空きを作っても誰も届かない)
      late Career c;
      for (var seed = 5;; seed++) {
        c = toContracts(seed);
        while (c.me.payroll > salaryCap - 300 && c.me.roster.isNotEmpty) {
          c.release(c.me.roster.reduce((a, b) => a.salary >= b.salary ? a : b).id);
        }
        if (c.freeAgents.any((p) => c.isBigFa(p) && c.bidProblem(p) == null) || seed > 20) break;
      }
      final p = bigOne(c);
      c.bids.putIfAbsent(p.id, () => []).add(FaBid((c.mine + 1) % 30, c.askOf(p, c.teams[(c.mine + 1) % 30]).salary, 2));
      c.bid(p.id, 2, 0.9);
      final low = c.winChanceOf(p);
      c.bid(p.id, 2, 1.1);
      final high = c.winChanceOf(p);
      // 見込みは95%で頭打ち(お金を重く見る選手は、少し上げるだけで届く)
      expect(high, low >= 0.95 ? 0.95 : greaterThan(low));
      expect(c.rivalBids(p.id), 1);
      // 申し込みを重ねていくと、上限の空きが無くなる
      var n = 0;
      for (final q in [...c.freeAgents]) {
        if (q.id == p.id || !c.isBigFa(q)) continue;
        if (c.bidProblem(q) == null) {
          c.bid(q.id, 1, 1.0);
          n++;
        }
      }
      expect(n, greaterThanOrEqualTo(0));
      final left = c.freeAgents.where((q) => c.isBigFa(q) && c.myBid(q.id) == null).toList();
      if (left.isNotEmpty && c.me.roster.length - c.expiring.length + c.bids.values.where((l) => l.any((b) => b.team == c.mine)).length < maxRoster) {
        final room = salaryCap - c.me.payroll - c.bids.values.expand((l) => l).where((b) => b.team == c.mine).fold(0, (s, b) => s + b.salary);
        for (final q in left.where((q) => c.askOf(q, c.me).salary > room)) {
          expect(c.bidProblem(q), contains('上限'));
        }
      }
      c.withdrawBid(p.id);
      expect(c.myBid(p.id), isNull);
    });

    test('日の途中で保存して読み直しても、同じ行き先になる', () {
      final c = toContracts(7);
      c.nextFaDay();
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.faDay, c.faDay);
      expect(copy.bids.keys, c.bids.keys);
      c.finishContracts();
      copy.finishContracts();
      expect(jsonEncode(copy.toJson()), jsonEncode(c.toJson()));
    });
  });

  group('ローテーションと気持ち', () {
    test('順を決めると、その順で数える。力の低い選手を先発にすると弱くなり、自動に戻せる', () {
      final c = careerAt(4, 10);
      final auto = c.me.strength;
      final weakFirst = [...c.me.roster]..sort((a, b) => a.ovr.compareTo(b.ovr));
      c.setRotation([for (final p in weakFirst) p.id]);
      expect(c.me.order.first, weakFirst.first);
      expect(c.me.strength, lessThan(auto - 3));
      c.setRotation(const []);
      expect(c.me.strength, closeTo(auto, 0.001));
    });

    test('出番を減らされた主力は気持ちが下がり、20を切ると再契約に応じない', () {
      final c = careerAt(4, 10)..startSeason();
      final star = c.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      c.setRotation([for (final p in [...c.me.roster.where((p) => p != star), star]) p.id]);
      final before = star.morale;
      c.playBlock();
      expect(star.morale, lessThan(before));
      star.morale = 10;
      expect(c.resignProblem(star), isNotNull);
      star.morale = 30;
      final low = c.askOf(star, c.me).salary;
      star.morale = 80;
      expect(c.askOf(star, c.me).salary, lessThanOrEqualTo(low), reason: '気持ちが低いほど高く求める');
    });

    test('順と気持ちは保存される。いなくなった選手は順から外れる', () {
      final c = careerAt(4, 10);
      final ids = [for (final p in [...c.me.roster].reversed) p.id];
      c.setRotation(ids);
      c.me.roster.first.morale = 33;
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.me.rotation, ids);
      expect(copy.me.roster.first.morale, 33);
      final gone = c.me.order.first;
      c.release(gone.id);
      expect(c.me.order.contains(gone), isFalse);
      expect(c.me.order.length, c.me.roster.length);
    });
  });

  group('お金とオーナーの目標', () {
    test('入場料が高いほど客は減る。人気が高いほど入る', () {
      final c = careerAt(2, 10);
      c.setPrice(0);
      final cheap = c.attendance;
      c.setPrice(3);
      expect(c.attendance, lessThan(cheap));
      c.hype = 90;
      final hot = c.attendance;
      c.hype = 10;
      expect(c.attendance, lessThan(hot));
    });

    test('区切りごとに収入と年俸の支出が入り、シーズンの終わりに目標の結果と収支が決まる', () {
      final c = careerAt(2, 10)..startSeason();
      expect(c.goals, hasLength(3));
      expect(c.goals.first.kind, GoalKind.wins);
      expect(c.goals[1].kind, GoalKind.profit);
      c.playBlock();
      expect(c.revenue, greaterThan(0));
      expect(c.costs, greaterThan(0));
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      c.playPlayoffs();
      expect(c.goals.every((g) => g.met != null), isTrue);
      expect(c.lastProfit, c.profit);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.goals.map((g) => g.met), c.goals.map((g) => g.met));
      expect(copy.hype, c.hype);
    });

    test('ぜいたく税の線を超えたチームは、超えた分の1.5倍を支出に払う', () {
      final c = careerAt(2, 0);
      // 税の線を100だけ超える(合計の上限よりは下)
      c.me.roster.first.salary += taxLine + 100 - c.me.payroll;
      c.startSeason();
      expect(c.phase, Phase.season);
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      final before = c.costs;
      c.playPlayoffs();
      expect(c.costs - before, ((c.me.payroll - taxLine) * 1.5).round());
    });
  });

  group('けが・スタッフ・交渉', () {
    test('シーズン中にけがが起き、けが人は出場せず、試合が進むと治る。オフには全員治る', () {
      final c = careerAt(7, 12)..startSeason();
      var hurtSeen = false;
      while (c.phase == Phase.season) {
        c.playBlock();
        for (final t in c.teams) {
          for (final p in t.roster.where((p) => p.injured > 0)) {
            hurtSeen = true;
            expect(t.order.indexOf(p), greaterThanOrEqualTo(t.healthy.length), reason: 'けが人は後ろ');
          }
        }
      }
      expect(hurtSeen, isTrue);
      expect(c.log.any((l) => l.contains('けが:')), isTrue);
      c.playPlayoffs();
      c.fired = false;
      c.toOffseason();
      expect([for (final t in c.teams) ...t.roster].every((p) => p.injured == 0), isTrue);
    });

    test('トレーナーが良いほど、けがは少ない', () {
      int count(int level) {
        var n = 0;
        for (var seed = 1; seed <= 4; seed++) {
          final c = Career.start(seed: seed);
          for (final t in c.teams) {
            t.staff = [2, level, 2, 2];
            t.coaches = [];
          }
          c.startSeason();
          while (c.phase == Phase.season) {
            c.playBlock();
          }
          n += c.log.where((l) => l.contains('けが:')).length;
        }
        return n;
      }
      expect(count(3), lessThan(count(1)));
    });

    test('コーチはシーズン前とオフだけ雇え、給料は支出に入る。スカウトの力でスカウトの数が変わる', () {
      final c = careerAt(7, 12);
      expect(c.me.coaches.length, Staff.values.length, reason: 'はじめから4人いる');
      c.coachPool.add(const Coach(name: '名スカウト', role: Staff.scout, rating: 90));
      expect(c.hireCoach(c.coachPool.length - 1), isTrue);
      expect(c.me.staffLevel(Staff.scout), 3);
      expect(c.me.coaches.length, Staff.values.length, reason: '同じ役の前のコーチは辞める');
      expect(c.coachPool.any((k) => k.role == Staff.scout && k.name != '名スカウト'), isTrue, reason: '辞めたコーチは候補に戻る');
      final weak = c.coachPool.indexWhere((k) => k.role == Staff.scout && k.rating < 65);
      c.startSeason();
      if (weak >= 0) expect(c.hireCoach(weak), isFalse, reason: 'シーズン中は替えられない');
      expect(c.me.staffLevel(Staff.scout), 3);
      c.playBlock();
      expect(c.costs, greaterThan((c.me.payroll * blockSizes[0] / gamesPerSeason).round()));
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      c.playPlayoffs();
      c.fired = false;
      c.toOffseason();
      expect(c.scoutsLeft, 4);
    });

    test('交渉: 求める額なら必ず契約、1割高いと気持ちが上がる、1割安くを断られると気持ちが下がり、3回断られたらもう値切れない', () {
      final c = careerAt(7, 12);
      var guard = 0;
      while ((c.phase != Phase.contracts || c.expiring.length < 2) && guard++ < 300) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        if (c.phase == Phase.contracts) {
          for (final id in [...c.expiring]) {
            c.letGo(id);
          }
        }
        botStep(c);
      }
      expect(c.phase, Phase.contracts);
      final a = c.me.roster.firstWhere((p) => p.id == c.expiring[0]);
      a.morale = 60;
      final askA = c.askOf(a, c.me).salary;
      if (c.resignProblem(a) == null) {
        expect(c.offer(a.id, 1, 1.1), isTrue);
        expect(a.morale, 70);
        expect(a.salary, (askA * 1.1).round().clamp(minSalary, maxSalary));
      }
      final b = c.me.roster.firstWhere((p) => p.id == c.expiring.last);
      // 値下げを断られるまで試す(断られたら、もう値切れない)
      b.morale = 25; // 低めだが、再契約に応じなくなるほどではない
      final before = b.morale;
      final ok = c.offer(b.id, 1, 0.9);
      if (!ok) {
        expect(c.haggled, contains(b.id));
        expect(b.morale, lessThanOrEqualTo(before));
        // 代理人との値切りは3回まで。3回断られたら、もう申し出られない
        var guard = 0;
        while (c.haggleRounds(b.id) < Career.maxHaggle && guard++ < 10) {
          if (c.offer(b.id, 1, 0.9)) break;
        }
        if (c.haggleRounds(b.id) >= Career.maxHaggle) expect(c.offer(b.id, 1, 0.9), isFalse);
      }
    });
  });

  group('1週間ずつ進める', () {
    test('1週間は3試合。区切りの終わりは越えず、着いたら区切りが進む。結果の一覧は区切りの中で足していく', () {
      final c = careerAt(9, 12)..startSeason();
      expect(c.playWeek(), isFalse);
      expect(c.roundAt, 3);
      expect(c.lastGames, hasLength(3));
      var guard = 0;
      while (!c.playWeek() && guard++ < 20) {}
      expect(c.roundAt, blockSizes[0]);
      expect(c.block, 1);
      expect(c.lastGames, hasLength(blockSizes[0]));
      c.playWeek();
      expect(c.lastGames, hasLength(3), reason: '次の区切りに入ったら一覧は空から');
      // 途中で保存しても同じ続きになる
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.roundAt, c.roundAt);
      c.playBlock();
      copy.playBlock();
      expect(jsonEncode(copy.toJson()), jsonEncode(c.toJson()));
      expect(c.roundAt, blockStart(2));
    });

    test('シーズンの終わりには、プレーオフの山がそろう', () {
      final c = careerAt(9, 12)..startSeason();
      while (c.phase == Phase.season) {
        c.playWeek();
      }
      expect(c.roundAt, gamesPerSeason);
      expect(c.phase, Phase.playoffs);
      c.playPlayoffs();
      expect(c.finals, isNotNull);
    });
  });

  group('受信箱・MVP争い・オールスター', () {
    test('開幕でオーナーの目標、区切りごとにMVP争いが届き、シーズンの半分でオールスター24人が決まる', () {
      final c = careerAt(11, 8)..startSeason();
      expect(c.inbox.first.from, Sender.owner);
      c.playBlock();
      expect(c.inbox.any((m) => m.title.startsWith('MVP争い')), isTrue);
      expect(c.mvpRace(), hasLength(5));
      c.playBlock();
      expect(c.allStarIds, hasLength(24));
      final stars = [for (final t in c.teams) ...t.roster.where((p) => c.allStarIds.contains(p.id))];
      expect(stars.where((p) => c.teams.firstWhere((t) => t.roster.contains(p)).east), hasLength(12));
      expect(stars.every((p) => p.allStars >= 1), isTrue);
      expect(c.inbox.any((m) => m.title.contains('オールスター')), isTrue);
      expect(c.inbox.length, lessThanOrEqualTo(Career.inboxLimit));
    });

    test('出番の不満に「先発に入れる」と返すと先発に入り気持ちが上がる。「今のまま」だと下がる', () {
      for (final choice in [0, 1]) {
        final c = careerAt(11, 8)..startSeason();
        final p = lineup(c.me.roster)[1];
        p.morale = 40;
        c.setRotation([for (final x in [...c.me.order.where((x) => x != p), p]) x.id]);
        c.playBlock();
        final m = c.inbox.where((m) => m.kind == MsgKind.minutes && m.player == p.id).firstOrNull;
        expect(m, isNotNull, reason: '先発の力なのに控えに回された選手から届く');
        final before = p.morale;
        c.answer(m!.id, choice);
        expect(m.needsAnswer, isFalse);
        if (choice == 0) {
          expect(c.me.order.indexOf(p), lessThan(5));
          expect(p.morale, before + 15);
        } else {
          expect(p.morale, before - 8);
        }
        final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
        expect(copy.inbox.firstWhere((x) => x.id == m.id).answer, choice);
      }
    });
  });

  group('見せる能力(2K の幅)', () {
    test('見せる数字は、もとの力の順を保ったまま、控え70前後・スター90台の幅になる', () {
      for (var v = 40; v < 99; v++) {
        expect(shown(v + 1), greaterThanOrEqualTo(shown(v)));
      }
      expect(shown(50), inInclusiveRange(66, 72));
      expect(shown(80), inInclusiveRange(86, 91));
      expect(shown(92), greaterThanOrEqualTo(95));
    });

    test('細かい能力は35項目で、6つの分類のどれにも2つ以上ある。ポジションの色が出る', () {
      expect(subRatings, hasLength(35));
      for (final a in Attr.values) {
        expect(subRatings.where((s) => s.attr == a).length, greaterThanOrEqualTo(2), reason: a.label);
      }
      final c = Career.start(seed: 4);
      final all = [for (final t in c.teams) ...t.roster];
      double avg(Pos pos, String label) {
        final s = subRatings.firstWhere((x) => x.label == label);
        final ps = all.where((p) => p.pos == pos).toList();
        return ps.fold(0, (n, p) => n + subRating(p, s)) / ps.length;
      }
      expect(avg(Pos.c, 'ブロック'), greaterThan(avg(Pos.pg, 'ブロック') + 5));
      expect(avg(Pos.pg, 'ボール運び'), greaterThan(avg(Pos.c, 'ボール運び') + 5));
      for (final p in all) {
        for (final s in subRatings) {
          expect(subRating(p, s), inInclusiveRange(40, 99));
        }
      }
    });

    test('体格はポジションで違い(センターが高い)、ポテンシャルは5刻みの幅', () {
      final c = Career.start(seed: 4);
      final all = [for (final t in c.teams) ...t.roster];
      double h(Pos pos) {
        final ps = all.where((p) => p.pos == pos).toList();
        return ps.fold(0, (n, p) => n + physicalOf(p).$1) / ps.length;
      }
      expect(h(Pos.c), greaterThan(h(Pos.pg) + 15));
      for (final p in all) {
        final (lo, hi) = potentialRange(p);
        expect(lo % 5, 0);
        expect(shown(p.pot), inInclusiveRange(lo, hi));
      }
    });
  });

  group('選手の型とバッジ', () {
    test('ビッグとガードで型が分かれ、能力の高い選手ほどバッジが多く段階も高い', () {
      final c = Career.start(seed: 2);
      final all = [for (final t in c.teams) ...t.roster];
      const bigTypes = {'ストレッチビッグ', 'プレーメイクビッグ', 'リムプロテクター', 'ポストスコアラー'};
      for (final p in all) {
        expect(bigTypes.contains(archetypeOf(p)), p.pos.big, reason: '${p.pos} ${archetypeOf(p)}');
      }
      final stars = all.where((p) => p.ovr >= 82).toList();
      final low = all.where((p) => p.ovr <= 60).toList();
      double avg(List<Player> ps) => ps.fold(0, (s, p) => s + badgesOf(p).length) / ps.length;
      expect(avg(stars), greaterThan(avg(low) + 1));
      for (final p in all) {
        final b = badgesOf(p);
        for (var i = 1; i < b.length; i++) {
          expect(b[i].$2, lessThanOrEqualTo(b[i - 1].$2), reason: '段階の高い順');
        }
      }
    });
  });

  group('ボックススコア・連勝・日程', () {
    test('自分の試合はクォーターの点と選手の数字が残り、合計が試合の点と合う', () {
      final c = careerAt(13, 10)..startSeason();
      c.playBlock();
      for (final g in c.lastGames) {
        expect(g.quarters, hasLength(8));
        // 延長があれば、その点も足す
        expect(g.quarters.take(4).fold(0, (a, b) => a + b) + [for (var k = 0; k < g.overtimes; k++) g.overtime[k * 2]].fold(0, (a, b) => a + b), g.homePts);
        expect(g.quarters.skip(4).fold(0, (a, b) => a + b) + [for (var k = 0; k < g.overtimes; k++) g.overtime[k * 2 + 1]].fold(0, (a, b) => a + b), g.awayPts);
        expect(g.box.fold(0, (a, b) => a + b.pts), g.ptsOf(c.mine));
        expect(g.box.every((b) => b.min > 0), isTrue);
      }
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.lastGames.first.box.length, c.lastGames.first.box.length);
    });

    test('連勝・連敗は直近の結果の続き。ゲーム差は首位との差', () {
      final c = careerAt(13, 10)..startSeason();
      c.playBlock();
      final mine = c.lastGames;
      var expect0 = 0;
      for (final g in mine) {
        final won = g.winner == c.mine;
        expect0 = won ? (expect0 > 0 ? expect0 + 1 : 1) : (expect0 < 0 ? expect0 - 1 : -1);
      }
      expect(c.me.streak, expect0);
      final st = standings(c.teams, east: c.me.east);
      expect(gamesBehind(st.first, st.first), 0);
      expect(gamesBehind(st.first, st.last), greaterThan(0));
    });

    test('これからの日程は、次の節の相手から順に並ぶ', () {
      final c = careerAt(13, 10)..startSeason();
      c.playWeek();
      final next = c.upcoming();
      expect(next, hasLength(5));
      final round = seasonSchedule(30)[c.roundAt];
      final (h, a) = round.firstWhere((x) => x.$1 == c.mine || x.$2 == c.mine);
      expect(next.first.$1, h == c.mine ? a : h);
      expect(next.first.$2, h == c.mine);
    });
  });

  group('契約の延長', () {
    test('残り1年の選手と延長できる。年俸は来季から変わり、年数が足される', () {
      final c = careerAt(17, 10);
      final p = c.me.roster.firstWhere((x) => x.years > 1);
      p.years = 1;
      p.morale = 70;
      expect(c.extendProblem(p), isNull);
      final now = p.salary;
      final ask = c.extensionAsk(p).salary;
      final add = c.extensionAsk(p).maxYears < 3 ? c.extensionAsk(p).maxYears : 3;
      expect(c.extend(p.id, 3, 1.1), isTrue, reason: '1割高くは必ず受ける');
      expect(p.salary, now, reason: '今季の年俸はそのまま');
      expect(p.nextSalary, (ask * 1.1).round().clamp(minSalary, maxSalary));
      expect(p.years, 1 + add, reason: '年齢で延ばせる年数は変わる');
      expect(c.extendProblem(p), isNotNull, reason: 'もう延長した');
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.me.roster.firstWhere((x) => x.id == p.id).nextSalary, p.nextSalary);
      _toPlayoffs(c).playPlayoffs();
      c.fired = false;
      final next = p.nextSalary;
      c.toOffseason();
      if (c.me.roster.contains(p)) {
        expect(p.salary, next);
        expect(p.nextSalary, isNull);
        expect(p.years, add);
      }
    });

    test('残り1年でない選手・気持ちが低い選手とは延長できない。断られると今季はもう申し出られない', () {
      final c = careerAt(17, 10);
      final p = c.me.roster.firstWhere((x) => x.years > 1);
      expect(c.extendProblem(p), isNotNull);
      p.years = 1;
      p.morale = 20;
      expect(c.extendProblem(p), isNotNull);
      p.morale = 36;
      var refused = false;
      for (var i = 0; i < 30 && !refused; i++) {
        if (!c.extend(p.id, 1, 0.9)) refused = true;
        if (p.nextSalary != null) break;
      }
      if (refused) {
        expect(c.extAsked, contains(p.id));
        expect(c.extendProblem(p), isNotNull);
      }
    });

    test('開幕で、残り1年の主力の代理人から延長の話が届く', () {
      final c = careerAt(17, 10);
      final star = c.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
      star.years = 1;
      c.startSeason();
      expect(c.inbox.any((m) => m.from == Sender.agent && m.player == star.id), star.ovr >= 70);
    });
  });

  group('指名権(4年先まで・保護・くじの見込み)', () {
    test('指名権は今年から6年先まで、1巡目と2巡目が30チーム分ある。ドラフトのあとも7年分そろう', () {
      final c = careerAt(19, 10);
      expect(c.picks, hasLength(7 * 2 * 30));
      expect(c.picks.map((p) => p.season).toSet(), {1, 2, 3, 4, 5, 6, 7});
      _toPlayoffs(c).playPlayoffs();
      c.fired = false;
      c.toOffseason();
      while (c.phase == Phase.draft) {
        c.passPick();
      }
      expect(c.picks.map((p) => p.season).toSet(), {2, 3, 4, 5, 6, 7, 8});
      expect(c.picks, hasLength(7 * 2 * 30));
    });

    test('先の年ほど、保護が付くほど、指名権の値打ちは下がる', () {
      final now = DraftPick(season: 1, round: 1, from: 3, owner: 3);
      final later = DraftPick(season: 3, round: 1, from: 3, owner: 3);
      expect(pickValue(later, TeamMode.balanced, 5, 1), lessThan(pickValue(now, TeamMode.balanced, 5, 1)));
      expect(pickValue(now, TeamMode.balanced, 20, 1, protect: 10), lessThan(pickValue(now, TeamMode.balanced, 20, 1)));
      expect(pickValue(now, TeamMode.balanced, 5, 1, protect: 10), lessThan(pickValue(now, TeamMode.balanced, 5, 1) * 0.3),
          reason: '保護の範囲に入りそうな今年の指名権は、ほとんど値打ちがない');
    });

    test('保護付きで出した1巡目は、保護の範囲に入ると元のチームに戻り、ニュースに出る', () {
      final c = careerAt(19, 28)..startSeason();
      final i = c.picks.indexWhere((p) => p.season == 1 && p.round == 1 && p.from == c.mine);
      final other = c.mine == 0 ? 1 : 0;
      c.picks[i]
        ..owner = other
        ..protect = 30;
      while (c.phase == Phase.season) {
        c.playBlock();
      }
      c.playPlayoffs();
      c.fired = false;
      c.toOffseason();
      expect(c.picks[i].owner, c.mine);
      expect(c.log.any((l) => l.contains('保護:')), isTrue);
    });

    test('トレードで保護を付けて出せる。成立すると指名権に保護が付く', () {
      final c = careerAt(19, 10);
      final mine = c.picksOf(c.mine).firstWhere((i) => c.picks[i].round == 1 && c.picks[i].season == 2);
      final pt = c.teams.where((t) => t.index != c.mine).firstWhere((t) => t.mode == TeamMode.rebuild).index;
      final scrub = c.teams[pt].roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final o = TradeOffer(partner: pt, givePicks: [mine], get: [scrub.id], protections: {mine: 10});
      if (c.judge(o).ok) {
        c.propose(o);
        expect(c.picks[mine].owner, pt);
        expect(c.picks[mine].protect, 10);
        expect(c.picks[mine].label(c.teams, c.season), contains('上位10位保護'));
      }
      final copy = TradeOffer.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(copy.protections, {mine: 10});
    });

    test('くじの見込みは14チームで合わせて100%、成績の悪いチームほど高い', () {
      final c = careerAt(19, 10)..startSeason();
      c.playBlock();
      final odds = lotteryOdds(c.teams);
      expect(odds, hasLength(14));
      expect(odds.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
      final worst = standings(c.teams).last.index;
      expect(odds[worst], odds.values.reduce((a, b) => a > b ? a : b));
    });

    test('前の版の保存(指名権が2年分)を読んでも、7年分そろう', () {
      final c = careerAt(19, 10);
      final j = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      j['picks'] = [for (final p in j['picks'] as List) if ((p as Map)['s'] as int <= 2) p];
      final copy = Career.fromJson(j);
      expect(copy.picks.map((p) => p.season).toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(copy.picks, hasLength(420));
    });
  });

  group('相手に聞く・相手同士のトレード・ニュース', () {
    test('受け取りたい選手を選ぶと、相手が受ける出し方が返り、そのまま成立する', () {
      var found = 0;
      for (var seed = 1; seed <= 20; seed++) {
        final c = careerAt(seed, 15);
        final pt = c.teams.where((t) => t.index != c.mine).firstWhere((t) => t.mode == TeamMode.rebuild).index;
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
      expect(found, greaterThanOrEqualTo(5), reason: '主力を取りに行っても、出し方が見つかることがよくある');
    });

    test('何も受け取らないなら聞けない。締め切りのあとも聞けない', () {
      final c = Career.start(seed: 2)..startSeason();
      final other = c.mine == 0 ? 1 : 0;
      expect(c.askPartner(other), isNull);
      c
        ..playBlock()
        ..playBlock();
      expect(c.askPartner(other, get: [c.teams[other].roster.first.id]), isNull);
    });

    test('相手同士のトレードが起き、どのチームも人数と年俸の決まりを守る。ニュースに残る', () {
      var trades = 0;
      for (var seed = 1; seed <= 5; seed++) {
        final c = careerAt(seed, 15);
        var guard = 0;
        while (c.season <= 3 && c.phase != Phase.over && guard++ < 200) {
          if (c.phase == Phase.seasonEnd) c.fired = false;
          botStep(c);
          // ドラフトの間は新人が入って一時的に15人を超える。シーズン前・シーズン中は15人まで
          if (c.phase != Phase.preseason && c.phase != Phase.season) continue;
          for (final t in c.teams.where((t) => t.index != c.mine)) {
            expect(t.roster.length, lessThanOrEqualTo(maxRoster), reason: t.name);
            expect(t.payroll, lessThanOrEqualTo(secondApron + 100), reason: t.name);
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
      final myPicks = c.order.where((i) => c.picks[i].owner == c.mine).length;
      final before = c.me.roster.length;
      final p = byMid(c).first;
      c.pickProspect(p);
      expect(c.me.roster, contains(p.player));
      expect(p.player.years, anyOf(2, 4), reason: '1巡は4年(選択権2年)、2巡は2年');
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
      final c = careerAt(30, 1);
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
      for (final t in c.teams.where((t) => t.index != c.mine)) {
        expect(t.roster.length, inInclusiveRange(13, maxRoster));
      }
    });

    test('自由契約: 上限の空きが無ければ取れない。最低年俸の選手はいつでも取れる', () {
      final c = careerAt(6, 1);
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
      // 弱いチームで、目標を82勝にして確実に届かないようにする
      final c = careerAt(14, 28);
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
      final done = botPlayCareer(15, team: teamAtRank(15, 15));
      expect(done.phase, Phase.over);
      expect(done.history.length, done.fired ? lessThanOrEqualTo(careerSeasons) : careerSeasons);
      expect(c.phase, Phase.preseason);
    });

    test('ぜいたく税の線を超えると、超えた分だけ信頼が下がる', () {
      expect(luxuryTaxTrust(taxLine), 0);
      expect(luxuryTaxTrust(taxLine + 120), 12);
      expect(luxuryTaxTrust(taxLine + 900), maxTaxTrust, reason: '税だけで解任されないよう、1シーズンの減りには上限がある');
    });
  });

  group('保存', () {
    test('どの局面でも、保存して読み直すと同じ続きになる', () {
      final c = careerAt(40, 28);
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
      for (final rank in [1, 15, 28]) {
        var titles = 0, fired = 0;
        const n = 30;
        for (var i = 0; i < n; i++) {
          final c = botPlayCareer(500 + i, team: teamAtRank(500 + i, rank));
          titles += c.titles;
          if (c.fired) fired++;
        }
        // 30チームなので、運だけなら10年で0.33回
        expect(titles / n, inInclusiveRange(0.05, 1.5), reason: '戦力$rank位 優勝/任期');
        expect(fired / n, lessThan(0.5), reason: '戦力$rank位 解任');
      }
    });
  });
}
