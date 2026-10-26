import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/game/standings.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(int level) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: 25,
    heightCm: 192,
    abilities: {for (final a in Ability.values) a: level},
    clearPositionLock: true,
  );
}

int _n = 0;

/// 大会ごとに違う名前の相手を付ける(順位表に、戦った相手が入るかを見るため)。
({String name, bool rival, double bonus}) _pick(int round, bool isFinal) =>
    (name: 'チーム${_n++}', rival: false, bonus: 0);

void main() {
  test('勝ち抜き戦には順位表が無い', () {
    final t = playTournament(_p(60), League.highSchool, form: 1, rng: Random(1));
    expect(standingsOf(t), isNull);
    expect(ourRank(standingsOf(t)), isNull);
  });

  test('進出した大会では進出圏(上位)、進めなかった大会では圏外。チーム数・自分の勝敗が合う', () {
    for (final lg in [League.university, League.corporate, League.proDomestic, League.proAbroad, League.national]) {
      var inCount = 0, outCount = 0;
      for (var seed = 0; seed < 120; seed++) {
        final t = playTournament(_p(seed.isEven ? 85 : 45), lg,
            form: 1, rng: Random(seed), pickOpponent: _pick);
        final table = standingsOf(t)!;
        expect(table.length, leagueTeams(lg), reason: lg.label);
        expect(table.where((s) => s.isUs), hasLength(1));
        final us = table.firstWhere((s) => s.isUs);
        expect(us.wins, t.regularWins);
        expect(us.wins + us.losses, lg.rounds);
        final rank = ourRank(table)!;
        if (t.reachedPlayoffs) {
          inCount++;
          expect(rank, lessThanOrEqualTo(playoffSpots(lg)), reason: '${lg.label} seed $seed');
        } else {
          outCount++;
          expect(rank, greaterThan(playoffSpots(lg)), reason: '${lg.label} seed $seed');
        }
        // 勝ち数の多い順に並んでいる。
        for (var i = 1; i < table.length; i++) {
          expect(table[i - 1].wins, greaterThanOrEqualTo(table[i].wins));
        }
        // 各チームの試合数はリーグ戦の数。
        for (final s in table) {
          expect(s.wins + s.losses, lg.rounds);
          expect(s.wins, inInclusiveRange(0, lg.rounds));
        }
      }
      expect(inCount, greaterThan(0), reason: lg.label);
      expect(outCount, greaterThan(0), reason: lg.label);
    }
  });

  test('戦った相手が順位表に入っている。同じ大会からは同じ表ができる', () {
    final t = playTournament(_p(70), League.proDomestic, form: 1, rng: Random(5), pickOpponent: _pick);
    final a = standingsOf(t)!, b = standingsOf(t)!;
    expect([for (final s in a) '${s.name}${s.wins}'], [for (final s in b) '${s.name}${s.wins}']);
    final names = a.map((s) => s.name).toSet();
    for (final m in t.matches.take(League.proDomestic.rounds)) {
      expect(names, contains(m.opponent));
    }
  });

  test('自分のチームには名前があり、順位表にもその名前で出る。進学・プロ入り・海外挑戦で変わり、保存で残る', () {
    final g = Game.start('x', rng: Random(9), events: false);
    expect(g.teamName, isNotEmpty);
    expect(g.teamName, endsWith('ミニバスクラブ'));
    final t = playTournament(_p(70), League.proDomestic, form: 1, rng: Random(2));
    final table = standingsOf(t, usName: 'サクラホークス')!;
    expect(table.firstWhere((s) => s.isUs).name, 'サクラホークス');
    final back = Game.fromJson(g.toJson());
    expect(back.teamName, g.teamName);
    // 古いセーブ(名前なし)は「自チーム」と出す。
    final old = Game.fromJson(g.toJson()..remove('teamName'));
    expect(old.teamLabel, '自チーム');
  });
}
