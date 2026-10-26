import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/marks.dart';
import 'package:baseball_manager/game/path.dart' show overall;
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
  markTests6();
  markTests7();
  markTests8();
  markTests9();
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
    expect(
        heroNoteOf(const Line(faced: 12, outs: 9, hitsAllowed: 1)), '無安打に近い好投');
    expect(
        heroNoteOf(
            const Line(faced: 12, outs: 9, hitsAllowed: 3, strikeouts: 6)),
        '6奪三振');
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

void markTests6() {
  SeasonRecord yr(int age, {List<String> titles = const [], int rank = 3}) =>
      SeasonRecord(
          age: age,
          stage: Stage.pro,
          line: const Line(games: 140, atBats: 500, hits: 150),
          rank: rank,
          titles: titles);
  test('殿堂入り投票: 10年未満は資格なし。レジェンドは入り、平凡は届かない', () {
    final short = [for (var a = 20; a < 26; a++) yr(a)];
    expect(
        hallOfFameVote(records: short, title: 'レジェンド', madePro: true), isNull);
    final legend = [
      for (var a = 20; a < 36; a++) yr(a, titles: ['本塁打王'], rank: 1)
    ];
    final v = hallOfFameVote(records: legend, title: 'レジェンド', madePro: true);
    expect(inHallOfFame(v), isTrue);
    final plain = [for (var a = 20; a < 32; a++) yr(a)];
    expect(
        inHallOfFame(
            hallOfFameVote(records: plain, title: '一流選手', madePro: true)),
        isFalse);
    expect(hallOfFameVote(records: legend, title: 'x', madePro: false), isNull);
  });
}

void markTests7() {
  test('順位表: 自分は指定の順位に居て、勝ち数は順位どおりに並ぶ', () {
    const league = [
      '青波ホークス',
      '北斗ベアーズ',
      '朱雀ファルコンズ',
      '紅葉ジャガーズ',
      '銀嶺ライオンズ',
      '黒潮マリナーズ',
    ];
    for (var rank = 1; rank <= 6; rank++) {
      final wins = 100 - rank * 9;
      final t = standingsOf(
          team: '大和スターズ',
          rank: rank,
          wins: wins,
          losses: 143 - wins,
          age: 25,
          league: league);
      expect(t.length, 6);
      expect(t[rank - 1].mine, isTrue);
      expect(t[rank - 1].wins, wins);
      expect(t.where((r) => r.mine).length, 1);
      for (var i = 1; i < 6; i++) {
        expect(t[i].wins, lessThanOrEqualTo(t[i - 1].wins),
            reason: 'rank $rank');
      }
      expect({for (final r in t) r.team}.length, 6);
    }
  });
}

void markTests8() {
  test('後輩・同期・年齢の節目・1年のまとめ', () {
    expect(kohaiOf('青波ホークス', 25), kohaiOf('青波ホークス', 25));
    final m = classmatesOf('はると', '青波ホークス');
    expect(m.length, 3);
    expect(m.every((e) => e.$2 >= 1 && e.$2 <= 6), isTrue);
    expect(ageNote(18), contains('進路'));
    expect(ageNote(19), isNull);
    expect(yearSummaryOf(7, 3), contains('7回'));
  });
}

void markTests9() {
  test('背番号の格上げ・ライバルの通算・成長の見通し', () {
    SeasonRecord r(List<String> titles) => SeasonRecord(
        age: 25, stage: Stage.pro, line: const Line(), titles: titles);
    expect(specialNumberOf(Role.pitcher, [r([])]), isNull);
    expect(
        specialNumberOf(Role.pitcher, [
          r(['最多勝'])
        ]),
        18);
    expect(
        specialNumberOf(Role.batter, [
          r(['本塁打王'])
        ]),
        3);
    final s = storyOf('ひかる', 90);
    expect(rivalStatsOf(s, 17), isNull);
    expect(rivalStatsOf(s, 23), contains('本塁打'));
    final p = Player(
        name: 't',
        role: Role.batter,
        age: 18,
        potential: 90,
        abilities: {for (final a in batterAbilities) a: 50});
    final now = overall(p).round();
    expect(projectedOverall(p, Ability.contact, 18), now);
    expect(projectedOverall(p, Ability.contact, 25), greaterThan(now));
    final old = p.copyWith(age: 36);
    expect(projectedOverall(old, Ability.contact, 41), lessThanOrEqualTo(now));
  });
}
