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
          expect(t.payroll, lessThanOrEqualTo(hardCap), reason: t.name);
          expect(t.roster.any((p) => p.pos.guard) && t.roster.any((p) => p.pos.big), isTrue);
        }
      }
    });

    test('同じ種なら、どのチームを選んでも同じリーグになる。チームの状態は強さの順位から決まる', () {
      final a = Career.start(seed: 11, team: 3);
      final b = Career.start(seed: 11, team: 17);
      expect(jsonEncode([for (final t in a.teams) t.toJson()]), jsonEncode([for (final t in b.teams) t.toJson()]));
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
            t.staff = [2, level, 2];
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

    test('スタッフはシーズン前とオフだけ変えられ、給料は支出に入る。スカウトの段階でスカウトの数が変わる', () {
      final c = careerAt(7, 12);
      c.setStaff(Staff.scout, 3);
      expect(c.me.staffLevel(Staff.scout), 3);
      c.startSeason();
      c.setStaff(Staff.scout, 1);
      expect(c.me.staffLevel(Staff.scout), 3, reason: 'シーズン中は変えられない');
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

    test('交渉: 求める額なら必ず契約、1割高いと気持ちが上がる、1割安くを断られると気持ちが下がって二度と値切れない', () {
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
        expect(c.offer(b.id, 1, 0.9), isFalse);
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
        expect(g.quarters.take(4).fold(0, (a, b) => a + b), g.homePts);
        expect(g.quarters.skip(4).fold(0, (a, b) => a + b), g.awayPts);
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
      final myPicks = c.order.where((i) => c.picks[i].owner == c.mine).length;
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
      final c = careerAt(14, 1);
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
