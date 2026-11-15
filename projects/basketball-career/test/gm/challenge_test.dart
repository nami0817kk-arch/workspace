import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// シーズンを終えたところまで進め、そのシーズンを優勝したことにする。
Career _champSeason(int seed, int rank) {
  final c = careerAt(seed, rank)..startSeason();
  var guard = 0;
  while (c.phase != Phase.seasonEnd && guard++ < 60) {
    botStep(c);
  }
  final h = c.history.last;
  c.history.last = SeasonRecord(season: h.season, wins: h.wins, losses: h.losses, rank: h.rank, result: 5, trustAfter: h.trustAfter, target: h.target);
  return c;
}

void main() {
  test('縛りの実績: 先発の年齢・生え抜き・年俸・3年で頂点が、優勝した年に条件どおりに付く', () {
    final c = _champSeason(3, 27);
    final starters = c.me.order.take(5).toList();
    // 若い先発
    for (final p in starters) {
      p.age = 22;
    }
    expect(Profile.challengesOf(c), contains(Achievement.youngTitle));
    expect(Profile.challengesOf(c), isNot(contains(Achievement.veteranTitle)));
    for (final p in starters) {
      p.age = 33;
    }
    expect(Profile.challengesOf(c), contains(Achievement.veteranTitle));
    // 生え抜き3人
    c.draftedIds = [for (final p in starters.take(3)) p.id];
    expect(Profile.challengesOf(c), contains(Achievement.homegrownCore));
    c.draftedIds = [for (final p in starters.take(2)) p.id];
    expect(Profile.challengesOf(c), isNot(contains(Achievement.homegrownCore)));
    // 強さ28位で始めて1年目の優勝
    expect(c.startRank, greaterThanOrEqualTo(22));
    expect(Profile.challengesOf(c), contains(Achievement.quickRebuild));
    // 年俸の合計が上限以下か
    expect(Profile.challengesOf(c).contains(Achievement.underCap), c.me.payroll <= 1650);
  });

  test('優勝していない年は、優勝の縛りは付かない。言葉の重み90とオーナーの目標全部は優勝に依らない', () {
    final c = careerAt(3, 5)..startSeason();
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 60) {
      botStep(c);
    }
    if (c.history.last.champion) return; // 万一優勝していたら、この確かめは要らない
    final got = Profile.challengesOf(c);
    for (final a in [Achievement.quickRebuild, Achievement.threePeat, Achievement.youngTitle, Achievement.veteranTitle, Achievement.underCap, Achievement.sweep]) {
      expect(got, isNot(contains(a)));
    }
    c.word = 92;
    expect(Profile.challengesOf(c), contains(Achievement.wordKeeper));
    for (final g in c.goals) {
      g.met = true;
    }
    expect(Profile.challengesOf(c), contains(Achievement.allGoals));
  });

  test('実績は保存して読み直しても残る(名前で保存)', () {
    final p = Profile()..done.addAll([Achievement.threePeat, Achievement.wordKeeper]);
    final back = Profile.fromJson(p.toJson());
    expect(back.has(Achievement.threePeat), isTrue);
    expect(back.has(Achievement.wordKeeper), isTrue);
  });

  test('「自動で組み直す」はけが人を順の後ろへ回し、出場時間を自動に戻す', () {
    final c = careerAt(11, 8)..startSeason();
    final o = c.me.order;
    final hurt = o[1];
    hurt.injured = 6;
    c.me.minutes = {for (final p in o) p.id: 20};
    c.benchInjured();
    expect(c.me.order.last, hurt);
    expect(c.me.order.take(5), isNot(contains(hurt)));
    expect(c.me.minutes, isEmpty);
  });
}
