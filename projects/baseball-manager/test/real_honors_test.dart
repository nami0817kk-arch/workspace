import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/awards.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/marks.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _awards(Line l, {List<String> titles = const []}) => awardsOf(l,
    games: 143,
    firstYear: false,
    prevGames: 143,
    fielding: 50,
    isBatter: l.hasBatting && !l.hasPitching,
    titles: titles);

/// 防御率が `era` 前後になる投手の1シーズン(先発)。
Line _pitch({
  required int wins,
  required int losses,
  required int strikeouts,
  double era = 2.0,
  int outs = 640,
}) {
  final faced = (outs * 1.25).round();
  final runs = era * outs / 27;
  return Line(
    games: 30,
    starts: 28,
    faced: faced,
    outs: outs,
    strikeouts: strikeouts,
    runsRaw: runs - runBaseline * faced,
    wins: wins,
    losses: losses,
  );
}

Line _bat({
  required int hits,
  required int homeRuns,
  int rbi = 80,
  int stolen = 5,
  int atBats = 550,
}) =>
    Line(
      games: 143,
      atBats: atBats,
      hits: hits,
      totalBases: hits + homeRuns * 3 + 40,
      walks: 70,
      homeRuns: homeRuns,
      rbi: rbi,
      stolenBases: stolen,
    );

