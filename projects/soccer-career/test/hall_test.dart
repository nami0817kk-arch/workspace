/// 引退した選手が、記録として残るか。
///
/// これまで引退画面に「この選手の記録は消えます」と書いてあって、
/// 新しいキャリアを始めた瞬間に本当に消えていた。
/// 20年ぶんの選択の結果が、次の選手を作るために捨てられていた。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hall_screen.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

/// 保存領域を持たない環境でも回るように、殿堂も差し替える。
class _MemoryHall implements HallRepository {
  Hall _saved = const Hall();

  @override
  Future<Hall> load() async => _saved;

  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

Future<CareerController> started({int seed = 3, int age = 34}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    hallRepository: _MemoryHall(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: age,
    agent: Agent.pool.first,
  );
  return c;
}

SeasonRecord record({
  required int year,
  required String clubName,
  int tier = 1,
  int position = 5,
  CupStage cup = CupStage.none,
  ContinentalStage continental = ContinentalStage.none,
  int overall = 70,
}) => SeasonRecord(
  year: year,
  clubName: clubName,
  tier: tier,
  leaguePosition: position,
  stats: const SeasonStats(
    appearances: 30,
    goals: 8,
    assists: 5,
    averageRating: 7.1,
  ),
  cupStage: cup,
  continentalStage: continental,
  overall: overall,
);

void main() {
  group('引退した選手が残る', () {
    test('引退した時点で殿堂に入る', () async {
      // 引退画面のボタンを押したときにすると、
      // 押さずに終える人の記録が消える。
      final c = await started();
      final state = c.state!;
      state.history.add(record(year: 2030, clubName: 'A'));
      expect(c.hall.isEmpty, isTrue);

      await c.retire();
      expect(c.hall.legends.length, 1);
      expect(c.hall.legends.first.name, '検証');
    });

    test('新しいキャリアを始めても消えない', () async {
      final c = await started();
      c.state!.history.add(record(year: 2030, clubName: 'A'));
      await c.retire();
      await c.deleteCareer();

      expect(c.hasCareer, isFalse);
      expect(c.hall.legends.length, 1, reason: '新しいキャリアで殿堂が消えた');
    });

    test('引退のたびに積み上がる。新しい順に並ぶ', () async {
      final c = await started();
      c.state!.history.add(record(year: 2030, clubName: 'A'));
      await c.retire();
      await c.deleteCareer();

      await c.startCareer(
        name: '2人目',
        position: Position.st,
        age: 34,
        agent: Agent.pool.first,
      );
      c.state!.history.add(record(year: 2031, clubName: 'B'));
      await c.retire();

      expect(c.hall.legends.length, 2);
      expect(c.hall.legends.first.name, '2人目', reason: '新しい順に並んでいない');
    });

    test('消せる。消したものは戻らない', () async {
      final c = await started();
      c.state!.history.add(record(year: 2030, clubName: 'A'));
      await c.retire();
      await c.removeLegend(0);
      expect(c.hall.isEmpty, isTrue);
      // 範囲外は何も起きない。
      await c.removeLegend(3);
      expect(c.hall.isEmpty, isTrue);
    });

    test('残す数には上限がある', () {
      var hall = const Hall();
      for (var i = 0; i < Hall.keep + 5; i++) {
        hall = hall.add(Legend.fromJson({'name': '$i'}));
      }
      expect(hall.legends.length, Hall.keep);
      // あふれるのは古いほう。
      expect(hall.legends.first.name, '${Hall.keep + 4}');
    });
  });

  group('何を残すか', () {
    test('歩んだクラブが順に残る。戻ってきたら別の区切り', () async {
      final c = await started();
      final state = c.state!;
      state.history.addAll([
        record(year: 2030, clubName: 'A', tier: 2),
        record(year: 2031, clubName: 'A', tier: 1),
        record(year: 2032, clubName: 'B'),
        record(year: 2033, clubName: 'A'),
      ]);
      await c.retire();

      // 引退した年も1シーズンとして記録に入るので、最後に今のクラブが付く。
      final spells = c.hall.legends.first.spells;
      expect(spells.map((s) => s.clubName).take(3).toList(), ['A', 'B', 'A']);
      expect(spells.last.clubName, c.state!.club.name);
      expect(spells[0].clubName, 'A');
      expect(spells[0].seasons, 2);
      // 2部と1部を跨いだら、上のほうを残す。
      expect(spells[0].tier, 1);
      expect(spells[1].clubName, 'B');
      expect(spells[2].clubName, 'A', reason: '戻ってきたぶんが1つにまとめられている');
    });

    test('総合力は引退時ではなくピークを残す', () async {
      // 衰えた後の数字だけが残るのは、その選手の記録として正しくない。
      final c = await started();
      final state = c.state!;
      state.history.addAll([
        record(year: 2030, clubName: 'A', overall: 84),
        record(year: 2031, clubName: 'A', overall: 78),
      ]);
      await c.retire();
      expect(c.hall.legends.first.peakOverall, greaterThanOrEqualTo(84));
    });

    test('タイトルを数える', () async {
      final c = await started();
      final state = c.state!;
      state.history.addAll([
        record(year: 2030, clubName: 'A', position: 1),
        record(year: 2031, clubName: 'A', cup: CupStage.winner),
        record(year: 2032, clubName: 'A', continental: ContinentalStage.winner),
        record(year: 2033, clubName: 'A', position: 3),
      ]);
      await c.retire();

      final legend = c.hall.legends.first;
      expect(legend.leagueTitles, 1);
      expect(legend.cupTitles, 1);
      expect(legend.continentalTitles, 1);
      expect(legend.titles, 3);
    });

    test('改変の印は殿堂にも持ち込む', () async {
      // ここで落とすと、改変済みの記録が普通の記録に紛れる。
      final c = await started();
      c.state!.tampered = true;
      c.state!.history.add(record(year: 2030, clubName: 'A'));
      await c.retire();
      expect(c.hall.legends.first.tampered, isTrue);
    });

    test('保存を往復しても中身が残る', () async {
      final c = await started();
      final state = c.state!;
      state.reputation = state.reputation.copyWith(
        awards: [Award.debut, Award.topScorer],
      );
      state.history.add(record(year: 2030, clubName: 'A'));
      await c.retire();

      final json = c.hall.toJson();
      final back = Hall.fromJson(json);
      final legend = back.legends.first;
      expect(legend.name, '検証');
      expect(legend.awards, contains(Award.topScorer));
      expect(legend.traits, c.hall.legends.first.traits);
      expect(legend.secondCareer, c.hall.legends.first.secondCareer);
    });

    test('知らない鍵が欠けていても読める', () {
      final legend = Legend.fromJson({'name': '古い記録'});
      expect(legend.name, '古い記録');
      expect(legend.spells, isEmpty);
      expect(legend.secondCareer, SecondCareer.quiet);
    });
  });

  group('画面', () {
    testWidgets('居なければ、そう書く', (tester) async {
      final c = await started();
      await tester.pumpWidget(MaterialApp(home: HallScreen(controller: c)));
      await tester.pumpAndSettle();
      expect(find.textContaining('まだ居ない'), findsOneWidget);
    });

    test('額の格は、獲ったタイトルだけで決まる', () {
      // 見た目のためだけの数字は作らない。カードに書いてあるものと同じ。
      Legend with_({int league = 0, int cup = 0, int continental = 0}) =>
          Legend.fromJson({
            'name': 'x',
            'leagueTitles': league,
            'cupTitles': cup,
            'continentalTitles': continental,
          });
      expect(HallPlaque.of(with_()), HallPlaque.bronze);
      expect(HallPlaque.of(with_(cup: 1)), HallPlaque.silver);
      expect(HallPlaque.of(with_(league: 1)), HallPlaque.silver);
      expect(HallPlaque.of(with_(continental: 1)), HallPlaque.gold);
      // 大陸を獲っていれば、他が無くても金。
      expect(HallPlaque.of(with_(league: 3, continental: 1)), HallPlaque.gold);
    });

    testWidgets('ピーク総合力が額に出る', (tester) async {
      final c = await started();
      c.state!.history.add(record(year: 2030, clubName: 'A', overall: 84));
      await c.retire();

      await tester.pumpWidget(MaterialApp(home: HallScreen(controller: c)));
      await tester.pumpAndSettle();
      final peak = c.hall.legends.first.peakOverall;
      // 歴代の記録カードにも同じ数字が出るので、1つとは限らない。
      expect(find.text('$peak'), findsWidgets);
      expect(find.text('ピーク'), findsOneWidget);
      expect(find.text('歴代の記録'), findsOneWidget);
    });

    testWidgets('引退した選手が並ぶ', (tester) async {
      final c = await started();
      c.state!.history.add(record(year: 2030, clubName: 'アルバ04'));
      await c.retire();

      await tester.pumpWidget(MaterialApp(home: HallScreen(controller: c)));
      await tester.pumpAndSettle();
      // 歴代の記録にも名前が出る（1人しか居なければ全部その人）。
      expect(find.text('検証'), findsWidgets);
      expect(find.textContaining('アルバ04'), findsWidgets);
      expect(find.textContaining('引退後'), findsOneWidget);
    });
  });
}
