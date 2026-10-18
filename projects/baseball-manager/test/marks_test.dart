import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/marks.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/rival_story.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role r, Map<Ability, int> a) => Player(
    name: 't',
    role: r,
    age: 25,
    potential: 50,
    abilities: {for (final x in abilitiesOf(r)) x: a[x] ?? 40});

void main() {
  markTests2();
  markTests3();
  markTests4();
  markTests5();
  test('通算の節目: 越えた年にだけ出る', () {
    expect(careerMarks(const Line(), const Line(hits: 150, homeRuns: 20)),
        containsAll(['プロ初安打', 'プロ初本塁打', '通算100安打']));
    expect(careerMarks(const Line(hits: 120), const Line(hits: 180)), isEmpty);
    expect(
        careerMarks(const Line(wins: 95), const Line(wins: 104)), ['通算100勝']);
    expect(
        careerMarks(const Line(strikeouts: 990), const Line(strikeouts: 1010)),
        ['通算1000奪三振']);
  });
  test('愛称は一番高い能力から、低すぎると無し', () {
    expect(nicknameOf(_p(Role.batter, {Ability.power: 80})), '大砲');
    expect(nicknameOf(_p(Role.pitcher, {Ability.stuff: 75})), '剛腕');
    expect(nicknameOf(_p(Role.batter, {})), '');
  });
  test('打順と投手の役割', () {
    expect(lineupRoleOf(_p(Role.batter, {Ability.power: 85})), '4番');
    expect(lineupRoleOf(_p(Role.batter, {Ability.speed: 70, Ability.eye: 65})),
        '1番');
    expect(lineupRoleOf(_p(Role.pitcher, {Ability.stamina: 70})), '先発');
    expect(
        lineupRoleOf(
            _p(Role.pitcher, {Ability.stamina: 40, Ability.stuff: 80})),
        '抑え');
    expect(lineupRoleOf(_p(Role.pitcher, {Ability.stamina: 40})), '中継ぎ');
  });
  test('怪我の名前とコーチの一言', () {
    expect(injuryNameOf(20, 3), injuryNameOf(20, 3));
    expect(injuryNameOf(20, 3), isNotEmpty);
    expect(coachWordOf(_p(Role.batter, {Ability.speed: 10})), contains('走力'));
  });
}

void markTests2() {
  test('殊勲の理由・自己ベスト・目安', () {
    expect(heroNoteOf(const Line(atBats: 4, hits: 2, homeRuns: 2)), '2本塁打');
    expect(heroNoteOf(const Line(atBats: 5, hits: 4)), '猛打賞');
    expect(heroNoteOf(const Line(atBats: 4, hits: 1)), '大活躍');
    final rs = [
      SeasonRecord(
          age: 24,
          stage: Stage.pro,
          line: const Line(games: 100, atBats: 400, hits: 100, homeRuns: 10)),
      SeasonRecord(
          age: 26,
          stage: Stage.pro,
          line: const Line(games: 100, atBats: 400, hits: 130, homeRuns: 30)),
    ];
    final h = careerHighs(rs);
    expect(h.firstWhere((e) => e.label == '本塁打').age, 26);
    expect(h.firstWhere((e) => e.label == '打率').value, '.325');
    expect(h.any((e) => e.label == '勝利'), isFalse);
    expect(declineAge(), 30);
    expect(fanClubOf(0), 0);
    expect(fanClubOf(80), greaterThan(fanClubOf(40)));
    expect(
        afterCareerOf(
            title: 'レジェンド',
            proYears: 18,
            popularity: 80,
            money: 0,
            madePro: true),
        contains('監督'));
    expect(
        afterCareerOf(
            title: 'x', proYears: 0, popularity: 0, money: 0, madePro: false),
        isNotEmpty);
  });
}

void markTests3() {
  test('ライバル対決・日本シリーズ・パレード・子ども', () {
    final s = storyOf('ひかる', 90);
    final good = rivalDuelLine(
        s, 22, 1, const Line(atBats: 80, hits: 35, totalBases: 70, walks: 10));
    final bad = rivalDuelLine(s, 22, 1, const Line(atBats: 80, hits: 10));
    expect(good, contains('上回った'));
    expect(bad, contains('競り負け'));
    expect(rivalDuelLine(s, 22, 0, const Line()), isNull); // 対決は決まった月だけ
    expect(rivalDuelLine(s, 15, 1, const Line()), isNull); // まだプロでない
    // 同じ入力なら同じ結果。出来が良いほど勝ちやすい。
    const great =
        Line(games: 140, atBats: 500, hits: 190, totalBases: 380, walks: 90);
    expect(wonSeries('t', 25, great), wonSeries('t', 25, great));
    var wins = 0, winsPoor = 0;
    for (var age = 20; age < 220; age++) {
      if (wonSeries('t', age, great)) wins++;
      if (wonSeries('t', age, const Line(games: 140, atBats: 500, hits: 90))) {
        winsPoor++;
      }
    }
    expect(wins, greaterThan(winsPoor));
    expect(paradeCrowd(80), greaterThan(paradeCrowd(0)));
    expect(childrenOf('みさき'), inInclusiveRange(1, 3));
  });
}

void markTests4() {
  test('CM出演料は人気が高いほど多い。出身地は名前で決まる', () {
    expect(cmFeeOf(10), 0);
    expect(cmFeeOf(40), 1000);
    expect(cmFeeOf(95), greaterThan(cmFeeOf(75)));
    expect(hometownOf('はると'), hometownOf('はると'));
    expect(hometownOf('はると'),
        endsWith(RegExp(r'[都道府県]').stringMatch(hometownOf('はると'))!));
  });
}

void markTests5() {
  test('スローガン・球場・体格・趣味・座右の銘は名前などから決まり、体格は成長する', () {
    expect(sloganOf('青波ホークス', 20), sloganOf('青波ホークス', 20));
    expect(stadiumOf('青波ホークス'), isNotEmpty);
    expect(hobbyOf('はると'), isNotEmpty);
    String cm(int age) =>
        RegExp(r'身長(\d+)cm').firstMatch(bodyOf('はると', age))!.group(1)!;
    expect(int.parse(cm(18)), greaterThan(int.parse(cm(8))));
    expect(int.parse(cm(18)), inInclusiveRange(172, 185));
    expect(mottoOf(_p(Role.batter, {Ability.power: 80})), contains('豪快'));
  });
}