void main() {
  group('プロの大記録・表彰', () {
    test('三冠王: 首位打者・本塁打王・打点王の水準がそろったとき', () {
      final l = _bat(hits: 200, homeRuns: 45, rbi: 120);
      expect(_awards(l, titles: ['首位打者', '本塁打王']), contains('三冠王'));
      // 打点が足りない・どちらかのタイトルが無いときは付かない
      expect(
          _awards(_bat(hits: 200, homeRuns: 45, rbi: 100),
              titles: ['首位打者', '本塁打王']),
          isNot(contains('三冠王')));
      expect(_awards(l, titles: ['首位打者']), isNot(contains('三冠王')));
    });

    test('投手三冠: 防御率・勝利・奪三振の3つのタイトル', () {
      final l = _pitch(wins: 22, losses: 4, strikeouts: 260, era: 1.5);
      expect(_awards(l, titles: ['最優秀防御率', '最多勝', '最多奪三振']), contains('投手三冠'));
      expect(_awards(l, titles: ['最優秀防御率', '最多勝']), isNot(contains('投手三冠')));
    });

    test('エース賞: 勝利・防御率・奪三振・勝率・投球回の基準をすべて満たす', () {
      expect(_awards(_pitch(wins: 18, losses: 6, strikeouts: 190, era: 2.2)),
          contains('エース賞'));
      // どれか1つでも足りなければ付かない
      expect(_awards(_pitch(wins: 12, losses: 6, strikeouts: 190, era: 2.2)),
          isNot(contains('エース賞'))); // 勝利
      expect(_awards(_pitch(wins: 18, losses: 6, strikeouts: 190, era: 3.0)),
          isNot(contains('エース賞'))); // 防御率
      expect(_awards(_pitch(wins: 18, losses: 6, strikeouts: 120, era: 2.2)),
          isNot(contains('エース賞'))); // 奪三振
      expect(_awards(_pitch(wins: 16, losses: 14, strikeouts: 190, era: 2.2)),
          isNot(contains('エース賞'))); // 勝率
      expect(
          _awards(_pitch(
              wins: 18, losses: 6, strikeouts: 190, era: 2.2, outs: 300)),
          isNot(contains('エース賞'))); // 投球回
    });

    test('20勝投手・4割打者・トリプルスリー・50本塁打', () {
      expect(_awards(_pitch(wins: 20, losses: 8, strikeouts: 150, era: 3.0)),
          contains('20勝投手'));
      expect(_awards(_pitch(wins: 19, losses: 8, strikeouts: 150, era: 3.0)),
          isNot(contains('20勝投手')));
      expect(_awards(_bat(hits: 225, homeRuns: 20)), contains('4割打者'));
      expect(_awards(_bat(hits: 215, homeRuns: 20)), isNot(contains('4割打者')));
      expect(_awards(_bat(hits: 170, homeRuns: 30, stolen: 30)),
          contains('トリプルスリー'));
      expect(_awards(_bat(hits: 170, homeRuns: 30, stolen: 25)),
          isNot(contains('トリプルスリー')));
      expect(_awards(_bat(hits: 150, homeRuns: 50)), contains('50本塁打'));
    });

    test('通算の大記録: 1000・1500・2000試合出場と1000四球', () {
      expect(careerMarks(const Line(games: 990), const Line(games: 1010)),
          contains('通算1000試合出場'));
      expect(careerMarks(const Line(games: 1000), const Line(games: 1010)),
          isNot(contains('通算1000試合出場')));
      expect(careerMarks(const Line(walks: 990), const Line(walks: 1005)),
          contains('通算1000四球'));
    });
  });

  group('連続タイトル・入団会見', () {
    SeasonRecord rec(List<String> titles, {Stage stage = Stage.pro}) =>
        SeasonRecord(age: 25, stage: stage, line: const Line(), titles: titles);

    test('連続した年数を数える(間が空けば切れる・アマの記録は数えない)', () {
      final rs = [
        rec(['首位打者']),
        rec(['首位打者']),
        rec([]),
        rec(['本塁打王']),
        rec(['本塁打王']),
        rec(['MVP', '本塁打王']),
      ];
      expect(longestTitleStreak(rs), 3);
      expect(currentTitleStreak(rs), 3);
      expect(currentTitleStreak([...rs, rec([])]), 0);
      expect(
          longestTitleStreak([
            rec(['首位打者'], stage: Stage.highSchool)
          ]),
          0);
      expect(longestTitleStreak(const []), 0);
    });

    test('入団会見のひとこと: 1位は期待が大きく、順位が低いと二軍から', () {
      expect(pressConferenceNote(1, 18), contains('背番号18'));
      expect(pressConferenceNote(1, 18), contains('新人王'));
      expect(pressConferenceNote(3, null), isNot(contains('背番号')));
      expect(pressConferenceNote(6, 30), contains('二軍'));
    });

    test('実績: 5年連続のタイトル', () {
      PlayerSnapshot snap(int years) => PlayerSnapshot(
            name: 'p',
            role: Role.batter,
            age: 35,
            stage: Stage.retired,
            potential: 60,
            abilities: {for (final a in batterAbilities) a: 50},
            traits: const {},
            records: [
              for (var i = 0; i < years; i++) rec(['首位打者'])
            ],
            events: const [],
            overallHistory: const [],
          );
      expect(earnedBy(snap(5)), contains('title-streak'));
      expect(earnedBy(snap(4)), isNot(contains('title-streak')));
    });

    test('一生を遊ぶと、ドラフトの入団会見がログに出る', () {
      var seen = 0;
      for (var s = 0; s < 10; s++) {
        final g = Game.newGame(
            name: 'a', role: Role.batter, rng: Random(s), potential: 95);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 4000) {
          switch (g.phase) {
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.term:
              g.autoSpend();
              g.choose(Plan.train, Ability.contact);
            case Phase.retired:
              break;
          }
        }
        if (g.log.any((l) => l.startsWith('入団会見'))) seen++;
      }
      expect(seen, greaterThan(0));
    });
  });

  group('アマの大会の表彰', () {
    test('優勝して出来が高ければ最優秀選手、2回戦以上で出来が良ければ優秀選手', () {
      expect(
          tournamentAwardsOf(roundsWon: 5, rounds: 5, rating: 70), ['大会最優秀選手']);
      expect(
          tournamentAwardsOf(roundsWon: 5, rounds: 5, rating: 60), ['大会優秀選手']);
      expect(
          tournamentAwardsOf(roundsWon: 3, rounds: 5, rating: 60), ['大会優秀選手']);
      expect(tournamentAwardsOf(roundsWon: 3, rounds: 5, rating: 50), isEmpty);
      expect(tournamentAwardsOf(roundsWon: 1, rounds: 5, rating: 90), isEmpty);
      expect(tournamentAwardsOf(roundsWon: 0, rounds: 0, rating: 90), isEmpty);
    });

    test('一生を遊ぶと、アマの記録に大会の表彰が付くことがある(名前はこの2つだけ)', () {
      final names = <String>{};
      for (var s = 0; s < 25; s++) {
        final g = Game.newGame(
            name: 'a', role: Role.batter, rng: Random(s), potential: 90);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 4000) {
          switch (g.phase) {
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.term:
              g.autoSpend();
              g.choose(Plan.train, Ability.contact);
            case Phase.retired:
              break;
          }
        }
        for (final r in g.records.where((r) => !r.isLeague)) {
          names.addAll(r.awards);
        }
      }
      expect(names, isNotEmpty);
      expect(names.difference({'大会優秀選手', '大会最優秀選手'}), isEmpty);
    });
  });

  group('実績', () {
    test('三冠王・投手三冠・エース賞・トリプルスリー・シリーズMVP・大会の主役', () {
      PlayerSnapshot snap(String award) => PlayerSnapshot(
            name: 'p',
            role: Role.batter,
            age: 30,
            stage: Stage.retired,
            potential: 60,
            abilities: {for (final a in batterAbilities) a: 50},
            traits: const {},
            records: [
              SeasonRecord(
                  age: 25,
                  stage: Stage.pro,
                  line: const Line(),
                  awards: [award]),
            ],
            events: const [],
            overallHistory: const [],
          );
      for (final (award, id) in [
        ('三冠王', 'triple-crown'),
        ('投手三冠', 'pitch-triple-crown'),
        ('エース賞', 'ace-award'),
        ('トリプルスリー', 'triple-three'),
        ('シリーズMVP', 'series-mvp'),
        ('大会最優秀選手', 'amateur-mvp'),
      ]) {
        expect(earnedBy(snap(award)), contains(id), reason: award);
        expect(earnedBy(snap('ベストナイン')), isNot(contains(id)), reason: id);
      }
    });
  });
}
