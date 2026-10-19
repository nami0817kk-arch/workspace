import 'package:baseball_manager/game/awards.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _a(Line l,
        {bool first = false,
        int? prev,
        int fielding = 50,
        bool batter = true}) =>
    awardsOf(l,
        games: 143,
        firstYear: first,
        prevGames: prev,
        fielding: fielding,
        isBatter: batter);

const _slugger = Line(
    games: 140,
    atBats: 520,
    hits: 170,
    totalBases: 300,
    walks: 80,
    homeRuns: 35,
    rbi: 100);

void main() {
  group('表彰', () {
    test('平凡な成績では何も出ない', () {
      expect(_a(const Line(games: 100, atBats: 300, hits: 70, totalBases: 90)),
          isEmpty);
    });
    test('好成績の初年度は新人王とベストナイン', () {
      final a = _a(_slugger, first: true);
      expect(a, containsAll(['新人王', 'ベストナイン']));
    });
    test('2年目以降は新人王が出ない', () {
      expect(_a(_slugger), isNot(contains('新人王')));
    });
    test('守備が高いとゴールデングラブ', () {
      expect(_a(_slugger, fielding: 80), contains('ゴールデングラブ'));
      expect(_a(_slugger, fielding: 60), isNot(contains('ゴールデングラブ')));
    });
    test('前年に大きく休んだあとの好成績はカムバック賞', () {
      expect(_a(_slugger, prev: 60), contains('カムバック賞'));
      expect(_a(_slugger, prev: 140), isNot(contains('カムバック賞')));
    });
    test('保存と読み込みで表彰が残る(古い保存は空)', () {
      final r = SeasonRecord.fromJson(SeasonRecord(
        age: 25,
        stage: Stage.pro,
        line: _slugger,
        awards: const ['新人王'],
      ).toJson());
      expect(r.awards, ['新人王']);
      expect(SeasonRecord.fromJson({'age': 20}).awards, isEmpty);
    });
  });
}
