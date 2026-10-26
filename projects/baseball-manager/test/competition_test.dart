// 実際の野球に合わせた試合の形式(2026-10-26)。
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/competition.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('アマの大会の呼び名', () {
    test('高校は地方大会 → 全国大会', () {
      expect(amateurRoundLabel(Stage.highSchool, 0, 5), '地方大会 準決勝');
      expect(amateurRoundLabel(Stage.highSchool, 1, 5), '地方大会 決勝');
      expect(amateurRoundLabel(Stage.highSchool, 4, 5), '全国大会 決勝');
      expect(amateurQualifyIndex(Stage.highSchool, 5), 2);
      expect(amateurQualifyLine(Stage.highSchool), contains('全国大会へ'));
    });

    test('大学はリーグ戦 → 大学選手権、社会人は都市対抗', () {
      expect(amateurEventName(Stage.pathChoice), '大学選手権');
      expect(amateurRoundLabel(Stage.pathChoice, 0, 4), 'リーグ戦 優勝決定戦');
      expect(amateurEventName(Stage.pathChoice, corporate: true), '都市対抗');
      expect(amateurRoundLabel(Stage.pathChoice, 0, 4, corporate: true),
          '地区予選 代表決定戦');
      expect(amateurQualifyIndex(Stage.pathChoice, 4), 1);
    });

    test('結果の文: 初戦・途中・準優勝・優勝', () {
      expect(amateurLossLine(Stage.highSchool, 0, 5), '夏の大会は初戦で敗れた。');
      expect(amateurLossLine(Stage.highSchool, 1, 5), '夏の大会は地方大会の決勝で敗れた。');
      expect(amateurLossLine(Stage.highSchool, 4, 5), '夏の大会は準優勝。');
      // 大会名と段の名前が同じなら重ねない
      expect(amateurLossLine(Stage.pathChoice, 1, 4), '大学選手権は準々決勝で敗れた。');
      expect(amateurLossLine(Stage.pathChoice, 1, 4, corporate: true), '都市対抗は本大会の準々決勝で敗れた。');
      expect(amateurChampionLine(Stage.highSchool), '夏の大会で全国優勝した!');
      expect(amateurChampionLine(Stage.pathChoice, corporate: true), '都市対抗で優勝した!');
      for (final s in [Stage.youth, Stage.juniorHigh, Stage.highSchool, Stage.pathChoice]) {
        expect(amateurChampionLine(s), endsWith('優勝した!'));
      }
    });

    test('形式に合わない回戦数は、一般的な呼び名に戻る', () {
      expect(amateurRoundLabel(Stage.highSchool, 0, 3), '1回戦');
      expect(amateurRoundLabel(Stage.highSchool, 2, 3), '決勝');
      expect(amateurQualifyIndex(Stage.highSchool, 3), isNull);
    });

    test('成績表の結果欄', () {
      const hs = SeasonRecord(
          age: 17, stage: Stage.highSchool, line: Line(), roundsWon: 2, rounds: 5);
      expect(hs.resultText, '全国大会 準々決勝敗退');
      const corp = SeasonRecord(
          age: 20,
          stage: Stage.pathChoice,
          line: Line(),
          roundsWon: 4,
          rounds: 4,
          corporate: true);
      expect(corp.resultText, '都市対抗優勝');
      const pro = SeasonRecord(
          age: 25, stage: Stage.pro, line: Line(), rank: 3, post: '日本一');
      expect(pro.resultText, '3位・日本一');
    });
  });

  group('プロのポストシーズン', () {
    test('4位以下は出ない。3位までは CS から', () {
      final none = playPostseason(
          name: 't', age: 25, rank: 4, winPct: 0.48, rating: 50);
      expect(none.lines, isEmpty);
      expect(none.result, isEmpty);
      final third = playPostseason(
          name: 't', age: 25, rank: 3, winPct: 0.52, rating: 50);
      expect(third.lines.first, startsWith('クライマックスシリーズ ファーストステージ'));
      final first = playPostseason(
          name: 't', age: 25, rank: 1, winPct: 0.62, rating: 50);
      expect(first.lines.first, startsWith('クライマックスシリーズ ファイナルステージ'));
      expect(first.lines.first, contains('アドバンテージ'));
    });

    test('同じ入力なら同じ結果。強いほど日本一になりやすく、1位は2位・3位より上', () {
      int count(int rank, double pct, int rating) {
        var n = 0;
        for (var age = 20; age < 620; age++) {
          if (playPostseason(
                  name: 'た', age: age, rank: rank, winPct: pct, rating: rating)
              .champion) {
            n++;
          }
        }
        return n;
      }

      final a = playPostseason(name: 'x', age: 30, rank: 1, winPct: .6, rating: 60);
      final b = playPostseason(name: 'x', age: 30, rank: 1, winPct: .6, rating: 60);
      expect(a.lines, b.lines);
      final top = count(1, 0.62, 50);
      final third = count(3, 0.52, 50);
      expect(top, greaterThan(third));
      expect(count(1, 0.62, 80), greaterThan(count(1, 0.62, 30)));
      // 1位でも日本一は半分に届かない程度(CSと日本シリーズの2つを勝つ)
      expect(top / 600, inInclusiveRange(0.2, 0.55));
    });

    test('シリーズは先に4勝(ファイナルは6試合、日本シリーズは7試合まで)', () {
      for (var age = 20; age < 200; age++) {
        final ps = playPostseason(
            name: 'し', age: age, rank: 2, winPct: 0.56, rating: 55, team: draftTeams.first);
        for (final l in ps.lines) {
          final m = RegExp(r'([○●]+) (\d+)勝(\d+)敗').firstMatch(l)!;
          final games = m.group(1)!.length;
          final w = int.parse(m.group(2)!), lo = int.parse(m.group(3)!);
          if (l.contains('ファーストステージ')) {
            expect(games, lessThanOrEqualTo(3));
            expect(max(w, lo), 2);
          } else if (l.contains('ファイナルステージ')) {
            expect(games, lessThanOrEqualTo(6));
          } else {
            expect(l, contains('日本シリーズ'));
            expect(l, isNot(contains(draftTeams.first)));
            expect(games, lessThanOrEqualTo(7));
            expect(max(w, lo), 4);
          }
        }
      }
    });
  });

  test('ゲームの中: プロの年に「夏の大会」が出ず、6月は交流戦、3位までは CS が出る', () {
    var proYears = 0, cs = 0, inter = 0;
    for (var seed = 0; seed < 30 && proYears < 30; seed++) {
      final g = Game.newGame(
          name: 'リアル', role: Role.batter, rng: Random(seed), potential: 95);
      var n = 0;
      while (g.phase != Phase.retired && n++ < 4000) {
        g.autoSpend();
        final before = g.log.length;
        final pro = g.stage == Stage.pro;
        switch (g.phase) {
          case Phase.term:
            g.choose(Plan.train, abilitiesOf(g.player.role).first);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
        if (!pro) continue;
        final added = g.log.sublist(before);
        for (final l in added) {
          expect(l, isNot(contains('夏の大会')), reason: l);
          if (l.contains('(交流戦)')) inter++;
          if (l.contains('クライマックスシリーズ')) cs++;
        }
        if (added.any((l) => l.startsWith('契約更改'))) proYears++;
      }
    }
    expect(proYears, greaterThan(5));
    expect(inter, greaterThan(0));
    expect(cs, greaterThan(0));
  });
}
