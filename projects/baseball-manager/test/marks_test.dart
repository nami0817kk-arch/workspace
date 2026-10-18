import 'package:baseball_manager/game/marks.dart';
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
